import 'dart:async';
import 'wear_bridge.dart';
import 'window_buffer.dart';
import 'feature_extractor.dart';
import 'model/model_factory.dart';
import 'model/on_device_model.dart';
import 'scorer.dart';

class SWIPConfig {
  final int windowSeconds;
  final int stepSeconds;
  final String modelBackend;   // 'json_linear' | 'coreml' | 'onnx'
  final String modelAssetPath; // path or logical ref

  const SWIPConfig({
    this.windowSeconds = 60,
    this.stepSeconds = 10,
    this.modelBackend = 'json_linear',
    this.modelAssetPath = 'assets/models/svm_linear_v1_0.json',
  });
}

class SWIPManager {
  final WearBridge _wear;
  late final OnDeviceModel _model;
  final _feature = FeatureExtractor();
  final _scoresCtrl = StreamController<SwipScore>.broadcast();
  StreamSubscription? _sub;
  WindowBuffer<SwipSample>? _win;

  SWIPManager({WearBridge? wear}) : _wear = wear ?? WearBridge();

  Stream<SwipScore> get scores => _scoresCtrl.stream;

  Future<void> initialize({SWIPConfig config = const SWIPConfig()}) async {
    _win = WindowBuffer(
      window: Duration(seconds: config.windowSeconds),
      hop: Duration(seconds: config.stepSeconds),
    );
    _model = await ModelFactory.load(
      backend: config.modelBackend,
      modelRef: config.modelAssetPath,
    );
  }

  Future<void> start({SWIPConfig config = const SWIPConfig()}) async {
    await _wear.requestPermissions();
    await _wear.start();

    _sub = _wear.watch().listen((s) async {
      final w = _win!.push(s.ts, s, (x) => x.ts);
      if (w == null) return;
      final feats = _feature.toFeatures(w).values;
      final p = await _model.predict(feats);
      final score =
          SwipScorer.fromProbability(p: p, features: feats, info: _model.info);
      _scoresCtrl.add(score);
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    await _wear.stop();
    await _scoresCtrl.close();
    await _model.dispose();
  }
}
