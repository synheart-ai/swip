import 'on_device_model.dart';

class CoreMLIOS implements OnDeviceModel {
  CoreMLIOS._();

  static Future<CoreMLIOS> load(String ref) async {
    throw UnsupportedError('CoreML backend not available in this build');
  }

  @override
  ModelInfo get info => throw UnsupportedError('CoreML not enabled');

  @override
  double predict(List<double> features) =>
      throw UnsupportedError('CoreML backend not available');

  @override
  Future<void> dispose() async {}
}
