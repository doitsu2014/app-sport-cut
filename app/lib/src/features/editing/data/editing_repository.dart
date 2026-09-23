import '../../library/domain/match_record.dart';
import '../domain/export_settings.dart';
import '../domain/highlight_clip.dart';
import '../domain/match_edit.dart';
import '../domain/match_editing.dart';
import '../domain/rally.dart';
import '../domain/score_timeline.dart';
import 'editing_store.dart';

/// Reads and writes a match's review, and derives the score from it.
///
/// Every action that changes a rally rewrites the score timeline, so the score
/// is always a function of the rallies rather than a second record that can
/// disagree with them.
class EditingRepository implements MatchEditing {
  /// Build a repository over an open store.
  EditingRepository({required EditingStore store, String Function()? idGenerator})
      : _store = store,
        _idGenerator = idGenerator ?? _defaultIdGenerator;

  final EditingStore _store;
  final String Function() _idGenerator;

  static int _sequence = 0;

  static String _defaultIdGenerator() {
    _sequence += 1;
    return 'rally-${DateTime.now().microsecondsSinceEpoch}-$_sequence';
  }

  @override
  Future<MatchEdit> load(MatchRecord match) async {
    final rallies = await _store.listRallies(match.id);
    final clips = await _store.listClips(match.id);
    final settings = await _store.readExportSettings(match.id) ??
        ExportSettings(matchId: match.id);
    return MatchEdit(
      rallies: rallies,
      clips: clips,
      score: ScoreTimeline.fromRallies(match.id, rallies),
      exportSettings: settings,
    );
  }

  @override
  Future<void> addRally(
    MatchRecord match, {
    required double startSeconds,
    required double endSeconds,
  }) async {
    if (!endSeconds.isFinite || !startSeconds.isFinite) {
      throw MatchEditingException(
        'That rally has a boundary that is not a number.',
      );
    }
    if (endSeconds <= startSeconds) {
      throw MatchEditingException(
        'A rally has to end after it starts.',
      );
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

    await _store.saveRally(
      Rally(
        id: _idGenerator(),
        matchId: match.id,
        startSeconds: startSeconds,
        endSeconds: endSeconds,
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
    if (endSeconds <= startSeconds) {
      throw MatchEditingException('A rally has to end after it starts.');
    }
    final rally = await _rally(match, rallyId);
    await _store.saveRally(
      rally.copyWith(startSeconds: startSeconds, endSeconds: endSeconds),
    );
  }

  @override
  Future<void> setWinner(
    MatchRecord match, {
    required String rallyId,
    required WinnerSide? side,
  }) async {
    final rally = await _rally(match, rallyId);
    final updated = side == null
        ? rally.copyWith(clearWinner: true, status: RallyStatus.unscored)
        : rally.copyWith(winnerSide: side, status: RallyStatus.confirmed);
    await _store.saveRally(updated);
    await _rewriteScore(match.id);
  }

  @override
  Future<void> removeRally(
    MatchRecord match, {
    required String rallyId,
  }) async {
    await _store.deleteRally(rallyId);
    await _rewriteScore(match.id);
  }

  @override
  Future<void> keepClip(
    MatchRecord match, {
    required Rally rally,
    required bool kept,
  }) async {
    final existing = (await _store.listClips(match.id))
        .where((clip) => clip.rallyId == rally.id)
        .toList();

    if (!kept) {
      for (final clip in existing) {
        await _store.deleteClip(clip.id);
      }
      return;
    }
    if (existing.isNotEmpty) {
      return;
    }

    final clips = await _store.listClips(match.id);
    await _store.saveClip(
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
    final clip = (await _store.listClips(match.id))
        .where((candidate) => candidate.id == clipId)
        .firstOrNull;
    if (clip == null) {
      throw MatchEditingException('That clip is no longer in the reel.');
    }

    final start = (startSeconds ?? clip.effectiveStartSeconds)
        .clamp(clip.startSeconds, clip.endSeconds);
    final end =
        (endSeconds ?? clip.effectiveEndSeconds).clamp(clip.startSeconds, clip.endSeconds);
    if (end <= start) {
      throw MatchEditingException('A clip has to end after it starts.');
    }

    await _store.saveClip(
      clip.copyWith(trimStartSeconds: start, trimEndSeconds: end),
    );
  }

  @override
  Future<void> reorderClips(MatchRecord match, List<String> clipIds) =>
      _store.reorderClips(match.id, clipIds);

  @override
  Future<void> saveExportSettings(ExportSettings settings) =>
      _store.writeExportSettings(settings);

  Future<Rally> _rally(MatchRecord match, String rallyId) async {
    final rallies = await _store.listRallies(match.id);
    final rally =
        rallies.where((candidate) => candidate.id == rallyId).firstOrNull;
    if (rally == null) {
      throw MatchEditingException('That rally is no longer part of the match.');
    }
    return rally;
  }

  /// Recompute and store the score after a rally changed.
  Future<void> _rewriteScore(String matchId) async {
    final rallies = await _store.listRallies(matchId);
    final timeline = ScoreTimeline.fromRallies(matchId, rallies);
    await _store.replaceScoreEvents(matchId, timeline.events);
  }
}
