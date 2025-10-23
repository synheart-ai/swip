import 'dart:async';
import 'dart:math';
import '../models.dart';
import 'feature_extractor.dart';
import 'emotion_recognition_model.dart';

/// Unified emotion recognition controller following RFC specifications
/// Integrates WESAD-trained models with real-time emotion detection
class EmotionRecognitionController {
  final FeatureExtractor _featureExtractor;
  EmotionRecognitionModel? _model;
  
  Timer? _inferenceTimer;
  StreamController<EmotionPrediction>? _emotionController;
  bool _isRunning = false;
  
  // Configuration
  final Duration inferenceInterval;
  final Duration featureWindowSize;
  final String modelAssetPath;
  
  EmotionRecognitionController({
    Duration? inferenceInterval,
    Duration? featureWindowSize,
    String? modelAssetPath,
  }) : _featureExtractor = FeatureExtractor(
          windowSizeSeconds: (featureWindowSize ?? const Duration(seconds: 60)).inSeconds,
          hopSizeSeconds: 10,
        ),
        inferenceInterval = inferenceInterval ?? const Duration(seconds: 10),
        featureWindowSize = featureWindowSize ?? const Duration(seconds: 60),
        modelAssetPath = modelAssetPath ?? 'assets/ml/wesad_emotion_v1_0.json';

  /// Stream of emotion predictions
  Stream<EmotionPrediction> get emotionStream {
    _emotionController ??= StreamController<EmotionPrediction>.broadcast();
    return _emotionController!.stream;
  }

  /// Initialize the emotion recognition controller
  Future<void> initialize() async {
    try {
      // Load the emotion recognition model
      _model = await EmotionRecognitionModel.loadFromAsset(modelAssetPath);
      
      // Validate model integrity
      if (!_model!.validateModel()) {
        throw Exception('Invalid emotion recognition model structure');
      }
      
      print('Emotion recognition model loaded: ${_model!.modelId}');
      print('Model performance: ${_model!.getPerformanceMetrics()}');
    } catch (e) {
      throw Exception('Failed to initialize emotion recognition: $e');
    }
  }

  /// Start real-time emotion recognition
  void startRecognition() {
    if (_isRunning) return;
    
    _isRunning = true;
    
    // Start periodic inference
    _inferenceTimer = Timer.periodic(inferenceInterval, (_) {
      _performEmotionInference();
    });
  }

  /// Stop emotion recognition
  void stopRecognition() {
    _isRunning = false;
    _inferenceTimer?.cancel();
    _inferenceTimer = null;
  }

  /// Add heart rate data point
  void addHeartRateData(double heartRate, DateTime timestamp) {
    _featureExtractor.addHeartRate(heartRate, timestamp);
  }

  /// Add RR interval data point
  void addRRIntervalData(double rrIntervalMs, DateTime timestamp) {
    _featureExtractor.addRRInterval(rrIntervalMs, timestamp);
  }

  /// Perform emotion inference on current feature window
  void _performEmotionInference() {
    try {
      if (_model == null) return;
      
      // Extract HRV features from current window
      final features = _featureExtractor.extractFeatures();
      
      if (features == null) {
        // Not enough data yet
        return;
      }

      // Predict emotion using the loaded model
      final prediction = _model!.predict(features);
      
      // Emit prediction
      _emotionController?.add(prediction);
      
    } catch (e) {
      // Log error but don't crash the inference loop
      print('Emotion inference error: $e');
    }
  }

  /// Get current emotion state (latest prediction)
  EmotionPrediction? getCurrentEmotion() {
    // This would typically cache the latest prediction
    // For now, we'll return null and rely on the stream
    return null;
  }

  /// Get model information
  Map<String, dynamic>? getModelInfo() {
    return _model?.getModelInfo();
  }

  /// Get model performance metrics
  Map<String, dynamic>? getPerformanceMetrics() {
    return _model?.getPerformanceMetrics();
  }

  /// Check if recognition is running
  bool get isRunning => _isRunning;

  /// Check if model is loaded
  bool get isModelLoaded => _model != null;

  /// Get available emotion classes
  List<String> get emotionClasses => _model?.classes ?? [];

  /// Get current data count in feature extractor
  int get dataCount => _featureExtractor.dataCount;

  /// Get feature schema
  List<String> get featureSchema => _model?.featureOrder ?? [];

  /// Dispose resources
  void dispose() {
    stopRecognition();
    _emotionController?.close();
    _emotionController = null;
    _featureExtractor.clear();
  }
}

/// Emotion state with additional metadata
class EmotionState {
  final EmotionClass emotion;
  final double confidence;
  final DateTime timestamp;
  final Map<String, double> probabilities;
  final Map<String, dynamic>? modelInfo;

  EmotionState({
    required this.emotion,
    required this.confidence,
    required this.timestamp,
    required this.probabilities,
    this.modelInfo,
  });

  factory EmotionState.fromPrediction(EmotionPrediction prediction, {Map<String, dynamic>? modelInfo}) {
    final probMap = <String, double>{};
    for (int i = 0; i < prediction.probabilities.length; i++) {
      probMap[prediction.emotion.label] = prediction.probabilities[i];
    }
    
    return EmotionState(
      emotion: prediction.emotion,
      confidence: prediction.confidence,
      timestamp: prediction.timestamp,
      probabilities: probMap,
      modelInfo: modelInfo,
    );
  }

  Map<String, dynamic> toJson() => {
    'emotion': emotion.label,
    'confidence': confidence,
    'timestamp': timestamp.toIso8601String(),
    'probabilities': probabilities,
    'modelInfo': modelInfo,
  };
}

/// Emotion recognition configuration
class EmotionRecognitionConfig {
  final Duration inferenceInterval;
  final Duration featureWindowSize;
  final String modelAssetPath;
  final bool enableDebugLogging;

  const EmotionRecognitionConfig({
    this.inferenceInterval = const Duration(seconds: 10),
    this.featureWindowSize = const Duration(seconds: 60),
    this.modelAssetPath = 'assets/ml/wesad_emotion_v1_0.json',
    this.enableDebugLogging = false,
  });
}
