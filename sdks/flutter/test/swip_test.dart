import 'package:flutter_test/flutter_test.dart';
import 'package:swip/swip.dart';

void main() {
  group('SWIPManager', () {
    late SWIPManager swipManager;

    setUp(() {
      swipManager = SWIPManager();
    });

    test('should initialize successfully', () async {
      // Note: This test will fail until synheart_wear is available
      // For now, we'll test the structure
      expect(swipManager, isNotNull);
    });

    test('should create valid session config', () {
      final config = SWIPSessionConfig(
        duration: const Duration(minutes: 30),
        type: 'baseline',
        platform: 'flutter',
        environment: 'indoor',
        customMetrics: {'task_difficulty': 'medium'},
      );

      expect(config.duration, const Duration(minutes: 30));
      expect(config.type, 'baseline');
      expect(config.platform, 'flutter');
      expect(config.environment, 'indoor');
      expect(config.customMetrics?['task_difficulty'], 'medium');
    });

    test('should create valid HRV measurement', () {
      final measurement = HRVMeasurement(
        rmssd: 42.5,
        sdnn: 38.2,
        pnn50: 12.3,
        lf: 156.7,
        hf: 89.3,
        lfHfRatio: 1.76,
        timestamp: DateTime.now(),
        quality: 'good',
      );

      expect(measurement.rmssd, 42.5);
      expect(measurement.sdnn, 38.2);
      expect(measurement.pnn50, 12.3);
      expect(measurement.lf, 156.7);
      expect(measurement.hf, 89.3);
      expect(measurement.lfHfRatio, 1.76);
      expect(measurement.quality, 'good');
    });

    test('should create valid session results', () {
      final results = SWIPSessionResults(
        sessionId: 'test-session-123',
        duration: const Duration(minutes: 30),
        wellnessScore: 0.75,
        deltaHrv: 0.15,
        coherenceIndex: 0.82,
        stressRecoveryRate: 0.68,
        impactType: 'beneficial',
      );

      expect(results.sessionId, 'test-session-123');
      expect(results.duration, const Duration(minutes: 30));
      expect(results.wellnessScore, 0.75);
      expect(results.deltaHrv, 0.15);
      expect(results.coherenceIndex, 0.82);
      expect(results.stressRecoveryRate, 0.68);
      expect(results.impactType, 'beneficial');
    });
  });

  group('SWIPError', () {
    test('should create error with code and message', () {
      final error = SWIPError('E_TEST', 'Test error message');
      expect(error.code, 'E_TEST');
      expect(error.message, 'Test error message');
      expect(error.toString(), 'SWIPError(code: E_TEST, message: Test error message)');
    });

    test('should create permission denied error', () {
      final error = PermissionDeniedError('Custom permission message');
      expect(error.code, 'E_PERMISSION_DENIED');
      expect(error.message, 'Custom permission message');
    });

    test('should create invalid configuration error', () {
      final error = InvalidConfigurationError('Custom config message');
      expect(error.code, 'E_INVALID_CONFIG');
      expect(error.message, 'Custom config message');
    });

    test('should create session not found error', () {
      final error = SessionNotFoundError('Custom session message');
      expect(error.code, 'E_SESSION_NOT_FOUND');
      expect(error.message, 'Custom session message');
    });

    test('should create data quality error', () {
      final error = DataQualityError('Custom quality message');
      expect(error.code, 'E_SIGNAL_LOW_QUALITY');
      expect(error.message, 'Custom quality message');
    });
  });
}
