// Crude artifact rejection for RR intervals (ms)
List<double> rejectArtifacts(List<double> rrMs) {
  final bounded = rrMs.where((v) => v >= 300 && v <= 2000).toList();
  if (bounded.length < 10) return const [];
  bounded.sort();
  final med = bounded[bounded.length ~/ 2];
  final keep = bounded.where((v) => (v - med).abs() <= med * 0.25).toList();
  return keep.length >= 10 ? keep : const [];
}
