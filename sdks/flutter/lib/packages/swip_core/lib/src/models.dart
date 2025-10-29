/// SWIP Score result containing all computed metrics
class SwipScoreResult {
  /// Final SWIP score (0-100)
  final double swipScore;
  
  /// Physiological subscore contribution (0-1)
  final double physSubscore;
  
  /// Emotion subscore contribution (0-1)
  final double emoSubscore;
  
  /// Confidence in the score (0-1)
  final double confidence;
  
  /// Dominant emotion detected
  final String dominantEmotion;
  
  /// All emotion probabilities
  final Map<String, double> emotionProbabilities;
  
  /// Timestamp of the computation
  final DateTime timestamp;
  
  /// Model identifier used
  final String modelId;
  
  /// Reason codes explaining the score
  final Map<String, double> reasons;
  
  /// Whether the data contains artifacts
  final bool artifactFlag;

  const SwipScoreResult({
    required this.swipScore,
    required this.physSubscore,
    required this.emoSubscore,
    required this.confidence,
    required this.dominantEmotion,
    required this.emotionProbabilities,
    required this.timestamp,
    required this.modelId,
    required this.reasons,
    this.artifactFlag = false,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'swip_score': swipScore,
      'phys_subscore': physSubscore,
      'emo_subscore': emoSubscore,
      'confidence': confidence,
      'dominant_emotion': dominantEmotion,
      'emotion_probs': emotionProbabilities,
      'timestamp': timestamp.toIso8601String(),
      'model_id': modelId,
      'reasons': reasons,
      'artifact_flag': artifactFlag,
    };
  }

  /// Create from JSON
  factory SwipScoreResult.fromJson(Map<String, dynamic> json) {
    return SwipScoreResult(
      swipScore: (json['swip_score'] as num).toDouble(),
      physSubscore: (json['phys_subscore'] as num).toDouble(),
      emoSubscore: (json['emo_subscore'] as num).toDouble(),
      confidence: (json['confidence'] as num).toDouble(),
      dominantEmotion: json['dominant_emotion'] as String,
      emotionProbabilities: Map<String, double>.from(json['emotion_probs']),
      timestamp: DateTime.parse(json['timestamp']),
      modelId: json['model_id'] as String,
      reasons: Map<String, double>.from(json['reasons']),
      artifactFlag: json['artifact_flag'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'SwipScoreResult(score: ${swipScore.toStringAsFixed(1)}, '
           'emotion: $dominantEmotion, confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
  }
}

/// Physiological baseline for normalization
class PhysiologicalBaseline {
  final double hrMean;
  final double hrStd;
  final double hrvMean;
  final double hrvStd;
  final DateTime timestamp;

  const PhysiologicalBaseline({
    required this.hrMean,
    required this.hrStd,
    required this.hrvMean,
    required this.hrvStd,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'hr_mean': hrMean,
      'hr_std': hrStd,
      'hrv_mean': hrvMean,
      'hrv_std': hrvStd,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory PhysiologicalBaseline.fromJson(Map<String, dynamic> json) {
    return PhysiologicalBaseline(
      hrMean: (json['hr_mean'] as num).toDouble(),
      hrStd: (json['hr_std'] as num).toDouble(),
      hrvMean: (json['hrv_mean'] as num).toDouble(),
      hrvStd: (json['hrv_std'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

