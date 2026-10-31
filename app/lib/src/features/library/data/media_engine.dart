import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../bridge/sportcut_engine.dart';

/// What the library needs from the engine.
///
/// The screen layer depends on this interface rather than on
/// [SportcutEngine] directly, so widget and repository tests can run without
/// loading the native library.
abstract interface class MediaEngine {
  /// The service state root, or null when the engine does not own one.
  ///
  /// The import path uses it to stage a picked recording in the service inbox
  /// before probing; the service refuses to read arbitrary user paths.
  String? get stateRoot;

  /// Read metadata from a recording.
  Future<MediaMetadataDto> probe(String path);

  /// Start the import pipeline for a match, producing proxy, audio, and frames.
  ///
  /// Returns as soon as the job is admitted; the caller follows it with
  /// [jobStatus].
  Future<JobHandleDto> startArtifacts({
    required String matchId,
    required String originalPath,
    required String matchDir,
    required double samplingRate,
  });

  /// Read the manifest of a match, including which artifacts are missing.
  Future<ArtifactManifestDto> manifest(String matchDir);

  /// Derive the court geometry a marked segment defines, without storing it.
  ///
  /// Returns the mapping in both directions and the court outline and net to
  /// draw over the recording.
  Future<CourtGeometryDto> courtGeometry(CalibrationSegmentDto segment);

  /// Store a match's court calibration in its artifact directory.
  Future<CalibrationSaveDto> saveCalibration({
    required String matchDir,
    required CourtCalibrationDto calibration,
  });

  /// Read the court calibration stored for a match, when there is one.
  Future<CourtCalibrationDto?> matchCalibration(String matchDir);

  /// Start rebuilding derived artifacts that are recorded but missing.
  Future<JobHandleDto> startRegenerate(
    String matchDir, {
    required double samplingRate,
  });

  /// Read the current state of a job started through this engine.
  Future<JobStatusDto> jobStatus(String jobId);

  /// Ask a job started through this engine to stop.
  Future<JobStatusDto> jobCancel(String jobId);

  /// Start rendering a highlight video.
  Future<JobHandleDto> startExport(ExportRequestDto request);
}

/// [MediaEngine] backed by the engine client over the service protocol.
class EngineMediaEngine implements MediaEngine {
  /// Wrap an initialized engine.
  EngineMediaEngine(this._engine);

  final SportcutEngine _engine;

  @override
  String? get stateRoot => _engine.serviceStateRoot;

  @override
  Future<MediaMetadataDto> probe(String path) => _engine.probe(path);

  @override
  Future<JobHandleDto> startArtifacts({
    required String matchId,
    required String originalPath,
    required String matchDir,
    required double samplingRate,
  }) async {
    final original = await _stageOriginal(originalPath, matchId);
    return _engine.startImport(
      matchId: matchId,
      originalPath: original,
      matchDir: matchDir,
      samplingRate: samplingRate,
    );
  }

  @override
  Future<ArtifactManifestDto> manifest(String matchDir) =>
      _engine.matchManifest(matchDir);

  @override
  Future<CourtGeometryDto> courtGeometry(CalibrationSegmentDto segment) =>
      _engine.courtGeometry(segment);

  @override
  Future<CalibrationSaveDto> saveCalibration({
    required String matchDir,
    required CourtCalibrationDto calibration,
  }) =>
      _engine.saveCalibration(matchDir: matchDir, calibration: calibration);

  @override
  Future<CourtCalibrationDto?> matchCalibration(String matchDir) =>
      _engine.matchCalibration(matchDir);

  @override
  Future<JobHandleDto> startRegenerate(
    String matchDir, {
    required double samplingRate,
  }) =>
      _engine.startRegenerate(matchDir, samplingRate: samplingRate);

  @override
  Future<JobStatusDto> jobStatus(String jobId) => _engine.jobStatus(jobId);

  @override
  Future<JobStatusDto> jobCancel(String jobId) => _engine.jobCancel(jobId);

  @override
  Future<JobHandleDto> startExport(ExportRequestDto request) =>
      _engine.startExport(request);

  /// Give the service a readable copy of [originalPath], when it has none.
  ///
  /// `engine.import.start` accepts a recording only under the service's
  /// `recordings/` or `inbox/` roots. The development client owns the playback
  /// copy (ADR-0001 Phase 3), so a copy is placed in
  /// `<state-root>/recordings/<matchId>/` and kept: the manifest records it as
  /// the original, and regeneration reads it later. The file the user picked is
  /// never modified, and `deleteMatch(deleteRecording: true)` removes this copy.
  Future<String> _stageOriginal(String originalPath, String matchId) async {
    final root = stateRoot;
    if (root == null ||
        p.isWithin(p.join(root, 'inbox'), originalPath) ||
        p.isWithin(p.join(root, 'recordings'), originalPath)) {
      return originalPath;
    }
    final directory = Directory(p.join(root, 'recordings', matchId));
    await directory.create(recursive: true);
    final staged = p.join(directory.path, p.basename(originalPath));
    if (await File(staged).exists()) {
      return staged;
    }
    await File(originalPath).copy(staged);
    return staged;
  }
}
