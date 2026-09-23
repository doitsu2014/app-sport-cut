import 'dart:io';

import '../../../bridge/sportcut_engine.dart';
import '../../editing/data/editing_store.dart';
import '../domain/import_cancel_token.dart';
import '../domain/match_import_exception.dart';
import '../domain/match_library.dart';
import '../domain/match_record.dart';
import 'match_catalog.dart';
import 'match_paths.dart';
import 'media_engine.dart';
import 'recording_store.dart';
import 'video_file_picker.dart';

/// Reads and writes matches: the catalog, the app-owned recording, and the
/// engine artifacts that belong to a match.
class MatchRepository implements MatchLibrary {
  /// Build a repository.
  MatchRepository({
    required MatchCatalog catalog,
    required MediaEngine engine,
    required MatchPaths paths,
    DateTime Function()? clock,
    String Function()? idGenerator,
  })  : _catalog = catalog,
        _engine = engine,
        _paths = paths,
        _recordings = RecordingStore(paths),
        _clock = clock ?? DateTime.now,
        _idGenerator = idGenerator ?? _defaultIdGenerator;

  final MatchCatalog _catalog;
  final MediaEngine _engine;
  final MatchPaths _paths;
  final RecordingStore _recordings;
  final DateTime Function() _clock;
  final String Function() _idGenerator;

  static int _sequence = 0;

  static String _defaultIdGenerator() {
    _sequence += 1;
    return 'match-${DateTime.now().microsecondsSinceEpoch}-$_sequence';
  }

  /// Every stored match, newest first.
  @override
  Future<List<MatchRecord>> listMatches() => _catalog.listMatches();

  /// The score each match has reached, for the library list.
  @override
  Future<Map<String, ({int left, int right})>> scoreSummaries() =>
      _editingStore.scoreSummaries();

  late final EditingStore _editingStore = EditingStore(_catalog.database);

  /// One match, or `null`.
  Future<MatchRecord?> findMatch(String id) => _catalog.findMatch(id);

  /// Create a match from a chosen recording.
  ///
  /// The order is deliberate: the picked file is checked, probed, and only then
  /// copied, so an unreadable file or an unsupported codec is rejected before
  /// gigabytes are duplicated. The match then records the app-owned copy — the
  /// picked path belongs to a directory the platform may purge — and the file
  /// the user selected is left exactly where it was.
  ///
  /// If the catalog write fails the copy is removed, so nothing partial is left
  /// behind: no record without a recording, and no recording without a record.
  @override
  Future<MatchRecord> importVideo(
    PickedVideo video, {
    String? title,
    ImportCancelToken? cancelToken,
  }) async {
    await _ensureReadable(video.path);
    final metadata = await _probe(video.path);

    final id = _idGenerator();
    _throwIfCancelled(cancelToken);
    final stored = await _recordings.takeCustody(
      matchId: id,
      video: video,
      cancelToken: cancelToken,
    );

    final match = MatchRecord(
      id: id,
      title: _titleFor(title, video),
      videoPath: stored.path,
      durationSeconds: metadata.durationSeconds,
      createdAt: _clock(),
      matchDir: _paths.matchDir(id),
      videoWidth: metadata.width,
      videoHeight: metadata.height,
      frameRate: metadata.frameRate,
      hasAudio: metadata.hasAudio,
      originalPath: video.path,
      sourceBytes: stored.bytes,
    );

    try {
      await _catalog.insertMatch(match);
    } on Exception catch (error) {
      await _recordings.remove(id);
      throw MatchImportException(
        'The match could not be saved to the library: $error',
        kind: MatchImportKind.catalog,
        cause: error,
      );
    }
    return match;
  }

  /// Whether this match's stored recording can still be read.
  @override
  bool isRecordingAvailable(MatchRecord match) =>
      RecordingStore.isAvailable(match.videoPath);

  /// Produce this match's derived artifacts (proxy, analysis audio, frames).
  @override
  Future<ArtifactManifestDto> generateArtifacts(
    MatchRecord match, {
    double samplingRate = 1,
  }) async {
    try {
      final handle = await _engine.startArtifacts(
        matchId: match.id,
        originalPath: match.videoPath,
        matchDir: match.matchDir,
        samplingRate: samplingRate,
      );
      await _awaitJob(handle.jobId, title: match.title);
      return await _engine.manifest(match.matchDir);
    } on MatchImportException {
      rethrow;
    } on Exception catch (error) {
      throw MatchImportException(
        'Analysis files could not be produced for ${match.title}: $error',
        kind: MatchImportKind.storage,
        cause: error,
      );
    }
  }

  /// Which artifacts are present, and which are missing.
  Future<ArtifactManifestDto> manifest(MatchRecord match) =>
      _engine.manifest(match.matchDir);

  /// Rebuild derived artifacts that are recorded but missing.
  Future<ArtifactManifestDto> regenerateArtifacts(
    MatchRecord match, {
    double samplingRate = 1,
  }) async {
    try {
      final handle = await _engine.startRegenerate(
        match.matchDir,
        samplingRate: samplingRate,
      );
      await _awaitJob(handle.jobId, title: match.title);
      return await _engine.manifest(match.matchDir);
    } on MatchImportException {
      rethrow;
    } on Exception catch (error) {
      throw MatchImportException(
        'Analysis files could not be produced for ${match.title}: $error',
        kind: MatchImportKind.storage,
        cause: error,
      );
    }
  }

  /// How often a started job's state is read while the caller waits.
  static const Duration _pollInterval = Duration(milliseconds: 150);

  /// Follow a started job until it stops, and turn its ending into a result.
  ///
  /// The engine's work is a job so that a longer one — an export, later — can be
  /// shown and cancelled; this helper is for the callers that only need to know
  /// how it ended.
  Future<void> _awaitJob(String jobId, {required String title}) async {
    while (true) {
      final status = await _engine.jobStatus(jobId);
      switch (status.state) {
        case JobStateDto.completed:
          return;
        case JobStateDto.cancelled:
          throw MatchImportException(
            'Producing analysis files for $title was cancelled.',
            kind: MatchImportKind.cancelled,
          );
        case JobStateDto.failed:
          throw MatchImportException(
            status.error ??
                'Analysis files could not be produced for $title: the '
                    'engine did not say why.',
            kind: MatchImportKind.storage,
          );
        case JobStateDto.pending:
        case JobStateDto.running:
          await Future<void>.delayed(_pollInterval);
      }
    }
  }

  /// Delete a match.
  ///
  /// The catalog records always go. Derived artifacts are removed only when
  /// [deleteArtifacts] is true, and the app-owned recording only when
  /// [deleteRecording] is true. The file the user originally selected is never
  /// touched: it is not the application's to delete.
  @override
  Future<void> deleteMatch(
    MatchRecord match, {
    bool deleteArtifacts = false,
    bool deleteRecording = false,
  }) async {
    await _catalog.deleteMatch(match.id);

    if (deleteRecording) {
      await _recordings.remove(match.id);
    }

    if (!deleteArtifacts) {
      return;
    }
    final directory = Directory(match.matchDir);
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> _ensureReadable(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw MatchImportException(
        'That file is no longer available: $path',
        kind: MatchImportKind.unreadable,
      );
    }
    try {
      final handle = await file.open();
      await handle.close();
    } on FileSystemException catch (error) {
      throw MatchImportException(
        'That file could not be opened. Access may have been denied: '
        '${error.message}',
        kind: MatchImportKind.unreadable,
        cause: error,
      );
    }
  }

  Future<MediaMetadataDto> _probe(String path) async {
    try {
      return await _engine.probe(path);
    } on Exception catch (error) {
      throw MatchImportException(
        'This recording could not be read: $error',
        kind: MatchImportKind.unsupported,
        cause: error,
      );
    }
  }

  static void _throwIfCancelled(ImportCancelToken? cancelToken) {
    if (cancelToken?.isCancelled ?? false) {
      throw MatchImportException(
        'Import cancelled.',
        kind: MatchImportKind.cancelled,
      );
    }
  }

  static String _titleFor(String? title, PickedVideo video) {
    final trimmed = title?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    final name = video.displayName ?? video.path.split(Platform.pathSeparator).last;
    final withoutExtension = name.contains('.')
        ? name.substring(0, name.lastIndexOf('.'))
        : name;
    return withoutExtension.isEmpty ? 'Untitled match' : withoutExtension;
  }
}
