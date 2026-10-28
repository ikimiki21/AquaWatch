// Estimated water level from two calibration readings (empty and full).
enum LevelBand { normal, low, high }

class LevelEstimator {
  int? empty;
  int? full;
  LevelBand? band;
  static const lowBelow = 20;
  static const highAt = 90;
  // Percentage points a level must recover by before leaving low/high,
  // so a reading hovering on a boundary cannot spam alerts.
  static const margin = 3;
  // Calibration points closer than this are too noisy to scale between.
  static const minSpan = 10;

  bool get calibrated =>
      empty != null && full != null && (full! - empty!).abs() >= minSpan;

  // Works whether the sensor reads higher or lower when wet.
  int? percent(int value) {
    if (!calibrated) return null;
    final ratio = (value - empty!) / (full! - empty!);
    return (ratio * 100).round().clamp(0, 100);
  }

  LevelBand? update(int value) {
    final level = percent(value);
    if (level == null) {
      band = null;
    } else if (level >= highAt) {
      band = LevelBand.high;
    } else if (level < lowBelow) {
      band = LevelBand.low;
    } else if (band == LevelBand.high && level >= highAt - margin) {
      // Still high until it drops clear of the margin.
    } else if (band == LevelBand.low && level < lowBelow + margin) {
      // Still low until it rises clear of the margin.
    } else {
      band = LevelBand.normal;
    }
    return band;
  }

  void clear() {
    empty = null;
    full = null;
    band = null;
  }
}
