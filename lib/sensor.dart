// USB packets can contain part of a line, or several lines at once.
class SensorDecoder {
  String _line = '';
  bool _discarding = false;

  List<int> add(List<int> bytes) {
    final readings = <int>[];
    for (final byte in bytes) {
      if (byte == 10) {
        if (!_discarding) {
          final match = RegExp(r'^AQ,1,([0-9]{1,4})\r?$').firstMatch(_line);
          final value = match == null ? null : int.tryParse(match.group(1)!);
          if (value != null && value <= 1023) readings.add(value);
        }
        _line = '';
        _discarding = false;
      } else if (!_discarding) {
        if (_line.length >= 32 || byte > 127) {
          _line = '';
          _discarding = true;
        } else {
          _line += String.fromCharCode(byte);
        }
      }
    }
    return readings;
  }
}
