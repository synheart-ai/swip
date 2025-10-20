import 'models.dart';
import 'errors.dart';
import 'package:synheart_wear/synheart_wear.dart' as wear;

class SynheartWearAdapter {
  late wear.WearableManager _wearableManager;
  bool _initialized = false;
  String? _activeSessionId;
  List<wear.BiometricData> _sessionData = [];

  Future<void> initialize() async {
    try {
      _wearableManager = wear.WearableManager();
      await _wearableManager.initialize();
      
      // Request permissions for HRV data
      final permissions = await _wearableManager.requestPermissions([
        wear.PermissionType.heartRate,
        wear.PermissionType.heartRateVariability,
        wear.PermissionType.motion,
      ]);
      
      if (!permissions[wear.PermissionType.heartRate]! || 
          !permissions[wear.PermissionType.heartRateVariability]!) {
        throw PermissionDeniedError('HRV permissions not granted');
      }
      
      _initialized = true;
    } catch (e) {
      throw SWIPError('E_INIT_FAILED', 'Failed to initialize synheart_wear: $e');
    }
  }

  Future<String> startCollection(SWIPSessionConfig config) async {
    if (!_initialized) {
      throw InvalidConfigurationError('Adapter not initialized');
    }

    try {
      // Start biometric data collection
      await _wearableManager.startCollection(
        dataTypes: [
          wear.DataType.heartRate,
          wear.DataType.heartRateVariability,
          wear.DataType.rrIntervals,
        ],
        samplingRate: wear.SamplingRate.standard, // ~1Hz for HRV
      );

      // Set up data stream listener
      _wearableManager.dataStream.listen(_onBiometricData);
      
      _activeSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      _sessionData.clear();
      
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
      // Get recent HRV data from synheart_wear
      final recentData = await _wearableManager.getRecentData(
        dataType: wear.DataType.heartRateVariability,
        duration: const Duration(minutes: 5),
      );

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
      await _wearableManager.stopCollection();
      
      // Calculate wellness metrics using SWIP-1.0 reference math
      final results = _calculateWellnessImpact(_sessionData);
      
      _activeSessionId = null;
      _sessionData.clear();
      
      return results;
    } catch (e) {
      throw SWIPError('E_EVALUATION_FAILED', 'Failed to evaluate session: $e');
    }
  }

  void _onBiometricData(wear.BiometricData data) {
    if (_activeSessionId != null) {
      _sessionData.add(data);
    }
  }

  HRVMeasurement _convertBiometricToHRV(wear.BiometricData data) {
    // Convert synheart_wear normalized data to SWIP HRV format
    return HRVMeasurement(
      rmssd: data.hrvMetrics?.rmssd ?? 0.0,
      sdnn: data.hrvMetrics?.sdnn ?? 0.0,
      pnn50: data.hrvMetrics?.pnn50 ?? 0.0,
      lf: data.hrvMetrics?.lowFrequency,
      hf: data.hrvMetrics?.highFrequency,
      lfHfRatio: data.hrvMetrics?.lowHighRatio,
      timestamp: data.timestamp,
      quality: _assessDataQuality(data),
    );
  }

  String _assessDataQuality(wear.BiometricData data) {
    // Assess data quality based on synheart_wear quality indicators
    if (data.qualityScore != null) {
      if (data.qualityScore! >= 0.9) return 'excellent';
      if (data.qualityScore! >= 0.7) return 'good';
      if (data.qualityScore! >= 0.5) return 'fair';
    }
    return 'poor';
  }

  SWIPSessionResults _calculateWellnessImpact(List<wear.BiometricData> sessionData) {
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
        .where((data) => data.hrvMetrics != null)
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
}


