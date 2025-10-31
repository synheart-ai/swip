import 'dart:async';
import 'models.dart';
import 'errors.dart';
import 'package:synheart_wear/synheart_wear.dart' as wearpkg;

/// Mock biometric data for testing and demo purposes
/// Adapter for wearable device integration backed by synheart_wear SDK
class SynheartWearAdapter {
  bool _initialized = false;
  String? _activeSessionId;
  final List<HRVMeasurement> _sessionData = [];
  wearpkg.SynheartWear? _wear;
  StreamSubscription<wearpkg.WearMetrics>? _hrvSubscription;
  Stream<wearpkg.WearMetrics>? _hrStream;
  // Temporary injection for testing emotion pipeline without device RR
  final bool _injectTestRr = false;

  Future<void> initialize() async {
    try {
      _wear = wearpkg.SynheartWear();
      await _wear!.initialize();
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

      // Start subscribing to HRV stream from synheart_wear
      _hrvSubscription?.cancel();
      _hrvSubscription = _wear!
          .streamHRV(windowSize: const Duration(seconds: 10))
          .listen((wearMetrics) {
        final m = _convertWearToHRV(wearMetrics);
        if (m != null) {
          _sessionData.add(m);
        }
      });

      return _activeSessionId!;
    } catch (e) {
      throw SWIPError(
        'E_COLLECTION_START_FAILED',
        'Failed to start collection: $e',
      );
    }
  }

  /// Expose a stream suitable for emotion engines (HR + RR intervals)
  Stream<({double? hr, List<double>? rrMs, DateTime ts})> emotionInputStream({
    Duration interval = const Duration(seconds: 2),
  }) {
    if (_wear == null) {
      return const Stream.empty();
    }
    _hrStream ??= _wear!.streamHR(interval: interval);
    return _hrStream!.map((m) {
      final hr = m.getMetric(wearpkg.MetricType.hr)?.toDouble();
      List<double>? rr = m.rrMs;
      if ((rr == null || rr.isEmpty) && hr != null && hr > 0) {
        rr =
            _injectTestRr ? _synthesizeRrList(hr, m.timestamp) : [60000.0 / hr];
      }
      return (
        hr: hr,
        rrMs: rr,
        ts: m.timestamp,
      );
    });
  }

  List<double> _synthesizeRrList(double hr, DateTime ts) {
    final base = 60000.0 / hr;
    final count = 40; // ~40 beats as a minimal window
    final out = <double>[];
    final seed = ts.millisecondsSinceEpoch % 1000;
    for (int i = 0; i < count; i++) {
      final phase = ((seed + i * 37) % 100) / 100.0;
      final jitter = (phase - 0.5) * 60.0; // ±30 ms jitter
      out.add((base + jitter).clamp(350.0, 1800.0));
    }
    return out;
  }

  Future<List<HRVMeasurement>> readCurrentHRV() async {
    if (!_initialized) {
      throw InvalidConfigurationError('Adapter not initialized');
    }

    try {
      // Get recent HRV data collected during this session from stream
      final cutoff = DateTime.now().subtract(const Duration(minutes: 5));
      return _sessionData.where((d) => d.timestamp.isAfter(cutoff)).toList();
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
      await _hrvSubscription?.cancel();
      _hrvSubscription = null;

      // Calculate wellness metrics using SWIP-1.0 reference math
      final results = _calculateWellnessImpact(_sessionData);

      _activeSessionId = null;
      _sessionData.clear();

      return results;
    } catch (e) {
      throw SWIPError('E_EVALUATION_FAILED', 'Failed to evaluate session: $e');
    }
  }

  HRVMeasurement? _convertWearToHRV(wearpkg.WearMetrics wear) {
    final rmssd = wear.getMetric(wearpkg.MetricType.hrvRmssd)?.toDouble();
    final sdnn = wear.getMetric(wearpkg.MetricType.hrvSdnn)?.toDouble();
    if (rmssd == null && sdnn == null) return null;

    return HRVMeasurement(
      rmssd: rmssd ?? 0.0,
      sdnn: sdnn ?? 0.0,
      pnn50: 0.0, // not provided by synheart_wear
      lf: null,
      hf: null,
      lfHfRatio: null,
      timestamp: wear.timestamp,
      quality: wear.isSynced ? 'good' : 'fair',
    );
  }

  SWIPSessionResults _calculateWellnessImpact(
    List<HRVMeasurement> sessionData,
  ) {
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

    // We already have HRV measurements
    final hrvMeasurements = sessionData;

    if (hrvMeasurements.length < 2) {
      throw DataQualityError('Insufficient HRV data for analysis');
    }

    // Calculate pre-session baseline (first 30% of data)
    final baselineCount = (hrvMeasurements.length * 0.3).round().clamp(
          1,
          hrvMeasurements.length,
        );
    final baselineRMSSD = hrvMeasurements
            .take(baselineCount)
            .map((m) => m.rmssd)
            .reduce((a, b) => a + b) /
        baselineCount;

    // Calculate post-session average (last 30% of data)
    final postCount = (hrvMeasurements.length * 0.3).round().clamp(
          1,
          hrvMeasurements.length,
        );
    final postRMSSD = hrvMeasurements
            .skip(hrvMeasurements.length - postCount)
            .map((m) => m.rmssd)
            .reduce((a, b) => a + b) /
        postCount;

    // Calculate ΔHRV (normalized)
    final deltaHrv = (postRMSSD - baselineRMSSD) / baselineRMSSD;

    // Calculate Coherence Index (simplified)
    final coherenceIndex = _calculateCoherenceIndex(hrvMeasurements);

    // Calculate Stress-Recovery Rate (simplified)
    final stressRecoveryRate = _calculateStressRecoveryRate(hrvMeasurements);

    // Calculate Wellness Impact Score (WIS) per SWIP-1.0 spec
    // WIS = w1(ΔHRV) + w2(CI) + w3(-SRR) where w1=0.5, w2=0.3, w3=0.2
    final wellnessScore = (0.5 * deltaHrv) +
        (0.3 * coherenceIndex) +
        (0.2 * (1.0 - stressRecoveryRate));

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
    // Without LF/HF, fall back to SDNN stability heuristic
    final sdnnValues = measurements.map((m) => m.sdnn).toList();
    if (sdnnValues.isEmpty) return 0.5;
    final mean = sdnnValues.reduce((a, b) => a + b) / sdnnValues.length;
    final variance =
        sdnnValues.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            sdnnValues.length;
    return (1.0 - (variance / (mean + 1.0))).clamp(0.0, 1.0);
  }

  double _calculateStressRecoveryRate(List<HRVMeasurement> measurements) {
    // Simplified recovery rate calculation
    // Look for return to baseline in the last portion of the session
    final baselineCount = (measurements.length * 0.3).round();
    final baselineRMSSD = measurements
            .take(baselineCount)
            .map((m) => m.rmssd)
            .reduce((a, b) => a + b) /
        baselineCount;

    final lastCount = (measurements.length * 0.2).round();
    final lastRMSSD = measurements
            .skip(measurements.length - lastCount)
            .map((m) => m.rmssd)
            .reduce((a, b) => a + b) /
        lastCount;

    // Recovery rate is how close the final RMSSD is to baseline
    return (lastRMSSD / baselineRMSSD).clamp(0.0, 1.0);
  }

  void dispose() {
    _hrvSubscription?.cancel();
    _hrvSubscription = null;
  }
}
