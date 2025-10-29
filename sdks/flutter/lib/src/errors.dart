class SWIPError implements Exception {
  final String code;
  final String message;

  const SWIPError(this.code, this.message);

  @override
  String toString() => 'SWIPError(code: $code, message: $message)';
}

class PermissionDeniedError extends SWIPError {
  PermissionDeniedError([String msg = 'Health permissions denied'])
      : super('E_PERMISSION_DENIED', msg);
}

class InvalidConfigurationError extends SWIPError {
  InvalidConfigurationError([String msg = 'Invalid configuration'])
      : super('E_INVALID_CONFIG', msg);
}

class SessionNotFoundError extends SWIPError {
  SessionNotFoundError([String msg = 'No active session'])
      : super('E_SESSION_NOT_FOUND', msg);
}

class DataQualityError extends SWIPError {
  DataQualityError([String msg = 'Low quality signal'])
      : super('E_SIGNAL_LOW_QUALITY', msg);
}

class InitializationError extends SWIPError {
  InitializationError([String msg = 'Failed to initialize SDK'])
      : super('E_INITIALIZATION_FAILED', msg);
}

class SessionError extends SWIPError {
  SessionError([String msg = 'Session error'])
      : super('E_SESSION_ERROR', msg);
}

class SensorError extends SWIPError {
  SensorError([String msg = 'Sensor error'])
      : super('E_SENSOR_ERROR', msg);
}

class ModelError extends SWIPError {
  ModelError([String msg = 'ML model error'])
      : super('E_MODEL_ERROR', msg);
}

class ConsentError extends SWIPError {
  ConsentError([String msg = 'Consent required'])
      : super('E_CONSENT_REQUIRED', msg);
}

class StorageError extends SWIPError {
  StorageError([String msg = 'Storage operation failed'])
      : super('E_STORAGE_ERROR', msg);
}
