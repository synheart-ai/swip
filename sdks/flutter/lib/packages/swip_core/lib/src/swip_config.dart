/// Configuration for SWIP Core engine
class SwipConfig {
  /// Exponential smoothing factor for scores (λ=0.9 default)
  final double smoothingLambda;
  
  /// Model identifier to use
  final String modelId;
  
  /// Enable/disable smoothing
  final bool enableSmoothing;
  
  /// Enable/disable artifact detection
  final bool enableArtifactDetection;
  
  /// Motion threshold for artifact detection (g)
  final double motionThreshold;
  
  /// Confidence threshold below which to flag low confidence
  final double lowConfidenceThreshold;

  const SwipConfig({
    this.smoothingLambda = 0.9,
    this.modelId = 'svm_linear_wrist_sdnn_v1_0',
    this.enableSmoothing = true,
    this.enableArtifactDetection = true,
    this.motionThreshold = 2.0,
    this.lowConfidenceThreshold = 0.3,
  });

  /// Default configuration
  static const SwipConfig defaultConfig = SwipConfig();

  /// Create from JSON
  factory SwipConfig.fromJson(Map<String, dynamic> json) {
    return SwipConfig(
      smoothingLambda: (json['smoothing_lambda'] as num?)?.toDouble() ?? 0.9,
      modelId: json['model_id'] as String? ?? 'svm_linear_wrist_sdnn_v1_0',
      enableSmoothing: json['enable_smoothing'] as bool? ?? true,
      enableArtifactDetection: json['enable_artifact_detection'] as bool? ?? true,
      motionThreshold: (json['motion_threshold'] as num?)?.toDouble() ?? 2.0,
      lowConfidenceThreshold: (json['low_confidence_threshold'] as num?)?.toDouble() ?? 0.3,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'smoothing_lambda': smoothingLambda,
      'model_id': modelId,
      'enable_smoothing': enableSmoothing,
      'enable_artifact_detection': enableArtifactDetection,
      'motion_threshold': motionThreshold,
      'low_confidence_threshold': lowConfidenceThreshold,
    };
  }
}

