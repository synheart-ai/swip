import 'package:swip_core/swip_core.dart';
import 'package:synheart_emotion/synheart_emotion.dart';
import 'package:synheart_wear/synheart_wear.dart';

/// SWIP Session Configuration
class SWIPSessionConfig {
  final String appId;
  final Map<String, dynamic> metadata;

  const SWIPSessionConfig({
    required this.appId,
    this.metadata = const {},
  });
}

/// SWIP Session Results
class SwipSessionResults {
  final String sessionId;
  final List<SwipScoreResult> scores;
  final List<EmotionResult> emotions;
  final DateTime startTime;
  final DateTime endTime;

  const SwipSessionResults({
    required this.sessionId,
    required this.scores,
    required this.emotions,
    required this.startTime,
    required this.endTime,
  });

  /// Get summary statistics
  Map<String, dynamic> getSummary() {
    if (scores.isEmpty) {
      return {
        'duration_seconds': 0,
        'average_swip_score': 0.0,
        'dominant_emotion': 'Unknown',
      };
    }

    final avgScore = scores.map((s) => s.swipScore).reduce((a, b) => a + b) / scores.length;
    final dominantEmotion = _getMostFrequentEmotion();
    
    return {
      'session_id': sessionId,
      'duration_seconds': endTime.difference(startTime).inSeconds,
      'average_swip_score': avgScore,
      'dominant_emotion': dominantEmotion,
      'score_count': scores.length,
      'emotion_count': emotions.length,
    };
  }

  /// Get most frequent emotion
  String _getMostFrequentEmotion() {
    if (scores.isEmpty) return 'Unknown';
    
    final emotionCounts = <String, int>{};
    for (final score in scores) {
      emotionCounts[score.dominantEmotion] = 
          (emotionCounts[score.dominantEmotion] ?? 0) + 1;
    }
    
    String mostFrequent = '';
    int maxCount = 0;
    
    for (final entry in emotionCounts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        mostFrequent = entry.key;
      }
    }
    
    return mostFrequent;
  }
}

/// SWIP Metrics - Deprecated, use SwipScoreResult instead
@Deprecated('Use SwipScoreResult from swip_core instead')
class SWIPMetrics {
  final double? hrv;
  final DateTime timestamp;

  SWIPMetrics({
    this.hrv,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Emotion Prediction wrapper (compatibility with old API)
class EmotionPrediction {
  final String emotion;
  final double confidence;
  final Map<String, double> probabilities;

  EmotionPrediction({
    required this.emotion,
    required this.confidence,
    this.probabilities = const {},
  });

  factory EmotionPrediction.fromEmotionResult(EmotionResult result) {
    return EmotionPrediction(
      emotion: result.emotion,
      confidence: result.confidence,
      probabilities: result.probabilities,
    );
  }
}
