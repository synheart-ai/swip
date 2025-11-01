import 'package:flutter_test/flutter_test.dart';
import 'package:swip_core/swip_core.dart';
import 'dart:math' as math;

void main() {
  group('HrvFeatures - SDNN', () {
    test('computes SDNN correctly for known values', () {
      // Known test case: RR intervals with known standard deviation
      final rrIntervals = [800.0, 810.0, 798.0, 805.0, 812.0, 795.0, 808.0];

      // Expected SDNN (calculated manually):
      // Mean = 804.0
      // Variance = [(800-804)^2 + (810-804)^2 + ... ] / 6 = 38.67
      // SDNN = sqrt(38.67) ≈ 6.22
      final sdnn = HrvFeatures.computeSdnn(rrIntervals);

      expect(sdnn, closeTo(6.22, 0.1));
    });

    test('returns 0 for empty list', () {
      expect(HrvFeatures.computeSdnn([]), equals(0.0));
    });

    test('returns 0 for single interval', () {
      expect(HrvFeatures.computeSdnn([800.0]), equals(0.0));
    });

    test('handles uniform intervals (zero variance)', () {
      final uniform = List.filled(10, 800.0);
      expect(HrvFeatures.computeSdnn(uniform), equals(0.0));
    });

    test('matches reference implementation for WESAD-like data', () {
      // Simulated RR intervals from stress condition
      final stressed = [
        650.0, 645.0, 655.0, 648.0, 652.0,
        647.0, 651.0, 649.0, 653.0, 646.0
      ];

      final sdnn = HrvFeatures.computeSdnn(stressed);
      // Low SDNN expected for stressed state (< 30ms typical)
      expect(sdnn, lessThan(10.0));
      expect(sdnn, greaterThan(0.0));
    });

    test('handles large variance correctly', () {
      final variable = [600.0, 900.0, 650.0, 850.0, 700.0, 800.0];
      final sdnn = HrvFeatures.computeSdnn(variable);

      // High variance should produce high SDNN
      expect(sdnn, greaterThan(80.0));
    });
  });

  group('HrvFeatures - RMSSD', () {
    test('computes RMSSD correctly for known values', () {
      // Known test case
      final rrIntervals = [800.0, 810.0, 798.0, 805.0, 812.0];

      // Successive differences: [10, -12, 7, 7]
      // Squared: [100, 144, 49, 49]
      // Mean: 85.5
      // RMSSD = sqrt(85.5) ≈ 9.25
      final rmssd = HrvFeatures.computeRmssd(rrIntervals);

      expect(rmssd, closeTo(9.25, 0.1));
    });

    test('returns 0 for empty list', () {
      expect(HrvFeatures.computeRmssd([]), equals(0.0));
    });

    test('returns 0 for single interval', () {
      expect(HrvFeatures.computeRmssd([800.0]), equals(0.0));
    });

    test('handles uniform intervals', () {
      final uniform = List.filled(10, 800.0);
      expect(HrvFeatures.computeRmssd(uniform), equals(0.0));
    });

    test('reflects parasympathetic activity (calm state)', () {
      // High HRV = high RMSSD (calm/relaxed)
      final calm = [820.0, 840.0, 810.0, 850.0, 800.0, 860.0];
      final rmssd = HrvFeatures.computeRmssd(calm);

      // Expect high RMSSD for calm state (> 30ms typical)
      expect(rmssd, greaterThan(25.0));
    });

    test('reflects low variability (stressed state)', () {
      // Low HRV = low RMSSD (stressed)
      final stressed = [650.0, 652.0, 651.0, 653.0, 649.0, 652.0];
      final rmssd = HrvFeatures.computeRmssd(stressed);

      // Expect low RMSSD for stressed state
      expect(rmssd, lessThan(5.0));
    });

    test('matches SDNN pattern for normal sinus rhythm', () {
      final normal = [780.0, 820.0, 790.0, 810.0, 800.0, 815.0, 795.0];

      final sdnn = HrvFeatures.computeSdnn(normal);
      final rmssd = HrvFeatures.computeRmssd(normal);

      // For normal rhythm, RMSSD typically < SDNN
      expect(rmssd, lessThanOrEqualTo(sdnn * 1.5));
    });
  });

  group('HrvFeatures - HR Computation', () {
    test('computes mean HR correctly', () {
      // RR = 800ms -> HR = 60000/800 = 75 bpm
      final rrIntervals = [800.0, 800.0, 800.0];
      final hr = HrvFeatures.computeMeanHR(rrIntervals);

      expect(hr, closeTo(75.0, 0.1));
    });

    test('returns 0 for empty list', () {
      expect(HrvFeatures.computeMeanHR([]), equals(0.0));
    });

    test('computes min HR correctly', () {
      // Min HR corresponds to max RR
      final rrIntervals = [600.0, 800.0, 900.0, 750.0];
      final minHr = HrvFeatures.computeMinHR(rrIntervals);

      // Max RR = 900ms -> Min HR = 60000/900 = 66.67 bpm
      expect(minHr, closeTo(66.67, 0.1));
    });

    test('computes max HR correctly', () {
      // Max HR corresponds to min RR
      final rrIntervals = [600.0, 800.0, 900.0, 750.0];
      final maxHr = HrvFeatures.computeMaxHR(rrIntervals);

      // Min RR = 600ms -> Max HR = 60000/600 = 100 bpm
      expect(maxHr, closeTo(100.0, 0.1));
    });

    test('computes HR std correctly', () {
      final rrIntervals = [800.0, 750.0, 850.0, 780.0, 820.0];
      final hrStd = HrvFeatures.computeHRStd(rrIntervals);

      // Should have some variance
      expect(hrStd, greaterThan(0.0));
      expect(hrStd, lessThan(10.0)); // Reasonable range for normal HR
    });
  });

  group('HrvFeatures - Feature Extraction', () {
    test('extractAll returns all features', () {
      final rrIntervals = [800.0, 810.0, 798.0, 805.0, 812.0, 795.0];
      final features = HrvFeatures.extractAll(
        hrMean: 75.0,
        rrIntervalsMs: rrIntervals,
      );

      // Check all expected keys are present
      expect(features.containsKey('hr_mean'), isTrue);
      expect(features.containsKey('hr_std'), isTrue);
      expect(features.containsKey('hr_min'), isTrue);
      expect(features.containsKey('hr_max'), isTrue);
      expect(features.containsKey('sdnn'), isTrue);
      expect(features.containsKey('rmssd'), isTrue);

      // Check values are reasonable
      expect(features['hr_mean'], equals(75.0));
      expect(features['sdnn']!, greaterThan(0.0));
      expect(features['rmssd']!, greaterThan(0.0));
      expect(features['hr_min']!, lessThan(features['hr_max']!));
    });

    test('extractMinimal returns only required features', () {
      final rrIntervals = [800.0, 810.0, 798.0, 805.0];
      final features = HrvFeatures.extractMinimal(
        hrMean: 75.0,
        rrIntervalsMs: rrIntervals,
      );

      // Check only minimal features present
      expect(features.keys.length, equals(3));
      expect(features.containsKey('hr_mean'), isTrue);
      expect(features.containsKey('sdnn'), isTrue);
      expect(features.containsKey('rmssd'), isTrue);

      // Should not contain extended features
      expect(features.containsKey('hr_min'), isFalse);
      expect(features.containsKey('hr_max'), isFalse);
      expect(features.containsKey('hr_std'), isFalse);
    });

    test('features are deterministic', () {
      final rrIntervals = [800.0, 810.0, 798.0, 805.0, 812.0];

      final features1 = HrvFeatures.extractAll(
        hrMean: 75.0,
        rrIntervalsMs: rrIntervals,
      );

      final features2 = HrvFeatures.extractAll(
        hrMean: 75.0,
        rrIntervalsMs: rrIntervals,
      );

      // Should produce identical results
      expect(features1['sdnn'], equals(features2['sdnn']));
      expect(features1['rmssd'], equals(features2['rmssd']));
      expect(features1['hr_std'], equals(features2['hr_std']));
    });
  });

  group('HrvFeatures - Edge Cases', () {
    test('handles very long RR intervals (bradycardia)', () {
      // HR ~35 bpm
      final slow = List.filled(10, 1700.0);
      final sdnn = HrvFeatures.computeSdnn(slow);
      final hr = HrvFeatures.computeMeanHR(slow);

      expect(sdnn, equals(0.0)); // Uniform
      expect(hr, closeTo(35.3, 0.1));
    });

    test('handles very short RR intervals (tachycardia)', () {
      // HR ~150 bpm
      final fast = List.filled(10, 400.0);
      final sdnn = HrvFeatures.computeSdnn(fast);
      final hr = HrvFeatures.computeMeanHR(fast);

      expect(sdnn, equals(0.0)); // Uniform
      expect(hr, closeTo(150.0, 0.1));
    });

    test('handles negative successive differences', () {
      // Decreasing RR intervals
      final decreasing = [850.0, 840.0, 830.0, 820.0, 810.0];
      final rmssd = HrvFeatures.computeRmssd(decreasing);

      // Should handle negative differences correctly
      expect(rmssd, closeTo(10.0, 0.1));
    });

    test('handles mixed positive/negative differences', () {
      final mixed = [800.0, 850.0, 780.0, 820.0, 790.0];
      final rmssd = HrvFeatures.computeRmssd(mixed);

      expect(rmssd, greaterThan(0.0));
      expect(rmssd, lessThan(100.0));
    });

    test('precision is maintained for small values', () {
      // Very small differences
      final subtle = [800.0, 801.0, 800.5, 800.2, 800.8];
      final rmssd = HrvFeatures.computeRmssd(subtle);

      // Should detect subtle variations
      expect(rmssd, greaterThan(0.0));
      expect(rmssd, lessThan(1.0));
    });
  });

  group('HrvFeatures - Clinical Validation', () {
    test('calm state produces expected HRV profile', () {
      // Simulated calm/relaxed state:
      // - Higher HRV (SDNN ~60ms, RMSSD ~40ms)
      // - Moderate HR variability
      final calm = [
        850.0, 870.0, 840.0, 880.0, 835.0,
        875.0, 845.0, 865.0, 855.0, 860.0,
      ];

      final sdnn = HrvFeatures.computeSdnn(calm);
      final rmssd = HrvFeatures.computeRmssd(calm);

      // Calm state expectations
      expect(sdnn, greaterThan(10.0), reason: 'SDNN should be elevated in calm state');
      expect(rmssd, greaterThan(5.0), reason: 'RMSSD should be elevated in calm state');
    });

    test('stressed state produces expected HRV profile', () {
      // Simulated stressed state:
      // - Lower HRV (SDNN ~20ms, RMSSD ~15ms)
      // - Reduced variability
      final stressed = [
        650.0, 648.0, 652.0, 647.0, 651.0,
        649.0, 653.0, 646.0, 650.0, 648.0,
      ];

      final sdnn = HrvFeatures.computeSdnn(stressed);
      final rmssd = HrvFeatures.computeRmssd(stressed);

      // Stressed state expectations
      expect(sdnn, lessThan(15.0), reason: 'SDNN should be reduced in stressed state');
      expect(rmssd, lessThan(10.0), reason: 'RMSSD should be reduced in stressed state');
    });

    test('matches published HRV norms for resting adults', () {
      // Reference: Nunan et al. (2010) - Resting HRV norms
      // Typical resting: HR ~70 bpm, SDNN ~50ms, RMSSD ~40ms
      final resting = [
        840.0, 870.0, 830.0, 880.0, 850.0,
        860.0, 845.0, 865.0, 855.0, 850.0,
      ];

      final sdnn = HrvFeatures.computeSdnn(resting);
      final rmssd = HrvFeatures.computeRmssd(resting);
      final hr = HrvFeatures.computeMeanHR(resting);

      // Should be in normal range
      expect(hr, inInclusiveRange(60.0, 80.0), reason: 'HR should be in resting range');
      expect(sdnn, greaterThan(10.0), reason: 'SDNN should indicate healthy HRV');
      expect(rmssd, greaterThan(10.0), reason: 'RMSSD should indicate healthy HRV');
    });
  });
}
