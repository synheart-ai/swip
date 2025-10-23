import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models.dart';

/// SvmPredictor performs on-device emotion classification using Linear SVM
/// Implements the prediction pipeline defined in RFC: On-Device Linear SVM Inference
class SvmPredictor {
  SVMModel? _model;
  bool _isLoaded = false;

  /// Load SVM model from JSON asset
  Future<void> loadModel(String assetPath) async {
    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      _model = SVMModel.fromJson(jsonData);
      _isLoaded = true;
    } catch (e) {
      throw Exception('Failed to load SVM model: $e');
    }
  }

  /// Predict emotion from HRV features
  EmotionPrediction predict(HRVFeatures features) {
    if (!_isLoaded || _model == null) {
      throw Exception('SVM model not loaded');
    }

    // Convert features to vector
    final featureVector = features.toFeatureVector();
    
    // Normalize features using scaler
    final normalizedFeatures = _normalizeFeatures(featureVector);
    
    // Compute scores for each class
    final scores = _computeScores(normalizedFeatures);
    
    // Convert scores to probabilities using softmax
    final probabilities = _softmax(scores);
    
    // Find predicted class
    final predictedIndex = scores.indexOf(scores.reduce(max));
    final predictedClass = EmotionClass.fromString(_model!.classes[predictedIndex]);
    
    // Calculate confidence as max probability
    final confidence = probabilities.reduce(max);

    return EmotionPrediction(
      emotion: predictedClass,
      probabilities: probabilities,
      confidence: confidence,
      timestamp: features.timestamp,
    );
  }

  /// Normalize features using model's scaler parameters
  List<double> _normalizeFeatures(List<double> features) {
    if (_model == null) throw Exception('Model not loaded');
    
    final normalized = <double>[];
    for (int i = 0; i < features.length; i++) {
      final normalizedValue = (features[i] - _model!.scalerMean[i]) / _model!.scalerScale[i];
      normalized.add(normalizedValue);
    }
    return normalized;
  }

  /// Compute SVM scores for each class (One-vs-Rest)
  List<double> _computeScores(List<double> normalizedFeatures) {
    if (_model == null) throw Exception('Model not loaded');
    
    final scores = <double>[];
    
    for (int classIndex = 0; classIndex < _model!.weights.length; classIndex++) {
      final weights = _model!.weights[classIndex];
      final bias = _model!.bias[classIndex];
      
      // Compute dot product: w · x + b
      double score = bias;
      for (int i = 0; i < normalizedFeatures.length; i++) {
        score += weights[i] * normalizedFeatures[i];
      }
      
      scores.add(score);
    }
    
    return scores;
  }

  /// Apply softmax to convert scores to probabilities
  List<double> _softmax(List<double> scores) {
    // Find maximum score for numerical stability
    final maxScore = scores.reduce(max);
    
    // Compute exponentials
    final exponentials = scores.map((score) => exp(score - maxScore)).toList();
    
    // Compute sum
    final sum = exponentials.reduce((a, b) => a + b);
    
    // Normalize to probabilities
    return exponentials.map((exp) => exp / sum).toList();
  }

  /// Get model information
  Map<String, dynamic>? getModelInfo() {
    if (_model == null) return null;
    
    return {
      'type': _model!.type,
      'version': _model!.version,
      'classes': _model!.classes,
      'featureOrder': _model!.featureOrder,
      'modelHash': _model!.modelHash,
      'exportTimeUtc': _model!.exportTimeUtc,
    };
  }

  /// Check if model is loaded
  bool get isLoaded => _isLoaded;

  /// Get model classes
  List<String> get classes => _model?.classes ?? [];
}
