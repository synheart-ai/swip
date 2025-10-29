import 'package:flutter_test/flutter_test.dart';
import 'package:swip_core/swip_core.dart';

void main() {
  group('AdaptiveBaseline - Initialization', () {
    test('starts with population baseline', () {
      final baseline = AdaptiveBaseline();

      expect(baseline.baseline.hrMean, equals(72.0));
      expect(baseline.baseline.hrStd, equals(12.0));
      expect(baseline.baseline.hrvMean, equals(45.0));
      expect(baseline.baseline.hrvStd, equals(18.0));
    });

    test('accepts custom initial baseline', () {
      final custom = PhysiologicalBaseline(
        hrMean: 80.0,
        hrStd: 10.0,
        hrvMean: 50.0,
        hrvStd: 20.0,
        timestamp: DateTime.now().toUtc(),
      );

      final baseline = AdaptiveBaseline(initialBaseline: custom);

      expect(baseline.baseline.hrMean, equals(80.0));
      expect(baseline.baseline.hrvMean, equals(50.0));
    });

    test('starts as not calibrated', () {
      final baseline = AdaptiveBaseline();
      expect(baseline.isCalibrated, isFalse);
    });

    test('uses configurable parameters', () {
      final baseline = AdaptiveBaseline(
        updateInterval: Duration(hours: 12),
        calibrationPeriod: Duration(minutes: 10),
        maxSamples: 720,
      );

      expect(baseline, isNotNull);
    });
  });

  group('AdaptiveBaseline - Sample Addition', () {
    test('accepts valid samples', () {
      final baseline = AdaptiveBaseline();

      baseline.addSample(
        hr: 75.0,
        hrv: 50.0,
        timestamp: DateTime.now().toUtc(),
        qualityScore: 0.9,
      );

      // Should not throw
    });

    test('rejects samples with low quality', () {
      final baseline = AdaptiveBaseline();

      baseline.addSample(
        hr: 75.0,
        hrv: 50.0,
        timestamp: DateTime.now().toUtc(),
        qualityScore: 0.5, // < 0.7 threshold
      );

      // Sample should be rejected (baseline unchanged)
      expect(baseline.baseline.hrMean, equals(72.0)); // Still population
    });

    test('rejects physiologically implausible HR', () {
      final baseline = AdaptiveBaseline();

      // Too low
      baseline.addSample(
        hr: 25.0,
        hrv: 50.0,
        timestamp: DateTime.now().toUtc(),
      );

      // Too high
      baseline.addSample(
        hr: 250.0,
        hrv: 50.0,
        timestamp: DateTime.now().toUtc(),
      );

      // Baseline should remain at population
      expect(baseline.baseline.hrMean, equals(72.0));
    });

    test('rejects physiologically implausible HRV', () {
      final baseline = AdaptiveBaseline();

      // Too low
      baseline.addSample(
        hr: 75.0,
        hrv: 3.0,
        timestamp: DateTime.now().toUtc(),
      );

      // Too high
      baseline.addSample(
        hr: 75.0,
        hrv: 350.0,
        timestamp: DateTime.now().toUtc(),
      );

      // Baseline should remain at population
      expect(baseline.baseline.hrMean, equals(72.0));
    });

    test('maintains rolling window of samples', () {
      final baseline = AdaptiveBaseline(maxSamples: 10);

      // Add 20 samples
      for (int i = 0; i < 20; i++) {
        baseline.addSample(
          hr: 75.0 + i,
          hrv: 50.0,
          timestamp: DateTime.now().toUtc(),
        );
      }

      // Should only keep last 10
      final json = baseline.toJson();
      expect(json['sample_count'], lessThanOrEqualTo(10));
    });
  });

  group('AdaptiveBaseline - Calibration', () {
    test('becomes calibrated after minimum samples and time', () async {
      final baseline = AdaptiveBaseline(
        calibrationPeriod: Duration(milliseconds: 100),
      );

      // Add 30 samples
      for (int i = 0; i < 30; i++) {
        baseline.addSample(
          hr: 75.0 + i % 5,
          hrv: 50.0 + i % 3,
          timestamp: DateTime.now().toUtc(),
        );
      }

      // Wait for calibration period
      await Future.delayed(Duration(milliseconds: 150));

      // Add one more sample to trigger check
      baseline.addSample(
        hr: 75.0,
        hrv: 50.0,
        timestamp: DateTime.now().toUtc(),
      );

      expect(baseline.isCalibrated, isTrue);
    });

    test('does not calibrate with insufficient samples', () async {
      final baseline = AdaptiveBaseline(
        calibrationPeriod: Duration(milliseconds: 100),
      );

      // Add only 10 samples (< 30 required)
      for (int i = 0; i < 10; i++) {
        baseline.addSample(
          hr: 75.0,
          hrv: 50.0,
          timestamp: DateTime.now().toUtc(),
        );
      }

      await Future.delayed(Duration(milliseconds: 150));

      baseline.addSample(
        hr: 75.0,
        hrv: 50.0,
        timestamp: DateTime.now().toUtc(),
      );

      expect(baseline.isCalibrated, isFalse);
    });

    test('force calibration works', () async {
      final baseline = AdaptiveBaseline();

      // Add samples
      for (int i = 0; i < 50; i++) {
        baseline.addSample(
          hr: 80.0 + i % 5,
          hrv: 60.0,
          timestamp: DateTime.now().toUtc(),
        );
      }

      await baseline.calibrate();

      expect(baseline.isCalibrated, isTrue);
      // Baseline should have adapted
      expect(baseline.baseline.hrMean, isNot(equals(72.0)));
    });
  });

  group('AdaptiveBaseline - Baseline Updates', () {
    test('baseline adapts to user data', () async {
      final baseline = AdaptiveBaseline(
        updateInterval: Duration(milliseconds: 100),
      );

      // Add samples with HR ~85 (higher than population 72)
      for (int i = 0; i < 50; i++) {
        baseline.addSample(
          hr: 85.0 + i % 3,
          hrv: 60.0,
          timestamp: DateTime.now().toUtc(),
        );
      }

      // Wait for update interval
      await Future.delayed(Duration(milliseconds: 150));

      // Trigger update with new sample
      baseline.addSample(
        hr: 85.0,
        hrv: 60.0,
        timestamp: DateTime.now().toUtc(),
      );

      // Baseline should have adapted toward user's actual HR
      expect(baseline.baseline.hrMean, greaterThan(75.0));
      expect(baseline.baseline.hrMean, closeTo(85.0, 5.0));
    });

    test('removes outliers before updating baseline', () async {
      final baseline = AdaptiveBaseline(
        updateInterval: Duration(milliseconds: 100),
      );

      // Add mostly normal samples with a few outliers
      for (int i = 0; i < 40; i++) {
        baseline.addSample(
          hr: 75.0 + i % 3,
          hrv: 50.0,
          timestamp: DateTime.now().toUtc(),
        );
      }

      // Add outliers
      baseline.addSample(hr: 150.0, hrv: 50.0, timestamp: DateTime.now().toUtc());
      baseline.addSample(hr: 40.0, hrv: 50.0, timestamp: DateTime.now().toUtc());

      await Future.delayed(Duration(milliseconds: 150));
      baseline.addSample(hr: 75.0, hrv: 50.0, timestamp: DateTime.now().toUtc());

      // Baseline should be close to 75, not affected by outliers
      expect(baseline.baseline.hrMean, closeTo(75.0, 5.0));
    });

    test('computes standard deviation correctly', () async {
      final baseline = AdaptiveBaseline(
        updateInterval: Duration(milliseconds: 100),
      );

      // Add samples with known variance
      final hrs = [70.0, 75.0, 80.0, 85.0, 90.0];
      for (int i = 0; i < 10; i++) {
        for (final hr in hrs) {
          baseline.addSample(
            hr: hr,
            hrv: 50.0,
            timestamp: DateTime.now().toUtc(),
          );
        }
      }

      await Future.delayed(Duration(milliseconds: 150));
      baseline.addSample(hr: 80.0, hrv: 50.0, timestamp: DateTime.now().toUtc());

      // Should have meaningful std dev
      expect(baseline.baseline.hrStd, greaterThan(5.0));
      expect(baseline.baseline.hrStd, lessThan(15.0));
    });

    test('does not update with insufficient samples', () async {
      final baseline = AdaptiveBaseline(
        updateInterval: Duration(milliseconds: 100),
      );

      // Add only 5 samples
      for (int i = 0; i < 5; i++) {
        baseline.addSample(
          hr: 85.0,
          hrv: 50.0,
          timestamp: DateTime.now().toUtc(),
        );
      }

      await Future.delayed(Duration(milliseconds: 150));
      baseline.addSample(hr: 85.0, hrv: 50.0, timestamp: DateTime.now().toUtc());

      // Baseline should remain at population (not enough data)
      expect(baseline.baseline.hrMean, equals(72.0));
    });
  });

  group('AdaptiveBaseline - Reset', () {
    test('reset clears samples and returns to population baseline', () async {
      final baseline = AdaptiveBaseline();

      // Add samples and calibrate
      for (int i = 0; i < 50; i++) {
        baseline.addSample(
          hr: 85.0,
          hrv: 60.0,
          timestamp: DateTime.now().toUtc(),
        );
      }

      await baseline.calibrate();
      expect(baseline.isCalibrated, isTrue);

      // Reset
      baseline.reset();

      expect(baseline.isCalibrated, isFalse);
      expect(baseline.baseline.hrMean, equals(72.0)); // Population
      expect(baseline.baseline.hrvMean, equals(45.0)); // Population
    });
  });

  group('AdaptiveBaseline - Serialization', () {
    test('exports to JSON', () async {
      final baseline = AdaptiveBaseline();

      for (int i = 0; i < 30; i++) {
        baseline.addSample(
          hr: 75.0,
          hrv: 50.0,
          timestamp: DateTime.now().toUtc(),
        );
      }

      await baseline.calibrate();

      final json = baseline.toJson();

      expect(json.containsKey('baseline'), isTrue);
      expect(json.containsKey('is_calibrated'), isTrue);
      expect(json.containsKey('sample_count'), isTrue);
      expect(json['is_calibrated'], isTrue);
    });

    test('imports from JSON', () {
      final json = {
        'baseline': {
          'hr_mean': 80.0,
          'hr_std': 10.0,
          'hrv_mean': 55.0,
          'hrv_std': 15.0,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        },
        'is_calibrated': true,
      };

      final baseline = AdaptiveBaseline.fromJson(json);

      expect(baseline.baseline.hrMean, equals(80.0));
      expect(baseline.baseline.hrvMean, equals(55.0));
      expect(baseline.isCalibrated, isTrue);
    });

    test('round-trip serialization preserves data', () async {
      final original = AdaptiveBaseline();

      for (int i = 0; i < 30; i++) {
        original.addSample(
          hr: 75.0,
          hrv: 50.0,
          timestamp: DateTime.now().toUtc(),
        );
      }

      await original.calibrate();

      final json = original.toJson();
      final restored = AdaptiveBaseline.fromJson(json);

      expect(restored.baseline.hrMean, equals(original.baseline.hrMean));
      expect(restored.baseline.hrvMean, equals(original.baseline.hrvMean));
      expect(restored.isCalibrated, equals(original.isCalibrated));
    });
  });

  group('AdaptiveBaseline - Realistic Scenarios', () {
    test('adapts for athlete with low resting HR', () async {
      final baseline = AdaptiveBaseline(
        updateInterval: Duration(milliseconds: 100),
      );

      // Athlete: HR ~55 bpm, HRV ~80ms
      for (int i = 0; i < 60; i++) {
        baseline.addSample(
          hr: 55.0 + i % 3,
          hrv: 80.0 + i % 5,
          timestamp: DateTime.now().toUtc(),
        );
      }

      await Future.delayed(Duration(milliseconds: 150));
      baseline.addSample(hr: 55.0, hrv: 80.0, timestamp: DateTime.now().toUtc());
      await baseline.calibrate();

      expect(baseline.baseline.hrMean, lessThan(60.0));
      expect(baseline.baseline.hrvMean, greaterThan(70.0));
    });

    test('adapts for sedentary user with high resting HR', () async {
      final baseline = AdaptiveBaseline(
        updateInterval: Duration(milliseconds: 100),
      );

      // Sedentary: HR ~90 bpm, HRV ~30ms
      for (int i = 0; i < 60; i++) {
        baseline.addSample(
          hr: 90.0 + i % 3,
          hrv: 30.0 + i % 2,
          timestamp: DateTime.now().toUtc(),
        );
      }

      await Future.delayed(Duration(milliseconds: 150));
      baseline.addSample(hr: 90.0, hrv: 30.0, timestamp: DateTime.now().toUtc());
      await baseline.calibrate();

      expect(baseline.baseline.hrMean, greaterThan(85.0));
      expect(baseline.baseline.hrvMean, lessThan(35.0));
    });

    test('handles circadian variation', () async {
      final baseline = AdaptiveBaseline(
        updateInterval: Duration(milliseconds: 100),
      );

      // Simulate day/night variation
      // Morning: higher HR
      for (int i = 0; i < 20; i++) {
        baseline.addSample(
          hr: 80.0,
          hrv: 45.0,
          timestamp: DateTime.now().toUtc(),
        );
      }

      // Night: lower HR
      for (int i = 0; i < 20; i++) {
        baseline.addSample(
          hr: 60.0,
          hrv: 65.0,
          timestamp: DateTime.now().toUtc(),
        );
      }

      await Future.delayed(Duration(milliseconds: 150));
      baseline.addSample(hr: 70.0, hrv: 55.0, timestamp: DateTime.now().toUtc());
      await baseline.calibrate();

      // Should average to middle
      expect(baseline.baseline.hrMean, inInclusiveRange(65.0, 75.0));
      expect(baseline.baseline.hrvMean, inInclusiveRange(50.0, 60.0));
    });

    test('handles gradual fitness improvement', () async {
      final baseline = AdaptiveBaseline(
        updateInterval: Duration(milliseconds: 50),
      );

      // Week 1: HR ~75, HRV ~45
      for (int i = 0; i < 20; i++) {
        baseline.addSample(
          hr: 75.0,
          hrv: 45.0,
          timestamp: DateTime.now().toUtc(),
        );
      }

      await Future.delayed(Duration(milliseconds: 60));
      baseline.addSample(hr: 75.0, hrv: 45.0, timestamp: DateTime.now().toUtc());

      final initialHR = baseline.baseline.hrMean;

      // Week 2: HR ~70, HRV ~55 (fitness improved)
      for (int i = 0; i < 20; i++) {
        baseline.addSample(
          hr: 70.0,
          hrv: 55.0,
          timestamp: DateTime.now().toUtc(),
        );
      }

      await Future.delayed(Duration(milliseconds: 60));
      baseline.addSample(hr: 70.0, hrv: 55.0, timestamp: DateTime.now().toUtc());

      // Baseline should adapt toward improved fitness
      expect(baseline.baseline.hrMean, lessThan(initialHR));
      expect(baseline.baseline.hrvMean, greaterThan(50.0));
    });
  });

  group('AdaptiveBaseline - Edge Cases', () {
    test('handles very long collection period', () async {
      final baseline = AdaptiveBaseline(maxSamples: 1440); // 24h of 1/min samples

      for (int i = 0; i < 1500; i++) {
        baseline.addSample(
          hr: 75.0 + (i % 10) * 0.5,
          hrv: 50.0,
          timestamp: DateTime.now().toUtc(),
        );
      }

      // Should handle without error and maintain window
      final json = baseline.toJson();
      expect(json['sample_count'], lessThanOrEqualTo(1440));
    });

    test('handles sparse sampling', () async {
      final baseline = AdaptiveBaseline(
        updateInterval: Duration(milliseconds: 100),
      );

      // Only 15 samples over long period
      for (int i = 0; i < 15; i++) {
        baseline.addSample(
          hr: 75.0,
          hrv: 50.0,
          timestamp: DateTime.now().toUtc(),
        );
      }

      await Future.delayed(Duration(milliseconds: 150));
      baseline.addSample(hr: 75.0, hrv: 50.0, timestamp: DateTime.now().toUtc());

      // Should handle but may not update (insufficient data)
      expect(baseline.baseline.hrMean, equals(72.0)); // Still population
    });

    test('handles all samples rejected', () {
      final baseline = AdaptiveBaseline();

      // All low quality
      for (int i = 0; i < 50; i++) {
        baseline.addSample(
          hr: 75.0,
          hrv: 50.0,
          timestamp: DateTime.now().toUtc(),
          qualityScore: 0.5, // Too low
        );
      }

      // Should remain at population baseline
      expect(baseline.baseline.hrMean, equals(72.0));
      expect(baseline.isCalibrated, isFalse);
    });

    test('time until update is computed correctly', () async {
      final baseline = AdaptiveBaseline(
        updateInterval: Duration(milliseconds: 200),
      );

      baseline.addSample(
        hr: 75.0,
        hrv: 50.0,
        timestamp: DateTime.now().toUtc(),
      );

      final timeUntil1 = baseline.timeUntilUpdate;
      expect(timeUntil1.inMilliseconds, lessThanOrEqualTo(200));

      await Future.delayed(Duration(milliseconds: 100));

      final timeUntil2 = baseline.timeUntilUpdate;
      expect(timeUntil2.inMilliseconds, lessThan(timeUntil1.inMilliseconds));
    });
  });
}
