// Water depth on the documented 0-9 scale, from two calibration readings.
// Empirical baselines: dry contacts read about 50, full immersion about 550.
enum LevelBand { low, halfway, full }

class LevelEstimator {
  int empty = defaultEmpty;
  int full = defaultFull;
  LevelBand? band;

  static const defaultEmpty = 50;
  static const defaultFull = 550;
  // Level 3 and level 7 begin here: the boundaries between the three states.
  static const lowEdge = 0.3;
  static const fullEdge = 0.7;
  // Calibration points closer than this are too noisy to scale between.
  static const minSpan = 10;
  // Fraction of the span a reading must clear before the band changes, so a
  // level resting on a boundary cannot flicker the LEDs.
  static const margin = 0.02;

  bool get calibrated => (full - empty).abs() >= minSpan;

  // Works whether the sensor reads higher or lower when wet.
  double? _ratio(int value) =>
      calibrated ? (value - empty) / (full - empty) : null;

  // 0 is dry, 9 is fully immersed.
  int? levelOf(int value) {
    final ratio = _ratio(value);
    return ratio == null ? null : (ratio * 10).floor().clamp(0, 9);
  }

  int? percent(int value) {
    final ratio = _ratio(value);
    return ratio == null ? null : (ratio * 100).round().clamp(0, 100);
  }

  LevelBand? update(int value) {
    final ratio = _ratio(value);
    if (ratio == null) return band = null;
    // A band holds until the reading clears its boundary by the margin.
    return band = switch (band) {
      LevelBand.low when ratio < lowEdge + margin => LevelBand.low,
      LevelBand.full when ratio >= fullEdge - margin => LevelBand.full,
      LevelBand.halfway
          when ratio >= lowEdge - margin && ratio < fullEdge + margin =>
        LevelBand.halfway,
      _ when ratio < lowEdge => LevelBand.low,
      _ when ratio < fullEdge => LevelBand.halfway,
      _ => LevelBand.full,
    };
  }

  void reset() {
    empty = defaultEmpty;
    full = defaultFull;
    band = null;
  }
}
