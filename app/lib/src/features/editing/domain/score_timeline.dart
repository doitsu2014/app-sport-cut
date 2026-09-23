import 'rally.dart';
import 'score_event.dart';

/// The running score, derived from the confirmed winners in rally order.
///
/// The score is never written by hand: it is computed from the rallies every
/// time one changes, which is what makes correcting an early rally rewrite
/// everything after it and keeps the timeline from drifting from the rallies it
/// describes.
class ScoreTimeline {
  const ScoreTimeline._({
    required this.matchId,
    required this.events,
    required Map<String, ScoreEvent> byRallyId,
    required this.left,
    required this.right,
  }) : _byRallyId = byRallyId;

  /// Build the timeline for a match from its rallies, in any order.
  factory ScoreTimeline.fromRallies(String matchId, List<Rally> rallies) {
    final ordered = List<Rally>.from(rallies)
      ..sort((a, b) => a.startSeconds.compareTo(b.startSeconds));

    var left = 0;
    var right = 0;
    final events = <ScoreEvent>[];
    final byRallyId = <String, ScoreEvent>{};

    for (final rally in ordered) {
      final side = rally.winnerSide;
      if (rally.status != RallyStatus.confirmed || side == null) {
        continue;
      }
      if (side == WinnerSide.left) {
        left += 1;
      } else {
        right += 1;
      }

      // The identifier is derived from the rally, so re-deriving the timeline
      // produces the same events rather than a growing set of duplicates.
      final event = ScoreEvent(
        id: 'score-${rally.id}',
        matchId: matchId,
        rallyId: rally.id,
        timestampSeconds: rally.startSeconds,
        winnerSide: side,
        leftScore: left,
        rightScore: right,
      );
      events.add(event);
      byRallyId[rally.id] = event;
    }

    return ScoreTimeline._(
      matchId: matchId,
      events: events,
      byRallyId: byRallyId,
      left: left,
      right: right,
    );
  }

  /// Match the timeline describes.
  final String matchId;

  /// One event per confirmed rally, oldest first.
  final List<ScoreEvent> events;

  /// Points won by the left-hand side.
  final int left;

  /// Points won by the right-hand side.
  final int right;

  final Map<String, ScoreEvent> _byRallyId;

  /// Whether any rally has been scored.
  bool get isEmpty => events.isEmpty;

  /// The score after a rally, or `null` when that rally is not scored.
  ScoreEvent? atRally(String rallyId) => _byRallyId[rallyId];

  /// The score as it stood at [seconds] into the recording.
  ///
  /// This is what the scoreboard shows during a clip: the state at that clip's
  /// place in the match, not the final score.
  ({int left, int right}) atSeconds(double seconds) {
    var left = 0;
    var right = 0;
    for (final event in events) {
      if (event.timestampSeconds > seconds) {
        break;
      }
      left = event.leftScore;
      right = event.rightScore;
    }
    return (left: left, right: right);
  }
}
