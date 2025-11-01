import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class LoggingDb {
  static Database? _db;
  static const _uuid = Uuid();

  static Future<void> init() async {
    if (_db != null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'swip_diagnostics.db');
    // ignore: avoid_print
    print('[SWIP][DB] Database path: $dbPath');
    final exists = await databaseFactory.databaseExists(dbPath);
    // ignore: avoid_print
    print('[SWIP][DB] Database exists before init: $exists');
    _db = await openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, version) async {
        // ignore: avoid_print
        print('[SWIP][DB] Creating tables (version $version)');
        await db.execute('''
          CREATE TABLE emotion_inference_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ts_utc TEXT NOT NULL,
            monotonic_ms INTEGER,
            model_id TEXT,
            backend TEXT,
            inference_latency_ms INTEGER,
            hr_mean REAL,
            rr_count INTEGER,
            buffer_duration_ms INTEGER,
            top_emotion TEXT,
            confidence REAL,
            probabilities_json TEXT,
            memory_heap_mb REAL,
            cpu_percent REAL,
            energy_estimate_uj REAL,
            battery_level REAL,
            is_charging INTEGER,
            app_version TEXT,
            device_id_hash TEXT
          );
        ''');
        // Create dim_App_biosignals table matching SWIP Data Schema
        await db.execute('''
          CREATE TABLE dim_App_biosignals (
            app_biosignal_id TEXT PRIMARY KEY,
            app_session_id TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            respiratory_rate REAL,
            hrv_sdnn REAL,
            heart_rate REAL,
            accelerometer REAL,
            temperature REAL,
            blood_oxygen_saturation REAL,
            ecg REAL,
            emg REAL,
            eda REAL,
            gyro REAL,
            ppg REAL,
            ibi REAL
          );
        ''');
        // Create index for faster session lookups
        await db.execute('''
          CREATE INDEX idx_biosignals_session ON dim_App_biosignals(app_session_id);
        ''');
        await db.execute('''
          CREATE INDEX idx_biosignals_timestamp ON dim_App_biosignals(timestamp);
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // ignore: avoid_print
        print(
            '[SWIP][DB] Upgrading database from version $oldVersion to $newVersion');
        if (oldVersion < 2) {
          // Migrate from version 1 to 2: Add dim_App_biosignals table
          await db.execute('''
            CREATE TABLE dim_App_biosignals (
              app_biosignal_id TEXT PRIMARY KEY,
              app_session_id TEXT NOT NULL,
              timestamp TEXT NOT NULL,
              respiratory_rate REAL,
              hrv_sdnn REAL,
              heart_rate REAL,
              accelerometer REAL,
              temperature REAL,
              blood_oxygen_saturation REAL,
              ecg REAL,
              emg REAL,
              eda REAL,
              gyro REAL,
              ppg REAL,
              ibi REAL
            );
          ''');
          await db.execute('''
            CREATE INDEX idx_biosignals_session ON dim_App_biosignals(app_session_id);
          ''');
          await db.execute('''
            CREATE INDEX idx_biosignals_timestamp ON dim_App_biosignals(timestamp);
          ''');
          // ignore: avoid_print
          print('[SWIP][DB] Created dim_App_biosignals table');
        }
      },
    );
    final existsAfter = await databaseFactory.databaseExists(dbPath);
    // ignore: avoid_print
    print('[SWIP][DB] Database exists after init: $existsAfter');
    final result = await _db!
        .rawQuery('SELECT COUNT(*) as count FROM emotion_inference_log');
    final count = result.isNotEmpty ? result.first['count'] as int? : 0;
    // ignore: avoid_print
    print('[SWIP][DB] Current row count: ${count ?? 0}');
  }

  static Future<void> insertEmotionLog({
    required String tsUtc,
    required int latencyMs,
    required Map<String, Object?> buffer,
    required Map<String, double> probabilities,
    required String topEmotion,
    required double confidence,
    Map<String, Object?>? model,
    double? hrMean,
    int? monotonicMs,
    double? memoryHeapMb,
    double? cpuPercent,
    double? energyEstimateUj,
    double? batteryLevel,
    bool? isCharging,
    String? appVersion,
    String? deviceIdHash,
  }) async {
    if (_db == null) return;
    final rrCount = (buffer['rr_count'] as int?) ?? 0;
    final durationMs = (buffer['duration_ms'] as int?) ?? 0;
    final id = await _db!.insert('emotion_inference_log', {
      'ts_utc': tsUtc,
      'monotonic_ms': monotonicMs,
      'model_id': model?['id'] as String?,
      'backend': model?['type'] as String?,
      'inference_latency_ms': latencyMs,
      'hr_mean': hrMean,
      'rr_count': rrCount,
      'buffer_duration_ms': durationMs,
      'top_emotion': topEmotion,
      'confidence': confidence,
      'probabilities_json': jsonEncode(probabilities),
      'memory_heap_mb': memoryHeapMb,
      'cpu_percent': cpuPercent,
      'energy_estimate_uj': energyEstimateUj,
      'battery_level': batteryLevel,
      'is_charging': isCharging == null ? null : (isCharging ? 1 : 0),
      'app_version': appVersion,
      'device_id_hash': deviceIdHash,
    });
    // ignore: avoid_print
    print(
        '[SWIP][DB] Inserted log row id=$id: emotion=$topEmotion latency=${latencyMs}ms rr_count=$rrCount');
  }

  /// Insert biosignal data into dim_App_biosignals (SWIP Data Schema)
  static Future<void> insertBiosignal({
    required String appSessionId,
    required DateTime timestamp,
    double? heartRate,
    double? hrvSdnn,
    double? respiratoryRate,
    double? accelerometer,
    double? temperature,
    double? bloodOxygenSaturation,
    double? ecg,
    double? emg,
    double? eda,
    double? gyro,
    double? ppg,
    double? ibi, // Inter-Beat Interval (RR interval in ms)
  }) async {
    if (_db == null) return;

    // Ensure table exists (safety check for migration issues)
    try {
      await _db!.rawQuery('SELECT 1 FROM dim_App_biosignals LIMIT 1');
    } catch (e) {
      // Table doesn't exist, try to create it
      // ignore: avoid_print
      print(
          '[SWIP][DB] dim_App_biosignals table missing, attempting to create...');
      try {
        await _db!.execute('''
          CREATE TABLE IF NOT EXISTS dim_App_biosignals (
            app_biosignal_id TEXT PRIMARY KEY,
            app_session_id TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            respiratory_rate REAL,
            hrv_sdnn REAL,
            heart_rate REAL,
            accelerometer REAL,
            temperature REAL,
            blood_oxygen_saturation REAL,
            ecg REAL,
            emg REAL,
            eda REAL,
            gyro REAL,
            ppg REAL,
            ibi REAL
          );
        ''');
        await _db!.execute('''
          CREATE INDEX IF NOT EXISTS idx_biosignals_session ON dim_App_biosignals(app_session_id);
        ''');
        await _db!.execute('''
          CREATE INDEX IF NOT EXISTS idx_biosignals_timestamp ON dim_App_biosignals(timestamp);
        ''');
        // ignore: avoid_print
        print('[SWIP][DB] Successfully created dim_App_biosignals table');
      } catch (createError) {
        // ignore: avoid_print
        print(
            '[SWIP][DB] Failed to create dim_App_biosignals table: $createError');
        return; // Skip insert if table creation fails
      }
    }

    final biosignalId = _uuid.v4();
    await _db!.insert('dim_App_biosignals', {
      'app_biosignal_id': biosignalId,
      'app_session_id': appSessionId,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'respiratory_rate': respiratoryRate,
      'hrv_sdnn': hrvSdnn,
      'heart_rate': heartRate,
      'accelerometer': accelerometer,
      'temperature': temperature,
      'blood_oxygen_saturation': bloodOxygenSaturation,
      'ecg': ecg,
      'emg': emg,
      'eda': eda,
      'gyro': gyro,
      'ppg': ppg,
      'ibi': ibi,
    });
    // ignore: avoid_print
    print(
        '[SWIP][DB] Inserted biosignal id=$biosignalId: hr=$heartRate hrv_sdnn=$hrvSdnn ibi=$ibi');
  }

  /// Get database path for export
  static Future<String?> getDatabasePath() async {
    if (_db == null) return null;
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, 'swip_diagnostics.db');
  }

  /// Export all data to JSON format
  /// Returns the path to the exported JSON file
  static Future<String?> exportToJson() async {
    if (_db == null) return null;

    try {
      // Query both tables
      final emotionLogs =
          await _db!.query('emotion_inference_log', orderBy: 'ts_utc ASC');
      final biosignals =
          await _db!.query('dim_App_biosignals', orderBy: 'timestamp ASC');

      // Get table counts
      final emotionCount = await _db!
          .rawQuery('SELECT COUNT(*) as count FROM emotion_inference_log');
      final biosignalCount = await _db!
          .rawQuery('SELECT COUNT(*) as count FROM dim_App_biosignals');

      // Build export structure
      final exportData = {
        'export_metadata': {
          'exported_at': DateTime.now().toUtc().toIso8601String(),
          'version': '1.0',
          'schema_version': '2',
        },
        'table_counts': {
          'emotion_inference_log': emotionCount.first['count'] as int? ?? 0,
          'dim_App_biosignals': biosignalCount.first['count'] as int? ?? 0,
        },
        'data': {
          'emotion_inference_log': emotionLogs.map((row) {
            // Parse probabilities_json if present
            final probsJson = row['probabilities_json'] as String?;
            final probs = probsJson != null
                ? jsonDecode(probsJson) as Map<String, dynamic>?
                : null;
            return {
              ...row,
              'probabilities': probs,
            };
          }).toList(),
          'dim_App_biosignals': biosignals,
        },
      };

      // Write to file
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now()
          .toUtc()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')[0];
      final exportPath = p.join(dir.path, 'swip_export_$timestamp.json');
      final file = File(exportPath);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(exportData),
      );

      // ignore: avoid_print
      print('[SWIP][DB] Exported data to: $exportPath');
      return exportPath;
    } catch (e) {
      // ignore: avoid_print
      print('[SWIP][DB] Export failed: $e');
      return null;
    }
  }

  /// Export to CSV format (simpler for spreadsheet tools)
  /// Returns the path to the exported CSV file
  static Future<String?> exportToCsv() async {
    if (_db == null) return null;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now()
          .toUtc()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')[0];
      final exportPath = p.join(dir.path, 'swip_export_$timestamp.csv');
      final file = File(exportPath);
      final sink = file.openWrite();

      // Export emotion_inference_log
      final emotionLogs =
          await _db!.query('emotion_inference_log', orderBy: 'ts_utc ASC');
      if (emotionLogs.isNotEmpty) {
        sink.writeln('# emotion_inference_log');
        // Write headers
        final headers = emotionLogs.first.keys.toList();
        sink.writeln(headers.join(','));
        // Write rows
        for (final row in emotionLogs) {
          final values = headers.map((h) {
            final val = row[h];
            if (val == null) return '';
            // Escape commas and quotes in CSV
            final str = val.toString();
            if (str.contains(',') || str.contains('"') || str.contains('\n')) {
              return '"${str.replaceAll('"', '""')}"';
            }
            return str;
          }).toList();
          sink.writeln(values.join(','));
        }
        sink.writeln(); // Empty line between tables
      }

      // Export dim_App_biosignals
      final biosignals =
          await _db!.query('dim_App_biosignals', orderBy: 'timestamp ASC');
      if (biosignals.isNotEmpty) {
        sink.writeln('# dim_App_biosignals');
        // Write headers
        final headers = biosignals.first.keys.toList();
        sink.writeln(headers.join(','));
        // Write rows
        for (final row in biosignals) {
          final values = headers.map((h) {
            final val = row[h];
            if (val == null) return '';
            // Escape commas and quotes in CSV
            final str = val.toString();
            if (str.contains(',') || str.contains('"') || str.contains('\n')) {
              return '"${str.replaceAll('"', '""')}"';
            }
            return str;
          }).toList();
          sink.writeln(values.join(','));
        }
      }

      await sink.close();
      // ignore: avoid_print
      print('[SWIP][DB] Exported CSV to: $exportPath');
      return exportPath;
    } catch (e) {
      // ignore: avoid_print
      print('[SWIP][DB] CSV export failed: $e');
      return null;
    }
  }

  /// Get statistics about the database
  static Future<Map<String, dynamic>> getStats() async {
    if (_db == null) {
      return {'error': 'Database not initialized'};
    }

    try {
      final emotionCount = await _db!
          .rawQuery('SELECT COUNT(*) as count FROM emotion_inference_log');
      final biosignalCount = await _db!
          .rawQuery('SELECT COUNT(*) as count FROM dim_App_biosignals');

      final oldestEmotion = await _db!
          .rawQuery('SELECT MIN(ts_utc) as oldest FROM emotion_inference_log');
      final newestEmotion = await _db!
          .rawQuery('SELECT MAX(ts_utc) as newest FROM emotion_inference_log');

      final oldestBiosignal = await _db!
          .rawQuery('SELECT MIN(timestamp) as oldest FROM dim_App_biosignals');
      final newestBiosignal = await _db!
          .rawQuery('SELECT MAX(timestamp) as newest FROM dim_App_biosignals');

      return {
        'emotion_inference_log': {
          'count': emotionCount.first['count'] as int? ?? 0,
          'oldest': oldestEmotion.first['oldest'] as String?,
          'newest': newestEmotion.first['newest'] as String?,
        },
        'dim_App_biosignals': {
          'count': biosignalCount.first['count'] as int? ?? 0,
          'oldest': oldestBiosignal.first['oldest'] as String?,
          'newest': newestBiosignal.first['newest'] as String?,
        },
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
