/// Raised when a recording cannot be turned into a match.
///
/// The message is written to be shown to a user: it names the file and the
/// reason, and the caller can be sure that no partial catalog record was left
/// behind.
class MatchImportException implements Exception {
  /// Create the exception.
  MatchImportException(this.message, {this.cause});

  /// Human-readable reason.
  final String message;

  /// Underlying error, when there was one.
  final Object? cause;

  @override
  String toString() => 'MatchImportException: $message';
}
