import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bridge/sportcut_engine.dart';
import '../../library/data/media_engine.dart';
import '../../library/domain/match_record.dart';
import '../../library/presentation/library_providers.dart';

/// Which engine job produces or repairs a match's analysis files.
enum AnalysisJobKind {
  /// First production of the proxy, analysis audio, and sampled frames.
  prepare,

  /// Rebuilding the files a manifest reports as missing.
  rebuild,
}

/// How the last analysis job ended, announced once by whoever listens.
class AnalysisOutcome {
  /// Describe a finished job.
  const AnalysisOutcome({
    required this.matchId,
    required this.title,
    required this.kind,
    required this.succeeded,
    this.message,
  });

  /// Match the job ran for.
  final String matchId;

  /// That match's title, for messages shown after the user moved on.
  final String title;

  /// Which job it was.
  final AnalysisJobKind kind;

  /// Whether the files were produced.
  final bool succeeded;

  /// Why it failed; `null` on success or cancellation.
  final String? message;
}

/// What the analysis screen shows.
///
/// The manifest belongs to the match being viewed; the job belongs to the
/// match it was started for. They differ when the user starts a job and then
/// opens another video, and the job keeps running in the background.
class AnalysisState {
  /// Describe an analysis view.
  const AnalysisState({
    this.matchId,
    this.manifest,
    this.jobId,
    this.jobKind,
    this.runningMatchId,
    this.runningTitle,
    this.stage,
    this.progress = 0,
    this.running = false,
    this.loaded = false,
    this.problem,
    this.lastOutcome,
  });

  /// Match whose manifest is shown.
  final String? matchId;

  /// The match's artifacts, once the manifest has been read.
  final ArtifactManifestDto? manifest;

  /// Job the engine is running, while it runs.
  final String? jobId;

  /// Which job is running.
  final AnalysisJobKind? jobKind;

  /// Match the running job belongs to.
  final String? runningMatchId;

  /// Title of that match.
  final String? runningTitle;

  /// Stage the engine last reported.
  final String? stage;

  /// Progress within that stage, in the range `0..1`.
  final double progress;

  /// Whether a job is in flight.
  final bool running;

  /// Whether the manifest has been read at least once.
  final bool loaded;

  /// Why the manifest could not be read, or a job failed.
  final String? problem;

  /// How the most recent job ended.
  final AnalysisOutcome? lastOutcome;

  /// Artifacts the manifest reports as gone.
  List<ArtifactDto> get missing => <ArtifactDto>[
        for (final artifact in manifest?.artifacts ?? const <ArtifactDto>[])
          if (artifact.state == ArtifactStateDto.missing) artifact,
      ];

  /// Whether the match has never had analysis files produced.
  bool get unprepared =>
      loaded && (manifest?.artifacts ?? const <ArtifactDto>[]).isEmpty;

  /// Whether a job is running for this match.
  bool runningFor(String matchId) => running && runningMatchId == matchId;

  /// Whether a job is running for a different match.
  bool busyElsewhere(String matchId) => running && runningMatchId != matchId;

  /// This state with the given fields replaced.
  AnalysisState copyWith({
    String? matchId,
    ArtifactManifestDto? manifest,
    String? jobId,
    AnalysisJobKind? jobKind,
    String? runningMatchId,
    String? runningTitle,
    String? stage,
    double? progress,
    bool? running,
    bool? loaded,
    String? problem,
    AnalysisOutcome? lastOutcome,
    bool clearManifest = false,
    bool clearProblem = false,
    bool clearStage = false,
  }) =>
      AnalysisState(
        matchId: matchId ?? this.matchId,
        manifest: clearManifest ? null : (manifest ?? this.manifest),
        jobId: jobId ?? this.jobId,
        jobKind: jobKind ?? this.jobKind,
        runningMatchId: runningMatchId ?? this.runningMatchId,
        runningTitle: runningTitle ?? this.runningTitle,
        stage: clearStage ? null : (stage ?? this.stage),
        progress: progress ?? this.progress,
        running: running ?? this.running,
        loaded: loaded ?? this.loaded,
        problem: clearProblem ? null : (problem ?? this.problem),
        lastOutcome: lastOutcome ?? this.lastOutcome,
      );
}

/// Reads a match's artifacts and drives producing or repairing them.
///
/// The controller is app-wide rather than owned by a screen, so a job keeps
/// being followed while the user switches features or videos.
class AnalysisController extends Notifier<AnalysisState> {
  /// How often the engine is asked how a job is going.
  static const Duration _pollInterval = Duration(milliseconds: 300);

  @override
  AnalysisState build() => const AnalysisState();

  /// Read the match's manifest.
  Future<void> open(MatchRecord match) async {
    if (state.matchId != match.id) {
      state = state.copyWith(
        matchId: match.id,
        loaded: false,
        clearManifest: true,
        // A problem belongs to the match it was reported for, unless it is the
        // running job's own failure, which is announced by its outcome.
        clearProblem: true,
      );
    }
    try {
      final manifest = await ref.read(mediaEngineProvider).manifest(
            match.matchDir,
          );
      if (state.matchId != match.id) {
        return; // the user opened another match while this one was read
      }
      state = state.copyWith(
        manifest: manifest,
        loaded: true,
        clearProblem: true,
      );
    } on Object catch (error) {
      if (state.matchId != match.id) {
        return;
      }
      state = state.copyWith(
        loaded: true,
        problem: 'This match\'s analysis files could not be read: $error',
      );
    }
  }

  /// Produce the proxy, analysis audio, and sampled frames for the first time.
  Future<void> prepare(MatchRecord match) => _runJob(
        match,
        AnalysisJobKind.prepare,
        (engine) => engine.startArtifacts(
          matchId: match.id,
          originalPath: match.videoPath,
          matchDir: match.matchDir,
          samplingRate: 1,
        ),
      );

  /// Rebuild the artifacts the manifest reports as missing.
  Future<void> repair(MatchRecord match) => _runJob(
        match,
        AnalysisJobKind.rebuild,
        (engine) => engine.startRegenerate(match.matchDir, samplingRate: 1),
      );

  /// Ask the engine to stop the running job.
  Future<void> cancel() async {
    final jobId = state.jobId;
    if (jobId == null || !state.running) {
      return;
    }
    await ref.read(mediaEngineProvider).jobCancel(jobId);
  }

  Future<void> _runJob(
    MatchRecord match,
    AnalysisJobKind kind,
    Future<JobHandleDto> Function(MediaEngine engine) start,
  ) async {
    if (state.running) {
      return; // the engine runs one heavy job at a time
    }
    state = state.copyWith(
      running: true,
      jobKind: kind,
      runningMatchId: match.id,
      runningTitle: match.title,
      progress: 0,
      clearStage: true,
      clearProblem: true,
    );

    final failurePrefix = kind == AnalysisJobKind.prepare
        ? 'The analysis files could not be prepared'
        : 'The analysis files could not be rebuilt';
    try {
      final engine = ref.read(mediaEngineProvider);
      final handle = await start(engine);
      state = state.copyWith(jobId: handle.jobId);

      final status = await _follow(engine, handle.jobId);
      switch (status.state) {
        case JobStateDto.cancelled:
          _finish(match, kind, succeeded: false);
        case JobStateDto.completed:
          _finish(match, kind, succeeded: true);
          if (state.matchId == match.id) {
            await open(match);
          }
        case JobStateDto.failed:
        case JobStateDto.pending:
        case JobStateDto.running:
          _finish(
            match,
            kind,
            succeeded: false,
            message: '$failurePrefix: '
                '${status.error ?? 'the engine did not say why.'}',
          );
      }
    } on Object catch (error) {
      _finish(match, kind, succeeded: false, message: '$failurePrefix: $error');
    }
  }

  void _finish(
    MatchRecord match,
    AnalysisJobKind kind, {
    required bool succeeded,
    String? message,
  }) {
    final shown = state.matchId == match.id;
    state = AnalysisState(
      matchId: state.matchId,
      manifest: state.manifest,
      loaded: state.loaded,
      progress: succeeded ? 1 : 0,
      problem: shown ? message : state.problem,
      lastOutcome: AnalysisOutcome(
        matchId: match.id,
        title: match.title,
        kind: kind,
        succeeded: succeeded,
        message: message,
      ),
    );
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

/// The analysis view and its job, shared across the studio.
final analysisControllerProvider =
    NotifierProvider<AnalysisController, AnalysisState>(AnalysisController.new);
