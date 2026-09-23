import 'package:sqflite/sqflite.dart';

import '../domain/match_record.dart';

/// One versioned schema change.
///
/// Migrations are applied in ascending order from the database's current
/// version, so a device that skipped a release still arrives at the current
/// schema by replaying every step it missed.
class Migration {
  /// Define a migration step.
  const Migration({required this.version, required this.apply});

  /// Schema version this step produces.
  final int version;

  /// Applies the change to a database at `version - 1`.
  final Future<void> Function(Database db) apply;
}

/// The local catalog of matches.
///
/// The application owns this database; the engine owns only the artifact files
/// in each match directory. That split keeps every library query a local SQLite
/// read rather than a round trip across the language boundary.
class MatchCatalog {
  MatchCatalog._(this._database);

  final Database _database;

  /// Schema version written by this build.
  static const int schemaVersion = 2;

  /// All migrations, in ascending version order.
  static const List<Migration> defaultMigrations = <Migration>[
    Migration(version: 1, apply: _createInitialSchema),
    Migration(version: 2, apply: _addRecordingOrigin),
  ];

  /// Open (and migrate) the catalog.
  ///
  /// [migrations] is a parameter so tests can exercise the framework with an
  /// extra version without pretending that version exists in the product.
  static Future<MatchCatalog> open({
    required DatabaseFactory factory,
    required String path,
    List<Migration> migrations = defaultMigrations,
  }) async {
    final targetVersion = migrations
        .map((migration) => migration.version)
        .reduce((a, b) => a > b ? a : b);

    final database = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: targetVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => _migrate(db, 0, version, migrations),
        onUpgrade: (db, oldVersion, newVersion) =>
            _migrate(db, oldVersion, newVersion, migrations),
      ),
    );
    return MatchCatalog._(database);
  }

  /// The underlying database handle, for later phases that add their own
  /// tables through a migration.
  Database get database => _database;

  /// Insert a match.
  ///
  /// Uses `abort` on conflict so a duplicate identifier fails loudly instead of
  /// silently replacing a catalog record.
  Future<void> insertMatch(MatchRecord match) async {
    await _database.insert(
      'matches',
      _matchToRow(match),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Every match, newest first.
  Future<List<MatchRecord>> listMatches() async {
    final rows = await _database.query(
      'matches',
      orderBy: 'created_at DESC, title ASC',
    );
    return rows.map(_matchFromRow).toList();
  }

  /// One match, or `null` when it is not in the catalog.
  Future<MatchRecord?> findMatch(String id) async {
    final rows = await _database.query(
      'matches',
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _matchFromRow(rows.first);
  }

  /// Replace a match's stored fields.
  Future<void> updateMatch(MatchRecord match) async {
    await _database.update(
      'matches',
      _matchToRow(match),
      where: 'id = ?',
      whereArgs: <Object?>[match.id],
    );
  }

  /// Delete a match and every record that belongs to it.
  Future<void> deleteMatch(String id) async {
    await _database.transaction((txn) async {
      final args = <Object?>[id];
      await txn.delete(
        'highlight_clips',
        where: 'match_id = ?',
        whereArgs: args,
      );
      await txn.delete('score_events', where: 'match_id = ?', whereArgs: args);
      await txn.delete('rallies', where: 'match_id = ?', whereArgs: args);
      await txn.delete('matches', where: 'id = ?', whereArgs: args);
    });
  }

  /// Close the database.
  Future<void> close() => _database.close();

  static Future<void> _migrate(
    Database db,
    int fromVersion,
    int toVersion,
    List<Migration> migrations,
  ) async {
    final ordered = List<Migration>.from(migrations)
      ..sort((a, b) => a.version.compareTo(b.version));
    for (final migration in ordered) {
      if (migration.version > fromVersion && migration.version <= toVersion) {
        await migration.apply(db);
      }
    }
  }

  static Future<void> _createInitialSchema(Database db) async {
    // Columns follow the product data model (docs/README.md) so later phases
    // add columns and tables rather than restructuring these.
    await db.execute('''
      CREATE TABLE matches (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        video_path TEXT NOT NULL,
        duration_seconds REAL NOT NULL,
        created_at INTEGER NOT NULL,
        match_dir TEXT NOT NULL,
        video_width INTEGER,
        video_height INTEGER,
        frame_rate REAL,
        has_audio INTEGER NOT NULL DEFAULT 0,
        court_calibration TEXT,
        team_left_name TEXT,
        team_right_name TEXT,
        final_score_left INTEGER,
        final_score_right INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE rallies (
        id TEXT PRIMARY KEY,
        match_id TEXT NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
        start_seconds REAL NOT NULL,
        end_seconds REAL NOT NULL,
        confidence REAL,
        winner_side TEXT,
        status TEXT,
        highlight_score REAL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_rallies_match ON rallies(match_id, start_seconds)',
    );

    await db.execute('''
      CREATE TABLE score_events (
        id TEXT PRIMARY KEY,
        match_id TEXT NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
        rally_id TEXT REFERENCES rallies(id) ON DELETE SET NULL,
        timestamp_seconds REAL NOT NULL,
        winner_side TEXT NOT NULL,
        left_score INTEGER NOT NULL,
        right_score INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_score_events_match '
      'ON score_events(match_id, timestamp_seconds)',
    );

    await db.execute('''
      CREATE TABLE highlight_clips (
        id TEXT PRIMARY KEY,
        match_id TEXT NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
        start_seconds REAL NOT NULL,
        end_seconds REAL NOT NULL,
        rank INTEGER,
        selected INTEGER NOT NULL DEFAULT 0,
        trim_start_seconds REAL,
        trim_end_seconds REAL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_highlight_clips_match ON highlight_clips(match_id, rank)',
    );
  }

  /// Record where a match's recording came from, and what the app-owned copy
  /// costs.
  ///
  /// Additive only, so an install written by version 1 keeps every match: the
  /// rows it already has gain two null columns, and their `video_path` is left
  /// exactly as stored. A match whose recording has since gone missing is
  /// reported as unavailable by the library rather than repaired here.
  static Future<void> _addRecordingOrigin(Database db) async {
    await db.execute('ALTER TABLE matches ADD COLUMN original_path TEXT');
    await db.execute('ALTER TABLE matches ADD COLUMN source_bytes INTEGER');
  }

  static Map<String, Object?> _matchToRow(MatchRecord match) =>
      <String, Object?>{
        'id': match.id,
        'title': match.title,
        'video_path': match.videoPath,
        'duration_seconds': match.durationSeconds,
        'created_at': match.createdAt.millisecondsSinceEpoch,
        'match_dir': match.matchDir,
        'video_width': match.videoWidth,
        'video_height': match.videoHeight,
        'frame_rate': match.frameRate,
        'has_audio': match.hasAudio ? 1 : 0,
        'original_path': match.originalPath,
        'source_bytes': match.sourceBytes,
      };

  static MatchRecord _matchFromRow(Map<String, Object?> row) => MatchRecord(
        id: row['id']! as String,
        title: row['title']! as String,
        videoPath: row['video_path']! as String,
        durationSeconds: (row['duration_seconds']! as num).toDouble(),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
        matchDir: row['match_dir']! as String,
        videoWidth: (row['video_width'] as num?)?.toInt(),
        videoHeight: (row['video_height'] as num?)?.toInt(),
        frameRate: (row['frame_rate'] as num?)?.toDouble(),
        hasAudio: (row['has_audio'] as int? ?? 0) == 1,
        originalPath: row['original_path'] as String?,
        sourceBytes: (row['source_bytes'] as num?)?.toInt(),
      );
}
