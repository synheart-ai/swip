import 'package:flutter_test/flutter_test.dart';
import 'package:swip_core/swip_core.dart';

void main() {
  group('ArtifactFilter - RR Interval Filtering', () {
    test('keeps all valid RR intervals', () {
      final valid = [600.0, 750.0, 800.0, 850.0, 900.0];
      final filtered = ArtifactFilter.filterRRIntervals(valid);

      expect(filtered.length, equals(5));
      expect(filtered, equals(valid));
    });

    test('removes intervals below minimum (300ms)', () {
      final withLow = [250.0, 600.0, 800.0, 200.0, 750.0];
      final filtered = ArtifactFilter.filterRRIntervals(withLow);

      // Should remove 250ms and 200ms
      expect(filtered.length, equals(3));
      expect(filtered, equals([600.0, 800.0, 750.0]));
    });

    test('removes intervals above maximum (2000ms)', () {
      final withHigh = [800.0, 2500.0, 750.0, 3000.0, 850.0];
      final filtered = ArtifactFilter.filterRRIntervals(withHigh);

      // Should remove 2500ms and 3000ms
      expect(filtered.length, equals(3));
      expect(filtered, equals([800.0, 750.0, 850.0]));
    });

    test('removes intervals with large successive differences', () {
      // Sudden jump > 250ms indicates artifact
      final withJump = [800.0, 850.0, 1200.0, 820.0];
      final filtered = ArtifactFilter.filterRRIntervals(withJump);

      // 1200ms should be removed (diff from 850ms = 350ms > 250ms)
      expect(filtered.length, equals(3));
      expect(filtered.contains(1200.0), isFalse);
    });

    test('handles alternating valid/invalid intervals', () {
      final alternating = [800.0, 200.0, 750.0, 2500.0, 820.0, 150.0, 810.0];
      final filtered = ArtifactFilter.filterRRIntervals(alternating);

      // Should keep only: 800, 750, 820, 810
      expect(filtered.length, equals(4));
      expect(filtered, equals([800.0, 750.0, 820.0, 810.0]));
    });

    test('returns empty list when all intervals invalid', () {
      final allInvalid = [100.0, 200.0, 2500.0, 3000.0];
      final filtered = ArtifactFilter.filterRRIntervals(allInvalid);

      expect(filtered.isEmpty, isTrue);
    });

    test('handles empty input', () {
      final filtered = ArtifactFilter.filterRRIntervals([]);
      expect(filtered.isEmpty, isTrue);
    });

    test('handles single valid interval', () {
      final single = [800.0];
      final filtered = ArtifactFilter.filterRRIntervals(single);

      expect(filtered.length, equals(1));
      expect(filtered[0], equals(800.0));
    });

    test('handles single invalid interval', () {
      final single = [100.0];
      final filtered = ArtifactFilter.filterRRIntervals(single);

      expect(filtered.isEmpty, isTrue);
    });
  });

  group('ArtifactFilter - Motion Artifacts', () {
    test('returns empty list when motion exceeds threshold', () {
      final valid = [800.0, 810.0, 820.0];
      final filtered = ArtifactFilter.filterRRIntervals(
        valid,
        motionMagnitude: 0.6, // > 0.5 threshold
      );

      expect(filtered.isEmpty, isTrue);
    });

    test('keeps intervals when motion below threshold', () {
      final valid = [800.0, 810.0, 820.0];
      final filtered = ArtifactFilter.filterRRIntervals(
        valid,
        motionMagnitude: 0.3, // < 0.5 threshold
      );

      expect(filtered.length, equals(3));
    });

    test('detects motion artifact correctly', () {
      expect(ArtifactFilter.hasMotionArtifact(0.6), isTrue);
      expect(ArtifactFilter.hasMotionArtifact(0.5), isFalse);
      expect(ArtifactFilter.hasMotionArtifact(0.4), isFalse);
      expect(ArtifactFilter.hasMotionArtifact(0.0), isFalse);
    });
  });

  group('ArtifactFilter - HR Validation', () {
    test('validates normal HR range', () {
      expect(ArtifactFilter.isValidHR(60.0), isTrue);
      expect(ArtifactFilter.isValidHR(100.0), isTrue);
      expect(ArtifactFilter.isValidHR(180.0), isTrue);
    });

    test('rejects HR below minimum (30 bpm)', () {
      expect(ArtifactFilter.isValidHR(25.0), isFalse);
      expect(ArtifactFilter.isValidHR(20.0), isFalse);
      expect(ArtifactFilter.isValidHR(0.0), isFalse);
    });

    test('rejects HR above maximum (220 bpm)', () {
      expect(ArtifactFilter.isValidHR(230.0), isFalse);
      expect(ArtifactFilter.isValidHR(250.0), isFalse);
    });

    test('accepts edge cases at boundaries', () {
      expect(ArtifactFilter.isValidHR(30.0), isTrue);
      expect(ArtifactFilter.isValidHR(220.0), isTrue);
    });
  });

  group('ArtifactFilter - HRV Validation', () {
    test('validates normal HRV range', () {
      expect(ArtifactFilter.isValidHRV(20.0), isTrue);
      expect(ArtifactFilter.isValidHRV(50.0), isTrue);
      expect(ArtifactFilter.isValidHRV(100.0), isTrue);
    });

    test('rejects HRV below minimum (5ms)', () {
      expect(ArtifactFilter.isValidHRV(3.0), isFalse);
      expect(ArtifactFilter.isValidHRV(0.0), isFalse);
    });

    test('rejects HRV above maximum (300ms)', () {
      expect(ArtifactFilter.isValidHRV(350.0), isFalse);
      expect(ArtifactFilter.isValidHRV(500.0), isFalse);
    });

    test('accepts edge cases at boundaries', () {
      expect(ArtifactFilter.isValidHRV(5.0), isTrue);
      expect(ArtifactFilter.isValidHRV(300.0), isTrue);
    });
  });

  group('ArtifactFilter - Quality Score', () {
    test('returns 1.0 for perfect data', () {
      final original = [800.0, 810.0, 820.0, 830.0];
      final filtered = original; // All kept

      final quality = ArtifactFilter.computeQualityScore(
        originalRR: original,
        filteredRR: filtered,
        hrBpm: 75.0,
        motionMagnitude: 0.1,
      );

      expect(quality, equals(1.0));
    });

    test('penalizes for dropped intervals', () {
      final original = [800.0, 100.0, 820.0, 2500.0, 830.0];
      final filtered = [800.0, 820.0, 830.0]; // 60% retention

      final quality = ArtifactFilter.computeQualityScore(
        originalRR: original,
        filteredRR: filtered,
        hrBpm: 75.0,
        motionMagnitude: 0.1,
      );

      // Should be ~0.6 (retention rate)
      expect(quality, closeTo(0.6, 0.1));
    });

    test('penalizes for high motion', () {
      final original = [800.0, 810.0, 820.0];
      final filtered = original;

      final quality = ArtifactFilter.computeQualityScore(
        originalRR: original,
        filteredRR: filtered,
        hrBpm: 75.0,
        motionMagnitude: 0.8, // High motion
      );

      // Should be significantly reduced
      expect(quality, lessThan(0.5));
    });

    test('penalizes for invalid HR', () {
      final original = [800.0, 810.0, 820.0];
      final filtered = original;

      final quality = ArtifactFilter.computeQualityScore(
        originalRR: original,
        filteredRR: filtered,
        hrBpm: 250.0, // Invalid HR
        motionMagnitude: 0.1,
      );

      // Should be penalized to ~0.3
      expect(quality, closeTo(0.3, 0.1));
    });

    test('combines multiple quality factors', () {
      final original = [800.0, 100.0, 820.0, 2500.0]; // 50% retention
      final filtered = [800.0, 820.0];

      final quality = ArtifactFilter.computeQualityScore(
        originalRR: original,
        filteredRR: filtered,
        hrBpm: 240.0, // Invalid HR
        motionMagnitude: 0.6, // High motion
      );

      // Multiple penalties should compound
      expect(quality, lessThan(0.2));
    });

    test('handles empty filtered list', () {
      final original = [100.0, 200.0, 2500.0];
      final filtered = <double>[];

      final quality = ArtifactFilter.computeQualityScore(
        originalRR: original,
        filteredRR: filtered,
        hrBpm: 75.0,
        motionMagnitude: 0.1,
      );

      expect(quality, equals(0.0));
    });

    test('clamps quality score between 0 and 1', () {
      final original = [800.0, 810.0];
      final filtered = original;

      final quality = ArtifactFilter.computeQualityScore(
        originalRR: original,
        filteredRR: filtered,
        hrBpm: 75.0,
        motionMagnitude: 0.0, // Perfect motion
      );

      expect(quality, inInclusiveRange(0.0, 1.0));
    });
  });

  group('ArtifactFilter - Sufficient Quality Check', () {
    test('accepts high quality data with enough intervals', () {
      final filtered = List.filled(50, 800.0); // 50 intervals

      final sufficient = ArtifactFilter.hasSufficientQuality(
        filteredRR: filtered,
        qualityScore: 0.9,
      );

      expect(sufficient, isTrue);
    });

    test('rejects when too few intervals', () {
      final filtered = List.filled(20, 800.0); // < 30 required

      final sufficient = ArtifactFilter.hasSufficientQuality(
        filteredRR: filtered,
        qualityScore: 0.9,
      );

      expect(sufficient, isFalse);
    });

    test('rejects when quality score too low', () {
      final filtered = List.filled(50, 800.0);

      final sufficient = ArtifactFilter.hasSufficientQuality(
        filteredRR: filtered,
        qualityScore: 0.5, // < 0.7 threshold
      );

      expect(sufficient, isFalse);
    });

    test('uses custom thresholds', () {
      final filtered = List.filled(15, 800.0);

      final sufficient = ArtifactFilter.hasSufficientQuality(
        filteredRR: filtered,
        qualityScore: 0.6,
        minRRCount: 10, // Custom: only need 10
        minQualityScore: 0.5, // Custom: accept 0.5
      );

      expect(sufficient, isTrue);
    });

    test('rejects empty filtered list', () {
      final sufficient = ArtifactFilter.hasSufficientQuality(
        filteredRR: [],
        qualityScore: 1.0,
      );

      expect(sufficient, isFalse);
    });
  });

  group('ArtifactFilter - Realistic Scenarios', () {
    test('filters walking motion artifacts', () {
      // Simulated walking: periodic motion artifacts
      final walking = [
        800.0, 810.0, 1500.0, // Motion spike
        805.0, 815.0, 1600.0, // Motion spike
        800.0, 808.0,
      ];

      final filtered = ArtifactFilter.filterRRIntervals(walking);

      // Should remove motion spikes
      expect(filtered.contains(1500.0), isFalse);
      expect(filtered.contains(1600.0), isFalse);
    });

    test('handles gradual HR increase (exercise)', () {
      // Simulated exercise onset: gradually decreasing RR
      final exercise = [
        900.0, 880.0, 860.0, 840.0, 820.0,
        800.0, 780.0, 760.0, 740.0, 720.0,
      ];

      final filtered = ArtifactFilter.filterRRIntervals(exercise);

      // Should keep all (gradual changes < 250ms delta)
      expect(filtered.length, equals(10));
    });

    test('detects sensor disconnection', () {
      // Simulated sensor loss: sudden invalid values
      final disconnected = [
        800.0, 810.0, 805.0,
        50.0, 0.0, 0.0, // Sensor lost
        800.0, 810.0,
      ];

      final filtered = ArtifactFilter.filterRRIntervals(disconnected);

      // Should remove invalid values
      expect(filtered.length, equals(5));
      expect(filtered.contains(50.0), isFalse);
      expect(filtered.contains(0.0), isFalse);
    });

    test('handles arrhythmia (premature beat)', () {
      // Simulated premature ventricular contraction
      final arrhythmia = [
        800.0, 810.0, 400.0, // PVC (short)
        1200.0, // Compensatory pause (long)
        805.0, 815.0,
      ];

      final filtered = ArtifactFilter.filterRRIntervals(arrhythmia);

      // May remove PVC and compensatory pause as artifacts
      expect(filtered.length, lessThan(6));
    });

    test('preserves normal sinus arrhythmia', () {
      // Natural respiratory variation in RR intervals
      final sinus = [
        820.0, 840.0, 860.0, 850.0, 830.0,
        810.0, 820.0, 840.0, 850.0, 840.0,
      ];

      final filtered = ArtifactFilter.filterRRIntervals(sinus);

      // Should keep all (natural variation)
      expect(filtered.length, equals(10));
      expect(filtered, equals(sinus));
    });

    test('computes realistic quality score for clean signal', () {
      final clean = List.generate(60, (i) => 800.0 + (i % 5) * 5.0);

      final filtered = ArtifactFilter.filterRRIntervals(clean);

      final quality = ArtifactFilter.computeQualityScore(
        originalRR: clean,
        filteredRR: filtered,
        hrBpm: 75.0,
        motionMagnitude: 0.15,
      );

      // Clean signal should have high quality
      expect(quality, greaterThan(0.85));
    });

    test('computes realistic quality score for noisy signal', () {
      final noisy = [
        800.0, 100.0, 810.0, 2500.0, 805.0, 200.0, 815.0, 3000.0,
        800.0, 150.0, 808.0, 2200.0, 812.0,
      ];

      final filtered = ArtifactFilter.filterRRIntervals(noisy);

      final quality = ArtifactFilter.computeQualityScore(
        originalRR: noisy,
        filteredRR: filtered,
        hrBpm: 75.0,
        motionMagnitude: 0.7, // High motion
      );

      // Noisy signal should have low quality
      expect(quality, lessThan(0.4));
    });
  });

  group('ArtifactFilter - Edge Cases', () {
    test('handles all intervals at boundary values', () {
      final boundaries = [300.0, 2000.0, 300.0, 2000.0];
      final filtered = ArtifactFilter.filterRRIntervals(boundaries);

      // Boundary values should be kept, but may fail delta check
      expect(filtered.isNotEmpty, isTrue);
    });

    test('handles very long sequence', () {
      final long = List.generate(1000, (i) => 800.0 + (i % 10) * 2.0);
      final filtered = ArtifactFilter.filterRRIntervals(long);

      // Should process without error
      expect(filtered.length, equals(1000));
    });

    test('handles extreme motion values', () {
      final valid = [800.0, 810.0];

      final filtered1 = ArtifactFilter.filterRRIntervals(
        valid,
        motionMagnitude: 0.0,
      );
      expect(filtered1.length, equals(2));

      final filtered2 = ArtifactFilter.filterRRIntervals(
        valid,
        motionMagnitude: 10.0, // Extreme
      );
      expect(filtered2.isEmpty, isTrue);
    });

    test('handles NaN and infinity gracefully', () {
      // Note: In production, these should be caught upstream
      // but filter should handle gracefully
      final withSpecial = [800.0, double.nan, 810.0, double.infinity];

      // Should not throw, may filter out special values
      expect(() => ArtifactFilter.filterRRIntervals(withSpecial), returnsNormally);
    });
  });
}
