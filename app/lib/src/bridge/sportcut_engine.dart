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
/// final result = await SportcutEngine.instance.importMatch(
///   matchId: 'match-1',
///   originalPath: '/path/to/match.mp4',
///   matchDir: '/path/to/matches/match-1',
///   samplingRate: 2,
/// );
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
        JobProgressDto,
        JobStateDto,
        JobStatusDto,
        MediaImportRequestDto,
        MediaImportResultDto,
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

  /// Import a recording into [matchDir].
  ///
  /// The original file is referenced in place; nothing is copied. Re-importing
  /// a match whose stages are already checkpointed completes without redoing
  /// work, and an interrupted import resumes from its last completed stage.
  Future<MediaImportResultDto> importMatch({
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
        return rust.importMedia(request: request);
      });

  /// Read a match's manifest, including which artifacts are missing.
  Future<ArtifactManifestDto> matchManifest(String matchDir) =>
      _guard(() async => rust.matchManifest(matchDir: matchDir));

  /// Rebuild derived artifacts that are recorded but missing from disk.
  Future<ArtifactManifestDto> regenerateMatch(
    String matchDir, {
    double samplingRate = 1,
  }) =>
      _guard(() async => rust.regenerateMatchMedia(
            matchDir: matchDir,
            samplingRate: samplingRate,
          ));

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
