import 'package:aquawatch/level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calibration points too close together give no estimate', () {
    final level = LevelEstimator()
      ..empty = 300
      ..full = 305;
    expect(level.calibrated, false);
    expect(level.percent(500), isNull);
    expect(level.levelOf(500), isNull);
    expect(level.update(500), isNull);
  });
  test('matches the documented depth trials on the 0-9 scale', () {
    final level = LevelEstimator();
    expect(level.empty, 50);
    expect(level.full, 550);
    const trials = {
      35: 0,
      105: 1,
      158: 2,
      215: 3,
      270: 4,
      325: 5,
      380: 6,
      435: 7,
      490: 8,
      545: 9,
    };
    trials.forEach((raw, expected) => expect(level.levelOf(raw), expected));
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
    expect(level.levelOf(0), 0);
    expect(level.levelOf(1023), 9);
  });
  test('works when the reading drops as water rises', () {
    final level = LevelEstimator()
      ..empty = 900
      ..full = 200;
    expect(level.percent(900), 0);
    expect(level.percent(550), 50);
    expect(level.percent(200), 100);
    expect(level.levelOf(900), 0);
    expect(level.levelOf(200), 9);
  });
  test('low below level 3, full at level 7, with a recovery margin', () {
    final level = LevelEstimator()
      ..empty = 0
      ..full = 1000;
    expect(level.update(500), LevelBand.halfway);
    // 290 is still inside the margin, so it takes 270 to leave halfway.
    expect(level.update(290), LevelBand.halfway);
    expect(level.update(270), LevelBand.low);
    expect(level.update(310), LevelBand.low);
    expect(level.update(330), LevelBand.halfway);
    expect(level.update(300), LevelBand.halfway);
    expect(level.update(730), LevelBand.full);
    expect(level.update(690), LevelBand.full);
    expect(level.update(670), LevelBand.halfway);
  });
  test('reset restores the documented baselines', () {
    final level = LevelEstimator()
      ..empty = 400
      ..full = 405;
    expect(level.calibrated, false);
    level.reset();
    expect(level.empty, LevelEstimator.defaultEmpty);
    expect(level.full, LevelEstimator.defaultFull);
    expect(level.band, isNull);
    expect(level.calibrated, true);
  });
}
