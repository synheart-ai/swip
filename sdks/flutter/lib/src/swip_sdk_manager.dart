import 'dart:async';
import 'package:synheart_wear/synheart_wear.dart';
import 'package:synheart_emotion/synheart_emotion.dart';
import 'package:swip_core/swip_core.dart';
import 'models.dart';
import 'errors.dart';

/// SWIP SDK Manager - Main entry point for the SDK
/// 
/// Integrates:
/// - synheart_wear: Reads HR, HRV, motion data
/// - synheart_emotion: Runs emotion inference models
/// - swip_core: Computes SWIP Score
class SwipSdkManager {
  // Core components
  final SynheartWear _wear;
  final EmotionEngine _emotionEngine;
  final SwipEngine _swipEngine;
  
  // State management
  bool _initialized = false;
  bool _isWearInitialized = false;
  bool _isRunning = false;
  String? _activeSessionId;
  
  // Stream controllers
  final _scoreStreamController = StreamController<SwipScoreResult>.broadcast();
  final _emotionStreamController = StreamController<EmotionResult>.broadcast();
  
  // Subscriptions
  StreamSubscription<WearMetrics>? _wearSubscription;
  Timer? _emotionProcessor;
  
  // Configuration
  final SwipSdkConfig config;
  
  // Session data
  final List<SwipScoreResult> _sessionScores = [];
  final List<EmotionResult> _sessionEmotions = [];
  
  SwipSdkManager({
    required this.config,
    SynheartWear? wear,
    EmotionEngine? emotionEngine,
    SwipEngine? swipEngine,
  }) : _wear = wear ?? SynheartWear(),
       _emotionEngine = emotionEngine ?? EmotionEngine.fromPretrained(
         EmotionConfig.defaultConfig,
       ),
       _swipEngine = swipEngine ?? SwipEngineFactory.createDefault(
         config: config.swipConfig,
         onLog: (level, message, {context}) {
           print('[$level] $message');
         },
       );

  /// Initialize the SDK
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Initialize wearable SDK
      await _wear.initialize();
      _isWearInitialized = true;
      
      // Request permissions for health data
      await _wear.requestPermissions();
      
      _initialized = true;
      _log('info', 'SWIP SDK initialized');
    } catch (e) {
      _log('error', 'Failed to initialize: $e');
      throw InitializationError('Failed to initialize SWIP SDK: $e');
    }
  }

  /// Start a session for an app
  Future<String> startSession({
    required String appId,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_initialized) {
      throw InvalidConfigurationError('SWIP SDK not initialized');
    }
    
    if (_isRunning) {
      throw SessionError('Session already in progress');
    }
    
    // Generate session ID
    _activeSessionId = '${DateTime.now().millisecondsSinceEpoch}_$appId';
    
    try {
      // Initialize wearable SDK if not already initialized
      if (!_isWearInitialized) {
        await _wear.initialize();
      }
      
      // Subscribe to wear metrics stream
      _wearSubscription = _wear.streamHR().listen(_handleWearMetrics);
      
      // Start emotion processing timer (1 Hz)
      _emotionProcessor = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _processEmotionUpdates(),
      );
      
      _isRunning = true;
      _log('info', 'Session started: $_activeSessionId');
      
      return _activeSessionId!;
    } catch (e) {
      _log('error', 'Failed to start session: $e');
      await stopSession();
      throw SessionError('Failed to start session: $e');
    }
  }

  /// Stop the current session
  Future<SwipSessionResults> stopSession() async {
    if (!_isRunning || _activeSessionId == null) {
      throw SessionError('No active session');
    }
    
    try {
      // Cancel subscriptions
      await _wearSubscription?.cancel();
      _wearSubscription = null;
      
      // Stop timer
      _emotionProcessor?.cancel();
      _emotionProcessor = null;
      
      // Metrics subscription will stop automatically when disposed
      
      // Create session results
      final results = SwipSessionResults(
        sessionId: _activeSessionId!,
        scores: List.from(_sessionScores),
        emotions: List.from(_sessionEmotions),
        startTime: _sessionScores.isNotEmpty 
            ? _sessionScores.first.timestamp 
            : DateTime.now(),
        endTime: _sessionScores.isNotEmpty 
            ? _sessionScores.last.timestamp 
            : DateTime.now(),
      );
      
      // Clear session data
      _clearSession();
      
      _isRunning = false;
      _log('info', 'Session stopped: $_activeSessionId');
      
      return results;
    } catch (e) {
      _log('error', 'Failed to stop session: $e');
      throw SessionError('Failed to stop session: $e');
    }
  }

  /// Handle incoming wearable metrics
  void _handleWearMetrics(WearMetrics metrics) {
    // Extract HR and HRV
    final hr = metrics.getMetric(MetricType.hr)?.toDouble();
    final hrvSdnn = metrics.getMetric(MetricType.hrvSdnn)?.toDouble();
    final motion = metrics.metrics['motion']?.toDouble() ?? 0.0;
    
    if (hr != null && hrvSdnn != null) {
      // Push to emotion engine
      _emotionEngine.push(
        hr: hr,
        rrIntervalsMs: _convertHrvToRRIntervals(hr, hrvSdnn),
        timestamp: metrics.timestamp,
        motion: {'magnitude': motion},
      );
    }
  }

  /// Process emotion updates from the emotion engine
  void _processEmotionUpdates() {
    final emotionResults = _emotionEngine.consumeReady();
    
    if (emotionResults.isEmpty) return;
    
    // Get latest emotion result
    final latestEmotion = emotionResults.last;
    _sessionEmotions.add(latestEmotion);
    
    // Emit emotion stream
    _emotionStreamController.add(latestEmotion);
    
    // Get current physiological data for SWIP computation
    try {
      final lastMetrics = await _wear.readMetrics();
      final hr = lastMetrics.getMetric(MetricType.hr)?.toDouble() ?? 0.0;
      final hrv = lastMetrics.getMetric(MetricType.hrvSdnn)?.toDouble() ?? 0.0;
      final motion = lastMetrics.metrics['motion']?.toDouble() ?? 0.0;
      
      // Compute SWIP score
      final swipResult = _swipEngine.computeScore(
        hr: hr,
        hrv: hrv,
        motion: motion,
        emotionProbabilities: latestEmotion.probabilities,
      );
      
      // Store and emit score
      _sessionScores.add(swipResult);
      _scoreStreamController.add(swipResult);
      
      _log('debug', 'SWIP Score: ${swipResult.swipScore.toStringAsFixed(1)}');
    } catch (e) {
      _log('warn', 'Failed to read metrics: $e');
    }
  }

  /// Convert HR and HRV_SDNN to RR intervals (simplified)
  List<double> _convertHrvToRRIntervals(double hr, double hrvSdnn) {
    // Simplified conversion: assume normal distribution around mean RR
    final meanRR = (60000 / hr); // Mean RR in ms
    final numIntervals = 60; // ~1 minute of data
    
    final intervals = <double>[];
    for (int i = 0; i < numIntervals; i++) {
      // Generate sample RR interval with SDNN-like variation
      final sample = meanRR + (hrvSdnn * (i % 2 == 0 ? 1 : -1) * 0.5);
      intervals.add(sample.clamp(200.0, 2000.0));
    }
    
    return intervals;
  }

  /// Stream of SWIP scores (emits ~1 Hz)
  Stream<SwipScoreResult> get scoreStream => _scoreStreamController.stream;

  /// Stream of emotion results
  Stream<EmotionResult> get emotionStream => _emotionStreamController.stream;

  /// Get current SWIP score
  SwipScoreResult? getCurrentScore() {
    return _sessionScores.isNotEmpty ? _sessionScores.last : null;
  }

  /// Get current emotion
  EmotionResult? getCurrentEmotion() {
    return _sessionEmotions.isNotEmpty ? _sessionEmotions.last : null;
  }

  /// Clear session data
  void _clearSession() {
    _sessionScores.clear();
    _sessionEmotions.clear();
    _activeSessionId = null;
    _emotionEngine.clear();
  }

  /// Dispose resources
  void dispose() {
    _wearSubscription?.cancel();
    _emotionProcessor?.cancel();
    _scoreStreamController.close();
    _emotionStreamController.close();
    _wear.dispose();
  }

  /// Log message
  void _log(String level, String message) {
    if (config.enableLogging) {
      print('[SWIP SDK] [$level] $message');
    }
  }
}

/// Configuration for SWIP SDK
class SwipSdkConfig {
  final SwipConfig swipConfig;
  final EmotionConfig emotionConfig;
  final bool enableLogging;
  final bool enableLocalStorage;
  final String? localStoragePath;

  const SwipSdkConfig({
    SwipConfig? swipConfig,
    EmotionConfig? emotionConfig,
    this.enableLogging = true,
    this.enableLocalStorage = true,
    this.localStoragePath,
  }) : swipConfig = swipConfig ?? const SwipConfig(),
       emotionConfig = emotionConfig ?? EmotionConfig.defaultConfig;
}

