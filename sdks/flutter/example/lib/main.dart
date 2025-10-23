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
    _simulationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final random = Random();
      
      // Simulate different emotional states with varying heart rate patterns
      final baseHr = 70.0 + random.nextDouble() * 20.0; // 70-90 BPM base
      final variation = random.nextDouble() * 10.0 - 5.0; // ±5 BPM variation
      final heartRate = baseHr + variation;
      
      // Add heart rate data to emotion recognition
      _swipManager.addHeartRateData(heartRate, DateTime.now());
      
      // Also add RR interval data
      final rrInterval = 60000.0 / heartRate; // Convert BPM to ms
      _swipManager.addRRIntervalData(rrInterval, DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SWIP Flutter Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(_status),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _isInitialized ? Icons.check_circle : Icons.error,
                          color: _isInitialized ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(_isInitialized ? 'Initialized' : 'Not Initialized'),
                      ],
                    ),
                    if (_isSessionActive) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.play_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Text('Session Active: $_activeSessionId'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session Controls',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isInitialized && !_isSessionActive
                                ? _startSession
                                : null,
                            child: const Text('Start Session'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSessionActive ? _endSession : null,
                            child: const Text('End Session'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isInitialized ? _getCurrentMetrics : null,
                        child: const Text('Get Current Metrics'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Emotion Recognition Display
            if (_swipManager.isEmotionRecognitionAvailable) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Real-time Emotion Recognition',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      if (_currentEmotion != null) ...[
                        Row(
                          children: [
                            Icon(
                              _getEmotionIcon(_currentEmotion!.emotion),
                              size: 32,
                              color: _getEmotionColor(_currentEmotion!.emotion),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _currentEmotion!.emotion.label,
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: _getEmotionColor(_currentEmotion!.emotion),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Confidence: ${(_currentEmotion!.confidence * 100).toStringAsFixed(1)}%',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Probability bars
                        ...List.generate(_currentEmotion!.probabilities.length, (index) {
                          final emotion = EmotionClass.values[index];
                          final probability = _currentEmotion!.probabilities[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 80,
                                  child: Text(emotion.label),
                                ),
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: probability,
                                    backgroundColor: Colors.grey[300],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _getEmotionColor(emotion),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('${(probability * 100).toStringAsFixed(1)}%'),
                              ],
                            ),
                          );
                        }),
                      ] else ...[
                        const Text('No emotion data yet. Start a session to see real-time emotion recognition.'),
                      ],
                    ],
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
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About SWIP',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The Synheart Wellness Impact Protocol (SWIP) measures the physiological impact of digital experiences using heart-rate variability (HRV) data from wearable devices.',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This example demonstrates basic SWIP integration with Flutter. In a real app, you would connect to actual wearable devices via synheart_wear.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getEmotionIcon(EmotionClass emotion) {
    switch (emotion) {
      case EmotionClass.amused:
        return Icons.sentiment_very_satisfied;
      case EmotionClass.calm:
        return Icons.sentiment_neutral;
      case EmotionClass.stressed:
        return Icons.sentiment_very_dissatisfied;
    }
  }

  Color _getEmotionColor(EmotionClass emotion) {
    switch (emotion) {
      case EmotionClass.amused:
        return Colors.green;
      case EmotionClass.calm:
        return Colors.blue;
      case EmotionClass.stressed:
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
