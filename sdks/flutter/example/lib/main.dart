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

  @override
  void initState() {
    super.initState();
    _initializeSWIP();
  }

  Future<void> _initializeSWIP() async {
    try {
      setState(() {
        _status = 'Initializing...';
      });
      
      await _swipManager.initialize();
      
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
}
