class SWIPSessionConfig {
  final Duration duration;
  final String type; // baseline, focus, stress, recovery, exercise, meditation
  final String platform; // flutter
  final String environment; // indoor, outdoor, office, home
  final Map<String, dynamic>? customMetrics;

  const SWIPSessionConfig({
    required this.duration,
    required this.type,
    required this.platform,
    required this.environment,
    this.customMetrics,
  });
}

class HRVMeasurement {
  final double rmssd;
  final double sdnn;
  final double pnn50;
  final double? lf;
  final double? hf;
  final double? lfHfRatio;
  final DateTime timestamp;
  final String quality; // excellent, good, fair, poor

  const HRVMeasurement({
    required this.rmssd,
    required this.sdnn,
    required this.pnn50,
    this.lf,
    this.hf,
    this.lfHfRatio,
    required this.timestamp,
    this.quality = 'good',
  });
}

class SWIPMetrics {
  final List<HRVMeasurement> hrv;
  final DateTime timestamp;

  const SWIPMetrics({
    required this.hrv,
    required this.timestamp,
  });
}

class SWIPSessionResults {
  final String sessionId;
  final Duration duration;
  final double wellnessScore;
  final double deltaHrv;
  final double coherenceIndex;
  final double stressRecoveryRate;
  final String impactType; // beneficial | neutral | harmful

  const SWIPSessionResults({
    required this.sessionId,
    required this.duration,
    required this.wellnessScore,
    required this.deltaHrv,
    required this.coherenceIndex,
    required this.stressRecoveryRate,
    required this.impactType,
  });
}


