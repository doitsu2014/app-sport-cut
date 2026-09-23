import '../domain/match_record.dart';

/// One row of the match library.
///
/// Availability is resolved when the list is built rather than while each row
/// renders, so a recording that has gone missing costs one stat for the whole
/// list instead of one per rebuild.
class MatchListEntry {
  /// Pair a stored match with what is known about its recording.
  const MatchListEntry({
    required this.match,
    required this.recordingAvailable,
    this.score,
  });

  /// The stored match.
  final MatchRecord match;

  /// Whether the match's stored recording can still be read.
  final bool recordingAvailable;

  /// Score reached by the confirmed rallies, or `null` when none are confirmed.
  final ({int left, int right})? score;
}
