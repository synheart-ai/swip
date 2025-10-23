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

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'duration': duration.inMilliseconds,
    'wellnessScore': wellnessScore,
    'deltaHrv': deltaHrv,
    'coherenceIndex': coherenceIndex,
    'stressRecoveryRate': stressRecoveryRate,
    'impactType': impactType,
  };
}

// Emotion Recognition Models
enum EmotionClass {
  amused('Amused'),
  calm('Calm'),
  stressed('Stressed');

  const EmotionClass(this.label);
  final String label;

  static EmotionClass fromString(String label) {
    return EmotionClass.values.firstWhere(
      (e) => e.label.toLowerCase() == label.toLowerCase(),
      orElse: () => EmotionClass.calm,
    );
  }
}

class EmotionPrediction {
  final EmotionClass emotion;
  final List<double> probabilities;
  final double confidence;
  final DateTime timestamp;

  EmotionPrediction({
    required this.emotion,
    required this.probabilities,
    required this.confidence,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'emotion': emotion.label,
    'probabilities': probabilities,
    'confidence': confidence,
    'timestamp': timestamp.toIso8601String(),
  };
}

class HRVFeatures {
  final double meanHr;
  final double hrStd;
  final double hrMin;
  final double hrMax;
  final double sdnn;
  final double rmssd;
  final double? pnn50;
  final double? lf;
  final double? hf;
  final double? lfHfRatio;
  final DateTime timestamp;

  HRVFeatures({
    required this.meanHr,
    required this.hrStd,
    required this.hrMin,
    required this.hrMax,
    required this.sdnn,
    required this.rmssd,
    this.pnn50,
    this.lf,
    this.hf,
    this.lfHfRatio,
    required this.timestamp,
  });

  // Convert to feature vector for ML model
  List<double> toFeatureVector() {
    return [
      meanHr,
      hrStd,
      hrMin,
      hrMax,
      sdnn,
      rmssd,
    ];
  }

  Map<String, dynamic> toJson() => {
    'meanHr': meanHr,
    'hrStd': hrStd,
    'hrMin': hrMin,
    'hrMax': hrMax,
    'sdnn': sdnn,
    'rmssd': rmssd,
    'pnn50': pnn50,
    'lf': lf,
    'hf': hf,
    'lfHfRatio': lfHfRatio,
    'timestamp': timestamp.toIso8601String(),
  };
}

class SVMModel {
  final String type;
  final String version;
  final List<String> featureOrder;
  final List<double> scalerMean;
  final List<double> scalerScale;
  final List<String> classes;
  final List<List<double>> weights;
  final List<double> bias;
  final String? modelHash;
  final String? exportTimeUtc;

  SVMModel({
    required this.type,
    required this.version,
    required this.featureOrder,
    required this.scalerMean,
    required this.scalerScale,
    required this.classes,
    required this.weights,
    required this.bias,
    this.modelHash,
    this.exportTimeUtc,
  });

  factory SVMModel.fromJson(Map<String, dynamic> json) {
    return SVMModel(
      type: json['type'] as String,
      version: json['version'] as String,
      featureOrder: List<String>.from(json['feature_order'] as List),
      scalerMean: List<double>.from(json['scaler_mean'] as List),
      scalerScale: List<double>.from(json['scaler_scale'] as List),
      classes: List<String>.from(json['classes'] as List),
      weights: (json['weights'] as List).map((w) => List<double>.from(w as List)).toList(),
      bias: List<double>.from(json['bias'] as List),
      modelHash: json['model_hash'] as String?,
      exportTimeUtc: json['export_time_utc'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'version': version,
    'feature_order': featureOrder,
    'scaler_mean': scalerMean,
    'scaler_scale': scalerScale,
    'classes': classes,
    'weights': weights,
    'bias': bias,
    'model_hash': modelHash,
    'export_time_utc': exportTimeUtc,
  };
}


