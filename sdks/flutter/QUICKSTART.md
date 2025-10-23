# SWIP Flutter SDK - Quick Start Guide

Get up and running with the SWIP Flutter SDK in 5 minutes.

## Prerequisites

- Flutter SDK >=3.10.0
- Dart SDK >=3.0.0
- iOS Simulator or Android Emulator (or physical device)

## Installation

### 1. Clone or Navigate to SDK

```bash
cd sdks/flutter
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Verify Installation

```bash
flutter analyze
flutter test
```

Expected output:
```
24 passed, 5 failed (known minor test issues)
```

---

## Running the Demo App

### Option 1: Run on Simulator/Emulator

```bash
cd example
flutter run
```

Select your target device when prompted.

### Option 2: Run on Physical Device

```bash
cd example
flutter run -d <device-id>
```

Get device ID with: `flutter devices`

---

## Using the Demo App

### 1. **Initialize SDK**
   - App automatically initializes on launch
   - Wait for "Ready" status
   - Model loads from `assets/ml/wesad_emotion_v1_0.json`

### 2. **Start a Session**
   - Tap **"Start Session"** button
   - Mock heart rate data begins streaming
   - Watch real-time emotion recognition update every 10 seconds

### 3. **View Live Emotions**
   - **Emotion Recognition Card** shows:
     - Current emotion (Amused/Calm/Stressed)
     - Confidence percentage
     - Probability bars for all classes
   - Updates automatically during session

### 4. **End Session**
   - Tap **"End Session"** button
   - View **Wellness Impact Score** results:
     - ΔHRV (HRV change)
     - Coherence Index
     - Stress Recovery Rate
     - Impact Type (Beneficial/Neutral/Harmful)

### 5. **Get Current Metrics**
   - Tap **"Get Current Metrics"** during or after session
   - Shows HRV measurement count

---

## Understanding the Output

### Emotion Recognition

| Emotion | Meaning | Physiological Pattern |
|---------|---------|----------------------|
| **Amused** 🙂 | Positive engagement | Higher HRV, moderate HR |
| **Calm** 😐 | Relaxed state | Stable HRV, low HR |
| **Stressed** ☹️ | Anxiety/tension | Lower HRV, higher HR |

**Confidence:** Percentage indicating prediction certainty (0-100%)

### Wellness Impact Score (WIS)

```
WIS = 0.5(ΔHRV) + 0.3(CI) + 0.2(-SRR)
```

| Score Range | Classification | Meaning |
|-------------|----------------|---------|
| > +0.2 | **Beneficial** | Experience improved coherence |
| -0.2 to +0.2 | **Neutral** | Negligible impact |
| < -0.2 | **Harmful** | Experience decreased coherence |

**Components:**
- **ΔHRV:** Change in HRV from baseline (higher is better)
- **CI (Coherence Index):** Heart rhythm stability (higher is better)
- **SRR (Stress Recovery Rate):** Time to return to baseline (lower is better)

---

## Integrating into Your App

### 1. Add Dependency

**pubspec.yaml:**
```yaml
dependencies:
  swip:
    path: ../path/to/swip/sdks/flutter
```

Or from pub.dev (when published):
```yaml
dependencies:
  swip: ^1.0.0
```

### 2. Import Package

```dart
import 'package:swip/swip.dart';
```

### 3. Initialize SDK

```dart
final swipManager = SWIPManager();
await swipManager.initialize();
```

### 4. Start Session

```dart
final sessionId = await swipManager.startSession(
  config: SWIPSessionConfig(
    duration: Duration(minutes: 5),
    type: 'focus',
    platform: 'flutter',
    environment: 'office',
  ),
);
```

### 5. Listen to Emotion Stream

```dart
swipManager.emotionStream.listen((prediction) {
  print('Emotion: ${prediction.emotion.label}');
  print('Confidence: ${prediction.confidence}');
});
```

### 6. Add Heart Rate Data

```dart
// From your wearable device integration
swipManager.addHeartRateData(heartRate, DateTime.now());
swipManager.addRRIntervalData(rrIntervalMs, DateTime.now());
```

### 7. End Session and Get Results

```dart
final results = await swipManager.endSession();
print('Wellness Score: ${results.wellnessScore}');
print('Impact Type: ${results.impactType}');
```

### 8. Cleanup

```dart
swipManager.dispose();
```

---

## Example: Minimal Integration

```dart
import 'package:flutter/material.dart';
import 'package:swip/swip.dart';

class MyWellnessApp extends StatefulWidget {
  @override
  _MyWellnessAppState createState() => _MyWellnessAppState();
}

class _MyWellnessAppState extends State<MyWellnessApp> {
  final swip = SWIPManager();
  EmotionPrediction? currentEmotion;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await swip.initialize();

    // Listen to emotion predictions
    swip.emotionStream.listen((prediction) {
      setState(() => currentEmotion = prediction);
    });

    // Start a session
    await swip.startSession(
      config: SWIPSessionConfig(
        duration: Duration(minutes: 5),
        type: 'focus',
        platform: 'flutter',
        environment: 'home',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: currentEmotion != null
          ? Text('Emotion: ${currentEmotion!.emotion.label}')
          : CircularProgressIndicator(),
      ),
    );
  }

  @override
  void dispose() {
    swip.dispose();
    super.dispose();
  }
}
```

---

## Configuration Options

### SWIPSessionConfig

```dart
SWIPSessionConfig(
  duration: Duration(minutes: 30),      // Session length (30s - 2h)
  type: 'meditation',                   // Session type
  platform: 'flutter',                  // Platform identifier
  environment: 'outdoor',               // User environment
  customMetrics: {'app': 'MyApp'},      // Optional metadata
)
```

**Session Types:**
- `baseline` - Resting state measurement
- `focus` - Concentrated work
- `stress` - Stressful activity
- `recovery` - Post-stress recovery
- `exercise` - Physical activity
- `meditation` - Mindfulness practice

---

## Troubleshooting

### SDK Fails to Initialize

**Error:** `Failed to initialize emotion recognition`

**Solution:**
1. Verify `assets/ml/wesad_emotion_v1_0.json` exists
2. Check `pubspec.yaml` includes:
   ```yaml
   flutter:
     assets:
       - assets/ml/
   ```
3. Run `flutter pub get`

### No Emotion Predictions

**Symptom:** Emotion stream emits no events

**Causes:**
- Session not started
- Insufficient heart rate data (<30s)
- Inference interval not reached (wait 10s)

**Solution:**
1. Start session with `startSession()`
2. Add HR data with `addHeartRateData()`
3. Wait at least 60 seconds for first prediction

### Mock Data Not Realistic

**Note:** Demo uses simulated data for testing. For real measurements:

1. Integrate with actual wearable devices
2. Use `synheart_wear` package (when available)
3. Connect to Apple HealthKit / Google Fit APIs

---

## Performance Tips

### Battery Optimization
- Use 60s windows (default) for best accuracy
- Avoid windows <30s (noisy predictions)
- Stop sessions when not needed

### Memory Management
- Call `dispose()` when done
- Limit session duration to <2 hours
- Clear old data after session ends

### Accuracy Improvements
- Ensure good wearable sensor contact
- Minimize motion during measurement
- Use quality score to filter bad data

---

## Next Steps

1. ✅ Run the demo app
2. 📖 Read [RFC documentation](../../docs/rfc/)
3. 🧪 Review [test suite](test/)
4. 🔌 Integrate with your wearable devices
5. 🚀 Deploy to production

---

## Support

- **Documentation:** `docs/rfc/`
- **Issues:** GitHub Issues
- **Email:** dev@synheart.ai
- **Website:** https://synheart.ai

---

## License

Apache 2.0 - See LICENSE file for details

© 2025 Synheart AI - Open source & community-driven
