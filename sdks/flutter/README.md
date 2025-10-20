# SWIP Flutter SDK

Flutter implementation of the Synheart Wellness Impact Protocol.

## Install

Add to pubspec.yaml:

```yaml
dependencies:
  swip:
    path: ./sdks/flutter
```

Or use as a package when published.

## Quick Start

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

## Hardware Connectivity

SWIP uses `synheart_wear` for device connectivity (Apple Watch, Wear OS, BLE straps).

## Notes
- Currency examples use ETB as per project docs.
- Author: Israel Goytom
