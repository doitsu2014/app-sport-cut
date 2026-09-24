import '../../../bridge/sportcut_engine.dart';

/// What the library needs from the engine.
///
/// The screen layer depends on this interface rather than on
/// [SportcutEngine] directly, so widget and repository tests can run without
/// loading the native library.
abstract interface class MediaEngine {
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

/// [MediaEngine] backed by the real engine across the bridge.
class BridgeMediaEngine implements MediaEngine {
  /// Wrap an initialized engine.
  BridgeMediaEngine(this._engine);

  final SportcutEngine _engine;

  @override
  Future<MediaMetadataDto> probe(String path) => _engine.probe(path);

  @override
  Future<JobHandleDto> startArtifacts({
    required String matchId,
    required String originalPath,
    required String matchDir,
    required double samplingRate,
  }) =>
      _engine.startImport(
        matchId: matchId,
        originalPath: originalPath,
        matchDir: matchDir,
        samplingRate: samplingRate,
      );

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
}
