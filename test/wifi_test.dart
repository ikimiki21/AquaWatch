import 'dart:convert';
import 'package:aquawatch/usb_controller.dart';
import 'package:aquawatch/wifi_link.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, Object> sample({
  int value = 500,
  int threshold = 400,
  bool higher = true,
}) => {
  'device': 'AquaWatch',
  'version': 1,
  'value': value,
  'threshold': threshold,
  'higherMeansWet': higher,
  'waterDetected': higher ? value >= threshold : value <= threshold,
  'sampleAgeMs': 100,
};

void main() {
  test('rejects stale, malformed and unrelated HTTP responses', () {
    for (final payload in [
      {...sample(), 'sampleAgeMs': 3001},
      {...sample(), 'value': 1024},
      {...sample(), 'value': 3.4},
      {...sample(), 'threshold': 0},
      {...sample(), 'device': 'Another device'},
      {...sample(), 'waterDetected': 'true'},
      <String, Object>{},
    ]) {
      expect(
        () => WifiReading.parse(jsonEncode(payload)),
        throwsFormatException,
      );
    }
    expect(WifiReading.parse(jsonEncode(sample(value: 0))).value, 0);
  });

  test(
    'reads only from the local ESP address and rejects missing Uno data',
    () async {
      var available = true;
      final link = WifiLink(
        client: MockClient((request) async {
          expect(request.url.toString(), 'http://192.168.4.1/api/reading');
          return available
              ? http.Response(jsonEncode(sample()), 200)
              : http.Response('{}', 503);
        }),
      );
      addTearDown(link.close);
      expect((await link.read()).wet, true);
      available = false;
      await expectLater(link.read(), throwsStateError);
    },
  );

  test('settings wait for matching Uno telemetry after POST', () async {
    var reads = 0;
    final link = WifiLink(
      client: MockClient((request) async {
        if (request.method == 'POST') {
          expect(request.url.path, '/api/config');
          expect(request.bodyFields, {
            'threshold': '600',
            'higherMeansWet': '0',
          });
          return http.Response('{"pending":true}', 202);
        }
        reads++;
        return http.Response(
          jsonEncode(
            reads == 1 ? sample() : sample(threshold: 600, higher: false),
          ),
          200,
        );
      }),
    );
    addTearDown(link.close);
    final confirmed = await link.configure(600, false);
    expect(reads, 2);
    expect(confirmed.threshold, 600);
    expect(confirmed.higherMeansWet, false);
  });

  test('unconfirmed UART settings fail rather than claiming success', () async {
    final link = WifiLink(
      client: MockClient(
        (request) async => request.method == 'POST'
            ? http.Response('{}', 202)
            : http.Response(jsonEncode(sample()), 200),
      ),
    );
    addTearDown(link.close);
    await expectLater(link.configure(600, false), throwsStateError);
  });

  test(
    'Wi-Fi monitor clears lost readings, retries, and cancels polling',
    () async {
      var available = true;
      var calls = 0;
      final controller = UsbController(
        useWifi: true,
        wifiLink: WifiLink(
          client: MockClient((request) async {
            calls++;
            if (!available) throw http.ClientException('Offline');
            return http.Response(jsonEncode(sample()), 200);
          }),
        ),
      );
      addTearDown(controller.dispose);
      await controller.connectWifi();
      expect(controller.hasReading, true);
      expect(controller.detector.wet, true);
      available = false;
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(controller.connected, false);
      expect(controller.value, isNull);
      expect(controller.detector.wet, isNull);
      available = true;
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(controller.hasReading, true);
      await controller.setWifiMode(false);
      final previousCalls = calls;
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(calls, previousCalls);
      expect(controller.hasReading, false);
    },
  );
}
