import 'on_device_model.dart';
import 'json_linear_model.dart';
import 'coreml_ios.dart';
import 'onnx_runtime.dart';

class ModelFactory {
  static Future<OnDeviceModel> load({
    required String backend,
    required String modelRef,
  }) async {
    switch (backend) {
      case 'json_linear':
        return JsonLinearModel.loadFromAsset(modelRef);
      case 'coreml':
        return CoreMLIOS.load(modelRef);
      case 'onnx':
        return ONNXRuntimeModel.load(modelRef);
      default:
        throw ArgumentError('Unknown backend: $backend');
    }
  }
}
