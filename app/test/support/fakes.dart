/// Shared test doubles for the client tests.
library;

import 'dart:async';

import 'package:sportcut/src/bridge/sportcut_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sportcut/src/features/library/data/media_engine.dart';
import 'package:sportcut/src/features/library/data/video_file_picker.dart';
import 'package:sportcut/src/features/library/presentation/playback_controller.dart';

/// Engine double returning canned metadata, or throwing a chosen error.
class FakeMediaEngine implements MediaEngine {
  /// Build the double.
  FakeMediaEngine({this.failure, this.durationSeconds = 90.5});

  /// Error thrown by every call, when set.
  final Object? failure;

  /// Duration reported by [probe].
  final double durationSeconds;

  /// Number of probe calls.
  int probeCalls = 0;

  /// Number of artifact-generation calls.
  int artifactCalls = 0;

  /// Match directory passed to the last artifact call.
  String? lastMatchDir;

  @override
  Future<MediaMetadataDto> probe(String path) async {
    probeCalls += 1;
    final error = failure;
    if (error != null) {
      throw error;
    }
    return MediaMetadataDto(
      path: path,
      durationSeconds: durationSeconds,
      frameRate: 30,
      width: 1920,
      height: 1080,
      rotationDegrees: 0,
      orientation: OrientationDto.landscape,
      hasAudio: true,
      sizeBytes: BigInt.from(1024),
    );
  }

  @override
  Future<MediaImportResultDto> generateArtifacts({
    required String matchId,
    required String originalPath,
    required String matchDir,
    required double samplingRate,
  }) async {
    artifactCalls += 1;
    lastMatchDir = matchDir;
    final error = failure;
    if (error != null) {
      throw error;
    }
    return MediaImportResultDto(
      metadata: await probe(originalPath),
      manifest: ArtifactManifestDto(
        matchId: matchId,
        originalPath: originalPath,
        artifacts: <ArtifactDto>[
          ArtifactDto(
            kind: 'proxy',
            relativePath: 'proxy/proxy.mp4',
            state: ArtifactStateDto.final_,
            sizeBytes: BigInt.from(2048),
          ),
        ],
        missingKinds: const <String>[],
        originalPresent: true,
      ),
      job: JobStatusDto(
        jobId: 'job-1',
        matchId: matchId,
        state: JobStateDto.completed,
        stage: 'frames',
        progress: null,
        error: null,
        completedStages: const <String>['probe', 'proxy', 'audio', 'frames'],
      ),
      framesSampled: 45,
      skippedStages: const <String>[],
    );
  }

  @override
  Future<ArtifactManifestDto> manifest(String matchDir) async {
    throw UnimplementedError('manifest is not used in these tests');
  }

  @override
  Future<ArtifactManifestDto> regenerate(
    String matchDir, {
    required double samplingRate,
  }) async {
    throw UnimplementedError('regenerate is not used in these tests');
  }
}

/// Picker double returning a scripted result.
class FakeVideoFilePicker implements VideoFilePicker {
  /// Result returned by [pickVideo]; `null` means the user cancelled.
  PickedVideo? result;

  /// Error thrown instead of returning a result, when set.
  Object? failure;

  /// When set, [pickVideo] waits for this to complete before returning, so a
  /// test can observe the library while a pick is still in flight.
  Completer<void>? gate;

  /// Number of pick attempts.
  int calls = 0;

  @override
  Future<PickedVideo?> pickVideo() async {
    calls += 1;
    final gate = this.gate;
    if (gate != null) {
      await gate.future;
    }
    final error = failure;
    if (error != null) {
      throw error;
    }
    return result;
  }
}

/// Playback double: records what the screen asked for and moves through the
/// states the real controller would.
class FakePlaybackController implements PlaybackController {
  /// Message reported as a load failure, when set.
  String? errorMessage;

  /// Paths passed to [load], in order.
  final List<String> loaded = <String>[];

  /// Number of play and pause calls.
  int playCalls = 0;
  int pauseCalls = 0;

  /// Last position passed to [seek].
  Duration? lastSeek;

  /// Whether [dispose] has been called.
  bool disposed = false;

  final ValueNotifier<PlaybackState> _state =
      ValueNotifier<PlaybackState>(const PlaybackState());

  @override
  ValueListenable<PlaybackState> get state => _state;

  @override
  Future<void> load(String path) async {
    loaded.add(path);
    final message = errorMessage;
    if (message != null) {
      _state.value = PlaybackState(error: message);
      return;
    }
    _state.value = const PlaybackState(
      isReady: true,
      duration: Duration(seconds: 90),
    );
  }

  @override
  Widget buildSurface(BuildContext context) => const ColoredBox(
        color: Color(0xFF101010),
        child: SizedBox.expand(key: Key('fake-playback-surface')),
      );

  @override
  Future<void> play() async {
    playCalls += 1;
    _state.value = PlaybackState(
      isReady: true,
      isPlaying: true,
      position: _state.value.position,
      duration: _state.value.duration,
    );
  }

  @override
  Future<void> pause() async {
    pauseCalls += 1;
    _state.value = PlaybackState(
      isReady: true,
      isPlaying: false,
      position: _state.value.position,
      duration: _state.value.duration,
    );
  }

  @override
  Future<void> seek(Duration position) async {
    lastSeek = position;
    _state.value = PlaybackState(
      isReady: true,
      isPlaying: _state.value.isPlaying,
      position: position,
      duration: _state.value.duration,
    );
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    _state.dispose();
  }
}
