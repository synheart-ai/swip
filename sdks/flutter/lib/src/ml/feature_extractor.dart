import 'dart:math';
import '../models.dart';

/// FeatureExtractor computes HRV features from RR intervals and heart rate data
/// Implements the feature extraction pipeline defined in RFC: WESAD SVM
class FeatureExtractor {
  static const int _defaultWindowSizeSeconds = 60;
  static const int _defaultHopSizeSeconds = 10;
  
  final int windowSizeSeconds;
  final int hopSizeSeconds;
  
  // Buffers for sliding window analysis
  final List<double> _rrIntervals = [];
  final List<double> _heartRates = [];
  final List<DateTime> _timestamps = [];
  
  FeatureExtractor({
    this.windowSizeSeconds = _defaultWindowSizeSeconds,
    this.hopSizeSeconds = _defaultHopSizeSeconds,
  });

  /// Add new RR interval data point
  void addRRInterval(double rrIntervalMs, DateTime timestamp) {
    _rrIntervals.add(rrIntervalMs);
    _timestamps.add(timestamp);
    
    // Calculate heart rate from RR interval
    final heartRate = 60000.0 / rrIntervalMs; // Convert ms to BPM
    _heartRates.add(heartRate);
    
    // Keep only recent data (last 2 minutes)
    _cleanupOldData();
  }

  /// Add heart rate data point directly
  void addHeartRate(double heartRate, DateTime timestamp) {
    _heartRates.add(heartRate);
    _timestamps.add(timestamp);
    
    // Calculate RR interval from heart rate
    final rrInterval = 60000.0 / heartRate; // Convert BPM to ms
    _rrIntervals.add(rrInterval);
    
    _cleanupOldData();
  }

  /// Extract HRV features from current window
  HRVFeatures? extractFeatures() {
    if (_rrIntervals.length < 30) {
      return null; // Need at least 30 seconds of data
    }

    final now = DateTime.now();
    final windowStart = now.subtract(Duration(seconds: windowSizeSeconds));
    
    // Filter data within the window
    final windowData = <double>[];
    final windowHR = <double>[];
    
    for (int i = 0; i < _timestamps.length; i++) {
      if (_timestamps[i].isAfter(windowStart)) {
        windowData.add(_rrIntervals[i]);
        windowHR.add(_heartRates[i]);
      }
    }
    
    if (windowData.length < 10) {
      return null; // Insufficient data in window
    }

    return _computeHRVFeatures(windowData, windowHR, now);
  }

  /// Compute HRV features from RR intervals and heart rate data
  HRVFeatures _computeHRVFeatures(List<double> rrIntervals, List<double> heartRates, DateTime timestamp) {
    // Heart rate statistics
    final meanHr = _mean(heartRates);
    final hrStd = _standardDeviation(heartRates);
    final hrMin = heartRates.reduce(min);
    final hrMax = heartRates.reduce(max);

    // HRV metrics
    final sdnn = _computeSDNN(rrIntervals);
    final rmssd = _computeRMSSD(rrIntervals);
    final pnn50 = _computePNN50(rrIntervals);
    
    // Frequency domain features (simplified)
    final lfHfRatio = _computeLFHFRatio(rrIntervals);
    final lf = lfHfRatio != null ? lfHfRatio * 0.6 : null; // Approximate LF
    final hf = lfHfRatio != null ? 0.4 : null; // Approximate HF

    return HRVFeatures(
      meanHr: meanHr,
      hrStd: hrStd,
      hrMin: hrMin,
      hrMax: hrMax,
      sdnn: sdnn,
      rmssd: rmssd,
      pnn50: pnn50,
      lf: lf,
      hf: hf,
      lfHfRatio: lfHfRatio,
      timestamp: timestamp,
    );
  }

  /// Compute Standard Deviation of NN intervals (SDNN)
  double _computeSDNN(List<double> rrIntervals) {
    final mean = _mean(rrIntervals);
    final variance = rrIntervals.map((rr) => pow(rr - mean, 2)).reduce((a, b) => a + b) / rrIntervals.length;
    return sqrt(variance);
  }

  /// Compute Root Mean Square of Successive Differences (RMSSD)
  double _computeRMSSD(List<double> rrIntervals) {
    if (rrIntervals.length < 2) return 0.0;
    
    double sumSquaredDiffs = 0.0;
    for (int i = 1; i < rrIntervals.length; i++) {
      final diff = rrIntervals[i] - rrIntervals[i - 1];
      sumSquaredDiffs += diff * diff;
    }
    
    return sqrt(sumSquaredDiffs / (rrIntervals.length - 1));
  }

  /// Compute Percentage of NN intervals differing by more than 50ms (pNN50)
  double _computePNN50(List<double> rrIntervals) {
    if (rrIntervals.length < 2) return 0.0;
    
    int count = 0;
    for (int i = 1; i < rrIntervals.length; i++) {
      if ((rrIntervals[i] - rrIntervals[i - 1]).abs() > 50.0) {
        count++;
      }
    }
    
    return (count / (rrIntervals.length - 1)) * 100.0;
  }

  /// Compute simplified LF/HF ratio using RR interval variability
  double? _computeLFHFRatio(List<double> rrIntervals) {
    if (rrIntervals.length < 10) return null;
    
    // Simplified frequency domain analysis
    // In a real implementation, this would use FFT or Lomb-Scargle periodogram
    final rmssd = _computeRMSSD(rrIntervals);
    final sdnn = _computeSDNN(rrIntervals);
    
    // Approximate LF/HF ratio based on RMSSD/SDNN relationship
    if (sdnn > 0) {
      return rmssd / sdnn;
    }
    return null;
  }

  /// Calculate mean of a list
  double _mean(List<double> values) {
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Calculate standard deviation of a list
  double _standardDeviation(List<double> values) {
    final mean = _mean(values);
    final variance = values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / values.length;
    return sqrt(variance);
  }

  /// Remove old data to prevent memory buildup
  void _cleanupOldData() {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 2));
    
    while (_timestamps.isNotEmpty && _timestamps.first.isBefore(cutoff)) {
      _timestamps.removeAt(0);
      _rrIntervals.removeAt(0);
      _heartRates.removeAt(0);
    }
  }

  /// Clear all buffered data
  void clear() {
    _rrIntervals.clear();
    _heartRates.clear();
    _timestamps.clear();
  }

  /// Get current data count
  int get dataCount => _rrIntervals.length;
}
