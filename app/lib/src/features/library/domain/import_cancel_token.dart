/// Cooperative cancellation for one running import.
///
/// The import copies a recording in chunks, so it can only stop where it looks
/// for a request to stop. The screen owns a token, the copy loop checks it
/// between chunks, and the copy cleans up after itself when it sees one — a
/// cancelled import therefore leaves no catalog record and no partial file.
class ImportCancelToken {
  bool _cancelled = false;

  /// Whether the owner has asked the running import to stop.
  bool get isCancelled => _cancelled;

  /// Ask the running import to stop at its next checkpoint.
  void cancel() => _cancelled = true;
}
