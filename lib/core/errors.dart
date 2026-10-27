/// Failures the data layer reports to controllers. Never shown raw to users.
sealed class AppException implements Exception {
  const AppException(this.debugMessage);

  /// Developer-facing detail for logs.
  final String debugMessage;

  @override
  String toString() => '$runtimeType: $debugMessage';
}

/// Usage Access is off, so Android won't share network statistics.
final class UsageAccessDeniedException extends AppException {
  const UsageAccessDeniedException([super.debugMessage = 'usage access off']);
}

/// The Android side failed or is missing (for example in a unit test).
final class NativeCallException extends AppException {
  const NativeCallException(super.debugMessage);
}
