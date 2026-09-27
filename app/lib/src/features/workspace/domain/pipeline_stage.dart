/// The stages of the analysis pipeline, in the order the user works through
/// them on a video.
enum PipelineStage { import, calibrate, analyze, track, score, highlight, export }

/// Human-readable label for a pipeline stage.
extension PipelineStageInfo on PipelineStage {
  /// What the toolbar shows for this stage.
  String get label => switch (this) {
        PipelineStage.import => 'Import',
        PipelineStage.calibrate => 'Mark court',
        PipelineStage.analyze => 'Prepare analysis',
        PipelineStage.track => 'Player analysis',
        PipelineStage.score => 'Review & score',
        PipelineStage.highlight => 'Highlights',
        PipelineStage.export => 'Export',
      };
}

/// Whether a stage is done, can be done now, or needs an earlier stage first.
enum StageState { done, ready, blocked }

/// Everything the toolbar needs to know about one video, gathered once per
/// workspace view rather than once per rebuild.
class VideoStageFacts {
  /// Gather one video's progress.
  const VideoStageFacts({
    required this.recordingAvailable,
    required this.calibrated,
    required this.analysisReady,
    required this.tracksReady,
    required this.exportReady,
    required this.hasScore,
    required this.hasSelectedClips,
  });

  /// Whether the app-owned recording copy can still be read.
  final bool recordingAvailable;

  /// Whether the court has been marked.
  final bool calibrated;

  /// Whether the analysis artifacts (sampled frames) are final.
  final bool analysisReady;

  /// Whether the player tracks artifact is final.
  final bool tracksReady;

  /// Whether an export artifact is final.
  final bool exportReady;

  /// Whether any rally has been scored.
  final bool hasScore;

  /// Whether the user has kept at least one selected clip.
  final bool hasSelectedClips;
}

/// Resolve each stage's state for one video.
///
/// A stage is `done` when its output exists, `ready` when its prerequisite is
/// satisfied but the output does not exist, and `blocked` otherwise. A missing
/// recording blocks every stage after import.
Map<PipelineStage, StageState> resolveStageStates(VideoStageFacts facts) {
  final available = facts.recordingAvailable;
  return <PipelineStage, StageState>{
    PipelineStage.import: StageState.done,
    PipelineStage.calibrate: _state(done: facts.calibrated, prereq: available),
    PipelineStage.analyze: _state(
      done: facts.analysisReady,
      prereq: available && facts.calibrated,
    ),
    PipelineStage.track: _state(
      done: facts.tracksReady,
      prereq: available && facts.analysisReady,
    ),
    PipelineStage.score: _state(
      done: facts.hasScore,
      prereq: available && facts.tracksReady,
    ),
    PipelineStage.highlight: _state(
      done: facts.hasSelectedClips,
      prereq: available && facts.tracksReady,
    ),
    PipelineStage.export: _state(
      done: facts.exportReady,
      prereq: available && facts.hasSelectedClips,
    ),
  };
}

/// The first stage the user can act on now, or `null` when none is ready.
PipelineStage? nextStage(Map<PipelineStage, StageState> states) {
  for (final stage in PipelineStage.values) {
    if (states[stage] == StageState.ready) {
      return stage;
    }
  }
  return null;
}

StageState _state({required bool done, required bool prereq}) {
  if (done) {
    return StageState.done;
  }
  return prereq ? StageState.ready : StageState.blocked;
}
