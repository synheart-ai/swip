import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
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
  
  // ONNX-specific fields
  OrtSession? _onnxSession;
  Map<String, dynamic>? _metadata;
  bool _isOnnxModel = false;

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
      inference: Map<String, dynamic>.from(json['inference'] as Map? ?? {}),
      training: Map<String, dynamic>.from(json['training'] as Map? ?? {}),
      modelHash: json['model_hash'] as String?,
      exportTimeUtc: json['export_time_utc'] as String?,
      trainingCommit: json['training_commit'] as String?,
      dataManifestId: json['data_manifest_id'] as String?,
    );
  }

  /// Load model from Flutter asset (supports both JSON and ONNX)
  static Future<EmotionRecognitionModel> loadFromAsset(String assetPath) async {
    try {
      if (assetPath.endsWith('.onnx')) {
        return await _loadOnnxModel(assetPath);
      } else {
        final jsonString = await rootBundle.loadString(assetPath);
        final jsonData = json.decode(jsonString) as Map<String, dynamic>;
        return EmotionRecognitionModel.fromJson(jsonData);
      }
    } catch (e) {
      throw Exception('Failed to load emotion recognition model: $e');
    }
  }

  /// Load ONNX model with metadata
  static Future<EmotionRecognitionModel> _loadOnnxModel(String onnxPath) async {
    try {
      // Load metadata
      final metaPath = onnxPath.replaceAll('.onnx', '.meta.json');
      final jsonString = await rootBundle.loadString(metaPath);
      final metadata = json.decode(jsonString) as Map<String, dynamic>;
      
      // Try to initialize ONNX Runtime
      try {
        final ort = OnnxRuntime();
        final session = await ort.createSessionFromAsset(onnxPath);
        
        // Create model instance with ONNX data
        final model = EmotionRecognitionModel(
          type: metadata['format'] as String,
          version: '1.0', // Default version for ONNX models
          modelId: metadata['model_id'] as String,
          featureOrder: List<String>.from(metadata['schema']['input_names'] as List),
          classes: List<String>.from(metadata['output']['class_names'] as List),
          scalerMean: [], // ONNX models have built-in normalization
          scalerStd: [],
          weights: [], // Not applicable for ONNX
          bias: [],
          inference: metadata['output'] as Map<String, dynamic>,
          training: {
            'dataset': metadata['training_data_tag'] as String? ?? 'unknown',
            'created_utc': metadata['created_utc'] as String?,
          },
          modelHash: metadata['checksum']?['value'] as String?,
          exportTimeUtc: metadata['created_utc'] as String?,
          trainingCommit: null,
          dataManifestId: metadata['training_data_tag'] as String?,
        );
        
        // Set ONNX-specific fields
        model._onnxSession = session;
        model._metadata = metadata;
        model._isOnnxModel = true;
        
        return model;
      } catch (onnxError) {
        // ONNX failed (likely on web platform), fallback to JSON model
        print('ONNX runtime failed: $onnxError');
        print('Falling back to JSON model...');
        
        // Try to load the corresponding JSON model
        final jsonPath = onnxPath.replaceAll('.onnx', '.json');
        return await loadFromAsset(jsonPath);
      }
    } catch (e) {
      throw Exception('Failed to load ONNX model: $e');
    }
  }

  /// Predict emotion from HRV features
  Future<EmotionPrediction> predict(HRVFeatures features) async {
    if (_isOnnxModel) {
      return await _predictOnnx(features);
    } else {
      return _predictJson(features);
    }
  }

  /// Predict using ONNX model
  Future<EmotionPrediction> _predictOnnx(HRVFeatures features) async {
    if (_onnxSession == null) {
      throw Exception('ONNX session not initialized');
    }

    try {
      // Extract all features based on model's feature order
      final featureVector = _extractFeatureVector(features);
      
      // Prepare input tensor
      // Sklearn ExtraTrees models use "X" as input name by default
      // Try common input names in order of likelihood
      final inputShape = [1, featureVector.length]; // Batch size 1, N features
      final inputTensor = await OrtValue.fromList(featureVector, inputShape);
      
      // Try different possible input names
      Map<String, OrtValue>? outputs;
      final possibleInputNames = ['X', 'float_input', 'input', 'inputs', featureOrder.first];
      
      for (final inputName in possibleInputNames) {
        try {
          final inputs = <String, OrtValue>{inputName: inputTensor};
          outputs = await _onnxSession!.run(inputs);
          break; // Success, exit loop
        } catch (e) {
          if (inputName == possibleInputNames.last) {
            // Last attempt failed, rethrow
            throw Exception('Could not find valid input name. Tried: ${possibleInputNames.join(", ")}. Error: $e');
          }
          // Try next name
          continue;
        }
      }
      
      if (outputs == null) {
        throw Exception('Failed to run ONNX inference');
      }
      
      // ExtraTrees ONNX models output: [label, probabilities]
      // probabilities is shape (1, 3) for 3 classes
      List<double> probabilities;
      
      if (outputs.length >= 2) {
        // Model has both label and probabilities outputs
        // Use second output for probabilities (like Python: outputs[1])
        final probsKey = outputs.keys.toList()[1]; // Second output is probabilities
        final probsValue = outputs[probsKey]!;
        final probsData = await probsValue.asList();
        
        // Handle the shape (1, 3) - first dimension is batch, second is classes
        if (probsData is List && probsData.isNotEmpty) {
          if (probsData[0] is List) {
            // Nested list [[p1, p2, p3]] - extract inner list
            final innerList = probsData[0] as List;
            probabilities = innerList.map((e) => (e as num).toDouble()).toList();
          } else {
            // Flat list [p1, p2, p3] - use directly
            probabilities = probsData.map((e) => (e as num).toDouble()).toList();
          }
        } else {
          throw Exception('Unexpected probabilities structure: empty or invalid');
        }
      } else {
        // Fallback: use first output and apply softmax
        final outputKey = outputs.keys.first;
        final outputValue = outputs[outputKey]!;
        final outputData = await outputValue.asList();
        
        List<double> logits;
        if (outputData is List && outputData.isNotEmpty) {
          if (outputData[0] is List) {
            // Nested list
            final innerList = outputData[0] as List;
            logits = innerList.map((e) => (e as num).toDouble()).toList();
          } else {
            // Flat list
            logits = outputData.map((e) => (e as num).toDouble()).toList();
          }
        } else {
          throw Exception('Unexpected output structure: empty or invalid');
        }
        
        probabilities = _softmax(logits, 1.0);
      }
      
      // Find predicted class
      final predictedIndex = probabilities.indexOf(probabilities.reduce(max));
      final predictedClass = EmotionClass.fromString(classes[predictedIndex]);
      
      // Calculate confidence as max probability
      final confidence = probabilities.reduce(max);

      return EmotionPrediction(
        emotion: predictedClass,
        probabilities: probabilities,
        confidence: confidence,
        timestamp: features.timestamp,
      );
    } catch (e) {
      throw Exception('ONNX inference failed: $e');
    }
  }

  /// Predict using JSON model
  EmotionPrediction _predictJson(HRVFeatures features) {
    // Convert features to vector in correct order
    final featureVector = _extractFeatureVector(features);
    
    // Normalize features using z-score
    final normalizedFeatures = _normalizeFeatures(featureVector);
    
    // Compute scores for each class (One-vs-Rest)
    final scores = _computeScores(normalizedFeatures);
    
    // Convert scores to probabilities
    final probabilities = _computeProbabilities(scores);
    
    // Find predicted class (use probabilities, not raw scores)
    final predictedIndex = probabilities.indexOf(probabilities.reduce(max));
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
      'pnn50': features.pnn50 ?? 0.0,
      'mean_rr': features.meanRR ?? 0.0,
      // Add uppercase variants for case-insensitive matching
      'SDNN': features.sdnn,
      'RMSSD': features.rmssd,
      'pNN50': features.pnn50 ?? 0.0,
      'Mean_RR': features.meanRR ?? 0.0,
      'HR_mean': features.meanHr,
      'HR_MEAN': features.meanHr,
      'HR_STD': features.hrStd,
      'HR_MIN': features.hrMin,
      'HR_MAX': features.hrMax,
    };

    final featureVector = featureOrder.map((name) => featureMap[name] ?? 0.0).toList();
    
    return featureVector;
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
    if (_isOnnxModel) {
      // For ONNX models, check that session is loaded and metadata is valid
      return _onnxSession != null && 
             _metadata != null && 
             classes.isNotEmpty && 
             featureOrder.isNotEmpty;
    } else {
      // Check basic structure for JSON models
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
  }

  /// Dispose of model resources
  Future<void> dispose() async {
    if (_isOnnxModel && _onnxSession != null) {
      // ONNX sessions are automatically disposed when they go out of scope
      _onnxSession = null;
    }
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
