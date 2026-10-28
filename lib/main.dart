import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'event_log.dart';
import 'level.dart';
import 'usb_controller.dart';

void main() => runApp(const AquaWatchApp());

const ink = Color(0xFF173C3B);
const teal = Color(0xFF087F79);

class AquaWatchApp extends StatelessWidget {
  const AquaWatchApp({super.key, this.startUsb = true});
  final bool startUsb;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'AquaWatch',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: teal),
      scaffoldBackgroundColor: const Color(0xFFF4F8F7),
      textTheme: ThemeData().textTheme.apply(bodyColor: ink, displayColor: ink),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF4F8F7)),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: teal,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    ),
    home: WatchPage(startUsb: startUsb),
  );
}

class WatchPage extends StatefulWidget {
  const WatchPage({super.key, required this.startUsb});
  final bool startUsb;
  @override
  State<WatchPage> createState() => _WatchPageState();
}

class _WatchPageState extends State<WatchPage> with WidgetsBindingObserver {
  final usb = UsbController(useWifi: true);
  final level = LevelEstimator();
  LevelBand? _alert;
  final log = EventLog();
  bool _wasConnected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    usb.addListener(_onUsb);
    if (widget.startUsb) usb.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.startUsb && state == AppLifecycleState.resumed) {
      unawaited(usb.scan());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    usb.removeListener(_onUsb);
    usb.dispose();
    super.dispose();
  }

  void _onUsb() {
    if (usb.connected != _wasConnected) {
      _wasConnected = usb.connected;
      if (usb.connected) {
        log.add('connected', usb.useWifi ? 'Wi-Fi' : 'USB');
      } else {
        log.add('disconnected', usb.message);
      }
    }
    final before = level.band;
    final after = usb.hasReading ? level.update(usb.value!) : null;
    level.band = after;
    if (after == before) return;
    // Only a new low/high transition raises the banner; anything else clears it.
    _alert = after == LevelBand.low || after == LevelBand.high ? after : null;
    final percent = usb.hasReading ? level.percent(usb.value!) : null;
    if (_alert != null) {
      log.add(
        'alert',
        '${_alert == LevelBand.high ? 'High' : 'Low'} water level ($percent%)',
      );
    } else if (after == LevelBand.normal &&
        (before == LevelBand.low || before == LevelBand.high)) {
      log.add('alert cleared', 'Level back to normal ($percent%)');
    }
  }

  String _time(DateTime t) =>
      [t.hour, t.minute, t.second].map((n) => '$n'.padLeft(2, '0')).join(':');

  Future<void> _copyCsv() async {
    await Clipboard.setData(ClipboardData(text: log.toCsv()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied ${log.events.length} events as CSV. Paste into a spreadsheet, note or email.',
        ),
      ),
    );
  }

  void _showLog() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text(
                  'Event log',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                trailing: TextButton.icon(
                  onPressed: log.events.isEmpty ? null : _copyCsv,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy CSV'),
                ),
              ),
              for (final e in log.events.reversed)
                ListTile(
                  dense: true,
                  leading: Text(_time(e.time)),
                  title: Text(e.type),
                  subtitle: Text(e.detail),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _calibrate({bool? full}) {
    setState(() {
      if (full == null) {
        level.clear();
      } else if (full) {
        level.full = usb.value;
      } else {
        level.empty = usb.value;
      }
      level.band = null;
      log.add(
        'calibration',
        full == null
            ? 'Cleared'
            : '${full ? 'Full' : 'Empty'} set to ${usb.value}',
      );
      _onUsb();
    });
  }

  Future<void> _connect() async {
    if (!widget.startUsb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Live USB monitoring requires the Android app and an OTG connection.',
          ),
        ),
      );
      return;
    }
    if (usb.useWifi) {
      await usb.connectWifi();
      return;
    }
    if (kIsWeb) {
      await usb.connectBrowser();
      return;
    }
    await usb.scan();
    if (!mounted || usb.connected || usb.connecting) return;
    if (usb.devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No USB device found. Connect the Uno with a data cable and OTG adapter.',
          ),
        ),
      );
      return;
    }
    if (usb.devices.length == 1) {
      await usb.connect(usb.devices.first);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Choose your Arduino')),
            for (final device in usb.devices)
              ListTile(
                leading: const Icon(Icons.usb_rounded),
                title: Text(device.productName ?? 'USB serial device'),
                subtitle: Text(
                  'VID ${device.vid?.toRadixString(16)} · PID ${device.pid?.toRadixString(16)}',
                ),
                onTap: () {
                  Navigator.pop(context);
                  unawaited(usb.connect(device));
                },
              ),
          ],
        ),
      ),
    );
  }

  void _settings() {
    var threshold = usb.detector.threshold.toDouble();
    var higher = usb.detector.higherMeansWet;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sensor settings',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Check the dry and wet readings, then set a threshold between them.',
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Detection threshold · ${threshold.round()}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Slider(
                    value: threshold,
                    min: 20,
                    max: 1003,
                    divisions: 983,
                    label: '${threshold.round()}',
                    onChanged: (value) => update(() => threshold = value),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Higher value means wet'),
                    subtitle: const Text(
                      'Turn off if the reading drops when water touches the sensor.',
                    ),
                    value: higher,
                    onChanged: (value) => update(() => higher = value),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Level calibration',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  ListenableBuilder(
                    listenable: usb,
                    builder: (context, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Empty · ${level.empty ?? '—'}   Full · ${level.full ?? '—'}'
                          '${usb.hasReading ? '   Now · ${usb.value}' : ''}',
                          style: const TextStyle(
                            color: Color(0xFF667F7D),
                            fontSize: 13,
                          ),
                        ),
                        if (level.empty != null &&
                            level.full != null &&
                            !level.calibrated)
                          const Text(
                            'Empty and full are too close together. Recalibrate.',
                            style: TextStyle(
                              color: Color(0xFFBA363E),
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: usb.hasReading
                                  ? () => update(() => _calibrate(full: false))
                                  : null,
                              child: const Text('Set empty'),
                            ),
                            OutlinedButton(
                              onPressed: usb.hasReading
                                  ? () => update(() => _calibrate(full: true))
                                  : null,
                              child: const Text('Set full'),
                            ),
                            TextButton(
                              onPressed:
                                  level.empty == null && level.full == null
                                  ? null
                                  : () => update(() => _calibrate()),
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                        const Text(
                          'Record empty with the sensor dry, then full with it in water up to the full mark.',
                          style: TextStyle(
                            color: Color(0xFF667F7D),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'A 20-point stability margin reduces flicker. Settings reset when the app restarts.',
                    style: TextStyle(color: Color(0xFF667F7D), fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        usb.configure(threshold.round(), higher);
                        Navigator.pop(context);
                      },
                      child: const Text('Apply settings'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: usb,
    builder: (context, _) {
      final wet = usb.hasReading ? usb.detector.wet : null;
      final statusColor = wet == null
          ? const Color(0xFF718582)
          : wet
          ? const Color(0xFFBA363E)
          : const Color(0xFF208354);
      final statusBackground = wet == null
          ? const Color(0xFFEDF2F1)
          : wet
          ? const Color(0xFFFFEEEE)
          : const Color(0xFFEBF7EF);
      return Scaffold(
        appBar: AppBar(
          titleSpacing: 24,
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.water_drop_rounded, color: teal, size: 26),
              SizedBox(width: 8),
              Text(
                'AquaWatch',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: -0.7,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _settings,
              tooltip: 'Sensor settings',
              icon: const Icon(Icons.tune_rounded),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_alert != null) ...[
                      LevelAlertBanner(
                        band: _alert!,
                        onDismiss: () => setState(() => _alert = null),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (!widget.startUsb) ...[
                      const Text(
                        'INTERFACE PREVIEW · USB REQUIRES ANDROID',
                        style: TextStyle(
                          fontSize: 10,
                          color: teal,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const Text(
                      'A little peace of mind.',
                      style: TextStyle(
                        fontSize: 28,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your water sensor, at a glance.',
                      style: TextStyle(color: Color(0xFF667F7D), fontSize: 15),
                    ),
                    const SizedBox(height: 20),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: true,
                          label: Text('Wi-Fi'),
                          icon: Icon(Icons.wifi_rounded),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text('USB'),
                          icon: Icon(Icons.usb_rounded),
                        ),
                      ],
                      selected: {usb.useWifi},
                      onSelectionChanged: usb.connecting
                          ? null
                          : (selection) => usb.setWifiMode(selection.first),
                    ),
                    if (usb.useWifi) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Join AquaWatch in your Wi-Fi settings.\nPassword: AquaWatch123 · No internet needed',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF667F7D),
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    _Panel(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.sensors_rounded,
                                color: teal,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'MOISTURE READING',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                              ),
                              Text(
                                usb.hasReading ? '● LIVE' : '○ WAITING',
                                style: TextStyle(
                                  color: usb.hasReading ? teal : statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE8F5F2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.water_drop_outlined,
                              size: 48,
                              color: teal,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            usb.hasReading ? '${usb.value}' : '—',
                            style: const TextStyle(
                              fontSize: 68,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -3,
                              height: 1.1,
                            ),
                          ),
                          const Text(
                            'RAW SENSOR VALUE · 0–1023',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.2,
                              color: Color(0xFF667F7D),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: LinearProgressIndicator(
                              value: usb.hasReading ? usb.value! / 1023 : 0,
                              minHeight: 6,
                              color: teal,
                              backgroundColor: const Color(0xFFEDF2F1),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Raw signal level, not a moisture percentage',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF667F7D),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _LevelPanel(
                      percent: usb.hasReading
                          ? level.percent(usb.value!)
                          : null,
                      band: level.band,
                      calibrated: level.calibrated,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: statusBackground,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            wet == null
                                ? Icons.hourglass_empty_rounded
                                : wet
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_outline_rounded,
                            color: statusColor,
                            size: 28,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  wet == null
                                      ? (usb.stale
                                            ? 'Reading unavailable'
                                            : 'Waiting for sensor')
                                      : wet
                                      ? 'Water Detected'
                                      : 'No Water Detected',
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  wet == null
                                      ? 'Status will appear with a live reading.'
                                      : wet
                                      ? 'Warning · water is present'
                                      : 'Normal · sensor is dry',
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                usb.useWifi
                                    ? Icons.wifi_rounded
                                    : Icons.usb_rounded,
                                color: teal,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Arduino Uno R3',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  usb.connecting
                                      ? 'Connecting…'
                                      : usb.connected
                                      ? 'Connected'
                                      : 'Disconnected',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: usb.connected
                                        ? teal
                                        : const Color(0xFF667F7D),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            usb.message,
                            style: const TextStyle(
                              color: Color(0xFF667F7D),
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                          if (usb.lastReading != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Last reading ${TimeOfDay.fromDateTime(usb.lastReading!).format(context)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF667F7D),
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: usb.connecting || usb.scanning
                                      ? null
                                      : usb.connected
                                      ? () => usb.disconnect()
                                      : _connect,
                                  icon: Icon(
                                    usb.connected
                                        ? Icons.link_off_rounded
                                        : usb.useWifi
                                        ? Icons.wifi_rounded
                                        : Icons.usb_rounded,
                                    size: 20,
                                  ),
                                  label: Text(
                                    usb.connected
                                        ? 'Disconnect'
                                        : usb.connecting
                                        ? 'Connecting…'
                                        : usb.useWifi
                                        ? 'Connect via Wi-Fi'
                                        : 'Connect Arduino',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.outlined(
                                onPressed:
                                    !widget.startUsb ||
                                        kIsWeb ||
                                        usb.useWifi ||
                                        usb.scanning ||
                                        usb.connecting
                                    ? null
                                    : () => usb.scan(),
                                tooltip: 'Refresh USB devices',
                                icon: const Icon(Icons.refresh_rounded),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EVENT LOG · ${log.events.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (log.events.isEmpty)
                            const Text(
                              'No events yet. Alerts and disconnects appear here.',
                              style: TextStyle(
                                color: Color(0xFF667F7D),
                                fontSize: 13,
                              ),
                            ),
                          for (final e in log.events.reversed.take(4))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                '${_time(e.time)}  ${e.type} · ${e.detail}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TextButton(
                                onPressed: log.events.isEmpty ? null : _showLog,
                                child: const Text('View all'),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: log.events.isEmpty ? null : _copyCsv,
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                label: const Text('Copy CSV'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Center(
                      child: Text(
                        'Local Wi-Fi or USB  ·  No internet needed',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF667F7D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

const levelColors = {
  LevelBand.normal: Color(0xFF208354),
  LevelBand.low: Color(0xFFB86E00),
  LevelBand.high: Color(0xFFBA363E),
};

class LevelAlertBanner extends StatelessWidget {
  const LevelAlertBanner({
    super.key,
    required this.band,
    required this.onDismiss,
  });
  final LevelBand band;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final color = levelColors[band]!;
    final high = band == LevelBand.high;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            high ? Icons.warning_rounded : Icons.water_drop_outlined,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              high
                  ? 'High water level · 90% or above'
                  : 'Low water level · below 20%',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            tooltip: 'Dismiss alert',
            icon: Icon(Icons.close_rounded, color: color),
          ),
        ],
      ),
    );
  }
}

class _LevelPanel extends StatelessWidget {
  const _LevelPanel({
    required this.percent,
    required this.band,
    required this.calibrated,
  });
  final int? percent;
  final LevelBand? band;
  final bool calibrated;

  @override
  Widget build(BuildContext context) {
    final color = levelColors[band] ?? const Color(0xFF718582);
    return _Panel(
      child: Row(
        children: [
          // Simple tank graphic filled to the estimated level.
          Container(
            width: 56,
            height: 96,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFB9CBC8), width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: (percent ?? 0) / 100,
              widthFactor: 1,
              child: ColoredBox(color: color.withValues(alpha: 0.75)),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ESTIMATED LEVEL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  percent == null ? '—' : '$percent%',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.5,
                    color: percent == null ? null : color,
                  ),
                ),
                Text(
                  !calibrated
                      ? 'Calibrate empty and full in Sensor settings.'
                      : switch (band) {
                          LevelBand.low => 'Low · below 20%',
                          LevelBand.high => 'High · 90% or above',
                          LevelBand.normal => 'Normal',
                          null => 'Waiting for a live reading.',
                        },
                  style: TextStyle(
                    fontSize: 12,
                    color: band == null ? const Color(0xFF667F7D) : color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE4ECE9)),
    ),
    child: child,
  );
}
