# swip_core (Flutter)

SWIP SDK core – integrates with `synheart_wear`, computes SDNN, runs a tiny on‑device model, and streams a 0–100 SWIP score.

## Quick start
```dart
final swip = SWIPManager();
await swip.initialize(
  config: const SWIPConfig(
    modelBackend: 'json_linear',
    modelAssetPath: 'assets/models/svm_linear_v1_0.json',
  ),
);
await swip.start();
swip.scores.listen((s) {
  print('SWIP ${s.score0to100.toStringAsFixed(1)} via ${s.modelInfo.id}');
});
```
