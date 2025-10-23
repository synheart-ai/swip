import 'dart:math';
import 'sdnn.dart';
import 'wear_bridge.dart';

class FeatureVector {
  final List<double> values; // schema order
  FeatureVector(this.values);
}

class FeatureExtractor {
  static const schema = ["hr_mean", "sdnn_ms", "accel_mag_mean", "accel_mag_std"];

  FeatureVector toFeatures(List<SwipSample> window) {
    // HR mean
    final hrs = window.map((s) => s.hrBpm).whereType<double>().toList();
    final hrMean =
        hrs.isEmpty ? double.nan : hrs.reduce((a, b) => a + b) / hrs.length;

    // SDNN
    final sdnnFromApple =
        window.map((s) => s.sdnnMs).whereType<double>().toList();
    final sdnnAppleMedian =
        sdnnFromApple.isEmpty ? null : _median(sdnnFromApple);

    final rrAll = window
        .map((s) => s.rrMs)
        .whereType<List<double>>()
        .expand((e) => e)
        .toList();
    final sdnnComputed = rrAll.isEmpty ? null : computeSdnnMs(rrAll);
    final sdnn = sdnnAppleMedian ?? sdnnComputed ?? double.nan;

    // Accel
    final mags = window
        .map((s) => s.accelG)
        .whereType<({double x, double y, double z})>()
        .map((a) => sqrt(a.x * a.x + a.y * a.y + a.z * a.z))
        .toList();
    final accelMean =
        mags.isEmpty ? double.nan : mags.reduce((a, b) => a + b) / mags.length;
    final accelStd = mags.length < 2 ? double.nan : _std(mags);

    return FeatureVector([hrMean, sdnn, accelMean, accelStd]);
  }

  double _median(List<double> xs) {
    final a = [...xs]..sort();
    final n = a.length;
    return n.isOdd ? a[n >> 1] : 0.5 * (a[n ~/ 2 - 1] + a[n ~/ 2]);
    }

  double _std(List<double> xs) {
    final m = xs.reduce((a, b) => a + b) / xs.length;
    final vs = xs.fold<double>(0, (s, v) => s + (v - m) * (v - m));
    return sqrt(vs / xs.length);
  }
}
