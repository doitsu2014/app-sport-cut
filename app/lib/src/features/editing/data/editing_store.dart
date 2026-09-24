import 'package:sqflite/sqflite.dart';

import '../domain/export_settings.dart';
import '../domain/highlight_clip.dart';
import '../domain/match_editing.dart';
import '../domain/rally.dart';
import '../domain/score_event.dart';
import '../domain/suggestion_decision.dart';

/// Typed access to the records a review session produces.
///
/// The catalog owns the schema and the migration that created these tables; this
/// class is the typed view on top of them, so feature code never writes SQL. It
/// shares the catalog's database handle rather than opening a second connection
/// to the same file.
class EditingStore {
  /// Wrap an open catalog database.
  EditingStore(this._database, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final Database _database;
  final DateTime Function() _clock;

  /// Every rally for a match, in recording order.
  Future<List<Rally>> listRallies(String matchId) async {
    final rows = await _database.query(
      'rallies',
      where: 'match_id = ?',
      whereArgs: <Object?>[matchId],
      orderBy: 'start_seconds ASC',
    );
    return rows.map(_rallyFromRow).toList();
  }

  /// Insert a rally, or replace the stored one with the same identifier.
  ///
  /// Deliberately an update-then-insert rather than `ConflictAlgorithm.replace`:
  /// replacing deletes the row first, which would fire the clip table's
  /// `ON DELETE SET NULL` and silently detach every clip made from this rally.
  Future<void> saveRally(Rally rally) async {
    final updated = await _database.update(
      'rallies',
      _rallyToRow(rally),
      where: 'id = ?',
      whereArgs: <Object?>[rally.id],
    );
    if (updated == 0) {
      await _database.insert(
        'rallies',
        _rallyToRow(rally),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
  }

  /// Remove a rally. Clips made from it survive, detached from it.
  Future<void> deleteRally(String rallyId) async {
    await _database.transaction((txn) async {
      await txn.delete(
        'rally_suggestion_decisions',
        where: 'rally_id = ?',
        whereArgs: <Object?>[rallyId],
      );
      await txn.delete(
        'rallies',
        where: 'id = ?',
        whereArgs: <Object?>[rallyId],
      );
    });
  }

  /// Decisions for one exact analysis generation.
  Future<List<SuggestionDecision>> listSuggestionDecisions(
    String matchId,
    String generationId,
  ) async {
    final rows = await _database.query(
      'rally_suggestion_decisions',
      where: 'match_id = ? AND generation_id = ?',
      whereArgs: <Object?>[matchId, generationId],
      orderBy: 'candidate_id ASC',
    );
    return rows
        .map(
          (row) => SuggestionDecision(
            generationId: row['generation_id']! as String,
            candidateId: row['candidate_id']! as String,
            kind: row['decision'] == 'accepted'
                ? SuggestionDecisionKind.accepted
                : SuggestionDecisionKind.dismissed,
            rallyId: row['rally_id'] as String?,
          ),
        )
        .toList();
  }

  /// Accept a proposal and create its unscored rally atomically.
  Future<void> acceptSuggestion({
    required Rally rally,
    required String generationId,
    required String candidateId,
  }) async {
    await _database.transaction((txn) async {
      final existing = await txn.query(
        'rally_suggestion_decisions',
        columns: <String>['decision', 'rally_id'],
        where: 'match_id = ? AND generation_id = ? AND candidate_id = ?',
        whereArgs: <Object?>[rally.matchId, generationId, candidateId],
        limit: 1,
      );
      if (existing.isNotEmpty &&
          existing.first['decision'] == 'accepted' &&
          existing.first['rally_id'] != null) {
        return;
      }
      final overlaps = await txn.query(
        'rallies',
        columns: <String>['id'],
        where: 'match_id = ? AND start_seconds < ? AND end_seconds > ?',
        whereArgs: <Object?>[
          rally.matchId,
          rally.endSeconds,
          rally.startSeconds,
        ],
        limit: 1,
      );
      if (overlaps.isNotEmpty) {
        throw MatchEditingException(
          'That suggestion overlaps a rally already in the match.',
        );
      }
      await txn.insert('rallies', _rallyToRow(rally));
      await txn.insert(
        'rally_suggestion_decisions',
        <String, Object?>{
          'match_id': rally.matchId,
          'generation_id': generationId,
          'candidate_id': candidateId,
          'decision': 'accepted',
          'rally_id': rally.id,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Hide a proposal for one generation without creating a rally.
  Future<void> dismissSuggestion({
    required String matchId,
    required String generationId,
    required String candidateId,
  }) async {
    await _database.transaction((txn) async {
      final existing = await txn.query(
        'rally_suggestion_decisions',
        columns: <String>['decision'],
        where: 'match_id = ? AND generation_id = ? AND candidate_id = ?',
        whereArgs: <Object?>[matchId, generationId, candidateId],
        limit: 1,
      );
      if (existing.isNotEmpty && existing.first['decision'] == 'accepted') {
        throw MatchEditingException(
          'An accepted suggestion cannot be dismissed while its rally remains.',
        );
      }
      await txn.insert(
        'rally_suggestion_decisions',
        <String, Object?>{
          'match_id': matchId,
          'generation_id': generationId,
          'candidate_id': candidateId,
          'decision': 'dismissed',
          'rally_id': null,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Every clip for a match, in the order the user put them in.
  Future<List<HighlightClip>> listClips(String matchId) async {
    final rows = await _database.query(
      'highlight_clips',
      where: 'match_id = ?',
      whereArgs: <Object?>[matchId],
      orderBy: 'order_index ASC, start_seconds ASC',
    );
    return rows.map(_clipFromRow).toList();
  }

  /// Insert a clip, or replace the stored one with the same identifier.
  Future<void> saveClip(HighlightClip clip) async {
    final updated = await _database.update(
      'highlight_clips',
      _clipToRow(clip),
      where: 'id = ?',
      whereArgs: <Object?>[clip.id],
    );
    if (updated == 0) {
      await _database.insert(
        'highlight_clips',
        _clipToRow(clip),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
  }

  /// Remove a clip.
  Future<void> deleteClip(String clipId) async {
    await _database.delete(
      'highlight_clips',
      where: 'id = ?',
      whereArgs: <Object?>[clipId],
    );
  }

  /// Write the reel's order in one transaction.
  ///
  /// [clipIds] is the reel from first to last; identifiers it does not mention
  /// keep their current position.
  Future<void> reorderClips(String matchId, List<String> clipIds) async {
    await _database.transaction((txn) async {
      for (var index = 0; index < clipIds.length; index += 1) {
        await txn.update(
          'highlight_clips',
          <String, Object?>{'order_index': index},
          where: 'id = ? AND match_id = ?',
          whereArgs: <Object?>[clipIds[index], matchId],
        );
      }
    });
  }

  /// Every recorded score event for a match, oldest first.
  Future<List<ScoreEvent>> listScoreEvents(String matchId) async {
    final rows = await _database.query(
      'score_events',
      where: 'match_id = ?',
      whereArgs: <Object?>[matchId],
      orderBy: 'timestamp_seconds ASC',
    );
    return rows.map(_scoreEventFromRow).toList();
  }

  /// The score each match reached, for the library list.
  ///
  /// One query for the whole library rather than one per match, because every
  /// row shows a score: a match with no confirmed rally simply has no entry.
  Future<Map<String, ({int left, int right})>> scoreSummaries() async {
    final rows = await _database.rawQuery(
      'SELECT match_id, MAX(left_score) AS left_score, '
      'MAX(right_score) AS right_score '
      'FROM score_events GROUP BY match_id',
    );
    return <String, ({int left, int right})>{
      for (final row in rows)
        row['match_id']! as String: (
          left: (row['left_score'] as num?)?.toInt() ?? 0,
          right: (row['right_score'] as num?)?.toInt() ?? 0,
        ),
    };
  }

  /// Replace every score event for a match with [events].
  ///
  /// The whole timeline is rewritten rather than patched, because a correction
  /// to an early rally changes every score that follows it.
  Future<void> replaceScoreEvents(
    String matchId,
    List<ScoreEvent> events,
  ) async {
    await _database.transaction((txn) async {
      await txn.delete(
        'score_events',
        where: 'match_id = ?',
        whereArgs: <Object?>[matchId],
      );
      for (final event in events) {
        await txn.insert('score_events', _scoreEventToRow(event));
      }
    });
  }

  /// A match's export settings, or `null` when none have been chosen yet.
  Future<ExportSettings?> readExportSettings(String matchId) async {
    final rows = await _database.query(
      'export_settings',
      where: 'match_id = ?',
      whereArgs: <Object?>[matchId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _exportSettingsFromRow(rows.first);
  }

  /// Store a match's export settings.
  Future<void> writeExportSettings(ExportSettings settings) async {
    final row = <String, Object?>{
      'match_id': settings.matchId,
      'title': settings.title,
      'music_path': settings.musicPath,
      'music_gain': settings.musicGain,
      'lead_in_seconds': settings.leadInSeconds,
      'lead_out_seconds': settings.leadOutSeconds,
      'updated_at': _clock().millisecondsSinceEpoch,
    };
    final updated = await _database.update(
      'export_settings',
      row,
      where: 'match_id = ?',
      whereArgs: <Object?>[settings.matchId],
    );
    if (updated == 0) {
      await _database.insert(
        'export_settings',
        row,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
  }

  static Map<String, Object?> _rallyToRow(Rally rally) => <String, Object?>{
        'id': rally.id,
        'match_id': rally.matchId,
        'start_seconds': rally.startSeconds,
        'end_seconds': rally.endSeconds,
        'confidence': rally.confidence,
        'winner_side': rally.winnerSide?.wireName,
        'status': rally.status.wireName,
        'highlight_score': rally.highlightScore,
      };

  static Rally _rallyFromRow(Map<String, Object?> row) => Rally(
        id: row['id']! as String,
        matchId: row['match_id']! as String,
        startSeconds: (row['start_seconds']! as num).toDouble(),
        endSeconds: (row['end_seconds']! as num).toDouble(),
        winnerSide: WinnerSide.fromWire(row['winner_side']),
        status: RallyStatus.fromWire(row['status']),
        confidence: (row['confidence'] as num?)?.toDouble(),
        highlightScore: (row['highlight_score'] as num?)?.toDouble(),
      );

  static Map<String, Object?> _clipToRow(HighlightClip clip) =>
      <String, Object?>{
        'id': clip.id,
        'match_id': clip.matchId,
        'rally_id': clip.rallyId,
        'start_seconds': clip.startSeconds,
        'end_seconds': clip.endSeconds,
        'rank': clip.rank,
        'selected': clip.selected ? 1 : 0,
        'trim_start_seconds': clip.trimStartSeconds,
        'trim_end_seconds': clip.trimEndSeconds,
        'order_index': clip.orderIndex,
      };

  static HighlightClip _clipFromRow(Map<String, Object?> row) => HighlightClip(
        id: row['id']! as String,
        matchId: row['match_id']! as String,
        rallyId: row['rally_id'] as String?,
        startSeconds: (row['start_seconds']! as num).toDouble(),
        endSeconds: (row['end_seconds']! as num).toDouble(),
        rank: (row['rank'] as num?)?.toInt(),
        selected: (row['selected'] as int? ?? 1) == 1,
        trimStartSeconds: (row['trim_start_seconds'] as num?)?.toDouble(),
        trimEndSeconds: (row['trim_end_seconds'] as num?)?.toDouble(),
        orderIndex: (row['order_index'] as num?)?.toInt() ?? 0,
      );

  static Map<String, Object?> _scoreEventToRow(ScoreEvent event) =>
      <String, Object?>{
        'id': event.id,
        'match_id': event.matchId,
        'rally_id': event.rallyId,
        'timestamp_seconds': event.timestampSeconds,
        'winner_side': event.winnerSide.wireName,
        'left_score': event.leftScore,
        'right_score': event.rightScore,
      };

  static ScoreEvent _scoreEventFromRow(Map<String, Object?> row) => ScoreEvent(
        id: row['id']! as String,
        matchId: row['match_id']! as String,
        rallyId: row['rally_id']! as String,
        timestampSeconds: (row['timestamp_seconds']! as num).toDouble(),
        winnerSide: WinnerSide.fromWire(row['winner_side']) ?? WinnerSide.left,
        leftScore: (row['left_score']! as num).toInt(),
        rightScore: (row['right_score']! as num).toInt(),
      );

  static ExportSettings _exportSettingsFromRow(Map<String, Object?> row) =>
      ExportSettings(
        matchId: row['match_id']! as String,
        title: row['title'] as String?,
        musicPath: row['music_path'] as String?,
        musicGain: (row['music_gain'] as num?)?.toDouble() ??
            ExportSettings.defaultMusicGain,
        leadInSeconds: (row['lead_in_seconds'] as num?)?.toDouble() ??
            ExportSettings.defaultLeadInSeconds,
        leadOutSeconds: (row['lead_out_seconds'] as num?)?.toDouble() ??
            ExportSettings.defaultLeadOutSeconds,
      );
}
