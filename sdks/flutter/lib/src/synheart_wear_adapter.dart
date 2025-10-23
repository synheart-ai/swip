import 'dart:async';
import 'dart:math';
import 'models.dart';
import 'errors.dart';

/// Mock biometric data for testing and demo purposes
class MockBiometricData {
  final DateTime timestamp;
  final double? heartRate;
  final double? rmssd;
  final double? sdnn;
  final double? pnn50;
  final double? lf;
  final double? hf;
  final double? lfHfRatio;
  final double? qualityScore;

  MockBiometricData({
    required this.timestamp,
    this.heartRate,
    this.rmssd,
    this.sdnn,
    this.pnn50,
    this.lf,
    this.hf,
    this.lfHfRatio,
    this.qualityScore,
  });
}

/// Adapter for wearable device integration
/// Currently uses mock data for demo purposes
class SynheartWearAdapter {
  bool _initialized = false;
  String? _activeSessionId;
  final List<MockBiometricData> _sessionData = [];
  Timer? _mockDataTimer;
  final Random _random = Random();

  // Configuration for simulated data
  bool _useMockData = true;

  Future<void> initialize() async {
    try {
      // In production, this would initialize the actual wearable connection
      // For now, we use simulated data
      _initialized = true;
    } catch (e) {
      throw SWIPError('E_INIT_FAILED', 'Failed to initialize adapter: $e');
    }
  }

  Future<String> startCollection(SWIPSessionConfig config) async {
    if (!_initialized) {
      throw InvalidConfigurationError('Adapter not initialized');
    }

    try {
      _activeSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      _sessionData.clear();

      if (_useMockData) {
        _startMockDataGeneration();
      }

      return _activeSessionId!;
    } catch (e) {
      throw SWIPError('E_COLLECTION_START_FAILED', 'Failed to start collection: $e');
    }
  }

  Future<List<HRVMeasurement>> readCurrentHRV() async {
    if (!_initialized) {
      throw InvalidConfigurationError('Adapter not initialized');
    }

    try {
      // Get recent HRV data
      final recentData = _sessionData.where((data) {
        return data.timestamp.isAfter(
          DateTime.now().subtract(const Duration(minutes: 5)),
        );
      }).toList();

      return recentData.map((data) => _convertBiometricToHRV(data)).toList();
    } catch (e) {
      throw SWIPError('E_DATA_READ_FAILED', 'Failed to read HRV data: $e');
    }
  }

  Future<SWIPSessionResults> stopAndEvaluate(String sessionId) async {
    if (_activeSessionId != sessionId) {
      throw SessionNotFoundError('Session ID mismatch');
    }

    try {
      // Stop data collection
      _mockDataTimer?.cancel();
      _mockDataTimer = null;

      // Calculate wellness metrics using SWIP-1.0 reference math
      final results = _calculateWellnessImpact(_sessionData);

      _activeSessionId = null;
      _sessionData.clear();

      return results;
    } catch (e) {
      throw SWIPError('E_EVALUATION_FAILED', 'Failed to evaluate session: $e');
    }
  }

  void _startMockDataGeneration() {
    // Generate mock biometric data every second
    _mockDataTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_activeSessionId != null) {
        _sessionData.add(_generateMockBiometricData());
      }
    });
  }

  MockBiometricData _generateMockBiometricData() {
    // Generate realistic mock HRV data
    final baseHR = 70.0 + _random.nextDouble() * 20.0; // 70-90 BPM
    final baseRMSSD = 25.0 + _random.nextDouble() * 30.0; // 25-55 ms
    final baseSDNN = 35.0 + _random.nextDouble() * 25.0; // 35-60 ms

    return MockBiometricData(
      timestamp: DateTime.now(),
      heartRate: baseHR,
      rmssd: baseRMSSD,
      sdnn: baseSDNN,
      pnn50: 15.0 + _random.nextDouble() * 35.0,
      lf: 500.0 + _random.nextDouble() * 500.0,
      hf: 300.0 + _random.nextDouble() * 400.0,
      lfHfRatio: 0.8 + _random.nextDouble() * 1.4,
      qualityScore: 0.7 + _random.nextDouble() * 0.3,
    );
  }

  HRVMeasurement _convertBiometricToHRV(MockBiometricData data) {
    return HRVMeasurement(
      rmssd: data.rmssd ?? 0.0,
      sdnn: data.sdnn ?? 0.0,
      pnn50: data.pnn50 ?? 0.0,
      lf: data.lf,
      hf: data.hf,
      lfHfRatio: data.lfHfRatio,
      timestamp: data.timestamp,
      quality: _assessDataQuality(data),
    );
  }

  String _assessDataQuality(MockBiometricData data) {
    if (data.qualityScore != null) {
      if (data.qualityScore! >= 0.9) return 'excellent';
      if (data.qualityScore! >= 0.7) return 'good';
      if (data.qualityScore! >= 0.5) return 'fair';
    }
    return 'poor';
  }

  SWIPSessionResults _calculateWellnessImpact(List<MockBiometricData> sessionData) {
    if (sessionData.isEmpty) {
      return SWIPSessionResults(
        sessionId: _activeSessionId!,
        duration: const Duration(minutes: 0),
        wellnessScore: 0.0,
        deltaHrv: 0.0,
        coherenceIndex: 0.0,
        stressRecoveryRate: 0.0,
        impactType: 'neutral',
      );
    }

    // Extract HRV measurements
    final hrvMeasurements = sessionData
        .map(_convertBiometricToHRV)
        .toList();

    if (hrvMeasurements.length < 2) {
      throw DataQualityError('Insufficient HRV data for analysis');
    }

    // Calculate pre-session baseline (first 30% of data)
    final baselineCount = (hrvMeasurements.length * 0.3).round();
    final baselineRMSSD = hrvMeasurements
        .take(baselineCount)
        .map((m) => m.rmssd)
        .reduce((a, b) => a + b) / baselineCount;

    // Calculate post-session average (last 30% of data)
    final postCount = (hrvMeasurements.length * 0.3).round();
    final postRMSSD = hrvMeasurements
        .skip(hrvMeasurements.length - postCount)
        .map((m) => m.rmssd)
        .reduce((a, b) => a + b) / postCount;

    // Calculate ΔHRV (normalized)
    final deltaHrv = (postRMSSD - baselineRMSSD) / baselineRMSSD;

    // Calculate Coherence Index (simplified)
    final coherenceIndex = _calculateCoherenceIndex(hrvMeasurements);

    // Calculate Stress-Recovery Rate (simplified)
    final stressRecoveryRate = _calculateStressRecoveryRate(hrvMeasurements);

    // Calculate Wellness Impact Score (WIS) per SWIP-1.0 spec
    // WIS = w1(ΔHRV) + w2(CI) + w3(-SRR) where w1=0.5, w2=0.3, w3=0.2
    final wellnessScore = (0.5 * deltaHrv) + (0.3 * coherenceIndex) + (0.2 * (1.0 - stressRecoveryRate));

    // Classify impact type
    String impactType;
    if (wellnessScore > 0.2) {
      impactType = 'beneficial';
    } else if (wellnessScore < -0.2) {
      impactType = 'harmful';
    } else {
      impactType = 'neutral';
    }

    return SWIPSessionResults(
      sessionId: _activeSessionId!,
      duration: Duration(
        milliseconds: sessionData.last.timestamp.millisecondsSinceEpoch -
                     sessionData.first.timestamp.millisecondsSinceEpoch,
      ),
      wellnessScore: wellnessScore.clamp(-1.0, 1.0),
      deltaHrv: deltaHrv,
      coherenceIndex: coherenceIndex,
      stressRecoveryRate: stressRecoveryRate,
      impactType: impactType,
    );
  }

  double _calculateCoherenceIndex(List<HRVMeasurement> measurements) {
    // Simplified coherence calculation based on LF/HF ratio stability
    final lfHfRatios = measurements
        .where((m) => m.lfHfRatio != null)
        .map((m) => m.lfHfRatio!)
        .toList();

    if (lfHfRatios.isEmpty) return 0.5; // Default neutral

    final meanRatio = lfHfRatios.reduce((a, b) => a + b) / lfHfRatios.length;
    final variance = lfHfRatios
        .map((r) => (r - meanRatio) * (r - meanRatio))
        .reduce((a, b) => a + b) / lfHfRatios.length;

    // Coherence increases with lower variance (more stable rhythm)
    return (1.0 - (variance / (meanRatio + 1.0))).clamp(0.0, 1.0);
  }

  double _calculateStressRecoveryRate(List<HRVMeasurement> measurements) {
    // Simplified recovery rate calculation
    // Look for return to baseline in the last portion of the session
    final baselineCount = (measurements.length * 0.3).round();
    final baselineRMSSD = measurements
        .take(baselineCount)
        .map((m) => m.rmssd)
        .reduce((a, b) => a + b) / baselineCount;

    final lastCount = (measurements.length * 0.2).round();
    final lastRMSSD = measurements
        .skip(measurements.length - lastCount)
        .map((m) => m.rmssd)
        .reduce((a, b) => a + b) / lastCount;

    // Recovery rate is how close the final RMSSD is to baseline
    return (lastRMSSD / baselineRMSSD).clamp(0.0, 1.0);
  }

  void dispose() {
    _mockDataTimer?.cancel();
    _mockDataTimer = null;
  }
}
