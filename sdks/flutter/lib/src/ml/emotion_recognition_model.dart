import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models.dart';

/// Unified emotion recognition model following RFC specifications
/// Supports both WESAD-trained models and custom emotion classification
class EmotionRecognitionModel {
  final String type;
  final String version;
  final String modelId;
  final List<String> featureOrder;
  final List<String> classes;
  final List<double> scalerMean;
  final List<double> scalerStd;
  final List<List<double>> weights;
  final List<double> bias;
  final Map<String, dynamic> inference;
  final Map<String, dynamic> training;
  final String? modelHash;
  final String? exportTimeUtc;
  final String? trainingCommit;
  final String? dataManifestId;

  EmotionRecognitionModel({
    required this.type,
    required this.version,
    required this.modelId,
    required this.featureOrder,
    required this.classes,
    required this.scalerMean,
    required this.scalerStd,
    required this.weights,
    required this.bias,
    required this.inference,
    required this.training,
    this.modelHash,
    this.exportTimeUtc,
    this.trainingCommit,
    this.dataManifestId,
  });

  factory EmotionRecognitionModel.fromJson(Map<String, dynamic> json) {
    final scaler = json['scaler'] as Map<String, dynamic>;
    
    return EmotionRecognitionModel(
      type: json['type'] as String,
      version: json['version'] as String,
      modelId: json['model_id'] as String,
      featureOrder: List<String>.from(json['feature_order'] as List),
      classes: List<String>.from(json['classes'] as List),
      scalerMean: List<double>.from(scaler['mean'] as List),
      scalerStd: List<double>.from(scaler['std'] as List),
      weights: (json['weights'] as List).map((w) => List<double>.from(w as List)).toList(),
      bias: List<double>.from(json['bias'] as List),
      inference: json['inference'] as Map<String, dynamic>? ?? {},
      training: json['training'] as Map<String, dynamic>? ?? {},
      modelHash: json['model_hash'] as String?,
      exportTimeUtc: json['export_time_utc'] as String?,
      trainingCommit: json['training_commit'] as String?,
      dataManifestId: json['data_manifest_id'] as String?,
    );
  }

  /// Load model from Flutter asset
  static Future<EmotionRecognitionModel> loadFromAsset(String assetPath) async {
    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      return EmotionRecognitionModel.fromJson(jsonData);
    } catch (e) {
      throw Exception('Failed to load emotion recognition model: $e');
    }
  }

  /// Predict emotion from HRV features
  EmotionPrediction predict(HRVFeatures features) {
    // Convert features to vector in correct order
    final featureVector = _extractFeatureVector(features);
    
    // Normalize features using z-score
    final normalizedFeatures = _normalizeFeatures(featureVector);
    
    // Compute scores for each class (One-vs-Rest)
    final scores = _computeScores(normalizedFeatures);
    
    // Convert scores to probabilities
    final probabilities = _computeProbabilities(scores);
    
    // Find predicted class
    final predictedIndex = scores.indexOf(scores.reduce(max));
    final predictedClass = EmotionClass.fromString(classes[predictedIndex]);
    
    // Calculate confidence as max probability
    final confidence = probabilities.reduce(max);

    return EmotionPrediction(
      emotion: predictedClass,
      probabilities: probabilities,
      confidence: confidence,
      timestamp: features.timestamp,
    );
  }

  /// Extract feature vector in the correct order
  List<double> _extractFeatureVector(HRVFeatures features) {
    final featureMap = {
      'hr_mean': features.meanHr,
      'hr_std': features.hrStd,
      'hr_min': features.hrMin,
      'hr_max': features.hrMax,
      'sdnn': features.sdnn,
      'rmssd': features.rmssd,
    };

    return featureOrder.map((name) => featureMap[name] ?? 0.0).toList();
  }

  /// Normalize features using z-score normalization
  List<double> _normalizeFeatures(List<double> features) {
    final normalized = <double>[];
    for (int i = 0; i < features.length; i++) {
      final mean = i < scalerMean.length ? scalerMean[i] : 0.0;
      final std = i < scalerStd.length ? scalerStd[i] : 1.0;
      final normalizedValue = (features[i] - mean) / std;
      normalized.add(normalizedValue.isNaN ? 0.0 : normalizedValue);
    }
    return normalized;
  }

  /// Compute SVM scores for each class (One-vs-Rest)
  List<double> _computeScores(List<double> normalizedFeatures) {
    final scores = <double>[];
    
    for (int classIndex = 0; classIndex < weights.length; classIndex++) {
      final classWeights = weights[classIndex];
      final classBias = bias[classIndex];
      
      // Compute dot product: w · x + b
      double score = classBias;
      for (int i = 0; i < normalizedFeatures.length && i < classWeights.length; i++) {
        score += classWeights[i] * normalizedFeatures[i];
      }
      
      scores.add(score);
    }
    
    return scores;
  }

  /// Convert scores to probabilities using softmax
  List<double> _computeProbabilities(List<double> scores) {
    final scoreFn = inference['score_fn'] as String? ?? 'softmax';
    final temperature = (inference['temperature'] as num?)?.toDouble() ?? 1.0;
    
    switch (scoreFn) {
      case 'softmax':
        return _softmax(scores, temperature);
      case 'sigmoid':
        return _sigmoid(scores);
      default:
        return _softmax(scores, temperature);
    }
  }

  /// Apply softmax with temperature scaling
  List<double> _softmax(List<double> scores, double temperature) {
    // Scale by temperature
    final scaledScores = scores.map((s) => s / temperature).toList();
    
    // Find maximum for numerical stability
    final maxScore = scaledScores.reduce(max);
    
    // Compute exponentials
    final exponentials = scaledScores.map((score) => exp(score - maxScore)).toList();
    
    // Compute sum
    final sum = exponentials.reduce((a, b) => a + b);
    
    // Normalize to probabilities
    return exponentials.map((exp) => exp / sum).toList();
  }

  /// Apply sigmoid to each score
  List<double> _sigmoid(List<double> scores) {
    return scores.map((score) => 1.0 / (1.0 + exp(-score))).toList();
  }

  /// Get model information
  Map<String, dynamic> getModelInfo() {
    return {
      'type': type,
      'version': version,
      'modelId': modelId,
      'classes': classes,
      'featureOrder': featureOrder,
      'training': training,
      'modelHash': modelHash,
      'exportTimeUtc': exportTimeUtc,
    };
  }

  /// Validate model integrity
  bool validateModel() {
    // Check basic structure
    if (featureOrder.length != scalerMean.length || 
        featureOrder.length != scalerStd.length) {
      return false;
    }
    
    if (weights.length != classes.length || 
        bias.length != classes.length) {
      return false;
    }
    
    // Check weights dimensions
    for (final weightVector in weights) {
      if (weightVector.length != featureOrder.length) {
        return false;
      }
    }
    
    return true;
  }

  /// Get model performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    return {
      'accuracy': training['accuracy'],
      'balanced_accuracy': training['balanced_accuracy'],
      'f1_score': training['f1_score'],
      'dataset': training['dataset'],
      'subjects': training['subjects'],
      'windows': training['windows'],
    };
  }
}
