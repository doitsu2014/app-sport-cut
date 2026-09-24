/// The application's typed entry point to the Rust engine.
///
/// The files under `generated/` are produced by `tools/generate-bridge.sh` and
/// are not committed, so everything else in the app talks to the engine through
/// this file: one small surface, with engine errors converted into a single
/// exception type.
///
/// Typical use:
///
/// ```dart
/// await SportcutEngine.initialize();
/// final metadata = await SportcutEngine.instance.probe('/path/to/match.mp4');
 /// final job = await SportcutEngine.instance.startImport(
///   matchId: 'match-1',
///   originalPath: '/path/to/match.mp4',
///   matchDir: '/path/to/matches/match-1',
///   samplingRate: 2,
/// );
/// final status = await SportcutEngine.instance.jobStatus(job.jobId);
/// ```
library;

import 'package:flutter_rust_bridge/flutter_rust_bridge.dart'
    show AnyhowException, FrbException, PanicException;

import 'generated/dto.dart';
import 'generated/facade.dart' as rust;
import 'generated/frb_generated.dart';

export 'generated/dto.dart'
    show
        ArtifactDto,
        ArtifactManifestDto,
        ArtifactStateDto,
        CalibrationSaveDto,
        CalibrationSaveRequestDto,
        CalibrationSegmentDto,
        CourtCalibrationDto,
        CourtCornerDto,
        CourtGeometryDto,
        CourtOrientationDto,
        EditClipDto,
        EditTitleDto,
        ExportRequestDto,
        JobHandleDto,
        JobProgressDto,
        JobStateDto,
        JobStatusDto,
        MediaImportRequestDto,
        MediaMetadataDto,
        OrientationDto;

/// Raised when the engine rejects a request or fails while working on one.
///
/// The message comes from the engine and is meant to be shown to a user: it
/// names the file and the reason rather than an internal failure mode.
class SportcutEngineException implements Exception {
  /// Wrap an engine error message.
  SportcutEngineException(this.message);

  /// Human-readable reason reported by the engine.
  final String message;

  @override
  String toString() => 'SportcutEngineException: $message';
}

/// The engine, as the rest of the application sees it.
class SportcutEngine {
  SportcutEngine._();

  static SportcutEngine? _instance;

  /// The initialized engine.
  ///
  /// Throws [StateError] when [initialize] has not completed, so a missing
  /// initialization surfaces at the call site instead of as a native crash.
  static SportcutEngine get instance {
    final engine = _instance;
    if (engine == null) {
      throw StateError(
        'SportcutEngine.initialize() must complete before using the engine.',
      );
    }
    return engine;
  }

  /// Whether [initialize] has completed.
  static bool get isInitialized => _instance != null;

  /// Load the native engine and its bindings.
  ///
  /// Call once during startup, after `WidgetsFlutterBinding.ensureInitialized()`.
  /// The shared library is located by the generated loader configuration, so
  /// iOS, Android, and host-side tests all use the same call.
  static Future<SportcutEngine> initialize() async {
    final existing = _instance;
    if (existing != null) {
      return existing;
    }
    await RustLib.init();
    final engine = SportcutEngine._();
    _instance = engine;
    return engine;
  }

  /// Release the native engine. Mainly useful in tests.
  static Future<void> dispose() async {
    if (_instance == null) {
      return;
    }
    _instance = null;
    RustLib.dispose();
  }

  /// The ordered stages of a media import, for progress display.
  Future<List<String>> importStages() =>
      _guard(() async => rust.mediaImportStages());

  /// Read metadata from a local recording.
  Future<MediaMetadataDto> probe(String path) =>
      _guard(() async => rust.probeMedia(path: path));

  /// Start importing a recording into [matchDir].
  ///
  /// The recording is referenced in place; nothing is copied. The call returns
  /// as soon as the job is admitted: follow it with [jobStatus] and read the
  /// match manifest once it reaches a terminal state. Re-importing a match whose
  /// stages are already checkpointed completes without redoing work, and an
  /// interrupted import resumes from its last completed stage.
  Future<JobHandleDto> startImport({
    required String matchId,
    required String originalPath,
    required String matchDir,
    double samplingRate = 1,
  }) =>
      _guard(() async {
        final request = MediaImportRequestDto(
          matchId: matchId,
          originalPath: originalPath,
          matchDir: matchDir,
          samplingRate: samplingRate,
        );
        return rust.startImport(request: request);
      });

  /// Read a match's manifest, including which artifacts are missing.
  Future<ArtifactManifestDto> matchManifest(String matchDir) =>
      _guard(() async => rust.matchManifest(matchDir: matchDir));

  /// Derive the court geometry a marked segment defines.
  ///
  /// Nothing is stored. Call this while the user is still moving corners around
  /// to draw the projected court over the recording, and again to redisplay a
  /// calibration the application already holds. Returns the mapping in both
  /// directions as row-major nine-value matrices, together with the court outline
  /// and net in normalized image coordinates.
  ///
  /// Throws [SportcutEngineException] when the corners cannot define a court.
  Future<CourtGeometryDto> courtGeometry(CalibrationSegmentDto segment) =>
      _guard(() async => rust.courtGeometry(segment: segment));

  /// Store a match's court calibration in its artifact directory.
  ///
  /// A calibration that differs from the one it replaces invalidates the
  /// artifacts derived from the previous court; the result names which. Write
  /// the application's own catalog copy only after this call succeeds, so a
  /// calibration the catalog holds always has a matching artifact behind it.
  Future<CalibrationSaveDto> saveCalibration({
    required String matchDir,
    required CourtCalibrationDto calibration,
  }) =>
      _guard(() async {
        final request = CalibrationSaveRequestDto(
          matchDir: matchDir,
          calibration: calibration,
        );
        return rust.saveMatchCalibration(request: request);
      });

  /// Read the court calibration stored for a match.
  ///
  /// `null` when the match has never been calibrated.
  Future<CourtCalibrationDto?> matchCalibration(String matchDir) =>
      _guard(() async => rust.matchCalibration(matchDir: matchDir));

  /// Start rebuilding the derived artifacts a match records but no longer has.
  Future<JobHandleDto> startRegenerate(
    String matchDir, {
    double samplingRate = 1,
  }) =>
      _guard(() async => rust.startRegenerateMatchMedia(
            matchDir: matchDir,
            samplingRate: samplingRate,
          ));

  /// Read the current state of a job that was started earlier.
  Future<JobStatusDto> jobStatus(String jobId) =>
      _guard(() async => rust.jobStatus(jobId: jobId));

  /// Ask a started job to stop.
  ///
  /// Cancellation is cooperative, so the returned status may still be running.
  Future<JobStatusDto> jobCancel(String jobId) =>
      _guard(() async => rust.jobCancel(jobId: jobId));

  /// Start rendering a match's highlight video from an edit decision list.
  ///
  /// The list is built from the match's catalog records, so the engine never
  /// reads the application's database. Follow the returned job with [jobStatus]
  /// and read the match manifest once it reaches a terminal state.
  Future<JobHandleDto> startExport(ExportRequestDto request) =>
      _guard(() async => rust.exportHighlight(request: request));

  /// Run an engine call, converting engine errors into one exception type.
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on AnyhowException catch (error) {
      throw SportcutEngineException(error.message);
    } on PanicException catch (error) {
      throw SportcutEngineException('the engine panicked: ${error.message}');
    } on FrbException catch (error) {
      throw SportcutEngineException(error.toString());
    }
  }
}
