import 'dart:async';
import 'swip_score.dart';
import 'swip_config.dart';
import 'models.dart';

/// SWIP Core Engine
/// 
/// Processes physiological data and emotion probabilities to compute SWIP Score
class SwipEngine {
  final SwipConfig config;
  final PhysiologicalBaseline baseline;
  
  double? _previousScore;
  DateTime _lastUpdate = DateTime.now().toUtc();
  
  /// Callback for logging/debugging
  void Function(String level, String message, {Map<String, dynamic>? context})? onLog;

  SwipEngine({
    required this.baseline,
    SwipConfig? config,
    this.onLog,
  }) : config = config ?? SwipConfig.defaultConfig;

  /// Compute SWIP Score from inputs
  SwipScoreResult computeScore({
    required double hr,
    required double hrv,
    required double motion,
    required Map<String, double> emotionProbabilities,
  }) {
    // Detect artifacts
    final hasArtifact = _detectArtifact(motion, hr, hrv);
    
    // Compute raw SWIP score
    final rawResult = SwipScoreComputation.computeSwipScore(
      hr: hr,
      hrv: hrv,
      motion: motion,
      emotionProbabilities: emotionProbabilities,
      baseline: baseline,
      modelId: config.modelId,
    );
    
    // Apply smoothing if enabled
    double finalScore = rawResult.swipScore;
    if (config.enableSmoothing && _previousScore != null) {
      finalScore = SwipScoreComputation.smoothScore(
        rawResult.swipScore,
        _previousScore!,
        lambda: config.smoothingLambda,
      );
      _previousScore = finalScore;
    } else {
      _previousScore = finalScore;
    }
    
    // Log the computation
    _log('info', 'Computed SWIP score: ${finalScore.toStringAsFixed(1)}, '
                  'emotion: ${rawResult.dominantEmotion}, '
                  'confidence: ${(rawResult.confidence * 100).toStringAsFixed(1)}%');
    
    // Update timestamp
    _lastUpdate = DateTime.now().toUtc();
    
    // Return final result
    return SwipScoreResult(
      swipScore: finalScore,
      physSubscore: rawResult.physSubscore,
      emoSubscore: rawResult.emoSubscore,
      confidence: rawResult.confidence,
      dominantEmotion: rawResult.dominantEmotion,
      emotionProbabilities: rawResult.emotionProbabilities,
      timestamp: _lastUpdate,
      modelId: rawResult.modelId,
      reasons: rawResult.reasons,
      artifactFlag: hasArtifact,
    );
  }

  /// Detect motion artifacts
  bool _detectArtifact(double motion, double hr, double hrv) {
    if (!config.enableArtifactDetection) return false;
    
    // High motion suggests artifact
    if (motion > config.motionThreshold) {
      _log('warn', 'Motion artifact detected: ${motion.toStringAsFixed(2)}g > ${config.motionThreshold}g');
      return true;
    }
    
    // Unusual HR patterns
    if (hr < 40 || hr > 200) {
      _log('warn', 'Abnormal HR detected: ${hr.toStringAsFixed(1)} bpm');
      return true;
    }
    
    // Very low HRV might indicate poor signal quality
    if (hrv < 10) {
      _log('warn', 'Low HRV detected: ${hrv.toStringAsFixed(1)} ms');
      return true;
    }
    
    return false;
  }

  /// Reset engine state
  void reset() {
    _previousScore = null;
    _lastUpdate = DateTime.now().toUtc();
    _log('info', 'Engine reset');
  }

  /// Get interpretation of a score
  String interpretScore(double score) {
    return SwipScoreComputation.interpretScore(score);
  }

  /// Log message
  void _log(String level, String message, {Map<String, dynamic>? context}) {
    onLog?.call(level, message, context: context);
  }

  /// Get current state
  Map<String, dynamic> getState() {
    return {
      'config': config.toJson(),
      'baseline': baseline.toJson(),
      'previous_score': _previousScore,
      'last_update': _lastUpdate.toIso8601String(),
    };
  }
}

/// Factory for creating SWIP Engines with sensible defaults
class SwipEngineFactory {
  /// Create engine with default baseline
  /// Useful for testing or when no user baseline is available
  static SwipEngine createDefault({
    SwipConfig? config,
    void Function(String level, String message, {Map<String, dynamic>? context})? onLog,
  }) {
    // Default baseline from population norms
    final baseline = PhysiologicalBaseline(
      hrMean: 72.0,
      hrStd: 12.0,
      hrvMean: 45.0,
      hrvStd: 18.0,
      timestamp: DateTime.now().toUtc(),
    );
    
    return SwipEngine(
      baseline: baseline,
      config: config,
      onLog: onLog,
    );
  }
  
  /// Create engine with personalized baseline
  /// Recommended for production use
  static SwipEngine createPersonalized({
    required PhysiologicalBaseline baseline,
    SwipConfig? config,
    void Function(String level, String message, {Map<String, dynamic>? context})? onLog,
  }) {
    return SwipEngine(
      baseline: baseline,
      config: config,
      onLog: onLog,
    );
  }
}

