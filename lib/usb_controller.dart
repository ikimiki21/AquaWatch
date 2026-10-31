import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:usb_serial/usb_serial.dart';
import 'level.dart';
import 'sensor.dart';
import 'browser_serial_stub.dart'
    if (dart.library.js_interop) 'browser_serial_web.dart'
    as browser;

class UsbController extends ChangeNotifier {
  final level = LevelEstimator();
  List<UsbDevice> devices = [];
  UsbDevice? selected;
  int? value;
  DateTime? lastReading;
  bool connected = false;
  bool connecting = false;
  bool scanning = false;
  bool stale = false;
  String message = 'Connect your Arduino using a USB OTG adapter.';
  UsbPort? _port;
  StreamSubscription<Uint8List>? _input;
  StreamSubscription<UsbEvent>? _events;
  Timer? _watchdog;
  SensorDecoder _decoder = SensorDecoder();
  bool _disposed = false;
  bool _autoConnect = true;
  int _generation = 0;
  DateTime? _openedAt;
  bool _configurationSent = false;

  bool get hasReading => connected && !stale && value != null;

  void start() {
    if (kIsWeb) {
      message =
          'Click Connect Arduino, then choose Arduino Uno (COM8) in the browser.';
    } else {
      _events = UsbSerial.usbEventStream?.listen(
        (event) async {
          if (event.event == UsbEvent.ACTION_USB_DETACHED &&
              event.device?.deviceId == selected?.deviceId) {
            await disconnect(
              message: 'Arduino disconnected. Check the USB cable.',
            );
            _autoConnect = true;
          }
          await scan();
        },
        onError: (Object error) {
          message = 'USB event error. Tap refresh to scan again.';
          _notify();
        },
      );
    }
    _watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
      final reference = lastReading ?? _openedAt;
      if (connected &&
          reference != null &&
          DateTime.now().difference(reference) > const Duration(seconds: 4)) {
        stale = true;
        value = null;
        level.band = null;
        message = 'No readings. Check the sketch and cable, then reconnect.';
        _notify();
      }
    });
    unawaited(scan());
  }

  Future<void> scan() async {
    // Browsers require a user click to choose a serial port.
    if (kIsWeb) return;
    if (_disposed || scanning) return;
    scanning = true;
    _notify();
    try {
      final found = await UsbSerial.listDevices();
      if (_disposed) return;
      devices = found;
      if (selected != null &&
          !devices.any((d) => d.deviceId == selected!.deviceId)) {
        await disconnect(message: 'Arduino disconnected. Check the USB cable.');
        _autoConnect = true;
      }
      if (!connected && !connecting && _autoConnect && devices.length == 1) {
        await connect(devices.first);
      }
    } catch (_) {
      if (!_disposed) message = 'Unable to scan USB devices. Try refresh.';
    } finally {
      scanning = false;
      _notify();
    }
  }

  Future<void> connect(UsbDevice device) async {
    if (_disposed || connecting || connected) return;
    _autoConnect = false; // Avoid repeated prompts after permission denial.
    connecting = true;
    selected = device;
    message = 'Allow USB access when Android asks.';
    final generation = ++_generation;
    _notify();
    UsbPort? candidate;
    try {
      candidate = await device.create();
      if (candidate == null || !await candidate.open()) {
        throw StateError('USB permission denied or device unsupported');
      }
      await candidate.setPortParameters(
        9600,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );
      await candidate.setFlowControl(UsbPort.FLOW_CONTROL_OFF);
      await candidate.setDTR(true); // Uno may reset on opening.
      await candidate.setRTS(true);
      if (_disposed || generation != _generation) {
        await _close(candidate);
        return;
      }
      final stream = candidate.inputStream;
      if (stream == null) throw StateError('No USB input stream');
      _port = candidate;
      _configurationSent = false;
      _decoder = SensorDecoder();
      value = null;
      lastReading = null;
      level.band = null;
      stale = false;
      connected = true;
      _openedAt = DateTime.now();
      message = 'Connected. Waiting for Arduino to start…';
      _input = stream.listen(
        (bytes) {
          _receive(bytes, generation);
        },
        onError: (Object error) {
          if (generation == _generation) {
            unawaited(
              disconnect(message: 'USB read failed. Reconnect the Arduino.'),
            );
          }
        },
        onDone: () {
          if (generation == _generation) {
            unawaited(
              disconnect(
                message: 'USB connection closed. Reconnect to continue.',
              ),
            );
          }
        },
      );
    } catch (_) {
      await _close(candidate);
      if (!_disposed && generation == _generation) {
        _port = null;
        connected = false;
        selected = null;
        message =
            'Could not connect. Allow USB access and check your OTG cable.';
      }
    } finally {
      if (generation == _generation) connecting = false;
      _notify();
    }
  }

  Future<void> connectBrowser() async {
    if (!kIsWeb || _disposed || connecting || connected) return;
    connecting = true;
    message = 'Choose Arduino Uno (COM8) in the browser connection dialog.';
    final generation = ++_generation;
    _notify();
    try {
      await browser.connect((bytes) => _receive(bytes, generation), () {
        if (!_disposed && generation == _generation) {
          unawaited(
            disconnect(message: 'Arduino disconnected. Check the USB cable.'),
          );
        }
      });
      if (_disposed || generation != _generation) {
        await browser.disconnect();
        return;
      }
      _decoder = SensorDecoder();
      _configurationSent = false;
      value = null;
      lastReading = null;
      level.band = null;
      stale = false;
      connected = true;
      _openedAt = DateTime.now();
      message = 'Connected. Waiting for the Uno to start…';
    } catch (_) {
      if (!_disposed && generation == _generation) {
        message =
            'Connection cancelled or port busy. Close Serial Monitor, then choose Arduino Uno (COM8).';
      }
    } finally {
      if (generation == _generation) connecting = false;
      _notify();
    }
  }

  void _receive(List<int> bytes, int generation) {
    if (_disposed || generation != _generation) return;
    for (final reading in _decoder.add(bytes)) {
      value = reading;
      level.update(reading);
      lastReading = DateTime.now();
      stale = false;
      message = 'Readings update automatically every 0.5 seconds.';
      // Send after the first frame so a DTR-triggered Uno reset cannot lose it.
      if (!_configurationSent) unawaited(_sendConfiguration());
    }
    _notify();
  }

  Future<void> _sendConfiguration() async {
    _configurationSent = true;
    final command = 'CAL,${level.empty},${level.full}\n';
    try {
      if (kIsWeb) {
        await browser.write(command);
      } else {
        await _port?.write(Uint8List.fromList(command.codeUnits));
      }
    } catch (_) {
      _configurationSent = false;
      message = 'Could not sync LED settings. Reconnect the Arduino.';
      _notify();
    }
  }

  Future<void> disconnect({
    String message = 'Disconnected. Tap Connect to resume.',
  }) async {
    ++_generation;
    _autoConnect = false;
    final input = _input;
    final port = _port;
    _input = null;
    _port = null;
    connected = false;
    connecting = false;
    selected = null;
    value = null;
    lastReading = null;
    stale = false;
    level.band = null;
    this.message = message;
    _notify();
    await input?.cancel();
    await _close(port);
    if (kIsWeb) await browser.disconnect();
  }

  void configure(int empty, int full) {
    level.empty = empty.clamp(0, 1023);
    level.full = full.clamp(0, 1023);
    level.band = null;
    if (hasReading) level.update(value!);
    if (connected) unawaited(_sendConfiguration());
    _notify();
  }

  static Future<void> _close(UsbPort? port) async {
    try {
      await port?.close();
    } catch (_) {
      /* Already unplugged. */
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _watchdog?.cancel();
    unawaited(_events?.cancel());
    unawaited(_input?.cancel());
    unawaited(_close(_port));
    if (kIsWeb) unawaited(browser.disconnect());
    super.dispose();
  }
}
