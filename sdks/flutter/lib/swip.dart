// Main SDK Manager
export 'src/swip_sdk_manager.dart';

// Models and data types
export 'src/models.dart';
export 'src/errors.dart';
export 'src/data_types.dart';

// Privacy and consent
export 'src/consent_manager.dart';

// Storage
export 'src/storage/storage_schema.dart';

// Legacy exports for backwards compatibility
export 'src/manager.dart' show SWIPManager;
export 'src/synheart_wear_adapter.dart';

// Re-export swip_core types
export 'package:swip_core/swip_core.dart' show SwipScoreResult, PhysiologicalBaseline, SwipConfig, SwipEngine, SwipEngineFactory, SwipScoreComputation;
export 'package:synheart_emotion/synheart_emotion.dart' show EmotionEngine, EmotionConfig, EmotionResult;
export 'package:synheart_wear/synheart_wear.dart' show SynheartWear, WearMetrics, MetricType;

// ML Components (legacy)
export 'src/ml/feature_extractor.dart';
export 'src/ml/svm_predictor.dart';
export 'src/ml/emotion_recognition_model.dart';
export 'src/ml/emotion_recognition_controller.dart' show EmotionRecognitionController, EmotionRecognitionConfig, EmotionState;


