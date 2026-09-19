/// Sealed class hierarchy for application failures.
sealed class AppFailure {
  const AppFailure({required this.message, this.cause});

  final String message;
  final Object? cause;

  String get failureType;

  @override
  String toString() => '$failureType: $message';
}

/// Failure communicating with the native platform bridge.
final class BridgeFailure extends AppFailure {
  const BridgeFailure(String message, [Object? cause])
      : super(message: message, cause: cause);

  @override
  String get failureType => 'BridgeFailure';
}

/// Failure accessing local storage (Drift / secure storage).
final class StorageFailure extends AppFailure {
  const StorageFailure(String message, [Object? cause])
      : super(message: message, cause: cause);

  @override
  String get failureType => 'StorageFailure';
}

/// Failure relating to authentication.
final class AuthFailure extends AppFailure {
  const AuthFailure(String message, [Object? cause])
      : super(message: message, cause: cause);

  @override
  String get failureType => 'AuthFailure';
}

/// Network failure during sync or backend calls.
final class NetworkFailure extends AppFailure {
  const NetworkFailure(String message, [Object? cause])
      : super(message: message, cause: cause);

  @override
  String get failureType => 'NetworkFailure';
}

/// Validation failure for rules/configuration.
final class ValidationFailure extends AppFailure {
  const ValidationFailure(String message, [Object? cause])
      : super(message: message, cause: cause);

  @override
  String get failureType => 'ValidationFailure';
}

/// Unexpected or unhandled runtime failure.
final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure(String message, [Object? cause])
      : super(message: message, cause: cause);

  @override
  String get failureType => 'UnexpectedFailure';
}
