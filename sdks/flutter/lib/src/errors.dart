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


