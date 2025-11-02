import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:swip/swip.dart';

void main() {
  runApp(const SWIPExampleApp());
}

class SWIPExampleApp extends StatelessWidget {
  const SWIPExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SWIP Flutter Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const SWIPExampleHomePage(),
    );
  }
}

class SWIPExampleHomePage extends StatefulWidget {
  const SWIPExampleHomePage({super.key});

  @override
  State<SWIPExampleHomePage> createState() => _SWIPExampleHomePageState();
}

class _SWIPExampleHomePageState extends State<SWIPExampleHomePage> {
  final SWIPManager _swipManager = SWIPManager();
  bool _isInitialized = false;
  bool _isSessionActive = false;
  String? _activeSessionId;
  SWIPSessionResults? _lastResults;
  String _status = 'Not initialized';
  
  // Emotion recognition
  EmotionPrediction? _currentEmotion;
  StreamSubscription<EmotionPrediction>? _emotionSubscription;
  Timer? _simulationTimer;
  
  // Model information
  Map<String, dynamic>? _modelInfo;
  Map<String, dynamic>? _performanceMetrics;

  @override
  void initState() {
    super.initState();
    _initializeSWIP();
  }

  @override
  void dispose() {
    _emotionSubscription?.cancel();
    _simulationTimer?.cancel();
    _swipManager.dispose();
    super.dispose();
  }

  Future<void> _initializeSWIP() async {
    try {
      setState(() {
        _status = 'Initializing...';
      });
      
      await _swipManager.initialize();
      
      // Set up emotion recognition stream
      _emotionSubscription = _swipManager.emotionStream.listen((prediction) {
        setState(() {
          _currentEmotion = prediction;
        });
      });
      
      // Get model information
      _modelInfo = _swipManager.emotionController.getModelInfo();
      _performanceMetrics = _swipManager.emotionController.getPerformanceMetrics();
      
      setState(() {
        _isInitialized = true;
        _status = 'Ready';
      });
    } catch (e) {
      setState(() {
        _status = 'Initialization failed: $e';
      });
    }
  }

  Future<void> _startSession() async {
    if (!_isInitialized) return;

    try {
      setState(() {
        _status = 'Starting session...';
      });

      final config = const SWIPSessionConfig(
        duration: Duration(minutes: 5), // Short session for demo
        type: 'baseline',
        platform: 'flutter',
        environment: 'indoor',
      );

      _activeSessionId = await _swipManager.startSession(config: config);
      
      // Start simulating heart rate data for emotion recognition demo
      _startHeartRateSimulation();
      
      setState(() {
        _isSessionActive = true;
        _status = 'Session active: $_activeSessionId';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to start session: $e';
      });
    }
  }

  Future<void> _endSession() async {
    if (!_isSessionActive || _activeSessionId == null) return;

    try {
      setState(() {
        _status = 'Ending session...';
      });

      // Stop heart rate simulation
      _simulationTimer?.cancel();
      _simulationTimer = null;
      
      final results = await _swipManager.endSession();
      
      setState(() {
        _isSessionActive = false;
        _activeSessionId = null;
        _lastResults = results;
        _status = 'Session completed';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to end session: $e';
      });
    }
  }

  Future<void> _getCurrentMetrics() async {
    if (!_isInitialized) return;

    try {
      setState(() {
        _status = 'Reading metrics...';
      });

      final metrics = await _swipManager.getCurrentMetrics();
      
      setState(() {
        _status = 'Metrics: ${metrics.hrv.length} HRV measurements';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to read metrics: $e';
      });
    }
  }

  void _startHeartRateSimulation() {
    // Simulate realistic heart rate data for emotion recognition demo
    // Based on the ExtraTrees model's expected feature ranges
    final random = Random(DateTime.now().millisecondsSinceEpoch); // Properly seeded random
    
    _simulationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Simulate different emotional states with varied heart rate patterns
      // ExtraTrees model expects: SDNN, RMSSD, pNN50, Mean_RR, HR_mean
      final emotionalState = random.nextInt(3); // 0=calm, 1=stressed, 2=amused
      
      double baseHr;
      double hrVariability; // Affects SDNN and RMSSD
      double rrVariability; // Affects pNN50
      
      switch (emotionalState) {
        case 0: // Calm - lower HR, high HRV (high SDNN/RMSSD)
          baseHr = 65.0 + random.nextDouble() * 10.0; // 65-75 BPM
          hrVariability = 8.0 + random.nextDouble() * 4.0; // Higher variability
          rrVariability = 1.5; // More RR interval changes > 50ms
          break;
        case 1: // Stressed - higher HR, low HRV (low SDNN/RMSSD)
          baseHr = 85.0 + random.nextDouble() * 20.0; // 85-105 BPM
          hrVariability = 2.0 + random.nextDouble() * 3.0; // Lower variability
          rrVariability = 0.5; // Fewer RR interval changes > 50ms
          break;
        case 2: // Amused - moderate HR, moderate HRV
          baseHr = 75.0 + random.nextDouble() * 15.0; // 75-90 BPM
          hrVariability = 5.0 + random.nextDouble() * 5.0; // Moderate variability
          rrVariability = 1.0; // Moderate RR interval changes
          break;
        default:
          baseHr = 70.0;
          hrVariability = 5.0;
          rrVariability = 1.0;
      }
      
      // Add random variation to create realistic HRV patterns
      final variation = (random.nextDouble() - 0.5) * hrVariability * 2;
      final heartRate = (baseHr + variation).clamp(50.0, 120.0); // Keep within realistic bounds
      
      // Calculate RR interval with added variability for pNN50
      final baseRR = 60000.0 / heartRate; // Convert BPM to ms
      final rrVariation = (random.nextDouble() - 0.5) * 100.0 * rrVariability;
      final rrInterval = (baseRR + rrVariation).clamp(500.0, 1200.0);
      
      // Add heart rate data to emotion recognition
      _swipManager.addHeartRateData(heartRate, DateTime.now());
      _swipManager.addRRIntervalData(rrInterval, DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SWIP Emotion Recognition'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Status',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 8,
                            color: _isInitialized ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _status,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          _isInitialized ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          color: _isInitialized ? Colors.green : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isInitialized ? 'System Ready' : 'Not Initialized',
                          style: TextStyle(
                            color: _isInitialized ? Colors.green[700] : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (_isSessionActive) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.play_circle_rounded, color: Colors.green[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Session Active',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.control_camera_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Session Controls',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isInitialized && !_isSessionActive
                                ? _startSession
                                : null,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Start Session'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSessionActive ? _endSession : null,
                            icon: const Icon(Icons.stop_rounded),
                            label: const Text('End Session'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Emotion Recognition Display
            if (_swipManager.isEmotionRecognitionAvailable) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _currentEmotion != null 
                          ? _getEmotionColor(_currentEmotion!.emotion).withOpacity(0.1)
                          : Colors.blue.withOpacity(0.05),
                        Colors.white,
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.psychology_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Real-time Emotion Recognition',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (_currentEmotion != null) ...[
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _getEmotionColor(_currentEmotion!.emotion).withOpacity(0.2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _getEmotionColor(_currentEmotion!.emotion).withOpacity(0.3),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _getEmotionIcon(_currentEmotion!.emotion),
                                    size: 80,
                                    color: _getEmotionColor(_currentEmotion!.emotion),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  _currentEmotion!.emotion.label,
                                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                    color: _getEmotionColor(_currentEmotion!.emotion),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 36,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _getEmotionColor(_currentEmotion!.emotion).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${(_currentEmotion!.confidence * 100).toStringAsFixed(1)}% Confidence',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: _getEmotionColor(_currentEmotion!.emotion),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Emotion Probabilities',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...List.generate(_currentEmotion!.probabilities.length, (index) {
                                  // Get the actual emotion class name from the model's class list
                                  final modelClasses = _swipManager.emotionController.emotionClasses;
                                  
                                  // Only show emotions that are in the model's class list
                                  if (index >= modelClasses.length) {
                                    return const SizedBox.shrink();
                                  }
                                  
                                  final emotionLabel = modelClasses[index];
                                  final emotion = EmotionClass.fromString(emotionLabel);
                                  final probability = _currentEmotion!.probabilities[index];
                                  
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  _getEmotionIcon(emotion),
                                                  size: 20,
                                                  color: _getEmotionColor(emotion),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  emotionLabel,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.grey[800],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              '${(probability * 100).toStringAsFixed(1)}%',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: _getEmotionColor(emotion),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: LinearProgressIndicator(
                                            value: probability,
                                            minHeight: 8,
                                            backgroundColor: Colors.grey[300],
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              _getEmotionColor(emotion),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ] else ...[
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.sentiment_neutral_rounded,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No emotion data yet',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Start a session to see real-time emotion recognition',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (_lastResults != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last Session Results',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      _buildResultRow('Wellness Score', '${_lastResults!.wellnessScore.toStringAsFixed(3)}'),
                      _buildResultRow('ΔHRV', '${_lastResults!.deltaHrv.toStringAsFixed(3)}'),
                      _buildResultRow('Coherence Index', '${_lastResults!.coherenceIndex.toStringAsFixed(3)}'),
                      _buildResultRow('Stress Recovery Rate', '${_lastResults!.stressRecoveryRate.toStringAsFixed(3)}'),
                      _buildResultRow('Impact Type', _lastResults!.impactType),
                      _buildResultRow('Duration', '${_lastResults!.duration.inMinutes} minutes'),
                    ],
                  ),
                ),
              ),
            ],
            // Model Information Display
            if (_modelInfo != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Emotion Recognition Model',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('Model ID', _modelInfo!['modelId'] ?? 'Unknown'),
                      _buildInfoRow('Version', _modelInfo!['version'] ?? 'Unknown'),
                      _buildInfoRow('Type', _modelInfo!['type'] ?? 'Unknown'),
                      if (_performanceMetrics != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Performance Metrics',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        _buildInfoRow('Accuracy', '${(_performanceMetrics!['accuracy'] ?? 0.0).toStringAsFixed(2)}'),
                        _buildInfoRow('F1 Score', '${(_performanceMetrics!['f1_score'] ?? 0.0).toStringAsFixed(2)}'),
                        _buildInfoRow('Dataset', _performanceMetrics!['dataset'] ?? 'Unknown'),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getEmotionIcon(EmotionClass emotion) {
    switch (emotion) {
      case EmotionClass.calm:
        return Icons.spa_rounded;
      case EmotionClass.stressed:
        return Icons.warning_rounded;
      case EmotionClass.amused:
        return Icons.sentiment_very_satisfied_rounded;
      case EmotionClass.amusement:
        return Icons.sentiment_very_satisfied;
      case EmotionClass.baseline:
        return Icons.sentiment_neutral;
      case EmotionClass.stress:
        return Icons.sentiment_very_dissatisfied;
    }
  }

  Color _getEmotionColor(EmotionClass emotion) {
    switch (emotion) {
      case EmotionClass.calm:
        return Colors.green;
      case EmotionClass.stressed:
        return Colors.red;
      case EmotionClass.amused:
        return Colors.amber;
      case EmotionClass.amusement:
        return Colors.amber;
      case EmotionClass.baseline:
        return Colors.blue;
      case EmotionClass.stress:
        return Colors.red;
    }
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
