import 'package:aquawatch/level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uncalibrated or too-close calibration gives no estimate', () {
    final level = LevelEstimator();
    expect(level.percent(500), isNull);
    level.empty = 300;
    expect(level.percent(500), isNull);
    level.full = 305;
    expect(level.calibrated, false);
    expect(level.update(500), isNull);
  });
  test('scales and clamps between empty and full', () {
    final level = LevelEstimator()
      ..empty = 100
      ..full = 600;
    expect(level.percent(100), 0);
    expect(level.percent(350), 50);
    expect(level.percent(600), 100);
    expect(level.percent(0), 0);
    expect(level.percent(1023), 100);
  });
  test('works when the reading drops as water rises', () {
    final level = LevelEstimator()
      ..empty = 900
      ..full = 200;
    expect(level.percent(900), 0);
    expect(level.percent(550), 50);
    expect(level.percent(200), 100);
  });
  test('low below 20%, high at 90%, with a recovery margin', () {
    final level = LevelEstimator()
      ..empty = 0
      ..full = 1000;
    expect(level.update(500), LevelBand.normal);
    expect(level.update(190), LevelBand.low);
    expect(level.update(210), LevelBand.low);
    expect(level.update(230), LevelBand.normal);
    expect(level.update(200), LevelBand.normal);
    expect(level.update(900), LevelBand.high);
    expect(level.update(880), LevelBand.high);
    expect(level.update(860), LevelBand.normal);
    level.clear();
    expect(level.update(500), isNull);
  });
}
