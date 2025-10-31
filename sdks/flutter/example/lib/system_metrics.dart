import 'dart:io';
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:battery_plus/battery_plus.dart';

/// Helper class to collect system metrics for logging
class SystemMetrics {
  static PackageInfo? _packageInfo;
  static DeviceInfoPlugin? _deviceInfo;
  static Battery? _battery;
  static String? _cachedDeviceIdHash;
  static String? _cachedAppVersion;

  /// Initialize system metrics collection
  static Future<void> init() async {
    _packageInfo = await PackageInfo.fromPlatform();
    _deviceInfo = DeviceInfoPlugin();
    _battery = Battery();
  }

  /// Get app version
  static Future<String?> getAppVersion() async {
    if (_cachedAppVersion != null) return _cachedAppVersion;
    if (_packageInfo == null) await init();
    _cachedAppVersion = _packageInfo?.version;
    return _cachedAppVersion;
  }

  /// Get device ID hash (privacy-friendly)
  static Future<String?> getDeviceIdHash() async {
    if (_cachedDeviceIdHash != null) return _cachedDeviceIdHash;
    if (_deviceInfo == null) await init();
    if (_deviceInfo == null) return null;

    try {
      String identifier;
      if (Platform.isIOS) {
        final iosInfo = await _deviceInfo!.iosInfo;
        identifier = iosInfo.identifierForVendor ??
            (iosInfo.name.isNotEmpty ? iosInfo.name : iosInfo.model);
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo!.androidInfo;
        identifier = androidInfo.id;
      } else {
        identifier = 'unknown';
      }

      // Hash the identifier for privacy
      _cachedDeviceIdHash = _hashString(identifier);
      return _cachedDeviceIdHash;
    } catch (e) {
      return null;
    }
  }

  /// Get battery level (0.0 to 1.0)
  static Future<double?> getBatteryLevel() async {
    if (_battery == null) await init();
    try {
      final level = await _battery!.batteryLevel;
      return level / 100.0;
    } catch (e) {
      return null;
    }
  }

  /// Get charging status
  static Future<bool?> getIsCharging() async {
    if (_battery == null) await init();
    try {
      final status = await _battery!.batteryState;
      return status == BatteryState.charging || status == BatteryState.full;
    } catch (e) {
      return null;
    }
  }

  /// Get memory heap size in MB (iOS only via platform channel, approximate for now)
  static Future<double?> getMemoryHeapMb() async {
    // Note: Accurate memory tracking requires platform-specific code
    // For now, we'll return null and implement platform channels if needed
    // On iOS, you'd need to use ProcessInfo.processInfo.physicalMemory
    // and track allocations, which is complex. This is a placeholder.
    try {
      // Approximate using Dart's process memory (not available directly)
      // TODO: Implement platform channel for accurate memory tracking
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get CPU usage percentage (requires platform channel)
  static Future<double?> getCpuPercent() async {
    // Note: CPU usage tracking requires platform-specific code
    // This would need a platform channel implementation
    // TODO: Implement platform channel for CPU tracking
    return null;
  }

  /// Estimate energy usage in microjoules based on inference latency
  /// This is a rough estimate: ~50mW base + latency-dependent component
  static double? estimateEnergyUj(int latencyMs) {
    // Rough model: ~50mW base power + 100mW during inference per 10ms
    // Convert to microjoules: 1 mW * 1 ms = 1 uJ
    const basePowerMw = 50.0; // Base power consumption
    const inferencePowerMw = 100.0; // Additional during inference
    const baseTimeMs = 1.0; // 1ms base

    final baseEnergyUj = basePowerMw * baseTimeMs;
    final inferenceEnergyUj = inferencePowerMw * (latencyMs / 10.0);

    return baseEnergyUj + inferenceEnergyUj;
  }

  /// Simple string hash for device ID privacy
  static String _hashString(String input) {
    final bytes = utf8.encode(input);
    int hash = 0;
    for (final byte in bytes) {
      hash = ((hash << 5) - hash) + byte;
      hash = hash & hash; // Convert to 32-bit integer
    }
    // Convert to hex string
    return hash.abs().toRadixString(16).padLeft(8, '0');
  }

  /// Get all metrics at once
  static Future<Map<String, Object?>> getAllMetrics({
    int? inferenceLatencyMs,
  }) async {
    final batteryLevel = await getBatteryLevel();
    final isCharging = await getIsCharging();
    final appVersion = await getAppVersion();
    final deviceIdHash = await getDeviceIdHash();
    final memoryHeapMb = await getMemoryHeapMb();
    final cpuPercent = await getCpuPercent();

    return {
      'memory_heap_mb': memoryHeapMb,
      'cpu_percent': cpuPercent,
      'energy_estimate_uj': inferenceLatencyMs != null
          ? estimateEnergyUj(inferenceLatencyMs)
          : null,
      'battery_level': batteryLevel,
      'is_charging': isCharging,
      'app_version': appVersion,
      'device_id_hash': deviceIdHash,
    };
  }
}
