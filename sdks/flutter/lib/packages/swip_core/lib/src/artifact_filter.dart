import 'dart:math';

/// Artifact filtering for biosignal data
///
/// Implements motion gating and quality filtering to ensure
/// reliable HRV measurements per RFC specification.
class ArtifactFilter {
  /// Motion threshold for artifact detection (g)
  static const double defaultMotionThreshold = 2.0;
  
  /// Maximum physiologically plausible RR interval (ms)
  static const double maxRrMs = 2000.0;
  
  /// Minimum physiologically plausible RR interval (ms)
  static const double minRrMs = 300.0;
  
  /// Maximum jump between consecutive RR intervals (ms)
  static const double maxJumpMs = 250.0;

  /// Filter RR intervals based on motion artifacts
  /// 
  /// Returns filtered RR intervals that are likely artifact-free.
  static List<double> filterRrIntervals({
    required List<double> rrIntervalsMs,
    required double motionMagnitude,
    double motionThreshold = defaultMotionThreshold,
  }) {
    // If motion is too high, return empty list
    if (motionMagnitude > motionThreshold) {
      return [];
    }
    
    return _applyRrFilters(rrIntervalsMs);
  }

  /// Apply comprehensive RR interval filtering
  static List<double> _applyRrFilters(List<double> rrIntervalsMs) {
    if (rrIntervalsMs.isEmpty) return [];

    final filtered = <double>[];
    
    for (int i = 0; i < rrIntervalsMs.length; i++) {
      final rr = rrIntervalsMs[i];
      
      // Check physiological bounds
      if (rr < minRrMs || rr > maxRrMs) continue;
      
      // Check for sudden jumps
      if (i > 0 && filtered.isNotEmpty) {
        final prevRr = filtered.last;
        if ((rr - prevRr).abs() > maxJumpMs) continue;
      }

      filtered.add(rr);
    }

    return filtered;
  }

  /// Detect motion artifacts in accelerometer data
  /// 
  /// Returns true if motion suggests artifacts in HRV measurement.
  static bool detectMotionArtifact({
    required double motionMagnitude,
    double threshold = defaultMotionThreshold,
  }) {
    return motionMagnitude > threshold;
  }

  /// Compute motion magnitude from 3D accelerometer data
  static double computeMotionMagnitude({
    required double x,
    required double y,
    required double z,
  }) {
    return sqrt(x * x + y * y + z * z);
  }

  /// Quality score for RR intervals (0-1)
  /// 
  /// Higher score indicates better quality, less artifacts.
  static double computeQualityScore({
    required List<double> rrIntervalsMs,
    required double motionMagnitude,
    double motionThreshold = defaultMotionThreshold,
  }) {
    if (rrIntervalsMs.isEmpty) return 0.0;
    
    // Motion penalty
    final motionScore = motionMagnitude > motionThreshold ? 0.0 : 
        1.0 - (motionMagnitude / motionThreshold);
    
    // Physiological plausibility
    final validCount = rrIntervalsMs.where((rr) => 
        rr >= minRrMs && rr <= maxRrMs).length;
    final plausibilityScore = validCount / rrIntervalsMs.length;
    
    // Consistency score (low variance in successive differences)
    double consistencyScore = 1.0;
    if (rrIntervalsMs.length > 1) {
      final diffs = <double>[];
      for (int i = 1; i < rrIntervalsMs.length; i++) {
        diffs.add((rrIntervalsMs[i] - rrIntervalsMs[i - 1]).abs());
      }
      
      if (diffs.isNotEmpty) {
        final meanDiff = diffs.reduce((a, b) => a + b) / diffs.length;
        final varianceDiff = diffs
            .map((d) => pow(d - meanDiff, 2))
            .reduce((a, b) => a + b) / diffs.length;
        
        // Lower variance = higher consistency
        consistencyScore = 1.0 / (1.0 + sqrt(varianceDiff) / 100.0);
      }
    }
    
    // Weighted combination
    return (motionScore * 0.4 + 
            plausibilityScore * 0.4 + 
            consistencyScore * 0.2).clamp(0.0, 1.0);
  }

  /// Filter heart rate based on physiological bounds
  static double? filterHeartRate(double hrBpm) {
    // Physiological bounds: 30-220 bpm
    if (hrBpm < 30 || hrBpm > 220) return null;
    return hrBpm;
  }

  /// Detect outliers in a time series
  /// 
  /// Uses modified Z-score method for outlier detection.
  static List<bool> detectOutliers(List<double> values, {
    double threshold = 3.5,
  }) {
    if (values.length < 3) return List.filled(values.length, false);
    
    final median = _median(values);
    final mad = _medianAbsoluteDeviation(values, median);
    
    return values.map((value) {
      final modifiedZScore = 0.6745 * (value - median) / mad;
      return modifiedZScore.abs() > threshold;
    }).toList();
  }

  /// Remove outliers from a list
  static List<double> removeOutliers(List<double> values, {
    double threshold = 3.5,
  }) {
    final isOutlier = detectOutliers(values, threshold: threshold);
    
    return values.asMap().entries
        .where((entry) => !isOutlier[entry.key])
        .map((entry) => entry.value)
        .toList();
  }

  /// Median absolute deviation
  static double _medianAbsoluteDeviation(List<double> values, double median) {
    final deviations = values.map((v) => (v - median).abs()).toList();
    return _median(deviations);
  }

  /// Compute median
  static double _median(List<double> values) {
    final sorted = List.from(values)..sort();
    final n = sorted.length;
    
    if (n % 2 == 1) {
      return sorted[n ~/ 2];
    } else {
      return (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
    }
  }

  /// Apply median filter to smooth data
  static List<double> medianFilter(List<double> values, {int windowSize = 3}) {
    if (values.length < windowSize) return values;
    
    final filtered = <double>[];
    
    for (int i = 0; i < values.length; i++) {
      final start = max(0, i - windowSize ~/ 2);
      final end = min(values.length, i + windowSize ~/ 2 + 1);
      
      final window = values.sublist(start, end);
      filtered.add(_median(window));
    }
    
    return filtered;
  }

  /// Comprehensive artifact detection for biosignal tick
  static ArtifactFlags detectArtifacts({
    required double? hrBpm,
    required List<double>? rrIntervalsMs,
    required double? motionMagnitude,
    double motionThreshold = defaultMotionThreshold,
  }) {
    bool hasMotionArtifact = false;
    bool hasHrArtifact = false;
    bool hasRrArtifact = false;
    double qualityScore = 1.0;
    
    // Check motion artifacts
    if (motionMagnitude != null) {
      hasMotionArtifact = detectMotionArtifact(
        motionMagnitude: motionMagnitude,
        threshold: motionThreshold,
      );
    }
    
    // Check HR artifacts
    if (hrBpm != null) {
      hasHrArtifact = filterHeartRate(hrBpm) == null;
    }
    
    // Check RR artifacts
    if (rrIntervalsMs != null && rrIntervalsMs.isNotEmpty) {
      hasRrArtifact = rrIntervalsMs.any((rr) => rr < minRrMs || rr > maxRrMs);
      
      qualityScore = computeQualityScore(
        rrIntervalsMs: rrIntervalsMs,
        motionMagnitude: motionMagnitude ?? 0.0,
        motionThreshold: motionThreshold,
      );
    }
    
    return ArtifactFlags(
      hasMotionArtifact: hasMotionArtifact,
      hasHrArtifact: hasHrArtifact,
      hasRrArtifact: hasRrArtifact,
      qualityScore: qualityScore,
    );
  }
}

/// Artifact detection results
class ArtifactFlags {
  final bool hasMotionArtifact;
  final bool hasHrArtifact;
  final bool hasRrArtifact;
  final double qualityScore;
  
  const ArtifactFlags({
    required this.hasMotionArtifact,
    required this.hasHrArtifact,
    required this.hasRrArtifact,
    required this.qualityScore,
  });
  
  /// Overall artifact status
  bool get hasAnyArtifact => 
      hasMotionArtifact || hasHrArtifact || hasRrArtifact;
  
  /// High quality data (no artifacts, good quality score)
  bool get isHighQuality => 
      !hasAnyArtifact && qualityScore > 0.7;
  
  /// Medium quality data (minor artifacts or lower quality score)
  bool get isMediumQuality => 
      !hasAnyArtifact && qualityScore > 0.4;
  
  /// Low quality data (major artifacts or very low quality score)
  bool get isLowQuality => 
      hasAnyArtifact || qualityScore <= 0.4;
  
  @override
  String toString() {
    return 'ArtifactFlags(motion: $hasMotionArtifact, hr: $hasHrArtifact, '
           'rr: $hasRrArtifact, quality: ${qualityScore.toStringAsFixed(2)})';
  }
}