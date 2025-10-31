import 'dart:async';
import 'models.dart';
import 'errors.dart';
import 'synheart_wear_adapter.dart';
import 'package:synheart_emotion/synheart_emotion.dart' as emo;

class SWIPManager {
  final SynheartWearAdapter wear;
  emo.EmotionEngine? _emotionEngine;
  final _emotionCtrl = StreamController<EmotionPrediction>.broadcast();
  Timer? _emotionTimer;
  StreamSubscription<({double? hr, List<double>? rrMs, DateTime ts})>?
      _emotionInputSub;

  bool _initialized = false;
  String? _activeSessionId;

  SWIPManager({
    SynheartWearAdapter? adapter,
  }) : wear = adapter ?? SynheartWearAdapter();

  Future<void> initialize() async {
    await wear.initialize();
    // Load ONNX model from assets and initialize engine
    final onnx = await emo.OnnxEmotionModel.loadFromAsset(
      modelAssetPath: 'assets/ml/extratrees_wrist_all_v1_0.onnx',
      metaAssetPath: 'assets/ml/extratrees_wrist_all_v1_0.meta.json',
    );
    _emotionEngine = emo.EmotionEngine.fromPretrained(
      const emo.EmotionConfig(
        window: Duration(seconds: 60),
        step: Duration(seconds: 5),
        minRrCount: 10,
      ),
      model: onnx,
      onLog: (level, message, {context}) {
        // ignore: avoid_print
        print('[SWIP][EMO][' +
            level +
            '] ' +
            message +
            (context != null ? ' ' + context.toString() : ''));
      },
    );
    _initialized = true;
  }

  Future<String> startSession({required SWIPSessionConfig config}) async {
    if (!_initialized) {
      throw InvalidConfigurationError('SWIPManager not initialized');
    }

    _activeSessionId = await wear.startCollection(config);

    // Start feeding emotion engine from wearable HR stream
    _emotionInputSub?.cancel();
    _emotionInputSub = wear
        .emotionInputStream(interval: const Duration(seconds: 2))
        .listen((e) {
      final hr = e.hr;
      if (hr == null) return;
      // Debug: log incoming wearable tick
      // ignore: avoid_print
      print('[SWIP][EMO] tick hr=' +
          hr.toStringAsFixed(1) +
          ' rr=' +
          ((e.rrMs?.length ?? 0)).toString() +
          ' ts=' +
          e.ts.toIso8601String());
      _emotionEngine?.push(
        hr: hr,
        rrIntervalsMs: (e.rrMs ?? const <double>[]),
        // Use current time to avoid trimming stale HealthKit timestamps
        timestamp: DateTime.now().toUtc(),
      );
    });

    // Periodically consume results and emit mapped predictions
    _emotionTimer?.cancel();
    _emotionTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      // Debug: buffer stats before inference
      final stats = _emotionEngine?.getBufferStats();
      if (stats != null) {
        // ignore: avoid_print
        print('[SWIP][EMO] buffer count=' +
            (stats['count'] as int).toString() +
            ' rr=' +
            (stats['rr_count'] as int).toString() +
            ' dur_ms=' +
            (stats['duration_ms'] as int).toString());
      }
      final results =
          await _emotionEngine?.consumeReady() ?? const <emo.EmotionResult>[];
      for (final r in results) {
        final pred = _mapEmotionResult(r);
        _emotionCtrl.add(pred);
        _onEmotionUpdate(pred);
      }
      if (results.isEmpty) {
        // ignore: avoid_print
        print('[SWIP][EMO] no emission this tick');
      }
    });

    return _activeSessionId!;
  }

  Future<SWIPSessionResults> endSession() async {
    if (_activeSessionId == null) {
      throw SessionNotFoundError();
    }

    _emotionTimer?.cancel();
    _emotionTimer = null;
    await _emotionInputSub?.cancel();
    _emotionInputSub = null;

    final results = await wear.stopAndEvaluate(_activeSessionId!);
    _activeSessionId = null;
    return results;
  }

  Future<SWIPMetrics> getCurrentMetrics() async {
    final hrv = await wear.readCurrentHRV();
    return SWIPMetrics(hrv: hrv, timestamp: DateTime.now());
  }

  /// Get stream of real-time emotion predictions
  Stream<EmotionPrediction> get emotionStream => _emotionCtrl.stream;

  /// Get current emotion state (best-effort: last emitted)
  EmotionPrediction? _lastEmotion;
  EmotionPrediction? get currentEmotion => _lastEmotion;

  /// Check if emotion recognition is available
  bool get isEmotionRecognitionAvailable => _emotionEngine != null;

  /// Get available emotion classes
  List<String> get emotionClasses => const ['Calm', 'Stressed', 'Amused'];

  /// Add heart rate data for emotion analysis (manual feed)
  void addHeartRateData(double heartRate, DateTime timestamp) {
    _emotionEngine?.push(
        hr: heartRate,
        rrIntervalsMs: const <double>[],
        timestamp: timestamp.toUtc());
  }

  /// Add RR interval data for emotion analysis (manual feed)
  void addRRIntervalData(double rrIntervalMs, DateTime timestamp) {
    _emotionEngine?.push(
        hr: 60000.0 / rrIntervalMs,
        rrIntervalsMs: [rrIntervalMs],
        timestamp: timestamp.toUtc());
  }

  /// Handle emotion prediction updates
  void _onEmotionUpdate(EmotionPrediction prediction) {
    // This can be overridden or extended by users of the SDK
    // For now, we'll just log the prediction
    _lastEmotion = prediction;
    print(
        'Emotion detected: ${prediction.emotion.label} (confidence: ${prediction.confidence.toStringAsFixed(2)})');
  }

  /// Dispose resources
  void dispose() {
    _emotionTimer?.cancel();
    _emotionInputSub?.cancel();
    _emotionCtrl.close();
  }

  EmotionPrediction _mapEmotionResult(emo.EmotionResult r) {
    final label = r.emotion.toLowerCase();
    final cls = switch (label) {
      'calm' => EmotionClass.calm,
      'stressed' => EmotionClass.stressed,
      'amused' => EmotionClass.amused,
      _ => EmotionClass.baseline,
    };
    // Order probabilities in [calm, stressed, amused] if available
    final probs = <double>[
      r.probabilities['Calm'] ?? r.probabilities['calm'] ?? 0.0,
      r.probabilities['Stressed'] ?? r.probabilities['stressed'] ?? 0.0,
      r.probabilities['Amused'] ?? r.probabilities['amused'] ?? 0.0,
    ];
    return EmotionPrediction(
      emotion: cls,
      probabilities: probs,
      confidence: r.confidence,
      timestamp: r.timestamp,
    );
  }
}
