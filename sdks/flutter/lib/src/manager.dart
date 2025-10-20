import 'models.dart';
import 'errors.dart';
import 'synheart_wear_adapter.dart';

class SWIPManager {
  final SynheartWearAdapter wear;
  bool _initialized = false;
  String? _activeSessionId;

  SWIPManager({SynheartWearAdapter? adapter}) : wear = adapter ?? SynheartWearAdapter();

  Future<void> initialize() async {
    await wear.initialize();
    _initialized = true;
  }

  Future<String> startSession({required SWIPSessionConfig config}) async {
    if (!_initialized) {
      throw InvalidConfigurationError('SWIPManager not initialized');
    }
    _activeSessionId = await wear.startCollection(config);
    return _activeSessionId!;
  }

  Future<SWIPSessionResults> endSession() async {
    if (_activeSessionId == null) {
      throw SessionNotFoundError();
    }
    final results = await wear.stopAndEvaluate(_activeSessionId!);
    _activeSessionId = null;
    return results;
  }

  Future<SWIPMetrics> getCurrentMetrics() async {
    final hrv = await wear.readCurrentHRV();
    return SWIPMetrics(hrv: hrv, timestamp: DateTime.now());
  }
}


