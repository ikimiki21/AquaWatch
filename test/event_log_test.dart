import 'package:aquawatch/event_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exports timestamped CSV with escaping', () {
    final log = EventLog()
      ..add('alert', 'Low water level (12%)', at: DateTime(2026, 10, 28, 9, 5))
      ..add(
        'disconnect',
        'Unplugged, "check" cable',
        at: DateTime(2026, 10, 28, 9, 6),
      )
      ..add('note', '=SUM(A1)', at: DateTime(2026, 10, 28, 9, 7));
    expect(
      log.toCsv(),
      'timestamp,event,detail\r\n'
      '2026-10-28T09:05:00.000,alert,Low water level (12%)\r\n'
      '2026-10-28T09:06:00.000,disconnect,"Unplugged, ""check"" cable"\r\n'
      "2026-10-28T09:07:00.000,note,'=SUM(A1)\r\n",
    );
  });
  test('keeps only the newest events', () {
    final log = EventLog();
    for (var i = 0; i < EventLog.maxEvents + 5; i++) {
      log.add('alert', '$i');
    }
    expect(log.events.length, EventLog.maxEvents);
    expect(log.events.first.detail, '5');
  });
}
