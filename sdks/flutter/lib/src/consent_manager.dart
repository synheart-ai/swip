import 'data_types.dart';

/// Consent management for SWIP SDK
/// 
/// Implements privacy-first design with explicit consent gates
/// for all data sharing operations.
class ConsentManager {
  ConsentLevel _currentLevel = ConsentLevel.onDevice;
  final Map<ConsentLevel, DateTime> _grantHistory = {};
  final Map<ConsentLevel, String> _grantReasons = {};

  /// Current consent level
  ConsentLevel get currentLevel => _currentLevel;

  /// Check if a specific action is allowed
  bool canPerformAction(ConsentLevel required) {
    return _currentLevel.allows(required);
  }

  /// Request consent for a specific level
  /// 
  /// This should show UI to the user explaining what data will be shared.
  /// Returns true if user grants consent, false otherwise.
  Future<bool> requestConsent({
    required ConsentLevel requested,
    required ConsentContext context,
    String? customMessage,
  }) async {
    // If we already have sufficient consent, return true
    if (_currentLevel.allows(requested)) {
      return true;
    }

    // Show consent UI (this would be implemented by the app)
    final granted = await _showConsentDialog(
      requested: requested,
      context: context,
      customMessage: customMessage,
    );

    if (granted) {
      await grantConsent(requested, reason: context.reason);
    }

    return granted;
  }

  /// Grant consent for a specific level
  Future<void> grantConsent(
    ConsentLevel level, {
    required String reason,
  }) async {
    _currentLevel = level;
    _grantHistory[level] = DateTime.now().toUtc();
    _grantReasons[level] = reason;
    
    // Persist consent (implement storage)
    await _persistConsent();
  }

  /// Revoke consent (downgrade to onDevice)
  Future<void> revokeConsent() async {
    _currentLevel = ConsentLevel.onDevice;
    await _persistConsent();
  }

  /// Purge all user data (GDPR compliance)
  Future<void> purgeAllData() async {
    // This would trigger deletion of all stored data
    // Implementation depends on storage layer
    await _purgeAllStoredData();
    
    // Reset consent
    _currentLevel = ConsentLevel.onDevice;
    _grantHistory.clear();
    _grantReasons.clear();
    await _persistConsent();
  }

  /// Get consent history for audit trail
  Map<ConsentLevel, ConsentRecord> getConsentHistory() {
    final history = <ConsentLevel, ConsentRecord>{};
    
    for (final level in ConsentLevel.values) {
      if (_grantHistory.containsKey(level)) {
        history[level] = ConsentRecord(
          level: level,
          grantedAt: _grantHistory[level]!,
          reason: _grantReasons[level] ?? 'Unknown',
        );
      }
    }
    
    return history;
  }

  /// Check if consent is still valid (not expired)
  bool isConsentValid(ConsentLevel level) {
    if (!_grantHistory.containsKey(level)) return false;
    
    final grantedAt = _grantHistory[level]!;
    final now = DateTime.now().toUtc();
    
    // Consent expires after 1 year
    final expirationDate = grantedAt.add(const Duration(days: 365));
    return now.isBefore(expirationDate);
  }

  /// Get consent status for all levels
  Map<ConsentLevel, ConsentStatus> getConsentStatus() {
    final status = <ConsentLevel, ConsentStatus>{};
    
    for (final level in ConsentLevel.values) {
      if (level.level <= _currentLevel.level) {
        status[level] = ConsentStatus.granted;
      } else {
        status[level] = ConsentStatus.denied;
      }
    }
    
    return status;
  }

  /// Show consent dialog (to be implemented by app)
  Future<bool> _showConsentDialog({
    required ConsentLevel requested,
    required ConsentContext context,
    String? customMessage,
  }) async {
    // This is a placeholder - the actual implementation would show
    // a proper consent dialog to the user
    
    final message = customMessage ?? _getDefaultConsentMessage(requested, context);
    
    // For now, return false (deny consent)
    // In a real implementation, this would show UI and return user's choice
    print('Consent requested: $message');
    return false;
  }

  /// Get default consent message
  String _getDefaultConsentMessage(ConsentLevel requested, ConsentContext context) {
    switch (requested) {
      case ConsentLevel.onDevice:
        return 'SWIP will process your data locally on your device. No data will be shared.';
      case ConsentLevel.localExport:
        return 'You can export your SWIP data locally. No automatic sharing will occur.';
      case ConsentLevel.dashboardShare:
        return 'Aggregated SWIP data may be shared with the SWIP Dashboard for research. Raw biosignals will never be transmitted.';
    }
  }

  /// Persist consent to storage
  Future<void> _persistConsent() async {
    // Implementation would save to secure storage
    // For now, just log
    print('Consent persisted: $_currentLevel');
  }

  /// Purge all stored data
  Future<void> _purgeAllStoredData() async {
    // Implementation would delete all user data
    print('All user data purged');
  }
}

/// Context for consent requests
class ConsentContext {
  final String appId;
  final String reason;
  final Map<String, dynamic>? metadata;

  const ConsentContext({
    required this.appId,
    required this.reason,
    this.metadata,
  });
}

/// Consent record for audit trail
class ConsentRecord {
  final ConsentLevel level;
  final DateTime grantedAt;
  final String reason;

  const ConsentRecord({
    required this.level,
    required this.grantedAt,
    required this.reason,
  });

  Map<String, dynamic> toJson() {
    return {
      'level': level.level,
      'level_name': level.name,
      'granted_at': grantedAt.toIso8601String(),
      'reason': reason,
    };
  }

  factory ConsentRecord.fromJson(Map<String, dynamic> json) {
    return ConsentRecord(
      level: ConsentLevel.values.firstWhere(
        (l) => l.level == json['level'],
      ),
      grantedAt: DateTime.parse(json['granted_at']),
      reason: json['reason'],
    );
  }
}

/// Consent status
enum ConsentStatus {
  granted,
  denied,
  expired,
}

/// Consent validation utilities
class ConsentValidator {
  /// Validate that required consent is present for an operation
  static void validateConsent({
    required ConsentLevel required,
    required ConsentLevel current,
    String? operation,
  }) {
    if (!current.allows(required)) {
      throw SwipConsentError(
        'Operation "${operation ?? 'unknown'}" requires consent level $required, '
        'but current level is $current',
        requiredLevel: required,
        currentLevel: current,
      );
    }
  }

  /// Check if consent is valid for a specific operation
  static bool isValidForOperation({
    required ConsentLevel required,
    required ConsentLevel current,
  }) {
    return current.allows(required);
  }
}

/// Consent-related error
class SwipConsentError implements Exception {
  final String message;
  final ConsentLevel requiredLevel;
  final ConsentLevel currentLevel;

  SwipConsentError(
    this.message, {
    required this.requiredLevel,
    required this.currentLevel,
  });

  @override
  String toString() {
    return 'SwipConsentError: $message';
  }
}