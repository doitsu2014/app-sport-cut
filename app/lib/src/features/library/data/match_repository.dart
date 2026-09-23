import 'dart:io';

import '../../../bridge/sportcut_engine.dart';
import '../domain/match_import_exception.dart';
import '../domain/match_library.dart';
import '../domain/match_record.dart';
import 'match_catalog.dart';
import 'match_paths.dart';
import 'media_engine.dart';
import 'video_file_picker.dart';

/// Reads and writes matches: the catalog, the original recording reference, and
/// the engine artifacts that belong to a match.
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
        _clock = clock ?? DateTime.now,
        _idGenerator = idGenerator ?? _defaultIdGenerator;

  final MatchCatalog _catalog;
  final MediaEngine _engine;
  final MatchPaths _paths;
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

  /// One match, or `null`.
  Future<MatchRecord?> findMatch(String id) => _catalog.findMatch(id);

  /// Create a match from a chosen recording.
  ///
  /// The original file is referenced in place: nothing is copied. Metadata is
  /// read through the engine, and the catalog record is written only after that
  /// succeeds, so a denied permission, a missing file, or an unsupported codec
  /// leaves no partial record behind.
  @override
  Future<MatchRecord> importVideo(
    PickedVideo video, {
    String? title,
  }) async {
    await _ensureReadable(video.path);

    final MediaMetadataDto metadata;
    try {
      metadata = await _engine.probe(video.path);
    } on Exception catch (error) {
      throw MatchImportException(
        'This recording could not be read: $error',
        cause: error,
      );
    }

    final id = _idGenerator();
    final match = MatchRecord(
      id: id,
      title: _titleFor(title, video),
      videoPath: video.path,
      durationSeconds: metadata.durationSeconds,
      createdAt: _clock(),
      matchDir: _paths.matchDir(id),
      videoWidth: metadata.width,
      videoHeight: metadata.height,
      frameRate: metadata.frameRate,
      hasAudio: metadata.hasAudio,
    );

    try {
      await _catalog.insertMatch(match);
    } on Exception catch (error) {
      throw MatchImportException(
        'The match could not be saved to the library: $error',
        cause: error,
      );
    }
    return match;
  }

  /// Produce this match's derived artifacts (proxy, analysis audio, frames).
  @override
  Future<MediaImportResultDto> generateArtifacts(
    MatchRecord match, {
    double samplingRate = 1,
  }) async {
    try {
      return await _engine.generateArtifacts(
        matchId: match.id,
        originalPath: match.videoPath,
        matchDir: match.matchDir,
        samplingRate: samplingRate,
      );
    } on Exception catch (error) {
      throw MatchImportException(
        'Analysis files could not be produced for ${match.title}: $error',
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
  }) =>
      _engine.regenerate(match.matchDir, samplingRate: samplingRate);

  /// Delete a match.
  ///
  /// The catalog records always go. Derived artifacts are removed only when
  /// [deleteArtifacts] is true; the original recording is never touched.
  @override
  Future<void> deleteMatch(
    MatchRecord match, {
    bool deleteArtifacts = false,
  }) async {
    await _catalog.deleteMatch(match.id);

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
      throw MatchImportException('That file is no longer available: $path');
    }
    try {
      final handle = await file.open();
      await handle.close();
    } on FileSystemException catch (error) {
      throw MatchImportException(
        'That file could not be opened. Access may have been denied: '
        '${error.message}',
        cause: error,
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
