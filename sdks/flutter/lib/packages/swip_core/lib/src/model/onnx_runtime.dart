import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'on_device_model.dart';

class ONNXRuntimeModel implements OnDeviceModel {
  late final OrtSession _session;
  late final ModelInfo _info;
  late final Map<String, dynamic> _metadata;
  bool _isLoaded = false;

  ONNXRuntimeModel._();

  static Future<ONNXRuntimeModel> load(String modelPath) async {
    final model = ONNXRuntimeModel._();
    await model._loadModel(modelPath);
    return model;
  }

  Future<void> _loadModel(String modelPath) async {
    try {
      // Load metadata from meta.json file
      final metaPath = modelPath.replaceAll('.onnx', '.meta.json');
      final jsonString = await rootBundle.loadString(metaPath);
      _metadata = json.decode(jsonString) as Map<String, dynamic>;

      // Initialize ONNX Runtime
      final ort = OnnxRuntime();
      _session = await ort.createSessionFromAsset(modelPath);

      // Create model info from metadata
      _info = ModelInfo(
        modelId: _metadata['model_id'] as String,
        format: _metadata['format'] as String,
        inputNames: List<String>.from(_metadata['schema']['input_names'] as List),
        classNames: List<String>.from(_metadata['output']['class_names'] as List),
        positiveClass: _metadata['output']['positive_class'] as String?,
      );

      _isLoaded = true;
    } catch (e) {
      throw Exception('Failed to load ONNX model: $e');
    }
  }

  @override
  ModelInfo get info {
    if (!_isLoaded) throw Exception('Model not loaded');
    return _info;
  }

  @override
  Future<double> predict(List<double> features) async {
    if (!_isLoaded) throw Exception('Model not loaded');
    
    try {
      // Prepare input tensor
      final inputName = _info.inputNames.first; // Assuming single input
      final inputShape = [1, features.length]; // Batch size 1
      final inputTensor = await OrtValue.fromList(features, inputShape);
      
      // Run inference (this returns a Future)
      final inputs = {inputName: inputTensor};
      final outputs = await _session.run(inputs);
      
      // Get output probabilities
      final outputKey = outputs.keys.first;
      final outputData = outputs[outputKey]!.asList() as List<double>;
      
      // Find the probability for the positive class (Stress)
      final positiveClassIndex = _info.classNames.indexOf(_info.positiveClass ?? 'Stress');
      if (positiveClassIndex >= 0 && positiveClassIndex < outputData.length) {
        return outputData[positiveClassIndex];
      }
      
      // Fallback: return max probability
      return outputData.reduce((a, b) => a > b ? a : b);
    } catch (e) {
      throw Exception('ONNX inference failed: $e');
    }
  }

  @override
  Future<void> dispose() async {
    if (_isLoaded) {
      // ONNX sessions are automatically disposed when they go out of scope
      _isLoaded = false;
    }
  }
}
