/// Editing store and repository tests, against a real SQLite database.
///
/// The review screens are covered by widget tests with an in-memory double;
/// this is where what those screens write is actually persisted: rally
/// validation, the derived score, the reel's clips and their order, the export
/// settings, and what happens to a clip whose rally is removed.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sportcut/src/features/editing/data/editing_repository.dart';
import 'package:sportcut/src/features/editing/data/editing_store.dart';
import 'package:sportcut/src/features/editing/domain/export_settings.dart';
import 'package:sportcut/src/features/editing/domain/match_editing.dart';
import 'package:sportcut/src/features/editing/domain/rally.dart';
import 'package:sportcut/src/features/library/data/match_catalog.dart';
import 'package:sportcut/src/features/library/domain/match_record.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late MatchCatalog catalog;
  late EditingStore store;
  late EditingRepository editing;
  var sequence = 0;

  final match = MatchRecord(
    id: 'match-1',
    title: 'Club final',
    videoPath: '/tmp/club-final.mp4',
    durationSeconds: 90,
    createdAt: DateTime(2026, 3, 2),
    matchDir: '/tmp/matches/match-1',
  );

  setUp(() async {
    sequence = 0;
    catalog = await MatchCatalog.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    await catalog.insertMatch(match);
    store = EditingStore(catalog.database);
    editing = EditingRepository(
      store: store,
      idGenerator: () => 'rally-${++sequence}',
    );
  });

  tearDown(() async {
    await catalog.close();
  });

  Future<Rally> markRally(double start, double end) async {
    await editing.addRally(match, startSeconds: start, endSeconds: end);
    final rallies = await store.listRallies(match.id);
    return rallies.last;
  }

  test('a match that has not been reviewed holds no records', () async {
    final edit = await editing.load(match);

    expect(edit.rallies, isEmpty);
    expect(edit.clips, isEmpty);
    expect(edit.score.isEmpty, isTrue);
    expect(edit.exportSettings.matchId, match.id);
  });

  test('a marked rally is recorded and is there next time', () async {
    await markRally(10, 20);

    // A second session reads what the first one wrote.
    final reopened = EditingRepository(store: store);
    final edit = await reopened.load(match);

    expect(edit.rallies, hasLength(1));
    expect(edit.rallies.single.startSeconds, 10);
    expect(edit.rallies.single.endSeconds, 20);
    expect(edit.rallies.single.winnerSide, isNull);
    expect(edit.rallies.single.status, RallyStatus.unscored);
  });

  test('a rally that does not end after it starts is rejected', () async {
    for (final boundaries in <(double, double)>[
      (20, 10),
      (10, 10),
      (10, double.nan),
    ]) {
      await expectLater(
        editing.addRally(
          match,
          startSeconds: boundaries.$1,
          endSeconds: boundaries.$2,
        ),
        throwsA(isA<MatchEditingException>()),
      );
    }

    expect(await store.listRallies(match.id), isEmpty);
  });

  test('moving a rally changes that rally and no other', () async {
    final first = await markRally(10, 20);
    final second = await markRally(30, 40);

    await editing.moveRally(
      match,
      rallyId: second.id,
      startSeconds: 32,
      endSeconds: 42,
    );

    final rallies = await store.listRallies(match.id);
    expect(rallies.map((rally) => rally.startSeconds), <double>[10, 32]);
    expect(rallies.first.id, first.id);
    expect(rallies.last.endSeconds, 42);
  });

  test('a winner is recorded only from an explicit confirmation', () async {
    final rally = await markRally(10, 20);
    expect(rally.isScored, isFalse);

    await editing.setWinner(match, rallyId: rally.id, side: WinnerSide.left);
    var stored = (await store.listRallies(match.id)).single;
    expect(stored.winnerSide, WinnerSide.left);
    expect(stored.status, RallyStatus.confirmed);
    expect(stored.isScored, isTrue);

    await editing.setWinner(match, rallyId: rally.id, side: WinnerSide.right);
    stored = (await store.listRallies(match.id)).single;
    expect(stored.winnerSide, WinnerSide.right);

    await editing.setWinner(match, rallyId: rally.id, side: null);
    stored = (await store.listRallies(match.id)).single;
    expect(stored.winnerSide, isNull);
    expect(stored.status, RallyStatus.unscored);
    expect(stored.isScored, isFalse);
  });

  test('the score events follow the confirmed winners, and a correction '
      'rewrites them', () async {
    final first = await markRally(10, 20);
    final second = await markRally(30, 40);
    await editing.setWinner(match, rallyId: first.id, side: WinnerSide.left);
    await editing.setWinner(match, rallyId: second.id, side: WinnerSide.left);

    var events = await store.listScoreEvents(match.id);
    expect(
      events.map((event) => (event.leftScore, event.rightScore)),
      <(int, int)>[(1, 0), (2, 0)],
    );
    expect(events.first.rallyId, first.id);

    // Correcting the first point rewrites the second: the score is derived, so
    // it cannot drift from the rallies it describes.
    await editing.setWinner(match, rallyId: first.id, side: WinnerSide.right);
    events = await store.listScoreEvents(match.id);
    expect(
      events.map((event) => (event.leftScore, event.rightScore)),
      <(int, int)>[(0, 1), (1, 1)],
    );

    // And the library's summary of the match reports the corrected score.
    final summaries = await store.scoreSummaries();
    expect(summaries[match.id], (left: 1, right: 1));
  });

  test('keeping a rally records a clip that carries the rally and its span',
      () async {
    final rally = await markRally(10, 20);
    await editing.keepClip(match, rally: rally, kept: true);

    final edit = await editing.load(match);
    expect(edit.clips, hasLength(1));
    final clip = edit.clips.single;
    expect(clip.rallyId, rally.id);
    expect(clip.startSeconds, rally.startSeconds);
    expect(clip.endSeconds, rally.endSeconds);
    expect(edit.isKept(rally), isTrue);
    expect(edit.clipForRally(rally.id)!.id, clip.id);
    expect(edit.reelSeconds, 10);

    // Keeping it again does not put a second copy in the reel.
    await editing.keepClip(match, rally: rally, kept: true);
    expect((await editing.load(match)).clips, hasLength(1));
  });

  test('trimming moves the clip and leaves the rally alone', () async {
    final rally = await markRally(10, 20);
    await editing.keepClip(match, rally: rally, kept: true);
    final clip = (await editing.load(match)).clips.single;

    await editing.trimClip(
      match,
      clipId: clip.id,
      startSeconds: 12,
      endSeconds: 18,
    );

    final edit = await editing.load(match);
    final trimmed = edit.clips.single;
    expect(trimmed.effectiveStartSeconds, 12);
    expect(trimmed.effectiveEndSeconds, 18);
    expect(trimmed.durationSeconds, 6);
    // The rally's own boundaries are what the score timeline is built from, so
    // trimming the reel must not touch them.
    expect(edit.rallies.single.startSeconds, 10);
    expect(edit.rallies.single.endSeconds, 20);
  });

  test('a trim that would not leave a clip is rejected', () async {
    final rally = await markRally(10, 20);
    await editing.keepClip(match, rally: rally, kept: true);
    final clip = (await editing.load(match)).clips.single;

    await expectLater(
      editing.trimClip(
        match,
        clipId: clip.id,
        startSeconds: clip.endSeconds,
      ),
      throwsA(isA<MatchEditingException>()),
    );

    expect((await editing.load(match)).clips.single.trimStartSeconds, isNull);
  });

  test('taking a rally out of the reel leaves its score alone', () async {
    final rally = await markRally(10, 20);
    await editing.keepClip(match, rally: rally, kept: true);
    await editing.setWinner(match, rallyId: rally.id, side: WinnerSide.left);

    await editing.keepClip(match, rally: rally, kept: false);

    final edit = await editing.load(match);
    expect(edit.clips, isEmpty);
    expect(edit.rallies, hasLength(1));
    expect(edit.score.left, 1);
    expect(edit.isKept(rally), isFalse);
  });

  test('the reel keeps the order the user set', () async {
    final first = await markRally(10, 20);
    final second = await markRally(30, 40);
    await editing.keepClip(match, rally: first, kept: true);
    await editing.keepClip(match, rally: second, kept: true);

    final clips = (await editing.load(match)).clips;
    expect(clips.map((clip) => clip.rallyId), <String>[first.id, second.id]);

    await editing.reorderClips(match, <String>[clips.last.id, clips.first.id]);

    // A later session sees the order the user set, not the order they were
    // added in.
    final reopened = EditingRepository(store: store);
    final edit = await reopened.load(match);
    expect(edit.clips.map((clip) => clip.rallyId), <String>[second.id, first.id]);
  });

  test('removing a rally detaches its clip instead of taking it out',
      () async {
    final rally = await markRally(10, 20);
    await editing.keepClip(match, rally: rally, kept: true);
    await editing.setWinner(match, rallyId: rally.id, side: WinnerSide.left);

    await editing.removeRally(match, rallyId: rally.id);

    final edit = await editing.load(match);
    expect(edit.rallies, isEmpty);
    expect(edit.clips, hasLength(1));
    expect(edit.clips.single.rallyId, isNull);
    expect(edit.score.isEmpty, isTrue);
  });

  test('export settings are stored and read back', () async {
    await editing.saveExportSettings(
      const ExportSettings(
        matchId: 'match-1',
        title: 'Club final',
        musicPath: '/music/warm-up.m4a',
        musicGain: 0.4,
        leadInSeconds: 2,
        leadOutSeconds: 0.5,
      ),
    );

    final edit = await editing.load(match);
    expect(edit.exportSettings.title, 'Club final');
    expect(edit.exportSettings.musicPath, '/music/warm-up.m4a');
    expect(edit.exportSettings.hasMusic, isTrue);
    expect(edit.exportSettings.musicGain, 0.4);
    expect(edit.exportSettings.leadInSeconds, 2);
    expect(edit.exportSettings.leadOutSeconds, 0.5);

    // Choosing no music again is recorded as no music, not left behind.
    await editing.saveExportSettings(
      edit.exportSettings.copyWith(clearMusic: true, clearTitle: true),
    );
    final again = await editing.load(match);
    expect(again.exportSettings.musicPath, isNull);
    expect(again.exportSettings.hasMusic, isFalse);
    expect(again.exportSettings.title, isNull);
  });
}
