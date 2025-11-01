import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:swip/swip.dart';
import 'package:synheart_wear/synheart_wear.dart' as wearpkg;
import 'package:share_plus/share_plus.dart';
import 'logging_db.dart';
import 'system_metrics.dart';

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
  bool _loggingEnabled = true;
  String? _activeSessionId;
  SWIPSessionResults? _lastResults;
  String _status = 'Not initialized';

  // Emotion recognition
  EmotionPrediction? _currentEmotion;
  StreamSubscription<EmotionPrediction>? _emotionSubscription;
  StreamSubscription? _biosignalSubscription;

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
    _biosignalSubscription?.cancel();
    _swipManager.dispose();
    super.dispose();
  }

  Future<void> _initializeSWIP() async {
    try {
      setState(() {
        _status = 'Initializing...';
      });

      await LoggingDb.init();
      await SystemMetrics.init(); // Initialize system metrics
      await _swipManager.initialize();

      // Set up emotion recognition stream
      _emotionSubscription = _swipManager.emotionStream.listen((prediction) {
        setState(() {
          _currentEmotion = prediction;
        });
      });

      // Diagnostics stream -> DB
      _swipManager.diagnosticsStream.listen((diag) async {
        if (!_loggingEnabled) return;
        final probs = (diag['probabilities'] as Map)
            .map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
        final latencyMs = (diag['latency_ms'] as int?) ?? 0;

        // Get system metrics
        final systemMetrics = await SystemMetrics.getAllMetrics(
          inferenceLatencyMs: latencyMs,
        );

        await LoggingDb.insertEmotionLog(
          tsUtc: diag['ts'] as String,
          latencyMs: latencyMs,
          buffer: (diag['buffer'] as Map<String, Object?>?) ?? const {},
          probabilities: probs,
          topEmotion: (diag['emotion'] as String?) ?? 'unknown',
          confidence: (diag['confidence'] as num?)?.toDouble() ?? 0.0,
          model: (diag['model'] as Map<String, Object?>?),
          hrMean: (diag['hr_mean'] as num?)?.toDouble(),
          memoryHeapMb: (systemMetrics['memory_heap_mb'] as num?)?.toDouble(),
          cpuPercent: (systemMetrics['cpu_percent'] as num?)?.toDouble(),
          energyEstimateUj:
              (systemMetrics['energy_estimate_uj'] as num?)?.toDouble(),
          batteryLevel: (systemMetrics['battery_level'] as num?)?.toDouble(),
          isCharging: systemMetrics['is_charging'] as bool?,
          appVersion: systemMetrics['app_version'] as String?,
          deviceIdHash: systemMetrics['device_id_hash'] as String?,
        );
      });

      // Model information (synheart_emotion external engine) not available via SWIP now
      _modelInfo = null;
      _performanceMetrics = null;

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

      // Using real wearable data via synheart_wear → synheart_emotion

      // Subscribe to biosignal stream for dim_App_biosignals logging
      _biosignalSubscription?.cancel();
      _biosignalSubscription =
          _swipManager.biosignalStream.listen((data) async {
        if (!_loggingEnabled || _activeSessionId == null) return;
        if (data is! wearpkg.WearMetrics) return;

        final m = data;
        final hr = m.getMetric(wearpkg.MetricType.hr)?.toDouble();
        var hrvSdnn = m.getMetric(wearpkg.MetricType.hrvSdnn)?.toDouble();
        final rrMs = m.rrMs;

        // Calculate SDNN from RR intervals if not provided by the stream
        // SDNN = standard deviation of all RR intervals
        if (hrvSdnn == null && rrMs != null && rrMs.isNotEmpty) {
          if (rrMs.length >= 2) {
            // Calculate mean
            final mean = rrMs.reduce((a, b) => a + b) / rrMs.length;
            // Calculate variance
            final variance = rrMs
                    .map((r) => (r - mean) * (r - mean))
                    .reduce((a, b) => a + b) /
                rrMs.length;
            // SDNN = sqrt(variance) = standard deviation
            hrvSdnn = variance > 0 ? sqrt(variance) : null;
          } else if (rrMs.length == 1) {
            // Single RR interval: SDNN = 0 (no variability)
            hrvSdnn = 0.0;
          }
        }

        // Debug log if still null
        if (hrvSdnn == null) {
          // ignore: avoid_print
          print(
              '[SWIP][DB] hrv_sdnn calculation failed: hr=$hr, rrMs length=${rrMs?.length ?? 0}');
        }

        // IBI (Inter-Beat Interval) = mean of RR intervals, or single RR estimate
        final ibi = rrMs != null && rrMs.isNotEmpty
            ? rrMs.reduce((a, b) => a + b) / rrMs.length
            : (hr != null && hr > 0 ? 60000.0 / hr : null);

        await LoggingDb.insertBiosignal(
          appSessionId: _activeSessionId!,
          timestamp: m.timestamp,
          heartRate: hr,
          hrvSdnn: hrvSdnn,
          ibi: ibi,
          // Other fields not yet available from synheart_wear:
          // respiratoryRate, accelerometer, temperature, bloodOxygenSaturation,
          // ecg, emg, eda, gyro, ppg - will remain null
        );
      });

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

      // Stop biosignal logging subscription
      await _biosignalSubscription?.cancel();
      _biosignalSubscription = null;

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

  Future<void> _exportDatabase() async {
    try {
      setState(() {
        _status = 'Exporting database...';
      });

      // Show format selection dialog
      final format = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export Format'),
          content: const Text('Choose export format:'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'json'),
              child: const Text('JSON'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'csv'),
              child: const Text('CSV'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (format == null) {
        setState(() {
          _status = 'Export cancelled';
        });
        return;
      }

      // Export based on format
      String? filePath;
      if (format == 'json') {
        filePath = await LoggingDb.exportToJson();
      } else if (format == 'csv') {
        filePath = await LoggingDb.exportToCsv();
      }

      if (filePath == null) {
        setState(() {
          _status = 'Export failed: No data to export';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Export failed: No data to export'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get stats to show in share dialog
      final stats = await LoggingDb.getStats();
      final statsMessage = '''
Exported ${format.toUpperCase()} file:
- Emotion logs: ${stats['emotion_inference_log']?['count'] ?? 0} records
- Biosignals: ${stats['dim_App_biosignals']?['count'] ?? 0} records

File saved to: ${filePath.split('/').last}
''';

      // Share the file using share_plus
      final file = File(filePath);
      if (await file.exists()) {
        final xFile = XFile(filePath);
        await Share.shareXFiles(
          [xFile],
          text: statsMessage,
          subject: 'SWIP Diagnostics Export',
        );
        setState(() {
          _status = 'Export completed';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Database exported successfully as $format'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          _status = 'Export failed: File not found';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Export failed: File not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _status = 'Export failed: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SWIP'),
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
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
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
                            color:
                                _isInitialized ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _status,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          _isInitialized
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          color: _isInitialized ? Colors.green : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isInitialized ? 'System Ready' : 'Not Initialized',
                          style: TextStyle(
                            color: _isInitialized
                                ? Colors.green[700]
                                : Colors.grey[600],
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
                            Icon(Icons.play_circle_rounded,
                                color: Colors.green[700], size: 20),
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
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
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
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Log diagnostics to SQLite'),
                        Switch(
                          value: _loggingEnabled,
                          onChanged: (v) {
                            setState(() => _loggingEnabled = v);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _exportDatabase,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Export Database'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
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
                            ? _getEmotionColor(_currentEmotion!.emotion)
                                .withOpacity(0.1)
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
                            Expanded(
                              child: Text(
                                'Real-time Emotion Recognition',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
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
                                    color: _getEmotionColor(
                                            _currentEmotion!.emotion)
                                        .withOpacity(0.2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _getEmotionColor(
                                                _currentEmotion!.emotion)
                                            .withOpacity(0.3),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _getEmotionIcon(_currentEmotion!.emotion),
                                    size: 80,
                                    color: _getEmotionColor(
                                        _currentEmotion!.emotion),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  _currentEmotion!.emotion.label,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineLarge
                                      ?.copyWith(
                                        color: _getEmotionColor(
                                            _currentEmotion!.emotion),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 36,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _getEmotionColor(
                                            _currentEmotion!.emotion)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${(_currentEmotion!.confidence * 100).toStringAsFixed(1)}% Confidence',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: _getEmotionColor(
                                              _currentEmotion!.emotion),
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                      ),
                                ),
                                const SizedBox(height: 12),
                                ...List.generate(
                                    _currentEmotion!.probabilities.length,
                                    (index) {
                                  // Fixed mapping order: Calm, Stressed, Amused
                                  final labels = ['Calm', 'Stressed', 'Amused'];
                                  if (index >= labels.length)
                                    return const SizedBox.shrink();
                                  final emotionLabel = labels[index];
                                  final emotion =
                                      EmotionClass.fromString(emotionLabel);
                                  final probability =
                                      _currentEmotion!.probabilities[index];

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 6.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  _getEmotionIcon(emotion),
                                                  size: 20,
                                                  color:
                                                      _getEmotionColor(emotion),
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
                                                color:
                                                    _getEmotionColor(emotion),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: LinearProgressIndicator(
                                            value: probability,
                                            minHeight: 8,
                                            backgroundColor: Colors.grey[300],
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.favorite_rounded,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Last Session Results',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _lastResults!.impactType == 'beneficial'
                                  ? Colors.green.withOpacity(0.12)
                                  : _lastResults!.impactType == 'harmful'
                                      ? Colors.red.withOpacity(0.12)
                                      : Colors.grey.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _lastResults!.impactType.toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _lastResults!.impactType == 'beneficial'
                                    ? Colors.green[700]
                                    : _lastResults!.impactType == 'harmful'
                                        ? Colors.red[700]
                                        : Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          // Big WIS donut
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SweepGradient(
                                startAngle: 0,
                                endAngle: 6.283,
                                stops: [
                                  (_lastResults!.wellnessScore
                                              .clamp(-1.0, 1.0) +
                                          1) /
                                      2,
                                  (_lastResults!.wellnessScore
                                              .clamp(-1.0, 1.0) +
                                          1) /
                                      2,
                                ],
                                colors: [
                                  _lastResults!.impactType == 'beneficial'
                                      ? Colors.green
                                      : _lastResults!.impactType == 'harmful'
                                          ? Colors.red
                                          : Colors.amber,
                                  Colors.grey.shade200,
                                ],
                              ),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${(_lastResults!.wellnessScore * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text(
                                    'WIS',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Key metrics
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildMetricLine(
                                  label: 'ΔHRV (RMSSD)',
                                  value:
                                      _lastResults!.deltaHrv.toStringAsFixed(2),
                                  color: Colors.blue,
                                ),
                                const SizedBox(height: 8),
                                _buildMetricLine(
                                  label: 'Coherence Index',
                                  value: _lastResults!.coherenceIndex
                                      .toStringAsFixed(2),
                                  color: Colors.purple,
                                ),
                                const SizedBox(height: 8),
                                _buildMetricLine(
                                  label: 'Recovery Ratio',
                                  value: _lastResults!.stressRecoveryRate
                                      .toStringAsFixed(2),
                                  color: Colors.teal,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Duration + score bar
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Duration: ${_lastResults!.duration.inMinutes} min',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const Spacer(),
                          const Icon(Icons.speed, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Score',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Export button
                      ElevatedButton.icon(
                        onPressed: _exportDatabase,
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Export Session Data'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value:
                              ((_lastResults!.wellnessScore.clamp(-1.0, 1.0) +
                                      1) /
                                  2),
                          minHeight: 10,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _lastResults!.impactType == 'beneficial'
                                ? Colors.green
                                : _lastResults!.impactType == 'harmful'
                                    ? Colors.red
                                    : Colors.amber,
                          ),
                        ),
                      ),
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
                      _buildInfoRow(
                          'Model ID', _modelInfo!['modelId'] ?? 'Unknown'),
                      _buildInfoRow(
                          'Version', _modelInfo!['version'] ?? 'Unknown'),
                      _buildInfoRow('Type', _modelInfo!['type'] ?? 'Unknown'),
                      if (_performanceMetrics != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Performance Metrics',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        _buildInfoRow('Accuracy',
                            '${(_performanceMetrics!['accuracy'] ?? 0.0).toStringAsFixed(2)}'),
                        _buildInfoRow('F1 Score',
                            '${(_performanceMetrics!['f1_score'] ?? 0.0).toStringAsFixed(2)}'),
                        _buildInfoRow('Dataset',
                            _performanceMetrics!['dataset'] ?? 'Unknown'),
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

  // Removed legacy _buildResultRow (unused)

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

  Widget _buildMetricLine({
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.black54),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
