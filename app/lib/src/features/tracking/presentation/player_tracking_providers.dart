import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../bridge/sportcut_engine.dart';
import '../../library/domain/match_record.dart';

/// Review state for one local player-track generation.
class PlayerTrackingState {
  const PlayerTrackingState({
    this.tracks,
    this.jobId,
    this.stage,
    this.progress = 0,
    this.running = false,
    this.loading = false,
    this.loaded = false,
    this.windowStart = 0,
    this.windowEnd = 0,
    this.problem,
  });

  final PlayerTracksDto? tracks;
  final String? jobId;
  final String? stage;
  final double progress;
  final bool running;
  final bool loading;
  final bool loaded;
  final double windowStart;
  final double windowEnd;
  final String? problem;

  PlayerTrackingState copyWith({
    PlayerTracksDto? tracks,
    String? jobId,
    String? stage,
    double? progress,
    bool? running,
    bool? loading,
    bool? loaded,
    double? windowStart,
    double? windowEnd,
    String? problem,
    bool clearTracks = false,
    bool clearProblem = false,
  }) =>
      PlayerTrackingState(
        tracks: clearTracks ? null : (tracks ?? this.tracks),
        jobId: jobId ?? this.jobId,
        stage: stage ?? this.stage,
        progress: progress ?? this.progress,
        running: running ?? this.running,
        loading: loading ?? this.loading,
        loaded: loaded ?? this.loaded,
        windowStart: windowStart ?? this.windowStart,
        windowEnd: windowEnd ?? this.windowEnd,
        problem: clearProblem ? null : (problem ?? this.problem),
      );
}

/// Starts analysis and reads small playback windows from its artifact.
class PlayerTrackingController extends Notifier<PlayerTrackingState> {
  static const Duration _pollInterval = Duration(milliseconds: 300);
  int _windowGeneration = 0;

  @override
  PlayerTrackingState build() => const PlayerTrackingState();

  Future<void> open(MatchRecord match) {
    state = const PlayerTrackingState(loading: true);
    return loadWindow(match, 0);
  }

  Future<void> loadWindow(MatchRecord match, double positionSeconds) async {
    if (match.durationSeconds <= 0) {
      state = state.copyWith(
        loaded: true,
        problem: 'The recording duration is unavailable.',
      );
      return;
    }
    final start = math.max(0.0, positionSeconds - 2.0);
    final end = math.min(match.durationSeconds, start + 5.0);
    if (end <= start) {
      return;
    }
    final generation = ++_windowGeneration;
    state = state.copyWith(loading: true, clearProblem: true);
    try {
      final tracks = await ref.read(sportcutEngineProvider).matchPlayerTracks(
            matchDir: match.matchDir,
            startSeconds: start,
            endSeconds: end,
          );
      if (generation != _windowGeneration) {
        return;
      }
      state = state.copyWith(
        tracks: tracks,
        clearTracks: tracks == null,
        windowStart: start,
        windowEnd: end,
        loaded: true,
        loading: false,
        clearProblem: true,
      );
    } on Object catch (error) {
      if (generation != _windowGeneration) {
        return;
      }
      state = state.copyWith(
        loaded: true,
        loading: false,
        clearTracks: true,
        problem: 'Player tracks could not be read: $error',
      );
    }
  }

  /// Run with provisional thresholds until representative footage tunes them.
  Future<void> analyze(MatchRecord match) async {
    if (state.running) {
      return;
    }
    state = state.copyWith(
      running: true,
      progress: 0,
      stage: null,
      clearTracks: true,
      clearProblem: true,
    );
    try {
      final engine = ref.read(sportcutEngineProvider);
      final handle = await engine.startPlayerTracking(
        matchDir: match.matchDir,
        config: const PlayerTrackingConfigDto(
          samplingRate: 5,
          minConfidence: 0.2,
          courtMargin: 0.04,
          netMargin: 0.05,
          maxTrackGapMs: 1200,
          maxFrameGapMs: 500,
          maxGroundSpeedPerSecond: 0.8,
          ambiguityMargin: 0.1,
          minTrackObservations: 3,
          minCountFrames: 5,
          minCountFraction: 0.7,
        ),
      );
      state = state.copyWith(jobId: handle.jobId);
      final status = await _follow(engine, handle.jobId);
      if (status.state == JobStateDto.cancelled) {
        state = state.copyWith(running: false, progress: 0);
        return;
      }
      if (status.state != JobStateDto.completed) {
        state = state.copyWith(
          running: false,
          problem: status.error ?? 'Player analysis could not finish.',
        );
        return;
      }
      state = state.copyWith(running: false, progress: 1, clearProblem: true);
      await loadWindow(match, 0);
    } on Object catch (error) {
      state = state.copyWith(
        running: false,
        problem: 'Player analysis is unavailable: $error',
      );
    }
  }

  Future<void> cancel() async {
    final jobId = state.jobId;
    if (jobId != null) {
      await ref.read(sportcutEngineProvider).jobCancel(jobId);
    }
  }

  Future<JobStatusDto> _follow(SportcutEngine engine, String jobId) async {
    while (true) {
      final status = await engine.jobStatus(jobId);
      state = state.copyWith(
        stage: status.stage ?? state.stage,
        progress: status.progress?.value ?? state.progress,
      );
      switch (status.state) {
        case JobStateDto.completed:
        case JobStateDto.cancelled:
        case JobStateDto.failed:
          return status;
        case JobStateDto.pending:
        case JobStateDto.running:
          await Future<void>.delayed(_pollInterval);
      }
    }
  }
}

final playerTrackingControllerProvider =
    NotifierProvider<PlayerTrackingController, PlayerTrackingState>(
  PlayerTrackingController.new,
);
