import 'rally.dart';

/// One change to the score, recorded against the rally that caused it.
///
/// Events are derived from the confirmed winners in rally order rather than
/// written as the user taps, so correcting an early rally rewrites everything
/// after it and the timeline can never drift from the rallies it describes.
class ScoreEvent {
  /// Create a score event.
  const ScoreEvent({
    required this.id,
    required this.matchId,
    required this.rallyId,
    required this.timestampSeconds,
    required this.winnerSide,
    required this.leftScore,
    required this.rightScore,
  });

  /// Stable identifier.
  final String id;

  /// Match this event belongs to.
  final String matchId;

  /// Rally that produced the point.
  final String rallyId;

  /// Position of the rally in the recording, in seconds.
  final double timestampSeconds;

  /// Side that won the rally.
  final WinnerSide winnerSide;

  /// Left-hand score after this event.
  final int leftScore;

  /// Right-hand score after this event.
  final int rightScore;
}
