import 'dart:math';

/// Adaptive baseline for physiological normalization
/// 
/// Implements rolling baseline updates per RFC specification:
/// - Auto-update every 24 hours
/// - Maintains population fallback
/// - Handles missing data gracefully
class AdaptiveBaseline {
  /// Update interval for baseline recalculation
  final Duration updateInterval;
  
  /// Minimum samples required for reliable baseline
  final int minSamples;
  
  /// Current baseline values
  double _hrMean;
  double _hrStd;
  double _hrvMean;
  double _hrvStd;
  
  /// Last update timestamp
  DateTime _lastUpdate;
  
  /// Sample storage for baseline calculation
  final List<double> _hrSamples = [];
  final List<double> _hrvSamples = [];
  
  /// Population baseline (fallback)
  static const double _populationHrMean = 72.0;
  static const double _populationHrStd = 12.0;
  static const double _populationHrvMean = 45.0;
  static const double _populationHrvStd = 18.0;

  AdaptiveBaseline({
    this.updateInterval = const Duration(hours: 24),
    this.minSamples = 100,
    double? initialHrMean,
    double? initialHrStd,
    double? initialHrvMean,
    double? initialHrvStd,
  }) : _hrMean = initialHrMean ?? _populationHrMean,
       _hrStd = initialHrStd ?? _populationHrStd,
       _hrvMean = initialHrvMean ?? _populationHrvMean,
       _hrvStd = initialHrvStd ?? _populationHrvStd,
       _lastUpdate = DateTime.now().toUtc();

  /// Add new physiological samples
  void addSamples({
    required double hrBpm,
    required double hrvSdnn,
  }) {
    _hrSamples.add(hrBpm);
    _hrvSamples.add(hrvSdnn);
    
    // Check if we should update baseline
    if (_shouldUpdate()) {
      _updateBaseline();
    }
  }

  /// Normalize HR value using current baseline
  double normalizeHr(double hrBpm) {
    return _normalize(hrBpm, _hrMean, _hrStd);
  }

  /// Normalize HRV value using current baseline
  double normalizeHrv(double hrvSdnn) {
    return _normalize(hrvSdnn, _hrvMean, _hrvStd);
  }

  /// Normalize value using mean and standard deviation
  double _normalize(double value, double mean, double std) {
    if (std == 0) return 0.0;
    return (value - mean) / std;
  }

  /// Denormalize HR value back to original scale
  double denormalizeHr(double normalizedHr) {
    return normalizedHr * _hrStd + _hrMean;
  }

  /// Denormalize HRV value back to original scale
  double denormalizeHrv(double normalizedHrv) {
    return normalizedHrv * _hrvStd + _hrvMean;
  }

  /// Check if baseline should be updated
  bool _shouldUpdate() {
    final now = DateTime.now().toUtc();
    final timeSinceUpdate = now.difference(_lastUpdate);
    
    return timeSinceUpdate >= updateInterval && 
           _hrSamples.length >= minSamples;
  }

  /// Update baseline from stored samples
  void _updateBaseline() {
    if (_hrSamples.length < minSamples) return;
    
    // Calculate new HR baseline
    _hrMean = _mean(_hrSamples);
    _hrStd = _std(_hrSamples, _hrMean);
    
    // Calculate new HRV baseline
    _hrvMean = _mean(_hrvSamples);
    _hrvStd = _std(_hrvSamples, _hrvMean);
    
    // Clear old samples (keep recent ones for smoothing)
    final keepCount = minSamples ~/ 2;
    if (_hrSamples.length > keepCount) {
      _hrSamples.removeRange(0, _hrSamples.length - keepCount);
      _hrvSamples.removeRange(0, _hrvSamples.length - keepCount);
    }
    
    _lastUpdate = DateTime.now().toUtc();
  }

  /// Force baseline update
  void forceUpdate() {
    if (_hrSamples.isNotEmpty) {
      _updateBaseline();
    }
  }

  /// Reset to population baseline
  void resetToPopulation() {
    _hrMean = _populationHrMean;
    _hrStd = _populationHrStd;
    _hrvMean = _populationHrvMean;
    _hrvStd = _populationHrvStd;
    
    _hrSamples.clear();
    _hrvSamples.clear();
    _lastUpdate = DateTime.now().toUtc();
  }

  /// Get current baseline values
  Map<String, double> getBaseline() {
    return {
      'hr_mean': _hrMean,
      'hr_std': _hrStd,
      'hrv_mean': _hrvMean,
      'hrv_std': _hrvStd,
      'last_update': _lastUpdate.millisecondsSinceEpoch.toDouble(),
      'sample_count': _hrSamples.length.toDouble(),
    };
  }

  /// Check if baseline is personalized (not population)
  bool get isPersonalized => 
      _hrSamples.length >= minSamples && 
      (_hrMean - _populationHrMean).abs() > 5.0;

  /// Get confidence in current baseline (0-1)
  double get confidence {
    if (_hrSamples.length < minSamples) return 0.0;
    
    final sampleCount = _hrSamples.length.toDouble();
    final maxSamples = minSamples * 2.0;
    
    // Confidence based on sample count and recency
    final countConfidence = (sampleCount / maxSamples).clamp(0.0, 1.0);
    
    final now = DateTime.now().toUtc();
    final hoursSinceUpdate = now.difference(_lastUpdate).inHours;
    final recencyConfidence = (1.0 - hoursSinceUpdate / 48.0).clamp(0.0, 1.0);
    
    return (countConfidence * 0.7 + recencyConfidence * 0.3);
  }

  /// Compute mean
  double _mean(List<double> values) {
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Compute standard deviation
  double _std(List<double> values, double mean) {
    if (values.length < 2) return 0.0;
    
    final variance = values
        .map((x) => pow(x - mean, 2))
        .reduce((a, b) => a + b) / (values.length - 1);
    
    return sqrt(variance);
  }

  /// Create from JSON
  factory AdaptiveBaseline.fromJson(Map<String, dynamic> json) {
    return AdaptiveBaseline(
      updateInterval: Duration(
        milliseconds: (json['update_interval_ms'] as num).toInt(),
      ),
      minSamples: (json['min_samples'] as num).toInt(),
      initialHrMean: (json['hr_mean'] as num?)?.toDouble(),
      initialHrStd: (json['hr_std'] as num?)?.toDouble(),
      initialHrvMean: (json['hrv_mean'] as num?)?.toDouble(),
      initialHrvStd: (json['hrv_std'] as num?)?.toDouble(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'update_interval_ms': updateInterval.inMilliseconds,
      'min_samples': minSamples,
      'hr_mean': _hrMean,
      'hr_std': _hrStd,
      'hrv_mean': _hrvMean,
      'hrv_std': _hrvStd,
      'last_update': _lastUpdate.millisecondsSinceEpoch,
      'sample_count': _hrSamples.length,
      'is_personalized': isPersonalized,
      'confidence': confidence,
    };
  }

  @override
  String toString() {
    return 'AdaptiveBaseline(hr: ${_hrMean.toStringAsFixed(1)}±${_hrStd.toStringAsFixed(1)}, '
           'hrv: ${_hrvMean.toStringAsFixed(1)}±${_hrvStd.toStringAsFixed(1)}, '
           'samples: ${_hrSamples.length}, confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
  }
}

/// Factory for creating adaptive baselines
class AdaptiveBaselineFactory {
  /// Create with population baseline
  static AdaptiveBaseline createPopulation() {
    return AdaptiveBaseline();
  }

  /// Create with custom initial values
  static AdaptiveBaseline createCustom({
    required double hrMean,
    required double hrStd,
    required double hrvMean,
    required double hrvStd,
    Duration updateInterval = const Duration(hours: 24),
    int minSamples = 100,
  }) {
    return AdaptiveBaseline(
      updateInterval: updateInterval,
      minSamples: minSamples,
      initialHrMean: hrMean,
      initialHrStd: hrStd,
      initialHrvMean: hrvMean,
      initialHrvStd: hrvStd,
    );
  }

  /// Create from user's historical data
  static AdaptiveBaseline createFromHistory({
    required List<double> hrHistory,
    required List<double> hrvHistory,
    Duration updateInterval = const Duration(hours: 24),
    int minSamples = 100,
  }) {
    if (hrHistory.isEmpty || hrvHistory.isEmpty) {
      return createPopulation();
    }

    final hrMean = hrHistory.reduce((a, b) => a + b) / hrHistory.length;
    final hrStd = _computeStd(hrHistory, hrMean);
    
    final hrvMean = hrvHistory.reduce((a, b) => a + b) / hrvHistory.length;
    final hrvStd = _computeStd(hrvHistory, hrvMean);

    return AdaptiveBaseline(
      updateInterval: updateInterval,
      minSamples: minSamples,
      initialHrMean: hrMean,
      initialHrStd: hrStd,
      initialHrvMean: hrvMean,
      initialHrvStd: hrvStd,
    );
  }

  static double _computeStd(List<double> values, double mean) {
    if (values.length < 2) return 0.0;
    
    final variance = values
        .map((x) => pow(x - mean, 2))
        .reduce((a, b) => a + b) / (values.length - 1);
    
    return sqrt(variance);
  }
}