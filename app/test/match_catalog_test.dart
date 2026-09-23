/// Catalog tests. These run against a real SQLite database through
/// `sqflite_common_ffi`, so the schema and migrations are exercised rather than
/// mocked.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sportcut/src/features/library/data/match_catalog.dart';
import 'package:sportcut/src/features/library/domain/match_record.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory tempDir;
  late String databasePath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sportcut-catalog-test');
    databasePath = p.join(tempDir.path, 'catalog.db');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  MatchRecord sampleMatch({
    String id = 'match-1',
    String title = 'Thursday night',
    DateTime? createdAt,
  }) =>
      MatchRecord(
        id: id,
        title: title,
        videoPath: '/Users/someone/Movies/match.mp4',
        durationSeconds: 1830.5,
        createdAt: createdAt ?? DateTime(2026, 5, 4, 19, 30),
        matchDir: '/Users/someone/Documents/SportcutMatches/$id',
        videoWidth: 1920,
        videoHeight: 1080,
        frameRate: 29.97,
        hasAudio: true,
      );

  test('the initial schema contains the product data model', () async {
    final catalog = await MatchCatalog.open(
      factory: databaseFactoryFfi,
      path: databasePath,
    );

    final rows = await catalog.database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final tables = rows.map((row) => row['name'] as String).toSet();
    await catalog.close();

    expect(
      tables,
      containsAll(<String>[
        'matches',
        'rallies',
        'score_events',
        'highlight_clips',
      ]),
    );
  });

  test('a match survives closing and reopening the catalog', () async {
    final first = await MatchCatalog.open(
      factory: databaseFactoryFfi,
      path: databasePath,
    );
    await first.insertMatch(sampleMatch());
    await first.close();

    final reopened = await MatchCatalog.open(
      factory: databaseFactoryFfi,
      path: databasePath,
    );
    final matches = await reopened.listMatches();
    await reopened.close();

    expect(matches, hasLength(1));
    expect(matches.single.title, 'Thursday night');
    expect(matches.single.durationSeconds, closeTo(1830.5, 0.001));
    expect(matches.single.videoPath, '/Users/someone/Movies/match.mp4');
    expect(matches.single.hasAudio, isTrue);
    expect(matches.single.createdAt, DateTime(2026, 5, 4, 19, 30));
  });

  test('matches are listed newest first', () async {
    final catalog = await MatchCatalog.open(
      factory: databaseFactoryFfi,
      path: databasePath,
    );
    await catalog.insertMatch(
      sampleMatch(id: 'older', createdAt: DateTime(2026, 1, 1)),
    );
    await catalog.insertMatch(
      sampleMatch(id: 'newer', createdAt: DateTime(2026, 6, 1)),
    );

    final matches = await catalog.listMatches();
    await catalog.close();

    expect(matches.map((match) => match.id), <String>['newer', 'older']);
  });

  test('a schema change is applied as a migration and existing matches survive',
      () async {
    final versionOne = await MatchCatalog.open(
      factory: databaseFactoryFfi,
      path: databasePath,
    );
    await versionOne.insertMatch(sampleMatch());
    await versionOne.close();

    final versionTwo = <Migration>[
      ...MatchCatalog.defaultMigrations,
      Migration(
        version: 2,
        apply: (db) async {
          await db.execute('ALTER TABLE matches ADD COLUMN notes TEXT');
        },
      ),
    ];

    final migrated = await MatchCatalog.open(
      factory: databaseFactoryFfi,
      path: databasePath,
      migrations: versionTwo,
    );
    final matches = await migrated.listMatches();
    final columns = await migrated.database.rawQuery(
      'PRAGMA table_info(matches)',
    );
    await migrated.close();

    expect(matches, hasLength(1), reason: 'the migration dropped a match');
    expect(matches.single.id, 'match-1');
    expect(
      columns.map((column) => column['name']),
      contains('notes'),
      reason: 'the migration did not run',
    );
  });

  test('deleting a match removes its dependent records', () async {
    final catalog = await MatchCatalog.open(
      factory: databaseFactoryFfi,
      path: databasePath,
    );
    await catalog.insertMatch(sampleMatch());

    final db = catalog.database;
    await db.insert('rallies', <String, Object?>{
      'id': 'rally-1',
      'match_id': 'match-1',
      'start_seconds': 12.0,
      'end_seconds': 30.0,
    });
    await db.insert('score_events', <String, Object?>{
      'id': 'event-1',
      'match_id': 'match-1',
      'rally_id': 'rally-1',
      'timestamp_seconds': 30.0,
      'winner_side': 'left',
      'left_score': 1,
      'right_score': 0,
    });
    await db.insert('highlight_clips', <String, Object?>{
      'id': 'clip-1',
      'match_id': 'match-1',
      'start_seconds': 12.0,
      'end_seconds': 30.0,
      'rank': 1,
      'selected': 1,
    });

    await catalog.deleteMatch('match-1');

    expect(await catalog.listMatches(), isEmpty);
    expect(await db.query('rallies'), isEmpty);
    expect(await db.query('score_events'), isEmpty);
    expect(await db.query('highlight_clips'), isEmpty);
    await catalog.close();
  });
}
