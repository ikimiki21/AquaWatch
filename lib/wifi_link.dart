import 'dart:convert';
import 'package:http/http.dart' as http;

class WifiReading {
  const WifiReading(this.value, this.threshold, this.higherMeansWet, this.wet);
  final int value;
  final int threshold;
  final bool higherMeansWet;
  final bool wet;

  factory WifiReading.parse(String body) {
    final data = jsonDecode(body);
    if (data is! Map<String, dynamic> ||
        data['device'] != 'AquaWatch' ||
        data['version'] != 1 ||
        data['value'] is! int ||
        data['value'] < 0 ||
        data['value'] > 1023 ||
        data['threshold'] is! int ||
        data['threshold'] < 20 ||
        data['threshold'] > 1003 ||
        data['higherMeansWet'] is! bool ||
        data['waterDetected'] is! bool ||
        data['sampleAgeMs'] is! int ||
        data['sampleAgeMs'] < 0 ||
        data['sampleAgeMs'] > 3000) {
      throw const FormatException('Invalid or stale AquaWatch reading');
    }
    return WifiReading(
      data['value'],
      data['threshold'],
      data['higherMeansWet'],
      data['waterDetected'],
    );
  }
}

class WifiLink {
  WifiLink({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  static final _readingUri = Uri.parse('http://192.168.4.1/api/reading');
  static final _configUri = Uri.parse('http://192.168.4.1/api/config');

  Future<WifiReading> read() async {
    final response = await _client
        .get(_readingUri)
        .timeout(const Duration(seconds: 2));
    if (response.statusCode != 200) throw StateError('No fresh Uno reading');
    return WifiReading.parse(response.body);
  }

  Future<WifiReading> configure(int threshold, bool higherMeansWet) async {
    final response = await _client
        .post(
          _configUri,
          body: {
            'threshold': '$threshold',
            'higherMeansWet': higherMeansWet ? '1' : '0',
          },
        )
        .timeout(const Duration(seconds: 2));
    if (response.statusCode != 202) throw StateError('Settings rejected');
    // Verify actual Uno telemetry, rather than assuming the UART command arrived.
    for (var attempt = 0; attempt < 6; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final reading = await read();
      if (reading.threshold == threshold &&
          reading.higherMeansWet == higherMeansWet) {
        return reading;
      }
    }
    throw StateError('Uno did not confirm the settings');
  }

  void close() => _client.close();
}
