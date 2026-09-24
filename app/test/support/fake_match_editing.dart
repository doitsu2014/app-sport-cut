/// In-memory [MatchEditing] for widget tests.
///
/// The screens depend on the editing interface, not on the SQLite store, so a
/// widget test can drive a review session without a database — which matters
/// because widget tests run in a fake-async zone where real database work never
/// completes. The real store is covered by `editing_repository_test.dart`.
///
/// The double records rallies and clips in lists but derives the score with the
/// real `ScoreTimeline`, so a screen cannot be tested against a score the
/// application would never show.
library;

import 'package:sportcut/src/features/editing/domain/export_settings.dart';
import 'package:sportcut/src/features/editing/domain/highlight_clip.dart';
import 'package:sportcut/src/features/editing/domain/match_edit.dart';
import 'package:sportcut/src/features/editing/domain/match_editing.dart';
import 'package:sportcut/src/features/editing/domain/rally.dart';
import 'package:sportcut/src/features/editing/domain/score_timeline.dart';
import 'package:sportcut/src/features/editing/domain/suggestion_decision.dart';
import 'package:sportcut/src/features/library/domain/match_record.dart';

class FakeMatchEditing implements MatchEditing {
  /// Build a double over the given records.
  FakeMatchEditing({
    List<Rally>? rallies,
    List<HighlightClip>? clips,
    this.settings,
  })  : rallies = List<Rally>.of(rallies ?? const <Rally>[]),
        clips = List<HighlightClip>.of(clips ?? const <HighlightClip>[]);

  /// Marked rallies, in the order they were recorded.
  final List<Rally> rallies;

  /// Clips in the reel.
  final List<HighlightClip> clips;

  /// Stored export settings, once the screen has written any.
  ExportSettings? settings;

  /// Error thrown by every action, when set.
  Object? failure;

  /// Names of the actions the screen asked for, in order.
  final List<String> calls = <String>[];

  final List<SuggestionDecision> _suggestionDecisions = <SuggestionDecision>[];

  int _sequence = 0;

  @override
  Future<MatchEdit> load(MatchRecord match) async {
    calls.add('load');
    _throwIfFailing();
    final ordered = List<Rally>.of(rallies)
      ..sort((a, b) => a.startSeconds.compareTo(b.startSeconds));
    final reel = List<HighlightClip>.of(clips)
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return MatchEdit(
      rallies: ordered,
      clips: reel,
      score: ScoreTimeline.fromRallies(match.id, ordered),
      exportSettings: settings ?? ExportSettings(matchId: match.id),
    );
  }

  @override
  Future<void> addRally(
    MatchRecord match, {
    required double startSeconds,
    required double endSeconds,
  }) async {
    calls.add('addRally');
    _throwIfFailing();
    if (endSeconds <= startSeconds) {
      throw MatchEditingException('A rally has to end after it starts.');
    }
    if (startSeconds < 0) {
      throw MatchEditingException(
        'A rally cannot start before the recording does.',
      );
    }
    if (endSeconds > match.durationSeconds) {
      throw MatchEditingException(
        'A rally cannot end after the recording does.',
      );
    }
    _sequence += 1;
    rallies.add(
      Rally(
        id: 'rally-$_sequence',
        matchId: match.id,
        startSeconds: startSeconds,
        endSeconds: endSeconds,
      ),
    );
  }

  @override
  Future<List<SuggestionDecision>> suggestionDecisions(
    MatchRecord match, {
    required String generationId,
  }) async {
    calls.add('suggestionDecisions');
    _throwIfFailing();
    return _suggestionDecisions
        .where((decision) => decision.generationId == generationId)
        .toList();
  }

  @override
  Future<void> acceptSuggestion(
    MatchRecord match, {
    required String generationId,
    required String candidateId,
    required double startSeconds,
    required double endSeconds,
  }) async {
    calls.add('acceptSuggestion');
    _throwIfFailing();
    await addRally(
      match,
      startSeconds: startSeconds,
      endSeconds: endSeconds,
    );
    _suggestionDecisions.add(
      SuggestionDecision(
        generationId: generationId,
        candidateId: candidateId,
        kind: SuggestionDecisionKind.accepted,
        rallyId: rallies.last.id,
      ),
    );
  }

  @override
  Future<void> dismissSuggestion(
    MatchRecord match, {
    required String generationId,
    required String candidateId,
  }) async {
    calls.add('dismissSuggestion');
    _throwIfFailing();
    _suggestionDecisions.add(
      SuggestionDecision(
        generationId: generationId,
        candidateId: candidateId,
        kind: SuggestionDecisionKind.dismissed,
      ),
    );
  }

  @override
  Future<void> moveRally(
    MatchRecord match, {
    required String rallyId,
    required double startSeconds,
    required double endSeconds,
  }) async {
    calls.add('moveRally');
    _throwIfFailing();
    if (endSeconds <= startSeconds) {
      throw MatchEditingException('A rally has to end after it starts.');
    }
    final index = _rallyIndex(rallyId);
    rallies[index] = rallies[index].copyWith(
      startSeconds: startSeconds,
      endSeconds: endSeconds,
    );
  }

  @override
  Future<void> setWinner(
    MatchRecord match, {
    required String rallyId,
    required WinnerSide? side,
  }) async {
    calls.add('setWinner');
    _throwIfFailing();
    final index = _rallyIndex(rallyId);
    rallies[index] = side == null
        ? rallies[index].copyWith(
            clearWinner: true,
            status: RallyStatus.unscored,
          )
        : rallies[index].copyWith(
            winnerSide: side,
            status: RallyStatus.confirmed,
          );
  }

  @override
  Future<void> removeRally(
    MatchRecord match, {
    required String rallyId,
  }) async {
    calls.add('removeRally');
    _throwIfFailing();
    rallies.removeWhere((rally) => rally.id == rallyId);
  }

  @override
  Future<void> keepClip(
    MatchRecord match, {
    required Rally rally,
    required bool kept,
  }) async {
    calls.add('keepClip');
    _throwIfFailing();
    clips.removeWhere((clip) => clip.rallyId == rally.id);
    if (!kept) {
      return;
    }
    clips.add(
      HighlightClip(
        id: 'clip-${rally.id}',
        matchId: match.id,
        rallyId: rally.id,
        startSeconds: rally.startSeconds,
        endSeconds: rally.endSeconds,
        orderIndex: clips.length,
      ),
    );
  }

  @override
  Future<void> trimClip(
    MatchRecord match, {
    required String clipId,
    double? startSeconds,
    double? endSeconds,
  }) async {
    calls.add('trimClip');
    _throwIfFailing();
    final index = clips.indexWhere((clip) => clip.id == clipId);
    if (index < 0) {
      throw MatchEditingException('That clip is no longer in the reel.');
    }
    final clip = clips[index];
    final start = (startSeconds ?? clip.effectiveStartSeconds)
        .clamp(clip.startSeconds, clip.endSeconds);
    final end = (endSeconds ?? clip.effectiveEndSeconds)
        .clamp(clip.startSeconds, clip.endSeconds);
    if (end <= start) {
      throw MatchEditingException('A clip has to end after it starts.');
    }
    clips[index] = clip.copyWith(
      trimStartSeconds: start,
      trimEndSeconds: end,
    );
  }

  @override
  Future<void> reorderClips(
    MatchRecord match,
    List<String> clipIds,
  ) async {
    calls.add('reorderClips');
    _throwIfFailing();
    for (var index = 0; index < clipIds.length; index += 1) {
      final at = clips.indexWhere((clip) => clip.id == clipIds[index]);
      if (at >= 0) {
        clips[at] = clips[at].copyWith(orderIndex: index);
      }
    }
    // The reel is the list in order, as the store hands it back.
    clips.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  }

  @override
  Future<void> saveExportSettings(ExportSettings newSettings) async {
    calls.add('saveExportSettings');
    _throwIfFailing();
    settings = newSettings;
  }

  int _rallyIndex(String rallyId) {
    final index = rallies.indexWhere((rally) => rally.id == rallyId);
    if (index < 0) {
      throw MatchEditingException('That rally is no longer part of the match.');
    }
    return index;
  }

  void _throwIfFailing() {
    final error = failure;
    if (error != null) {
      throw error;
    }
  }
}
