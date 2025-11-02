import 'dart:async';
import 'models.dart';
import 'errors.dart';
import 'synheart_wear_adapter.dart';
import 'ml/emotion_recognition_controller.dart';

class SWIPManager {
  final SynheartWearAdapter wear;
  final EmotionRecognitionController emotionController;
  
  bool _initialized = false;
  String? _activeSessionId;
  StreamSubscription<EmotionPrediction>? _emotionSubscription;

  SWIPManager({
    SynheartWearAdapter? adapter,
    EmotionRecognitionController? emotionController,
  }) : wear = adapter ?? SynheartWearAdapter(),
       emotionController = emotionController ?? EmotionRecognitionController();

  Future<void> initialize() async {
    await wear.initialize();
    await emotionController.initialize();
    _initialized = true;
  }

  Future<String> startSession({required SWIPSessionConfig config}) async {
    if (!_initialized) {
      throw InvalidConfigurationError('SWIPManager not initialized');
    }
    
    _activeSessionId = await wear.startCollection(config);
    
    // Start emotion recognition
    emotionController.startRecognition();
    
    // Set up emotion stream subscription for real-time updates
    _emotionSubscription = emotionController.emotionStream.listen((prediction) {
      // Handle emotion prediction updates
      _onEmotionUpdate(prediction);
    });
    
    return _activeSessionId!;
  }

  Future<SWIPSessionResults> endSession() async {
    if (_activeSessionId == null) {
      throw SessionNotFoundError();
    }
    
    // Stop emotion recognition
    emotionController.stopRecognition();
    _emotionSubscription?.cancel();
    _emotionSubscription = null;
    
    final results = await wear.stopAndEvaluate(_activeSessionId!);
    _activeSessionId = null;
    return results;
  }

  Future<SWIPMetrics> getCurrentMetrics() async {
    final hrv = await wear.readCurrentHRV();
    return SWIPMetrics(hrv: hrv, timestamp: DateTime.now());
  }

  /// Get stream of real-time emotion predictions
  Stream<EmotionPrediction> get emotionStream => emotionController.emotionStream;

  /// Get current emotion state
  EmotionPrediction? get currentEmotion => emotionController.getCurrentEmotion();

  /// Check if emotion recognition is available
  bool get isEmotionRecognitionAvailable => emotionController.isModelLoaded;

  /// Get available emotion classes
  List<String> get emotionClasses => emotionController.emotionClasses;

  /// Add heart rate data for emotion analysis
  void addHeartRateData(double heartRate, DateTime timestamp) {
    emotionController.addHeartRateData(heartRate, timestamp);
  }

  /// Add RR interval data for emotion analysis
  void addRRIntervalData(double rrIntervalMs, DateTime timestamp) {
    emotionController.addRRIntervalData(rrIntervalMs, timestamp);
  }

  /// Handle emotion prediction updates
  void _onEmotionUpdate(EmotionPrediction prediction) {
    // This can be overridden or extended by users of the SDK
    // For now, we'll just log the prediction
    print('Emotion detected: ${prediction.emotion.label} (confidence: ${prediction.confidence.toStringAsFixed(2)})');
  }

  /// Dispose resources
  void dispose() {
    emotionController.dispose();
    _emotionSubscription?.cancel();
  }
}


