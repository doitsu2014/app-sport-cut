import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bridge/sportcut_engine.dart';
import '../../library/data/media_engine.dart';
import '../../library/domain/match_record.dart';
import '../../library/presentation/library_providers.dart';

/// What the analysis screen shows.
class AnalysisState {
  /// Describe an analysis view.
  const AnalysisState({
    this.manifest,
    this.jobId,
    this.stage,
    this.progress = 0,
    this.running = false,
    this.loaded = false,
    this.problem,
  });

  /// The match's artifacts, once the manifest has been read.
  final ArtifactManifestDto? manifest;

  /// Job the engine is running, while it runs.
  final String? jobId;

  /// Stage the engine last reported.
  final String? stage;

  /// Progress within that stage, in the range `0..1`.
  final double progress;

  /// Whether a repair is in flight.
  final bool running;

  /// Whether the manifest has been read at least once.
  final bool loaded;

  /// Why the manifest could not be read, or a repair failed.
  final String? problem;

  /// Artifacts the manifest reports as gone.
  List<ArtifactDto> get missing => <ArtifactDto>[
        for (final artifact in manifest?.artifacts ?? const <ArtifactDto>[])
          if (artifact.state == ArtifactStateDto.missing) artifact,
      ];

  /// This state with the given fields replaced.
  AnalysisState copyWith({
    ArtifactManifestDto? manifest,
    String? jobId,
    String? stage,
    double? progress,
    bool? running,
    bool? loaded,
    String? problem,
    bool clearProblem = false,
  }) =>
      AnalysisState(
        manifest: manifest ?? this.manifest,
        jobId: jobId ?? this.jobId,
        stage: stage ?? this.stage,
        progress: progress ?? this.progress,
        running: running ?? this.running,
        loaded: loaded ?? this.loaded,
        problem: clearProblem ? null : (problem ?? this.problem),
      );
}

/// Reads a match's artifacts and drives repairing them.
class AnalysisController extends Notifier<AnalysisState> {
  /// How often the engine is asked how a repair is going.
  static const Duration _pollInterval = Duration(milliseconds: 300);

  @override
  AnalysisState build() => const AnalysisState();

  /// Read the match's manifest.
  Future<void> open(MatchRecord match) async {
    try {
      final manifest = await ref.read(mediaEngineProvider).manifest(
            match.matchDir,
          );
      state = state.copyWith(
        manifest: manifest,
        loaded: true,
        clearProblem: true,
      );
    } on Object catch (error) {
      state = state.copyWith(
        loaded: true,
        problem: 'This match\'s analysis files could not be read: $error',
      );
    }
  }

  /// Rebuild the artifacts the manifest reports as missing.
  Future<void> repair(MatchRecord match) async {
    if (state.running) {
      return;
    }
    state = state.copyWith(
      running: true,
      progress: 0,
      stage: null,
      clearProblem: true,
    );

    try {
      final engine = ref.read(mediaEngineProvider);
      final handle = await engine.startRegenerate(match.matchDir, samplingRate: 1);
      state = state.copyWith(jobId: handle.jobId);

      final status = await _follow(engine, handle.jobId);
      if (status.state == JobStateDto.cancelled) {
        state = state.copyWith(running: false, progress: 0);
        return;
      }
      if (status.state != JobStateDto.completed) {
        state = state.copyWith(
          running: false,
          problem: status.error ??
              'The analysis files could not be rebuilt: the engine did not '
                  'say why.',
        );
        return;
      }

      final manifest = await engine.manifest(match.matchDir);
      state = state.copyWith(
        manifest: manifest,
        running: false,
        progress: 1,
        clearProblem: true,
      );
    } on Object catch (error) {
      state = state.copyWith(
        running: false,
        problem: 'The analysis files could not be rebuilt: $error',
      );
    }
  }

  /// Ask the engine to stop repairing.
  Future<void> cancel() async {
    final jobId = state.jobId;
    if (jobId == null) {
      return;
    }
    await ref.read(mediaEngineProvider).jobCancel(jobId);
  }

  Future<JobStatusDto> _follow(MediaEngine engine, String jobId) async {
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

/// The analysis view in flight.
final analysisControllerProvider =
    NotifierProvider<AnalysisController, AnalysisState>(AnalysisController.new);
