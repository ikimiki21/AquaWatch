import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:aquawatch/sensor.dart';

void main() {
  test('decodes fragmented packets, CRLF, and multiple readings', () {
    final decoder = SensorDecoder();
    expect(decoder.add(utf8.encode('AQ,1,4')), isEmpty);
    expect(decoder.add(utf8.encode('20\r\nAQ,1,0\nAQ,1,1023\n')), [
      420,
      0,
      1023,
    ]);
  });
  test('rejects noise, wrong versions, invalid values and oversized lines', () {
    final decoder = SensorDecoder();
    expect(
      decoder.add(utf8.encode('42\nAQ,2,200\nAQ,1,-1\nAQ,1,1024\nAQ,1,1.0\n')),
      isEmpty,
    );
    expect(decoder.add(utf8.encode('${'x' * 10000}AQ,1,400\nAQ,1,500\n')), [
      500,
    ]);
    expect(decoder.add([255, ...utf8.encode('AQ,1,600\nAQ,1,700\n')]), [700]);
  });
}
