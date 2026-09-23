/// Raised when a reel cannot be prepared or rendered.
///
/// The message is written to be shown to the user, and the caller can rely on
/// the previous export being untouched when one is thrown.
class ExportException implements Exception {
  /// Create the exception.
  ExportException(this.message, {this.cause});

  /// Human-readable reason.
  final String message;

  /// Underlying error, when there was one.
  final Object? cause;

  @override
  String toString() => 'ExportException: $message';
}
