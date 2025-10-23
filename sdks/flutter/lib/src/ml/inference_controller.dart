import 'dart:async';
import 'dart:math';
import '../models.dart';
import 'feature_extractor.dart';
import 'svm_predictor.dart';

/// InferenceController coordinates real-time emotion detection pipeline
/// Manages data flow from wearable sensors to emotion predictions
class InferenceController {
  final FeatureExtractor _featureExtractor;
  final SvmPredictor _svmPredictor;
  
  Timer? _inferenceTimer;
  StreamController<EmotionPrediction>? _emotionController;
  bool _isRunning = false;
  
  // Configuration
  final Duration inferenceInterval;
  final Duration featureWindowSize;
  
  InferenceController({
    Duration? inferenceInterval,
    Duration? featureWindowSize,
  }) : _featureExtractor = FeatureExtractor(
          windowSizeSeconds: (featureWindowSize ?? const Duration(seconds: 60)).inSeconds,
          hopSizeSeconds: 10,
        ),
        _svmPredictor = SvmPredictor(),
        inferenceInterval = inferenceInterval ?? const Duration(seconds: 10),
        featureWindowSize = featureWindowSize ?? const Duration(seconds: 60);

  /// Stream of emotion predictions
  Stream<EmotionPrediction> get emotionStream {
    _emotionController ??= StreamController<EmotionPrediction>.broadcast();
    return _emotionController!.stream;
  }

  /// Initialize the inference controller
  Future<void> initialize() async {
    // Load the SVM model
    await _svmPredictor.loadModel('assets/ml/svm_linear_v1_0.json');
  }

  /// Start real-time emotion inference
  void startInference() {
    if (_isRunning) return;
    
    _isRunning = true;
    
    // Start periodic inference
    _inferenceTimer = Timer.periodic(inferenceInterval, (_) {
      _performInference();
    });
  }

  /// Stop emotion inference
  void stopInference() {
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
  void _performInference() {
    try {
      // Extract HRV features from current window
      final features = _featureExtractor.extractFeatures();
      
      if (features == null) {
        // Not enough data yet
        return;
      }

      // Predict emotion
      final prediction = _svmPredictor.predict(features);
      
      // Emit prediction
      _emotionController?.add(prediction);
      
    } catch (e) {
      // Log error but don't crash the inference loop
      print('Inference error: $e');
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
    return _svmPredictor.getModelInfo();
  }

  /// Check if inference is running
  bool get isRunning => _isRunning;

  /// Check if model is loaded
  bool get isModelLoaded => _svmPredictor.isLoaded;

  /// Get available emotion classes
  List<String> get emotionClasses => _svmPredictor.classes;

  /// Get current data count in feature extractor
  int get dataCount => _featureExtractor.dataCount;

  /// Dispose resources
  void dispose() {
    stopInference();
    _emotionController?.close();
    _emotionController = null;
    _featureExtractor.clear();
  }
}

/// EmotionState represents the current emotional state with confidence
class EmotionState {
  final EmotionClass emotion;
  final double confidence;
  final DateTime timestamp;
  final Map<String, double> probabilities;

  EmotionState({
    required this.emotion,
    required this.confidence,
    required this.timestamp,
    required this.probabilities,
  });

  factory EmotionState.fromPrediction(EmotionPrediction prediction) {
    final probMap = <String, double>{};
    for (int i = 0; i < prediction.probabilities.length; i++) {
      probMap[prediction.emotion.label] = prediction.probabilities[i];
    }
    
    return EmotionState(
      emotion: prediction.emotion,
      confidence: prediction.confidence,
      timestamp: prediction.timestamp,
      probabilities: probMap,
    );
  }

  Map<String, dynamic> toJson() => {
    'emotion': emotion.label,
    'confidence': confidence,
    'timestamp': timestamp.toIso8601String(),
    'probabilities': probabilities,
  };
}
