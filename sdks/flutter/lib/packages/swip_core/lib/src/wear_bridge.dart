import 'dart:async';
import 'package:synheart_wear/synheart_wear.dart' as wear;

class SwipSample {
  final DateTime ts;
  final double? hrBpm;
  final double? sdnnMs;       // Apple SDNN if available
  final List<double>? rrMs;   // For computed SDNN
  final ({double x, double y, double z})? accelG;

  SwipSample({
    required this.ts,
    this.hrBpm,
    this.sdnnMs,
    this.rrMs,
    this.accelG,
  });
}

class WearBridge {
  Stream<SwipSample> watch() {
    final src = wear.Wear().stream();
    return src.map((e) => SwipSample(
          ts: e.timestamp,
          hrBpm: e.hrBpm,
          sdnnMs: e.sdnnMs,
          rrMs: e.rrMs,
          accelG: e.accelG == null
              ? null
              : (x: e.accelG!.x, y: e.accelG!.y, z: e.accelG!.z),
        ));
  }

  Future<void> requestPermissions() => wear.Wear().requestPermissions();
  Future<void> start() => wear.Wear().start();
  Future<void> stop() => wear.Wear().stop();
}
