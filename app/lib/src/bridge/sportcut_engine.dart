/// The application's typed entry point to the engine.
///
/// The engine is a separate process. This file is the one place the app knows
/// that: it opens a [ServiceConnection] to the Sportcut service, sends the
/// protocol methods, and decodes the results into the model types in
/// `models.dart`. Everything above it — features, repositories, providers —
/// talks to this API and never to a socket.
///
/// There is no FFI here. The engine is not a shared library linked into the
/// app; see `docs/adr/0001-rust-background-service.md`.
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

import 'dart:io' show File, Platform;

import 'package:path/path.dart' as p;

import 'models.dart';
import 'protocol_client.dart';

export 'models.dart';

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
  SportcutEngine._(this._connection);

  static SportcutEngine? _instance;

  final ServiceConnection _connection;

  /// The initialized engine.
  ///
  /// Throws [StateError] when [initialize] has not completed, so a missing
  /// initialization surfaces at the call site instead of as a socket error.
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

  /// Connect to the engine service.
  ///
  /// Call once during startup, after `WidgetsFlutterBinding.ensureInitialized()`.
  /// The endpoint and token come from the environment; a packaged build will
  /// supply them by launching the service helper, which is ADR-0001 Phase 6.
  /// For development, start the service with `tools/run-service.sh` and export
  /// the endpoint and token it prints.
  static Future<SportcutEngine> initialize() async {
    final existing = _instance;
    if (existing != null) {
      return existing;
    }
    final target = await _resolveTarget();
    final connection = await ServiceConnection.open(
      endpoint: target.endpoint,
      token: target.token,
    );
    final engine = SportcutEngine._(connection);
    _instance = engine;
    return engine;
  }

  /// Where and how to reach the service.
  ///
  /// Resolution order: `--dart-define` values, then `SPORTCUT_ENDPOINT` with
  /// `SPORTCUT_TOKEN` or `SPORTCUT_TOKEN_FILE`, then a state root in
  /// `SPORTCUT_STATE_ROOT` using the layout `tools/run-service.sh` creates.
  static Future<({String endpoint, String token})> _resolveTarget() async {
    const defineEndpoint = String.fromEnvironment('SPORTCUT_ENDPOINT');
    const defineToken = String.fromEnvironment('SPORTCUT_TOKEN');
    if (defineEndpoint.isNotEmpty && defineToken.isNotEmpty) {
      return (endpoint: defineEndpoint, token: defineToken);
    }

    final environment = Platform.environment;
    final endpoint = environment['SPORTCUT_ENDPOINT'];
    final token = environment['SPORTCUT_TOKEN'];
    if (endpoint != null && endpoint.isNotEmpty && token != null && token.isNotEmpty) {
      return (endpoint: endpoint, token: token);
    }

    final tokenFile = environment['SPORTCUT_TOKEN_FILE'];
    if (endpoint != null && endpoint.isNotEmpty && tokenFile != null) {
      return (endpoint: endpoint, token: _readToken(tokenFile));
    }

    final stateRoot = environment['SPORTCUT_STATE_ROOT'];
    if (stateRoot != null && stateRoot.isNotEmpty) {
      return (
        endpoint: p.join(stateRoot, 'run', 's.sock'),
        token: _readToken(p.join(stateRoot, 'run', 'token')),
      );
    }

    throw SportcutEngineException(
      'No Sportcut service is configured. Start the service with '
      'tools/run-service.sh, then pass its endpoint and token with '
      '--dart-define=SPORTCUT_ENDPOINT=... --dart-define=SPORTCUT_TOKEN=..., '
      'or export SPORTCUT_ENDPOINT and SPORTCUT_STATE_ROOT.',
    );
  }

  static String _readToken(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw SportcutEngineException(
        'The service token file is missing at $path. Start the service with '
        'tools/run-service.sh and use the token it prints.',
      );
    }
    return file.readAsStringSync().trim();
  }

  /// Close the connection and release the engine. Mainly useful in tests.
  static Future<void> dispose() async {
    final engine = _instance;
    if (engine == null) {
      return;
    }
    _instance = null;
    await engine._connection.close();
  }

  /// Notifications pushed by the service, such as `job.progress`.
  Stream<ServiceNotification> get notifications => _connection.notifications;

  /// The ordered stages of a media import, for progress display.
  Future<List<String>> importStages() => _guard(() async {
        final result = await _connection.call('engine.importStages');
        final stages = result?['stages'];
        return stages is List ? stages.map((e) => e.toString()).toList() : const <String>[];
      });

  /// Read metadata from a local recording.
  Future<MediaMetadataDto> probe(String path) => _guard(() async {
        final result = await _connection.call('engine.probe', <String, dynamic>{
          'source': <String, dynamic>{'kind': 'path', 'value': path},
        });
        return MediaMetadataDto.fromJson(_requireObject(result, 'engine.probe'));
      });

  /// Start importing a recording into [matchDir].
  ///
  /// The service owns recording custody: it copies the selected file into its
  /// own store and the original is never modified. The call returns as soon as
  /// the job is admitted; follow it with [jobStatus] and read the match manifest
  /// once it reaches a terminal state. An interrupted import resumes from its
  /// last completed stage.
  Future<JobHandleDto> startImport({
    required String matchId,
    required String originalPath,
    required String matchDir,
    double samplingRate = 1,
  }) =>
      _guard(() async {
        final result = await _connection.call(
          'engine.import.start',
          <String, dynamic>{
            'matchId': matchId,
            'matchDir': matchDir,
            'originalPath': originalPath,
            'samplingRate': samplingRate,
          },
        );
        return JobHandleDto.fromJson(_requireObject(result, 'engine.import.start'));
      });

  /// Read a match's manifest, including which artifacts are missing.
  Future<ArtifactManifestDto> matchManifest(String matchDir) => _guard(() async {
        final result = await _connection.call(
          'engine.manifest',
          _matchParams(matchDir),
        );
        return ArtifactManifestDto.fromJson(_requireObject(result, 'engine.manifest'));
      });

  /// Derive the court geometry a marked segment defines.
  ///
  /// Nothing is stored. Call this while the user is still moving corners around
  /// to draw the projected court over the recording, and again to redisplay a
  /// calibration the application already holds.
  ///
  /// Throws [SportcutEngineException] when the corners cannot define a court.
  Future<CourtGeometryDto> courtGeometry(CalibrationSegmentDto segment) =>
      _guard(() async {
        final result = await _connection.call(
          'engine.court.geometry',
          <String, dynamic>{'segment': segment.toJson()},
        );
        return CourtGeometryDto.fromJson(
          _requireObject(result, 'engine.court.geometry'),
        );
      });

  /// Store a match's court calibration in its artifact directory.
  ///
  /// A calibration that differs from the one it replaces invalidates the
  /// artifacts derived from the previous court; the result names which.
  Future<CalibrationSaveDto> saveCalibration({
    required String matchDir,
    required CourtCalibrationDto calibration,
  }) =>
      _guard(() async {
        final result = await _connection.call(
          'engine.calibration.save',
          <String, dynamic>{
            ..._matchParams(matchDir),
            'calibration': calibration.toJson(),
          },
        );
        return CalibrationSaveDto.fromJson(
          _requireObject(result, 'engine.calibration.save'),
        );
      });

  /// Read the court calibration stored for a match.
  ///
  /// `null` when the match has never been calibrated.
  Future<CourtCalibrationDto?> matchCalibration(String matchDir) =>
      _guard(() async {
        final result = await _connection.call(
          'engine.calibration.get',
          _matchParams(matchDir),
        );
        return result == null ? null : CourtCalibrationDto.fromJson(result);
      });

  /// Start rebuilding the derived artifacts a match records but no longer has.
  Future<JobHandleDto> startRegenerate(
    String matchDir, {
    double samplingRate = 1,
  }) =>
      _guard(() async {
        final result = await _connection.call(
          'engine.regenerate.start',
          <String, dynamic>{
            ..._matchParams(matchDir),
            'samplingRate': samplingRate,
          },
        );
        return JobHandleDto.fromJson(
          _requireObject(result, 'engine.regenerate.start'),
        );
      });

  /// Start rally-boundary analysis from a completed local track artifact.
  ///
  /// The call reports an unavailable-input error while player tracking has not
  /// produced a supported artifact. [config] is explicit until representative
  /// footage establishes a supported preset.
  Future<JobHandleDto> startRallySegmentation({
    required String matchDir,
    required RallySegmentationConfigDto config,
  }) =>
      _guard(() async {
        final result = await _connection.call(
          'engine.rally.start',
          <String, dynamic>{
            ..._matchParams(matchDir),
            'config': config.toJson(),
          },
        );
        return JobHandleDto.fromJson(_requireObject(result, 'engine.rally.start'));
      });

  /// Read suggestions only when their tracks and thresholds are still current.
  Future<RallySuggestionsDto?> matchRallySuggestions({
    required String matchDir,
    required RallySegmentationConfigDto config,
  }) =>
      _guard(() async {
        final result = await _connection.call(
          'engine.rally.suggestions',
          <String, dynamic>{
            ..._matchParams(matchDir),
            'config': config.toJson(),
          },
        );
        return result == null ? null : RallySuggestionsDto.fromJson(result);
      });

  /// Read player observations in one playback window from final, current tracks.
  /// Returns `null` when the match has no track artifact yet.
  Future<PlayerTracksDto?> matchPlayerTracks({
    required String matchDir,
    required double startSeconds,
    required double endSeconds,
  }) =>
      _guard(() async {
        final result = await _connection.call(
          'engine.tracks.window',
          <String, dynamic>{
            ..._matchParams(matchDir),
            'startSeconds': startSeconds,
            'endSeconds': endSeconds,
          },
        );
        return result == null ? null : PlayerTracksDto.fromJson(result);
      });

  /// Start local player analysis.
  ///
  /// The inference runtime and model are service-owned: the service resolves
  /// them, and a request that names its own paths is rejected. [runtimePath] and
  /// [modelPath] are therefore ignored, and kept only so existing call sites
  /// compile while the tracking screen is simplified.
  Future<JobHandleDto> startPlayerTracking({
    required String matchDir,
    required PlayerTrackingConfigDto config,
    String? runtimePath,
    String? modelPath,
  }) =>
      _guard(() async {
        final result = await _connection.call(
          'engine.tracking.start',
          <String, dynamic>{
            ..._matchParams(matchDir),
            'config': config.toJson(),
          },
        );
        return JobHandleDto.fromJson(
          _requireObject(result, 'engine.tracking.start'),
        );
      });

  /// Read the current state of a job that was started earlier.
  Future<JobStatusDto> jobStatus(String jobId) => _guard(() async {
        final result = await _connection.call(
          'engine.job.status',
          <String, dynamic>{'jobId': jobId},
        );
        return JobStatusDto.fromJson(_requireObject(result, 'engine.job.status'));
      });

  /// Ask a started job to stop.
  ///
  /// Cancellation is cooperative, so the returned status may still be running.
  Future<JobStatusDto> jobCancel(String jobId) => _guard(() async {
        final result = await _connection.call(
          'engine.job.cancel',
          <String, dynamic>{'jobId': jobId},
        );
        return JobStatusDto.fromJson(_requireObject(result, 'engine.job.cancel'));
      });

  /// Derive who served each rally from the confirmed winners.
  ///
  /// The result is used to propose the server as a tentative winner on
  /// unscored rallies and to show who serves next on the scoreboard.
  Future<List<ServingSideDto>> servingSides(List<RallyOutcomeDto> rallies) =>
      _guard(() async {
        final result = await _connection.call(
          'engine.servingSides',
          <String, dynamic>{
            'rallies': rallies.map((rally) => rally.toJson()).toList(),
          },
        );
        return _decodeList(result, 'rallies', ServingSideDto.fromJson);
      });

  /// Rank rallies into a suggested highlight order.
  ///
  /// A pure, deterministic call over the signals the application already
  /// holds. Returns one score and rank per rally, best first.
  Future<List<HighlightRankDto>> rankHighlights(
    List<HighlightRallyDto> rallies,
  ) =>
      _guard(() async {
        final result = await _connection.call(
          'engine.highlight.rank',
          <String, dynamic>{
            'rallies': rallies.map((rally) => rally.toJson()).toList(),
          },
        );
        return _decodeList(result, 'rallies', HighlightRankDto.fromJson);
      });

  /// Start rendering a match's highlight video from an edit decision list.
  ///
  /// The list is built from the match's catalog records, so the engine never
  /// reads the application's database. Follow the returned job with [jobStatus]
  /// and read the match manifest once it reaches a terminal state.
  Future<JobHandleDto> startExport(ExportRequestDto request) => _guard(() async {
        final result = await _connection.call(
          'engine.export.start',
          request.toJson(),
        );
        return JobHandleDto.fromJson(_requireObject(result, 'engine.export.start'));
      });

  /// The service resolves a match from its identifier; the directory is a
  /// development affordance, so it is sent alongside the identifier.
  static Map<String, dynamic> _matchParams(String matchDir) => <String, dynamic>{
        'matchId': p.basename(matchDir),
        'matchDir': matchDir,
      };

  static Map<String, dynamic> _requireObject(
    Map<String, dynamic>? result,
    String method,
  ) {
    if (result == null) {
      throw SportcutEngineException('$method returned no result');
    }
    return result;
  }

  static List<T> _decodeList<T>(
    Map<String, dynamic>? result,
    String key,
    T Function(Map<String, dynamic>) decode,
  ) {
    final items = result?[key];
    if (items is! List) {
      return <T>[];
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(decode)
        .toList(growable: false);
  }

  /// Run an engine call, converting transport and protocol errors into one
  /// exception type.
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on ProtocolFailure catch (error) {
      throw SportcutEngineException(error.message);
    }
  }
}
