import '../src/models.dart';

/// Emotion utilities as defined in the RFC
class EmotionUtilities {
  /// Utility values for each emotion class
  static const Map<String, double> utilities = {
    'Amused': 0.95,
    'Calm': 0.85,
    'Focused': 0.80,
    'Neutral': 0.70,
    'Stressed': 0.15,
  };

  /// Get utility for an emotion class
  static double getUtility(String emotion) {
    return utilities[emotion] ?? 0.5;
  }
}

/// Physiological weights as defined in the RFC
class PhysiologicalWeights {
  static const double hr = 0.45;
  static const double hrv = 0.35;
  static const double motion = 0.20;
}

/// Computes SWIP Score based on RFC specification
class SwipScoreComputation {
  /// Compute physiological subscore
  /// 
  /// Formula: S_phys = w_HR * S_HR + w_HRV * S_HRV + w_M * S_M
  /// Each S_i is baseline-normalized: S_i = 1 - |x_i - μ_i^base| / σ_i^base
  static double computePhysiologicalSubscore({
    required double hr,
    required double hrv,
    required double motion,
    required PhysiologicalBaseline baseline,
  }) {
    // Normalize HR
    final hrScore = 1.0 - ((hr - baseline.hrMean).abs() / baseline.hrStd).clamp(0.0, 1.0);
    
    // Normalize HRV
    final hrvScore = 1.0 - ((hrv - baseline.hrvMean).abs() / baseline.hrvStd).clamp(0.0, 1.0);
    
    // Motion score (lower motion is better for HRV quality)
    final motionScore = (1.0 - (motion / 2.0).clamp(0.0, 1.0));
    
    // Weighted combination
    final physScore = 
        PhysiologicalWeights.hr * hrScore +
        PhysiologicalWeights.hrv * hrvScore +
        PhysiologicalWeights.motion * motionScore;
    
    return physScore.clamp(0.0, 1.0);
  }

  /// Compute emotion subscore
  /// 
  /// Formula: S_emo = Σ(p_i * u_i)
  static double computeEmotionSubscore(Map<String, double> emotionProbabilities) {
    double emoScore = 0.0;
    
    for (final entry in emotionProbabilities.entries) {
      final utility = EmotionUtilities.getUtility(entry.key);
      emoScore += entry.value * utility;
    }
    
    return emoScore;
  }

  /// Compute confidence from emotion probabilities
  /// 
  /// Formula: C = (p_max - p_2) / (1 - 1/K)
  static double computeConfidence(Map<String, double> emotionProbabilities) {
    if (emotionProbabilities.isEmpty) return 0.0;
    
    final sortedProbs = emotionProbabilities.values.toList()..sort((a, b) => b.compareTo(a));
    final K = emotionProbabilities.length;
    
    final pMax = sortedProbs[0];
    final p2 = sortedProbs.length > 1 ? sortedProbs[1] : 0.0;
    
    final confidence = (pMax - p2) / (1.0 - 1.0 / K);
    return confidence.clamp(0.0, 1.0);
  }

  /// Find dominant emotion
  static String findDominantEmotion(Map<String, double> emotionProbabilities) {
    if (emotionProbabilities.isEmpty) return 'Neutral';
    
    String dominant = '';
    double maxProb = 0.0;
    
    for (final entry in emotionProbabilities.entries) {
      if (entry.value > maxProb) {
        maxProb = entry.value;
        dominant = entry.key;
      }
    }
    
    return dominant;
  }

  /// Compute full SWIP Score
  /// 
  /// Formula: SWIP = β * S_emo + (1-β) * S_phys
  /// where β = min(0.6, C)
  /// Then: SWIP_100 = 100 * SWIP
  static SwipScoreResult computeSwipScore({
    required double hr,
    required double hrv,
    required double motion,
    required Map<String, double> emotionProbabilities,
    required PhysiologicalBaseline baseline,
    required String modelId,
    DateTime? timestamp,
  }) {
    // Compute subscores
    final physScore = computePhysiologicalSubscore(
      hr: hr,
      hrv: hrv,
      motion: motion,
      baseline: baseline,
    );
    
    final emoScore = computeEmotionSubscore(emotionProbabilities);
    
    // Compute confidence
    final confidence = computeConfidence(emotionProbabilities);
    
    // Compute fusion weight β
    final beta = (0.6 * confidence).clamp(0.0, 0.6);
    
    // Fuse subscores
    final swipRaw = beta * emoScore + (1.0 - beta) * physScore;
    
    // Convert to 0-100 scale
    final swipScore = (swipRaw * 100).clamp(0.0, 100.0);
    
    // Find dominant emotion
    final dominantEmotion = findDominantEmotion(emotionProbabilities);
    
    // Build reasons
    final reasons = {
      'hr': hr,
      'hrv': hrv,
      'motion': motion,
      'phys_contribution': physScore,
      'emo_contribution': emoScore,
      'beta': beta,
    };
    
    return SwipScoreResult(
      swipScore: swipScore,
      physSubscore: physScore,
      emoSubscore: emoScore,
      confidence: confidence,
      dominantEmotion: dominantEmotion,
      emotionProbabilities: emotionProbabilities,
      timestamp: timestamp ?? DateTime.now().toUtc(),
      modelId: modelId,
      reasons: reasons,
    );
  }

  /// Apply exponential smoothing to a series of scores
  /// 
  /// Formula: smoothed = λ * current + (1 - λ) * previous
  static double smoothScore(double current, double previous, {double lambda = 0.9}) {
    return lambda * current + (1.0 - lambda) * previous;
  }

  /// Interpret SWIP Score according to RFC ranges
  static String interpretScore(double swipScore) {
    if (swipScore >= 80.0) {
      return 'Positive';
    } else if (swipScore >= 60.0) {
      return 'Neutral';
    } else if (swipScore >= 40.0) {
      return 'Mild Stress';
    } else {
      return 'Negative';
    }
  }
}

