import '../../../bridge/sportcut_engine.dart';

/// What the library needs from the engine.
///
/// The screen layer depends on this interface rather than on
/// [SportcutEngine] directly, so widget and repository tests can run without
/// loading the native library.
abstract interface class MediaEngine {
  /// Read metadata from a recording.
  Future<MediaMetadataDto> probe(String path);

  /// Run the import pipeline for a match, producing proxy, audio, and frames.
  Future<MediaImportResultDto> generateArtifacts({
    required String matchId,
    required String originalPath,
    required String matchDir,
    required double samplingRate,
  });

  /// Read the manifest of a match, including which artifacts are missing.
  Future<ArtifactManifestDto> manifest(String matchDir);

  /// Rebuild derived artifacts that are recorded but missing.
  Future<ArtifactManifestDto> regenerate(
    String matchDir, {
    required double samplingRate,
  });
}

/// [MediaEngine] backed by the real engine across the bridge.
class BridgeMediaEngine implements MediaEngine {
  /// Wrap an initialized engine.
  BridgeMediaEngine(this._engine);

  final SportcutEngine _engine;

  @override
  Future<MediaMetadataDto> probe(String path) => _engine.probe(path);

  @override
  Future<MediaImportResultDto> generateArtifacts({
    required String matchId,
    required String originalPath,
    required String matchDir,
    required double samplingRate,
  }) =>
      _engine.importMatch(
        matchId: matchId,
        originalPath: originalPath,
        matchDir: matchDir,
        samplingRate: samplingRate,
      );

  @override
  Future<ArtifactManifestDto> manifest(String matchDir) =>
      _engine.matchManifest(matchDir);

  @override
  Future<ArtifactManifestDto> regenerate(
    String matchDir, {
    required double samplingRate,
  }) =>
      _engine.regenerateMatch(matchDir, samplingRate: samplingRate);
}
