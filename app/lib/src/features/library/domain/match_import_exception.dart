/// Why an import did not produce a match.
///
/// The kind exists so behavior that must differ never depends on parsing the
/// message: a cancellation is silent while a failure is reported, and the
/// picker's own failure is raised by a different layer than the copy's.
enum MatchImportKind {
  /// The user cancelled before the import completed.
  cancelled,

  /// The selected file is missing, or could not be opened.
  unreadable,

  /// The selected file could not be read as video.
  unsupported,

  /// The device had no room to store the app-owned copy.
  noSpace,

  /// The app-owned copy could not be written.
  storage,

  /// The match could not be written to the catalog.
  catalog,

  /// The platform picker failed instead of returning a file.
  pickerFailed,
}

/// Raised when a recording cannot be turned into a match.
///
/// The message is written to be shown to a user: it names the file and the
/// reason, and the caller can be sure that no partial catalog record was left
/// behind.
class MatchImportException implements Exception {
  /// Create the exception.
  MatchImportException(this.message, {required this.kind, this.cause});

  /// Human-readable reason.
  final String message;

  /// What went wrong, for callers that must behave differently.
  final MatchImportKind kind;

  /// Underlying error, when there was one.
  final Object? cause;

  @override
  String toString() => 'MatchImportException(${kind.name}): $message';
}
