import '../../library/domain/match_record.dart';
import 'export_settings.dart';
import 'match_edit.dart';
import 'rally.dart';

/// Raised when a review action cannot be applied.
///
/// The message is written to be shown to the user, and the caller can rely on
/// nothing having changed when one is thrown.
class MatchEditingException implements Exception {
  /// Create the exception.
  MatchEditingException(this.message, {this.cause});

  /// Human-readable reason.
  final String message;

  /// Underlying error, when there was one.
  final Object? cause;

  @override
  String toString() => 'MatchEditingException: $message';
}

/// The review operations the screens need.
///
/// The screens depend on this rather than on the SQLite-backed store, so a
/// widget test can drive a session without a database.
abstract interface class MatchEditing {
  /// Load everything a review session shows for a match.
  Future<MatchEdit> load(MatchRecord match);

  /// Mark a span of the recording as a rally.
  Future<void> addRally(
    MatchRecord match, {
    required double startSeconds,
    required double endSeconds,
  });

  /// Move a rally's start or end.
  Future<void> moveRally(
    MatchRecord match, {
    required String rallyId,
    required double startSeconds,
    required double endSeconds,
  });

  /// Confirm which side won a rally, or clear the winner when [side] is null.
  Future<void> setWinner(
    MatchRecord match, {
    required String rallyId,
    required WinnerSide? side,
  });

  /// Remove a rally. Clips made from it stay in the reel, detached from it.
  Future<void> removeRally(MatchRecord match, {required String rallyId});

  /// Put a rally in the reel, or take it out.
  Future<void> keepClip(
    MatchRecord match, {
    required Rally rally,
    required bool kept,
  });

  /// Pull a clip's boundaries inward, without moving the rally's own.
  Future<void> trimClip(
    MatchRecord match, {
    required String clipId,
    double? startSeconds,
    double? endSeconds,
  });

  /// Write the reel's order.
  Future<void> reorderClips(MatchRecord match, List<String> clipIds);

  /// Store the choices that shape the export.
  Future<void> saveExportSettings(ExportSettings settings);
}
