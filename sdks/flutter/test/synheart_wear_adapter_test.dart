import 'package:flutter_test/flutter_test.dart';
import 'package:swip/swip.dart';

void main() {
  group('SynheartWearAdapter', () {
    late SynheartWearAdapter adapter;

    setUp(() {
      adapter = SynheartWearAdapter();
    });

    test('should be created successfully', () {
      expect(adapter, isNotNull);
    });

    test('should throw error when not initialized', () async {
      expect(
        () => adapter.startCollection(
          const SWIPSessionConfig(
            duration: Duration(minutes: 30),
            type: 'baseline',
            platform: 'flutter',
            environment: 'indoor',
          ),
        ),
        throwsA(isA<InvalidConfigurationError>()),
      );
    });

    test('should throw error when reading HRV without initialization', () async {
      expect(
        () => adapter.readCurrentHRV(),
        throwsA(isA<InvalidConfigurationError>()),
      );
    });

    test('should throw error when stopping session without active session', () async {
      expect(
        () => adapter.stopAndEvaluate('non-existent-session'),
        throwsA(isA<SessionNotFoundError>()),
      );
    });

    // Note: Integration tests with actual synheart_wear will be added
    // once the synheart_wear package is available
  });

  group('Wellness Impact Calculation', () {
    test('should classify beneficial impact correctly', () {
      // Test the WIS calculation logic
      final deltaHrv = 0.3; // Positive HRV change
      final coherenceIndex = 0.8; // High coherence
      final stressRecoveryRate = 0.9; // Good recovery
      
      // WIS = w1(ΔHRV) + w2(CI) + w3(-SRR) where w1=0.5, w2=0.3, w3=0.2
      final wellnessScore = (0.5 * deltaHrv) + (0.3 * coherenceIndex) + (0.2 * (1.0 - stressRecoveryRate));
      
      expect(wellnessScore, greaterThan(0.2)); // Should be beneficial
    });

    test('should classify harmful impact correctly', () {
      final deltaHrv = -0.3; // Negative HRV change
      final coherenceIndex = 0.2; // Low coherence
      final stressRecoveryRate = 0.3; // Poor recovery
      
      final wellnessScore = (0.5 * deltaHrv) + (0.3 * coherenceIndex) + (0.2 * (1.0 - stressRecoveryRate));
      
      expect(wellnessScore, lessThan(-0.2)); // Should be harmful
    });

    test('should classify neutral impact correctly', () {
      final deltaHrv = 0.1; // Small HRV change
      final coherenceIndex = 0.5; // Medium coherence
      final stressRecoveryRate = 0.6; // Moderate recovery
      
      final wellnessScore = (0.5 * deltaHrv) + (0.3 * coherenceIndex) + (0.2 * (1.0 - stressRecoveryRate));
      
      expect(wellnessScore, greaterThanOrEqualTo(-0.2));
      expect(wellnessScore, lessThanOrEqualTo(0.2)); // Should be neutral
    });
  });
}
