# SWIP Flutter SDK

Flutter implementation of the Synheart Wellness Impact Protocol with integrated emotion recognition capabilities.

## Overview

The SWIP Flutter SDK provides comprehensive wellness impact measurement and real-time emotion recognition using heart rate variability (HRV) data from wearable devices. The SDK includes:

- **Wellness Impact Measurement** - Quantify the physiological effects of digital experiences
- **Real-time Emotion Recognition** - Classify emotional states using WESAD-trained models
- **Multi-device Support** - Works with Apple Watch, Fitbit, Garmin, and other wearables
- **Privacy-focused** - All processing happens on-device

## Install

Add to pubspec.yaml:

```yaml
dependencies:
  swip:
    path: ./sdks/flutter
```

Or use as a package when published.

## Quick Start

### Basic Wellness Measurement

```dart
import 'package:swip/swip.dart';

final swip = SWIPManager();
await swip.initialize();

final sessionId = await swip.startSession(
  config: SWIPSessionConfig(
    duration: Duration(minutes: 30),
    type: 'baseline',
    platform: 'flutter',
    environment: 'indoor',
  ),
);

final metrics = await swip.getCurrentMetrics();
final results = await swip.endSession();
print('Wellness Impact Score: ${results.wellnessScore}');
```

### Emotion Recognition

```dart
// Initialize with emotion recognition
final swipManager = SWIPManager();
await swipManager.initialize();

// Start session with emotion recognition
final sessionId = await swipManager.startSession(config: sessionConfig);

// Listen to real-time emotion predictions
swipManager.emotionStream.listen((prediction) {
  print('Emotion: ${prediction.emotion.label}');
  print('Confidence: ${prediction.confidence}');
  print('Probabilities: ${prediction.probabilities}');
});

// Add heart rate data (from wearable device)
swipManager.addHeartRateData(75.0, DateTime.now());

// Add RR interval data (from wearable device)  
swipManager.addRRIntervalData(800.0, DateTime.now());

// End session
final results = await swipManager.endSession();
```

## Features

### Wellness Impact Measurement

- **HRV Analysis** - RMSSD, SDNN, PNN50, frequency domain metrics
- **Wellness Impact Score** - Quantified physiological impact (0-100)
- **Session Tracking** - Monitor changes over time
- **Multi-platform Support** - Works across different wearable devices

### Emotion Recognition

- **Real-time Classification** - Amused, Calm, Stressed emotional states
- **WESAD-trained Models** - 78% accuracy on academic dataset
- **On-device Processing** - Complete privacy, no cloud dependencies
- **Configurable Parameters** - Adjustable window sizes and inference frequency

### Emotion Classes
- **Amused** - Positive emotional state with elevated HRV
- **Calm** - Neutral baseline emotional state  
- **Stressed** - Negative emotional state with reduced HRV

### HRV Metrics Computed
1. **Mean Heart Rate** - Average BPM over window
2. **Heart Rate Standard Deviation** - Variability measure
3. **Heart Rate Min/Max** - Range indicators
4. **SDNN** - Standard deviation of NN intervals
5. **RMSSD** - Root mean square of successive differences
6. **PNN50** - Percentage of intervals differing by >50ms

## Architecture

### Wellness Measurement
```
Wearable Data → SynheartWearAdapter → SWIPManager → Wellness Results
```

### Emotion Recognition
```
Wearable Data → FeatureExtractor → EmotionRecognitionModel → EmotionRecognitionController → UI
```

### Components

| Component | Description | File |
|-----------|-------------|------|
| `SWIPManager` | Main SDK interface with integrated emotion recognition | `lib/src/manager.dart` |
| `SynheartWearAdapter` | Hardware connectivity via synheart_wear | `lib/src/synheart_wear_adapter.dart` |
| `EmotionRecognitionModel` | Unified model loader and predictor | `lib/src/ml/emotion_recognition_model.dart` |
| `EmotionRecognitionController` | Real-time emotion detection pipeline | `lib/src/ml/emotion_recognition_controller.dart` |
| `FeatureExtractor` | Computes HRV features from sensor data | `lib/src/ml/feature_extractor.dart` |

## Model Specifications

### Emotion Recognition Model
- **Type**: Linear SVM (One-vs-Rest, 3 classes)
- **Features**: 6-dimensional HRV feature vector
- **Window Size**: 60 seconds (configurable)
- **Inference Interval**: 10 seconds (configurable)
- **Model Size**: < 1 MB JSON file
- **Training Dataset**: WESAD (Wearable Stress and Affect Detection)
- **Performance**: 78% accuracy, 76% balanced accuracy, 75% F1 score

## Hardware Connectivity

SWIP uses `synheart_wear` for unified device connectivity across multiple platforms:

- **Apple Watch** - Native HealthKit integration
- **Fitbit** - API-based data collection
- **Garmin** - Connect IQ and API support
- **Samsung Watch** - Samsung Health integration
- **BLE Heart Rate Monitors** - Generic Bluetooth Low Energy support

## Performance Targets

| Metric | Target | Current |
|--------|--------|---------|
| Model Size | < 1 MB | ~50 KB |
| Inference Time | < 10 ms | ~5 ms |
| Memory Footprint | < 5 MB | ~2 MB |
| Battery Impact | < 2% per hour | ~1% per hour |
| Accuracy | ≥ 75% | 78% (WESAD) |

## Privacy & Security

- **Local Processing**: All wellness and emotion analysis runs on-device
- **No Data Transmission**: HRV data never leaves the device
- **Open Model Weights**: Model parameters are transparent and auditable
- **User Control**: Users can opt-in for anonymized research data
- **Model Integrity**: SHA-256 hash verification for model authenticity

## Testing

Run the comprehensive test suite:

```bash
# Run all tests
flutter test

# Run emotion recognition tests specifically
flutter test test/emotion_recognition_test.dart

# Run ML component tests
flutter test test/ml_components_test.dart
```

Run the example app to see both wellness measurement and emotion recognition in action:

```bash
cd example
flutter run
```

## Advanced Usage

### Custom Emotion Recognition Configuration

```dart
// Custom emotion recognition controller with different parameters
final emotionController = EmotionRecognitionController(
  inferenceInterval: Duration(seconds: 5),  // More frequent updates
  featureWindowSize: Duration(seconds: 90), // Longer analysis window
  modelAssetPath: 'assets/ml/custom_model.json', // Custom model
);

final swipManager = SWIPManager(
  emotionController: emotionController,
);
```

### Direct Model Access

```dart
// Load emotion recognition model directly
final model = await EmotionRecognitionModel.loadFromAsset('assets/ml/wesad_emotion_v1_0.json');

// Get model information
final modelInfo = model.getModelInfo();
print('Model: ${modelInfo['modelId']} v${modelInfo['version']}');

// Get performance metrics
final metrics = model.getPerformanceMetrics();
print('Accuracy: ${metrics['accuracy']}');
```

## Model Files

### Emotion Recognition Model

The emotion recognition model uses a unified JSON format:

```json
{
  "type": "linear_svm_ovr",
  "version": "1.0",
  "model_id": "wesad_emotion_v1_0",
  "feature_order": ["hr_mean", "hr_std", "hr_min", "hr_max", "sdnn", "rmssd"],
  "classes": ["Amused", "Calm", "Stressed"],
  "scaler": {
    "mean": [72.5, 8.2, 65.0, 85.0, 45.3, 32.1],
    "std": [12.0, 5.5, 8.0, 15.0, 18.7, 12.4]
  },
  "weights": [
    [0.12, -0.33, 0.08, -0.19, 0.5, 0.3],
    [-0.21, 0.55, -0.07, 0.1, -0.4, -0.3],
    [0.02, -0.12, 0.1, 0.05, 0.2, 0.1]
  ],
  "bias": [-0.2, 0.3, 0.1],
  "training": {
    "dataset": "WESAD",
    "accuracy": 0.78,
    "balanced_accuracy": 0.76,
    "f1_score": 0.75
  }
}
```

### Model Loading

Models are loaded from Flutter assets:

```yaml
# pubspec.yaml
flutter:
  assets:
    - assets/ml/
```

Place your model JSON files in `assets/ml/` directory.

## Troubleshooting

### Common Issues

1. **Model Not Loading**: Ensure model JSON file is in `assets/ml/` directory
2. **No Emotion Predictions**: Check that heart rate data is being added regularly
3. **Low Confidence**: Ensure sufficient data in analysis window (60+ seconds)
4. **Performance Issues**: Reduce inference frequency or window size

### Debug Mode

Enable debug logging to troubleshoot issues:

```dart
// Enable debug output
swipManager.emotionStream.listen((prediction) {
  print('DEBUG: Emotion prediction: $prediction');
});

// Get model information
final modelInfo = swipManager.emotionController.getModelInfo();
print('Model: ${modelInfo['modelId']} v${modelInfo['version']}');

// Get performance metrics
final metrics = swipManager.emotionController.getPerformanceMetrics();
print('Accuracy: ${metrics['accuracy']}');
```

## Future Enhancements

1. **Model Training Pipeline**: Automated WESAD dataset processing and model training
2. **Adaptive Baselines**: Personalized emotion recognition based on individual HRV patterns
3. **Federated Learning**: Aggregate performance metrics without sharing raw data
4. **Model Distillation**: Compress SVM to lightweight neural network
5. **Multimodal Fusion**: Combine HRV with motion, GSR, and cognitive performance data
6. **Real-time Calibration**: On-device model adaptation based on user feedback

## References

- **WESAD Dataset**: Wearable Stress and Affect Detection
- **Li & Washington (2023)**: Personalized vs Generalized Emotion Recognition
- **SWIP-1.0 Specification**: Synheart Wellness Impact Protocol
- **RFC Documents**: On-device SVM implementation specifications

## License

Apache-2.0  
© 2025 Synheart AI — open source & community-driven.

---

**Author**: Israel Goytom  
**Organization**: Synheart Open Council (SOC)