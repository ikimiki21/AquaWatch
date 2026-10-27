import 'package:aquawatch/usb_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('USB frames, timeout, recovery, denial and detach', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const codec = StandardMethodCodec();
    const device = <String, Object>{
      'deviceName': '/dev/bus/usb/001/002',
      'vid': 9025,
      'pid': 67,
      'deviceId': 2,
      'productName': 'Arduino Uno',
      'manufacturerName': 'Arduino',
      'serialNumber': 'TEST',
      'interfaceCount': 2,
    };
    var attached = true;
    var denied = false;
    final parameters = <String, dynamic>{};
    final writes = <String>[];
    messenger.setMockMethodCallHandler(const MethodChannel('usb_serial'), (
      call,
    ) async {
      if (call.method == 'listDevices') return attached ? [device] : [];
      if (call.method == 'create') {
        if (denied) throw PlatformException(code: 'permission_denied');
        return 'test_port';
      }
      return null;
    });
    messenger.setMockMethodCallHandler(const MethodChannel('test_port'), (
      call,
    ) async {
      if (call.method == 'setPortParameters') {
        parameters.addAll(Map<String, dynamic>.from(call.arguments as Map));
      }
      if (call.method == 'write') {
        writes.add(
          String.fromCharCodes((call.arguments as Map)['data'] as List<int>),
        );
      }
      if (call.method == 'open' || call.method == 'close') return true;
      return null;
    });
    for (final name in ['usb_serial/usb_events', 'test_port/stream']) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
    }
    Future<void> send(String channel, Object payload) async {
      await messenger.handlePlatformMessage(
        channel,
        codec.encodeSuccessEnvelope(payload),
        (_) {},
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    final usb = UsbController()..start();
    addTearDown(usb.dispose);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(usb.connected, true);
    expect(usb.hasReading, false);
    expect(parameters['baudRate'], 9600);
    await send(
      'test_port/stream',
      Uint8List.fromList('AQ,1,600\r\n'.codeUnits),
    );
    expect(usb.value, 600);
    expect(usb.detector.wet, true);
    expect(writes, ['CFG,400,1\n']);
    usb.configure(600, false);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(writes.last, 'CFG,600,0\n');
    usb.configure(400, true);
    // Use real elapsed time injection through the public timestamp for the watchdog.
    usb.lastReading = DateTime.now().subtract(const Duration(seconds: 5));
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(usb.connected, true);
    expect(usb.hasReading, false);
    expect(usb.value, isNull);
    expect(usb.detector.wet, isNull);
    await send(
      'test_port/stream',
      Uint8List.fromList('noise\nAQ,1,100\n'.codeUnits),
    );
    expect(usb.hasReading, true);
    expect(usb.detector.wet, false);

    await usb.disconnect();
    expect(usb.value, isNull);
    denied = true;
    await usb.connect(usb.devices.first);
    expect(usb.connected, false);
    expect(usb.connecting, false);
    expect(usb.message, contains('Could not connect'));
    denied = false;
    await usb.connect(usb.devices.first);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(usb.connected, true);
    attached = false;
    await send('usb_serial/usb_events', {
      ...device,
      'event': 'android.hardware.usb.action.USB_DEVICE_DETACHED',
    });
    expect(usb.connected, false);
    expect(usb.hasReading, false);
    expect(usb.devices, isEmpty);
    attached = true;
    await send('usb_serial/usb_events', {
      ...device,
      'event': 'android.hardware.usb.action.USB_DEVICE_ATTACHED',
    });
    expect(usb.connected, true);
    await usb.disconnect();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    for (final name in [
      'usb_serial',
      'test_port',
      'usb_serial/usb_events',
      'test_port/stream',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(name), null);
    }
  });
}
