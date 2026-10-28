// In-memory event history (alerts, connects, disconnects), exportable as CSV.
class LogEvent {
  const LogEvent(this.time, this.type, this.detail);
  final DateTime time;
  final String type;
  final String detail;
}

class EventLog {
  final events = <LogEvent>[];
  static const maxEvents = 500;

  void add(String type, String detail, {DateTime? at}) {
    events.add(LogEvent(at ?? DateTime.now(), type, detail));
    if (events.length > maxEvents) events.removeAt(0);
  }

  String toCsv() {
    final rows = ['timestamp,event,detail'];
    for (final e in events) {
      rows.add(
        [e.time.toIso8601String(), e.type, e.detail].map(_field).join(','),
      );
    }
    return '${rows.join('\r\n')}\r\n';
  }

  static String _field(String value) {
    // Prefix spreadsheet formula characters so a cell cannot execute.
    if (value.startsWith(RegExp(r'[=+\-@]'))) value = "'$value";
    if (value.contains(RegExp(r'[",\r\n]'))) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
