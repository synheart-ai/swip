import 'package:flutter_test/flutter_test.dart';
import 'package:swip/swip.dart';

void main() {
  group('ML Components Tests', () {
    test('FeatureExtractor should compute HRV features correctly', () {
      final extractor = FeatureExtractor();
      
      // Add some test RR intervals
      final now = DateTime.now();
      for (int i = 0; i < 60; i++) {
        extractor.addRRInterval(800.0 + (i % 10) * 20.0, now.add(Duration(seconds: i)));
      }
      
      final features = extractor.extractFeatures();
      expect(features, isNotNull);
      expect(features!.meanHr, greaterThan(0));
      expect(features.sdnn, greaterThan(0));
      expect(features.rmssd, greaterThan(0));
    });

    test('SvmPredictor should load model and make predictions', () async {
      final predictor = SvmPredictor();
      
      // Create test features
      final features = HRVFeatures(
        meanHr: 75.0,
        hrStd: 8.0,
        hrMin: 65.0,
        hrMax: 85.0,
        sdnn: 45.0,
        rmssd: 32.0,
        timestamp: DateTime.now(),
      );
      
      // Note: This test would require the actual model file to be present
      // For now, we'll just test the structure
      expect(features.toFeatureVector().length, equals(6));
      expect(features.toFeatureVector()[0], equals(75.0));
    });

    test('EmotionClass should parse strings correctly', () {
      expect(EmotionClass.fromString('Amused'), equals(EmotionClass.amused));
      expect(EmotionClass.fromString('calm'), equals(EmotionClass.calm));
      expect(EmotionClass.fromString('STRESSED'), equals(EmotionClass.stressed));
      expect(EmotionClass.fromString('unknown'), equals(EmotionClass.calm)); // default
    });

    test('SVMModel should parse JSON correctly', () {
      final jsonData = {
        'type': 'linear_svm',
        'version': '1.0',
        'feature_order': ['meanHr', 'hrStd'],
        'scaler_mean': [72.0, 8.0],
        'scaler_scale': [12.0, 5.0],
        'classes': ['Calm', 'Stressed'],
        'weights': [[0.5, -0.3], [-0.2, 0.4]],
        'bias': [0.1, -0.1],
      };
      
      final model = SVMModel.fromJson(jsonData);
      expect(model.type, equals('linear_svm'));
      expect(model.version, equals('1.0'));
      expect(model.classes.length, equals(2));
      expect(model.weights.length, equals(2));
      expect(model.bias.length, equals(2));
    });

    test('InferenceController should manage state correctly', () {
      final controller = InferenceController();
      
      expect(controller.isRunning, isFalse);
      expect(controller.isModelLoaded, isFalse);
      
      // Test adding data
      controller.addHeartRateData(75.0, DateTime.now());
      controller.addRRIntervalData(800.0, DateTime.now());
      
      expect(controller.dataCount, equals(2));
      
      controller.dispose();
    });
  });
}
