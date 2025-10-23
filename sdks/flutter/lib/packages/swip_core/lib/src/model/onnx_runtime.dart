import 'on_device_model.dart';

class ONNXRuntimeModel implements OnDeviceModel {
  ONNXRuntimeModel._();

  static Future<ONNXRuntimeModel> load(String ref) async {
    throw UnsupportedError('ONNX backend not available in this build');
  }

  @override
  ModelInfo get info => throw UnsupportedError('ONNX not enabled');

  @override
  double predict(List<double> features) =>
      throw UnsupportedError('ONNX backend not available');

  @override
  Future<void> dispose() async {}
}
