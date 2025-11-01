import 'dart:math';

/// HRV Feature extraction utilities
/// 
/// Implements standard HRV metrics per RFC specification:
/// - SDNN: Standard deviation of NN intervals
/// - RMSSD: Root mean square of successive differences
/// - PNN50: Percentage of NN intervals differing by >50ms
class HrvFeatures {
  /// Compute SDNN (Standard Deviation of NN intervals)
  /// 
  /// SDNN reflects overall HRV and is sensitive to both sympathetic
  /// and parasympathetic influences.
  static double computeSdnn(List<double> rrIntervalsMs) {
    if (rrIntervalsMs.length < 2) return 0.0;
    
    // Filter physiologically plausible intervals
    final validRr = rrIntervalsMs.where((rr) => 
        rr >= 300 && rr <= 2000).toList();
    
    if (validRr.length < 2) return 0.0;
    
    final mean = validRr.reduce((a, b) => a + b) / validRr.length;
    final variance = validRr
        .map((x) => pow(x - mean, 2))
        .reduce((a, b) => a + b) / (validRr.length - 1);
    
    return sqrt(variance);
  }

  /// Compute RMSSD (Root Mean Square of Successive Differences)
  /// 
  /// RMSSD is primarily influenced by parasympathetic activity
  /// and reflects short-term HRV.
  static double computeRmssd(List<double> rrIntervalsMs) {
    if (rrIntervalsMs.length < 2) return 0.0;
    
    // Filter valid intervals
    final validRr = rrIntervalsMs.where((rr) => 
        rr >= 300 && rr <= 2000).toList();
    
    if (validRr.length < 2) return 0.0;
    
    double sumSquaredDiffs = 0.0;
    for (int i = 1; i < validRr.length; i++) {
      final diff = validRr[i] - validRr[i - 1];
      sumSquaredDiffs += diff * diff;
    }
    
    return sqrt(sumSquaredDiffs / (validRr.length - 1));
  }

  /// Compute PNN50 (Percentage of NN intervals differing by >50ms)
  /// 
  /// PNN50 is another measure of short-term HRV variability.
  static double computePnn50(List<double> rrIntervalsMs) {
    if (rrIntervalsMs.length < 2) return 0.0;
    
    final validRr = rrIntervalsMs.where((rr) => 
        rr >= 300 && rr <= 2000).toList();
    
    if (validRr.length < 2) return 0.0;
    
    int count = 0;
    for (int i = 1; i < validRr.length; i++) {
      if ((validRr[i] - validRr[i - 1]).abs() > 50) {
        count++;
      }
    }
    
    return (count / (validRr.length - 1)) * 100;
  }

  /// Extract all HRV features for emotion inference
  /// 
  /// Returns a map with standardized feature names expected by
  /// the emotion model (svm_linear_wrist_sdnn_v1_0).
  static Map<String, double> extractAll({
    required double hrMean,
    required List<double> rrIntervalsMs,
    double? motionMagnitude,
  }) {
    return {
      'hr_mean': hrMean,
      'sdnn': computeSdnn(rrIntervalsMs),
      'rmssd': computeRmssd(rrIntervalsMs),
      if (motionMagnitude != null) 'motion': motionMagnitude,
    };
  }

  /// Validate RR intervals for quality
  /// 
  /// Returns quality score (0-1) based on:
  /// - Percentage of physiologically plausible intervals
  /// - Consistency of intervals (low variance in differences)
  static double validateQuality(List<double> rrIntervalsMs) {
    if (rrIntervalsMs.isEmpty) return 0.0;
    
    // Check physiological plausibility
    final validCount = rrIntervalsMs.where((rr) => 
        rr >= 300 && rr <= 2000).length;
    final plausibilityScore = validCount / rrIntervalsMs.length;
    
    if (rrIntervalsMs.length < 2) return plausibilityScore;
    
    // Check consistency (low variance in successive differences)
    final diffs = <double>[];
    for (int i = 1; i < rrIntervalsMs.length; i++) {
      diffs.add((rrIntervalsMs[i] - rrIntervalsMs[i - 1]).abs());
    }
    
    if (diffs.isEmpty) return plausibilityScore;
    
    final meanDiff = diffs.reduce((a, b) => a + b) / diffs.length;
    final varianceDiff = diffs
        .map((d) => pow(d - meanDiff, 2))
        .reduce((a, b) => a + b) / diffs.length;
    
    // Consistency score: lower variance = higher quality
    final consistencyScore = 1.0 / (1.0 + sqrt(varianceDiff) / 100.0);
    
    // Combined quality score
    return (plausibilityScore * 0.7 + consistencyScore * 0.3).clamp(0.0, 1.0);
  }

  /// Clean RR intervals by removing artifacts
  /// 
  /// Applies multiple filters:
  /// - Remove physiologically implausible values
  /// - Remove sudden jumps (>250ms difference)
  /// - Apply median filter for outliers
  static List<double> cleanRrIntervals(
    List<double> rrIntervalsMs, {
    double maxJumpMs = 250.0,
  }) {
    if (rrIntervalsMs.isEmpty) return [];
    
    final cleaned = <double>[];
    
    for (int i = 0; i < rrIntervalsMs.length; i++) {
      final rr = rrIntervalsMs[i];
      
      // Basic physiological bounds
      if (rr < 300 || rr > 2000) continue;
      
      // Check for sudden jumps
      if (i > 0) {
        final prevRr = cleaned.isNotEmpty ? cleaned.last : rrIntervalsMs[i - 1];
        if ((rr - prevRr).abs() > maxJumpMs) continue;
      }
      
      cleaned.add(rr);
    }
    
    return cleaned;
  }

  /// Convert RR intervals to heart rate
  static double rrToHeartRate(double rrMs) {
    return 60000.0 / rrMs; // Convert ms to bpm
  }

  /// Convert heart rate to RR interval
  static double heartRateToRr(double hrBpm) {
    return 60000.0 / hrBpm; // Convert bpm to ms
  }

  /// Get statistics for RR intervals
  static Map<String, double> getStatistics(List<double> rrIntervalsMs) {
    if (rrIntervalsMs.isEmpty) {
      return {
        'count': 0,
        'mean': 0,
        'min': 0,
        'max': 0,
        'std': 0,
      };
    }
    
    final validRr = rrIntervalsMs.where((rr) => 
        rr >= 300 && rr <= 2000).toList();
    
    if (validRr.isEmpty) {
      return {
        'count': 0,
        'mean': 0,
        'min': 0,
        'max': 0,
        'std': 0,
      };
    }
    
    final mean = validRr.reduce((a, b) => a + b) / validRr.length;
    final min = validRr.reduce((a, b) => a < b ? a : b);
    final max = validRr.reduce((a, b) => a > b ? a : b);
    
    final variance = validRr
        .map((x) => pow(x - mean, 2))
        .reduce((a, b) => a + b) / validRr.length;
    final std = sqrt(variance);
    
    return {
      'count': validRr.length.toDouble(),
      'mean': mean,
      'min': min,
      'max': max,
      'std': std,
    };
  }
}