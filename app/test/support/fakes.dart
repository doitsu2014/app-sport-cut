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

  /// Match identifier passed to the last artifact call.
  String? lastMatchId;

  /// Job identifiers handed out by [startArtifacts], in order.
  final List<String> startedJobs = <String>[];

  /// State [jobStatus] reports for a started job.
  JobStateDto jobState = JobStateDto.completed;

  /// Reason [jobStatus] reports when [jobState] is failed.
  String? jobError;

  /// Number of status and cancel calls.
  int jobStatusCalls = 0;
  int jobCancelCalls = 0;

  /// Match directory passed to the last manifest call.
  String? lastManifestDir;

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
  Future<JobHandleDto> startArtifacts({
    required String matchId,
    required String originalPath,
    required String matchDir,
    required double samplingRate,
  }) async {
    artifactCalls += 1;
    lastMatchDir = matchDir;
    lastMatchId = matchId;
    final error = failure;
    if (error != null) {
      throw error;
    }
    final jobId = 'job-${startedJobs.length + 1}';
    startedJobs.add(jobId);
    return JobHandleDto(jobId: jobId, matchId: matchId);
  }

  @override
  Future<ArtifactManifestDto> manifest(String matchDir) async {
    lastManifestDir = matchDir;
    return ArtifactManifestDto(
      matchId: lastMatchId ?? 'match-1',
      originalPath: 'original.mp4',
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
    );
  }

  @override
  Future<JobHandleDto> startRegenerate(
    String matchDir, {
    required double samplingRate,
  }) async {
    lastMatchDir = matchDir;
    final error = failure;
    if (error != null) {
      throw error;
    }
    final jobId = 'job-${startedJobs.length + 1}';
    startedJobs.add(jobId);
    return JobHandleDto(jobId: jobId, matchId: lastMatchId ?? 'match-1');
  }

  @override
  Future<JobStatusDto> jobStatus(String jobId) async {
    jobStatusCalls += 1;
    return JobStatusDto(
      jobId: jobId,
      matchId: lastMatchId ?? 'match-1',
      state: jobState,
      stage: 'frames',
      progress: null,
      error: jobError,
      completedStages: const <String>['probe', 'proxy', 'audio', 'frames'],
    );
  }

  @override
  Future<JobStatusDto> jobCancel(String jobId) async {
    jobCancelCalls += 1;
    return jobStatus(jobId);
  }

  /// Export requests passed to [startExport].
  final List<ExportRequestDto> exportRequests = <ExportRequestDto>[];

  @override
  Future<JobHandleDto> startExport(ExportRequestDto request) async {
    lastMatchId = request.matchId;
    lastMatchDir = request.matchDir;
    final error = failure;
    if (error != null) {
      throw error;
    }
    exportRequests.add(request);
    final jobId = 'job-${startedJobs.length + 1}';
    startedJobs.add(jobId);
    return JobHandleDto(jobId: jobId, matchId: request.matchId);
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
