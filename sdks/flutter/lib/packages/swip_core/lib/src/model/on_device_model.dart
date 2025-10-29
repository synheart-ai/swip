class ModelInfo {
  final String id, type, checksum;
  final List<String> inputSchema;
  const ModelInfo({
    required this.id,
    required this.type,
    required this.checksum,
    required this.inputSchema,
  });
}

abstract class OnDeviceModel {
  ModelInfo get info;
  /// features must follow info.inputSchema. Returns probability in [0,1].
  Future<double> predict(List<double> features);
  Future<void> dispose() async {}
}
