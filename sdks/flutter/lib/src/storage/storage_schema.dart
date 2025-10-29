/// Storage schema for SWIP SDK
/// 
/// Defines the local SQLite database schema for storing sessions,
/// scores, and aggregated data per RFC specification.

/// Storage schema definition
class SwipStorageSchema {
  /// Create all tables
  static List<String> get createTables => [
    createSessionsTable,
    createSamplesRawTable,
    createScoresTable,
    createDailyAggTable,
    createMonthlyAggTable,
    createConsentHistoryTable,
  ];

  /// Sessions table
  static const String createSessionsTable = '''
    CREATE TABLE IF NOT EXISTS sessions (
      session_id TEXT PRIMARY KEY,
      app_id TEXT NOT NULL,
      start_time INTEGER NOT NULL,
      end_time INTEGER,
      duration_seconds INTEGER,
      consent_level INTEGER NOT NULL DEFAULT 0,
      metadata TEXT,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
    );
  ''';

  /// Raw biosignal samples table
  static const String createSamplesRawTable = '''
    CREATE TABLE IF NOT EXISTS samples_raw (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      session_id TEXT NOT NULL,
      ts_ms INTEGER NOT NULL,
      hr_bpm REAL,
      hrv_sdnn_ms REAL,
      hrv_rmssd_ms REAL,
      motion_mag REAL,
      quality_flags INTEGER DEFAULT 0,
      artifact_flags INTEGER DEFAULT 0,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
      FOREIGN KEY (session_id) REFERENCES sessions(session_id) ON DELETE CASCADE
    );
  ''';

  /// SWIP scores table
  static const String createScoresTable = '''
    CREATE TABLE IF NOT EXISTS scores (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      session_id TEXT NOT NULL,
      ts_ms INTEGER NOT NULL,
      swip_score REAL NOT NULL,
      phys_subscore REAL,
      emo_subscore REAL,
      confidence REAL,
      dominant_emotion TEXT,
      emotion_probs TEXT,
      reasons TEXT,
      artifact_flag INTEGER DEFAULT 0,
      model_id TEXT,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
      FOREIGN KEY (session_id) REFERENCES sessions(session_id) ON DELETE CASCADE
    );
  ''';

  /// Daily aggregates table
  static const String createDailyAggTable = '''
    CREATE TABLE IF NOT EXISTS daily_agg (
      ymd TEXT PRIMARY KEY,
      mean_score REAL,
      p50_score REAL,
      p90_score REAL,
      active_minutes INTEGER,
      calm_duration INTEGER,
      stress_duration INTEGER,
      session_count INTEGER,
      total_samples INTEGER,
      quality_score REAL,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
    );
  ''';

  /// Monthly aggregates table
  static const String createMonthlyAggTable = '''
    CREATE TABLE IF NOT EXISTS monthly_agg (
      ym TEXT PRIMARY KEY,
      mean_score REAL,
      p50_score REAL,
      p90_score REAL,
      total_active_minutes INTEGER,
      total_sessions INTEGER,
      calm_percentage REAL,
      stress_percentage REAL,
      trend_score REAL,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
    );
  ''';

  /// Consent history table
  static const String createConsentHistoryTable = '''
    CREATE TABLE IF NOT EXISTS consent_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      consent_level INTEGER NOT NULL,
      action TEXT NOT NULL,
      granted_at INTEGER NOT NULL,
      reason TEXT,
      app_id TEXT,
      metadata TEXT,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
    );
  ''';

  /// Indexes for performance
  static List<String> get createIndexes => [
    'CREATE INDEX IF NOT EXISTS idx_sessions_app_id ON sessions(app_id);',
    'CREATE INDEX IF NOT EXISTS idx_sessions_start_time ON sessions(start_time);',
    'CREATE INDEX IF NOT EXISTS idx_samples_session_id ON samples_raw(session_id);',
    'CREATE INDEX IF NOT EXISTS idx_samples_ts ON samples_raw(ts_ms);',
    'CREATE INDEX IF NOT EXISTS idx_scores_session_id ON scores(session_id);',
    'CREATE INDEX IF NOT EXISTS idx_scores_ts ON scores(ts_ms);',
    'CREATE INDEX IF NOT EXISTS idx_daily_agg_ymd ON daily_agg(ymd);',
    'CREATE INDEX IF NOT EXISTS idx_monthly_agg_ym ON monthly_agg(ym);',
    'CREATE INDEX IF NOT EXISTS idx_consent_level ON consent_history(consent_level);',
    'CREATE INDEX IF NOT EXISTS idx_consent_granted_at ON consent_history(granted_at);',
  ];

  /// Triggers for automatic cleanup
  static List<String> get createTriggers => [
    // Auto-delete raw samples older than 30 days
    '''
    CREATE TRIGGER IF NOT EXISTS cleanup_old_samples
    AFTER INSERT ON samples_raw
    BEGIN
      DELETE FROM samples_raw 
      WHERE created_at < (strftime('%s', 'now') - 2592000);
    END;
    ''',
    
    // Auto-update session duration when it ends
    '''
    CREATE TRIGGER IF NOT EXISTS update_session_duration
    AFTER UPDATE OF end_time ON sessions
    WHEN NEW.end_time IS NOT NULL AND OLD.end_time IS NULL
    BEGIN
      UPDATE sessions 
      SET duration_seconds = (NEW.end_time - NEW.start_time) / 1000
      WHERE session_id = NEW.session_id;
    END;
    ''',
  ];

  /// Data retention policies
  static const Map<String, Duration> retentionPolicies = {
    'samples_raw': Duration(days: 30),
    'scores': Duration(days: 90),
    'sessions': Duration(days: 365),
    'daily_agg': Duration(days: 1095), // 3 years
    'monthly_agg': Duration(days: 3650), // 10 years
    'consent_history': Duration(days: 2555), // 7 years
  };

  /// Get cleanup queries for old data
  static List<String> getCleanupQueries() {
    final queries = <String>[];
    final now = DateTime.now().millisecondsSinceEpoch;
    
    for (final entry in retentionPolicies.entries) {
      final tableName = entry.key;
      final retention = entry.value;
      final cutoffMs = now - retention.inMilliseconds;
      
      queries.add('''
        DELETE FROM $tableName 
        WHERE created_at < $cutoffMs;
      ''');
    }
    
    return queries;
  }

  /// Schema version for migrations
  static const int schemaVersion = 1;

  /// Get schema version query
  static const String getSchemaVersion = '''
    SELECT value FROM schema_info WHERE key = 'version';
  ''';

  /// Set schema version query
  static const String setSchemaVersion = '''
    INSERT OR REPLACE INTO schema_info (key, value) VALUES ('version', '$schemaVersion');
  ''';

  /// Schema info table
  static const String createSchemaInfoTable = '''
    CREATE TABLE IF NOT EXISTS schema_info (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );
  ''';

  /// Complete schema creation
  static List<String> get completeSchema => [
    createSchemaInfoTable,
    ...createTables,
    ...createIndexes,
    ...createTriggers,
    setSchemaVersion,
  ];

  /// Validate schema integrity
  static List<String> get validationQueries => [
    'PRAGMA integrity_check;',
    'PRAGMA foreign_key_check;',
  ];

  /// Get table statistics
  static Map<String, String> get tableStatsQueries => {
    'sessions': 'SELECT COUNT(*) as count FROM sessions;',
    'samples_raw': 'SELECT COUNT(*) as count FROM samples_raw;',
    'scores': 'SELECT COUNT(*) as count FROM scores;',
    'daily_agg': 'SELECT COUNT(*) as count FROM daily_agg;',
    'monthly_agg': 'SELECT COUNT(*) as count FROM monthly_agg;',
    'consent_history': 'SELECT COUNT(*) as count FROM consent_history;',
  };

  /// Export queries for data export
  static Map<String, String> get exportQueries => {
    'sessions': '''
      SELECT 
        session_id,
        app_id,
        start_time,
        end_time,
        duration_seconds,
        consent_level,
        metadata
      FROM sessions 
      WHERE start_time >= ? AND start_time <= ?
      ORDER BY start_time;
    ''',
    'scores': '''
      SELECT 
        s.session_id,
        s.app_id,
        sc.ts_ms,
        sc.swip_score,
        sc.phys_subscore,
        sc.emo_subscore,
        sc.confidence,
        sc.dominant_emotion,
        sc.emotion_probs,
        sc.reasons,
        sc.model_id
      FROM scores sc
      JOIN sessions s ON sc.session_id = s.session_id
      WHERE s.start_time >= ? AND s.start_time <= ?
      ORDER BY sc.ts_ms;
    ''',
    'daily_agg': '''
      SELECT 
        ymd,
        mean_score,
        p50_score,
        p90_score,
        active_minutes,
        calm_duration,
        stress_duration,
        session_count,
        quality_score
      FROM daily_agg 
      WHERE ymd >= ? AND ymd <= ?
      ORDER BY ymd;
    ''',
  };
}