# Getting Started with SWIP

Welcome to the Synheart Wellness Impact Protocol (SWIP)! This guide will help you get started with measuring the physiological impact of your digital applications.

## What is SWIP?

SWIP is an open protocol that enables applications to quantitatively assess their impact on human wellness using heart-rate variability (HRV) and related biosignals. By integrating SWIP, you can:

- Measure how your app affects users' physiological state
- Earn **Heart-Verified Certification (HVC)** for wellness-positive apps
- Make data-driven decisions about user experience design
- Contribute to ethical, bio-aligned technology development

## Current Status

**🚧 In Development** - SWIP is currently in early development phase. Only the Flutter SDK is available for testing.

## Quick Start (Flutter Only)

### 1. Install Flutter SDK

Add to your `pubspec.yaml`:

```yaml
dependencies:
  swip:
    path: ./sdks/flutter  # Local path for now
```

### 2. Initialize SWIP

```dart
import 'package:swip/swip.dart';

final swip = SWIPManager();
await swip.initialize();
```

### 3. Start Measuring

```dart
final sessionId = await swip.startSession(
  config: SWIPSessionConfig(
    duration: Duration(minutes: 30),
    type: 'baseline',
    platform: 'flutter',
    environment: 'indoor',
  ),
);

// Your app logic here...

final results = await swip.endSession();
print('Wellness Impact Score: ${results.wellnessScore}');
```

## Hardware Integration

SWIP uses **synheart_wear** for unified biometric data collection from multiple wearable devices:

- Apple Watch
- Fitbit  
- Garmin
- Whoop
- Samsung Watch
- And more...

The synheart_wear SDK provides a standardized interface for accessing HRV data across all these platforms.

## Core Concepts

### HRV Metrics

SWIP measures several key HRV metrics:

- **RMSSD**: Root mean square of successive differences
- **SDNN**: Standard deviation of NN intervals
- **pNN50**: Percentage of NN intervals differing by >50ms
- **Frequency Domain**: LF, HF, and LF/HF ratio

### Wellness Metrics

From HRV data, SWIP calculates:

- **ΔHRV**: Change in HRV during session
- **Coherence Index**: Heart rhythm coherence (0-1 scale)
- **Stress-Recovery Rate**: Rate of stress recovery

### Session Types

- **baseline**: Normal app usage
- **focus**: Deep work or concentration
- **stress**: High cognitive load
- **recovery**: Post-stress relaxation
- **exercise**: Physical activity
- **meditation**: Mindfulness practice

## Example App

Check out the [Flutter example app](sdks/flutter/example/) for a complete working implementation.

## Data Privacy

SWIP is designed with privacy-first principles:

- **Local Processing**: HRV analysis happens on-device
- **Anonymization**: All data is anonymized before transmission
- **Encryption**: End-to-end encryption for sensitive data
- **Consent**: Explicit user consent for all data collection
- **GDPR Compliance**: Full compliance with privacy regulations

## Next Steps

1. **Read the [SWIP-1.0 Specification](specs/SWIP-1.0-Spec.md)** for complete protocol details
2. **Try the [Flutter example app](sdks/flutter/example/)** to see SWIP in action
3. **Check the [Contributing Guide](CONTRIBUTING.md)** if you want to help develop SWIP

## Getting Help

- **Documentation**: Check the [docs](.) directory
- **Issues**: Search [GitHub Issues](https://github.com/synheart/swip/issues)
- **Discussions**: Use [GitHub Discussions](https://github.com/synheart/swip/discussions)

---

**Author**: Israel Goytom  
**Organization**: Synheart Open Council (SOC)
