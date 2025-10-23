import 'dart:math';
import 'artifact.dart';

double? computeSdnnMs(List<double>? rrMs) {
  if (rrMs == null || rrMs.isEmpty) return null;
  final clean = rejectArtifacts(rrMs);
  if (clean.length < 10) return null;
  final mean = clean.reduce((a, b) => a + b) / clean.length;
  final varSum = clean.fold<double>(0.0, (s, v) => s + pow(v - mean, 2));
  return sqrt(varSum / clean.length);
}
