# SWIP Flutter SDK

Synheart Wellness Impact Protocol - Flutter SDK for measuring how apps affect user well-being in real-time.

## Overview

The SWIP SDK enables apps to understand how users feel during digital interactions — privately, locally, and in real time. It combines:

1. **synheart_wear** – Reads heart rate (HR), heart rate variability (HRV), and motion from wearables
2. **synheart-emotion** – Runs lightweight on-device models that infer emotional states
3. **swip-core** – Fuses biosignal features and emotion probabilities into a single SWIP Score (0–100)

## Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  swip:
    path: ../../../swip/sdks/flutter
  
  # SWIP dependencies
  synheart_wear:
    path: ../../../synheart-wear/packages/synheart_wear
  synheart_emotion:
    path: ../../../synheart-emotion
```

## Quick Start

```dart
import 'package:swip/swip.dart';

// Initialize the SDK
final sdk = SwipSdkManager(
  config: SwipSdkConfig(
    enableLogging: true,
  ),
);

await sdk.initialize();

// Listen to SWIP scores
sdk.scoreStream.listen((result) {
  print('SWIP Score: ${result.swipScore}');
  print('Emotion: ${result.dominantEmotion}');
  print('Confidence: ${result.confidence}');
});

// Start a session when your app goes to foreground
final sessionId = await sdk.startSession(
  appId: 'com.example.myapp',
);

// ... your app logic ...

// Stop the session when app goes to background
final results = await sdk.stopSession();
print('Average SWIP Score: ${results.getSummary()['average_swip_score']}');

// Dispose when done
sdk.dispose();
```

## Components

### SwipSdkManager

Main entry point for the SDK that orchestrates all components.

```dart
final sdk = SwipSdkManager(
  config: SwipSdkConfig(
    swipConfig: SwipConfig(
      smoothingLambda: 0.9,  // Exponential smoothing factor
      enableSmoothing: true,
      enableArtifactDetection: true,
    ),
    emotionConfig: EmotionConfig.defaultConfig,
    enableLogging: true,
  ),
);
```

### SwipScoreResult

Contains the computed SWIP score and metadata:

```dart
class SwipScoreResult {
  final double swipScore;              // 0-100 score
  final double physSubscore;           // Physiological contribution
  final double emoSubscore;            // Emotion contribution
  final double confidence;             // Confidence level
  final String dominantEmotion;        // Top emotion
  final Map<String, double> emotionProbabilities;  // All emotions
  final DateTime timestamp;
  final String modelId;
  final Map<String, double> reasons;   // Explainable factors
  final bool artifactFlag;
}
```

### Score Interpretation

| Score Range | State | Meaning |
|-------------|-------|---------|
| 80-100 | Positive | Relaxed / Engaged - app supports wellness |
| 60-79 | Neutral | Emotionally stable |
| 40-59 | Mild Stress | Cognitive or emotional fatigue |
| <40 | Negative | Stress / emotional load detected |

## Architecture

```
┌─────────────────────┐
│   Your App          │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  SwipSdkManager     │ ← Orchestrates everything
└──────────┬──────────┘
           │
    ┌──────┴──────┬────────────┐
    ▼             ▼            ▼
┌──────────┐ ┌───────────┐ ┌──────────┐
│synheart_ │ │synheart_  │ │swip_core │
│wear      │ │emotion    │ │          │
└────┬─────┘ └────┬──────┘ └────┬─────┘
     │            │             │
     ▼            ▼             ▼
  HR/HRV      Emotion       SWIP Score
  Motion      Probabilities (0-100)
```

## Data Flow

1. **Wearable Sensor** → `synheart_wear` reads HR, HRV, motion data
2. **Feature Extraction** → Sliding window aggregates data (~1 Hz)
3. **Emotion Inference** → `synheart-emotion` computes emotion probabilities
4. **SWIP Computation** → `swip-core` fuses physiological and emotion data
5. **Stream Output** → Your app receives SWIP scores and emotion updates

## Privacy & Consent

SWIP follows a **privacy-first design** with three consent levels:

### Consent Levels

| Level | Name | Description |
|-------|------|-------------|
| 0 | `onDevice` | **Default** - All processing local, no network calls, raw biosignals never leave device |
| 1 | `localExport` | User can manually export data, no automatic uploads |
| 2 | `dashboardShare` | Aggregated metrics can be uploaded (no raw biosignals) |

### Privacy Guarantees

- **Local-first**: All computation defaults to on-device processing
- **No Raw Data Transmission**: Raw HR/RR intervals never uploaded automatically
- **Explicit Consent Required**: Network operations gated by consent level
- **Data Purge API**: Complete data deletion with `purgeAllData()`
- **30-Day Retention**: Raw biosignals auto-deleted after 30 days
- **Encryption**: Sensitive data encrypted via device Keychain/Keystore
- **Anonymization**: Hashed device IDs, per-session UUIDs
- **TLS 1.3**: Required for any cloud transmission

### Usage Example

```dart
import 'package:swip/swip.dart';

// Initialize consent manager
final consentManager = ConsentManager();

// Request dashboard sharing (shows UI to user)
final approved = await consentManager.requestConsent(
  requested: ConsentLevel.dashboardShare,
  context: ConsentContext(appId: 'com.example.app'),
);

if (approved) {
  await consentManager.grantConsent(ConsentLevel.dashboardShare);

  // Now network operations are allowed
  await sdk.uploadDailyAggregate();
}

// Check consent before sensitive operations
if (consentManager.canPerformAction(ConsentLevel.dashboardShare)) {
  // Upload aggregates
}

// Purge all user data (GDPR compliance)
await consentManager.purgeAllData();
```

### Data Storage

Local SQLite database with schema:
- `sessions` - Session tracking
- `scores` - SWIP scores
- `samples_raw` - Raw biosignals (30-day retention)
- `daily_agg` - Daily aggregates
- `monthly_agg` - Monthly summaries
- `consent_history` - Audit trail

See `SwipStorageSchema` for complete schema.

## SWIP Core Implementation

The `swip-core` package implements the RFC specification:

### Physiological Subscore

```
S_phys = w_HR * S_HR + w_HRV * S_HRV + w_M * S_M

where:
- w_HR = 0.45 (heart rate weight)
- w_HRV = 0.35 (heart rate variability weight)
- w_M = 0.20 (motion weight)
```

### Emotion Subscore

```
S_emo = Σ(p_i * u_i)

where emotion utilities are:
- Amused: 0.95
- Calm: 0.85
- Focused: 0.80
- Neutral: 0.70
- Stressed: 0.15
```

### Fusion Formula

```
SWIP = β * S_emo + (1-β) * S_phys
where β = min(0.6, C)

Finally: SWIP_100 = 100 * SWIP
```

## Session Lifecycle

1. **App Opened / Foreground** → Start reading biosignals
2. **During Session** → Continuous emotion inference and SWIP score updates (~1 Hz)
3. **App Minimized / Background** → Stop sampling, save session summary
4. **App Closed** → Finalize session, write daily aggregates

## Example Usage

```dart
import 'package:swip/swip.dart';

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late SwipSdkManager _sdk;
  String? _currentSessionId;
  double? _currentScore;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSdk();
  }

  Future<void> _initSdk() async {
    _sdk = SwipSdkManager(
      config: SwipSdkConfig(enableLogging: true),
    );
    
    await _sdk.initialize();
    
    // Listen to score updates
    _sdk.scoreStream.listen((result) {
      setState(() {
        _currentScore = result.swipScore;
      });
      
      if (result.swipScore < 40) {
        // Alert user about stress
        _showStressAlert();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startSession();
    } else if (state == AppLifecycleState.paused) {
      _stopSession();
    }
  }

  Future<void> _startSession() async {
    if (_currentSessionId != null) return;
    
    _currentSessionId = await _sdk.startSession(
      appId: 'com.example.myapp',
    );
  }

  Future<void> _stopSession() async {
    if (_currentSessionId == null) return;
    
    final results = await _sdk.stopSession();
    print('Session summary: ${results.getSummary()}');
    _currentSessionId = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Current SWIP Score: ${_currentScore?.toStringAsFixed(1) ?? 'N/A'}'),
            _currentScore != null
                ? _buildScoreIndicator(_currentScore!)
                : CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreIndicator(double score) {
    Color color;
    if (score >= 80) color = Colors.green;
    else if (score >= 60) color = Colors.yellow;
    else if (score >= 40) color = Colors.orange;
    else color = Colors.red;
    
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: color.withOpacity(0.3),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          score.toStringAsFixed(0),
          style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showStressAlert() {
    // Show user-friendly stress alert
  }

  @override
  void dispose() {
    _sdk.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
```

## Requirements

- Flutter SDK >=3.0.0
- iOS 13+ or Android API 24+
- Compatible wearable device (Apple Watch, Fitbit, Garmin, etc.)
- Health permissions granted

## License

Apache-2.0

## Documentation

- [SWIP Core RFC](../../docs/rfc/rfc-swip-core.md)
- [SWIP SDK RFC](../../docs/rfc/)
- [Synheart Wear SDK](https://github.com/synheart-ai/synheart-wear)
- [Synheart Emotion](https://github.com/synheart-ai/synheart-emotion)

## Author

Israel Goytom - Synheart AI
