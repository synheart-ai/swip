import 'model/on_device_model.dart';

class SwipScore {
  final double score0to100;
  final Map<String, double> contributors;
  final ModelInfo modelInfo;
  SwipScore(this.score0to100, this.contributors, this.modelInfo);
}

class SwipScorer {
  static SwipScore fromProbability({
    required double p,
    required List<double> features,
    required ModelInfo info,
  }) {
    final score = (p * 100).clamp(0.0, 100.0);
    final contrib = <String, double>{
      'hr': 0.4,
      'hrv': 0.4,
      'motion': 0.2,
    };
    return SwipScore(score, contrib, info);
  }
}
