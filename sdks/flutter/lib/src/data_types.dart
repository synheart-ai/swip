/// Data types and enums for SWIP SDK
/// 
/// Defines canonical types used across all layers of the SWIP system.

/// Consent levels for data sharing
enum ConsentLevel {
  /// Level 0: On-device only (default)
  /// - All processing local
  /// - No network calls
  /// - Raw biosignals never leave device
  onDevice(0),
  
  /// Level 1: Local export allowed
  /// - User can manually export data
  /// - No automatic uploads
  localExport(1),
  
  /// Level 2: Dashboard sharing allowed
  /// - Aggregated metrics can be uploaded
  /// - No raw biosignals transmitted
  dashboardShare(2);

  const ConsentLevel(this.level);
  final int level;

  /// Check if this level allows the requested action
  bool allows(ConsentLevel required) {
    return level >= required.level;
  }

  /// Get human-readable description
  String get description {
    switch (this) {
      case ConsentLevel.onDevice:
        return 'On-device only - no data sharing';
      case ConsentLevel.localExport:
        return 'Local export - manual data export allowed';
      case ConsentLevel.dashboardShare:
        return 'Dashboard sharing - aggregated data can be uploaded';
    }
  }
}

/// SWIP Score interpretation ranges
enum SwipScoreRange {
  /// 80-100: Positive state
  positive(80, 100),
  
  /// 60-79: Neutral state
  neutral(60, 79),
  
  /// 40-59: Mild stress
  mildStress(40, 59),
  
  /// 0-39: Negative state
  negative(0, 39);

  const SwipScoreRange(this.min, this.max);
  final int min;
  final int max;

  /// Check if score falls in this range
  bool contains(double score) {
    return score >= min && score <= max;
  }

  /// Get range for a given score
  static SwipScoreRange forScore(double score) {
    for (final range in SwipScoreRange.values) {
      if (range.contains(score)) return range;
    }
    return SwipScoreRange.negative; // Fallback
  }

  /// Get human-readable description
  String get description {
    switch (this) {
      case SwipScoreRange.positive:
        return 'Relaxed/Engaged - app supports wellness';
      case SwipScoreRange.neutral:
        return 'Emotionally stable';
      case SwipScoreRange.mildStress:
        return 'Cognitive or emotional fatigue';
      case SwipScoreRange.negative:
        return 'Stress/emotional load detected';
    }
  }
}

/// Emotion classes supported by the system
enum EmotionClass {
  amused('Amused', 0.95),
  calm('Calm', 0.85),
  focused('Focused', 0.80),
  neutral('Neutral', 0.70),
  stressed('Stressed', 0.15);

  const EmotionClass(this.label, this.utility);
  final String label;
  final double utility;

  /// Get emotion class from string label
  static EmotionClass? fromLabel(String label) {
    for (final emotion in EmotionClass.values) {
      if (emotion.label.toLowerCase() == label.toLowerCase()) {
        return emotion;
      }
    }
    return null;
  }

  /// Get utility value for this emotion
  double get utilityValue => utility;
}

/// Session states
enum SessionState {
  /// Session is not started
  idle,
  
  /// Session is starting up
  starting,
  
  /// Session is active and collecting data
  active,
  
  /// Session is stopping
  stopping,
  
  /// Session has ended
  ended,
  
  /// Session encountered an error
  error;

  /// Check if session is active
  bool get isActive => this == SessionState.active;
  
  /// Check if session can be started
  bool get canStart => this == SessionState.idle || this == SessionState.ended;
  
  /// Check if session can be stopped
  bool get canStop => this == SessionState.active || this == SessionState.starting;
}

/// Data quality levels
enum DataQuality {
  /// High quality data (no artifacts, good signal)
  high(0.7, 1.0),
  
  /// Medium quality data (minor artifacts or lower signal quality)
  medium(0.4, 0.7),
  
  /// Low quality data (major artifacts or very poor signal)
  low(0.0, 0.4);

  const DataQuality(this.minScore, this.maxScore);
  final double minScore;
  final double maxScore;

  /// Get quality level for a given score
  static DataQuality forScore(double score) {
    for (final quality in DataQuality.values) {
      if (score >= quality.minScore && score < quality.maxScore) {
        return quality;
      }
    }
    return DataQuality.low; // Fallback
  }

  /// Check if this quality level is acceptable for processing
  bool get isAcceptable => this != DataQuality.low;
}

/// Model types supported by the system
enum ModelType {
  /// Linear SVM model
  linearSvm('linear_svm'),
  
  /// Neural network model
  neuralNetwork('neural_network'),
  
  /// Rule-based model (fallback)
  ruleBased('rule_based');

  const ModelType(this.identifier);
  final String identifier;

  /// Get model type from identifier
  static ModelType? fromIdentifier(String identifier) {
    for (final type in ModelType.values) {
      if (type.identifier == identifier) {
        return type;
      }
    }
    return null;
  }
}

/// Storage table names
enum StorageTable {
  sessions('sessions'),
  samplesRaw('samples_raw'),
  scores('scores'),
  dailyAgg('daily_agg'),
  monthlyAgg('monthly_agg'),
  consentHistory('consent_history');

  const StorageTable(this.name);
  final String name;
}

/// Error types for SWIP SDK
enum SwipErrorType {
  /// Initialization failed
  initialization,
  
  /// Session management error
  session,
  
  /// Permission denied
  permission,
  
  /// Device unavailable
  device,
  
  /// Network error
  network,
  
  /// Data processing error
  processing,
  
  /// Storage error
  storage,
  
  /// Consent required
  consent;

  /// Get human-readable error message
  String get message {
    switch (this) {
      case SwipErrorType.initialization:
        return 'Failed to initialize SWIP SDK';
      case SwipErrorType.session:
        return 'Session management error';
      case SwipErrorType.permission:
        return 'Required permissions not granted';
      case SwipErrorType.device:
        return 'Wearable device unavailable';
      case SwipErrorType.network:
        return 'Network operation failed';
      case SwipErrorType.processing:
        return 'Data processing error';
      case SwipErrorType.storage:
        return 'Storage operation failed';
      case SwipErrorType.consent:
        return 'User consent required for this operation';
    }
  }
}

/// Configuration validation results
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  /// Create valid result
  factory ValidationResult.valid({List<String> warnings = const []}) {
    return ValidationResult(isValid: true, warnings: warnings);
  }

  /// Create invalid result
  factory ValidationResult.invalid(List<String> errors) {
    return ValidationResult(isValid: false, errors: errors);
  }

  /// Combine multiple validation results
  factory ValidationResult.combine(List<ValidationResult> results) {
    final allErrors = <String>[];
    final allWarnings = <String>[];
    bool isValid = true;

    for (final result in results) {
      allErrors.addAll(result.errors);
      allWarnings.addAll(result.warnings);
      if (!result.isValid) isValid = false;
    }

    return ValidationResult(
      isValid: isValid,
      errors: allErrors,
      warnings: allWarnings,
    );
  }
}