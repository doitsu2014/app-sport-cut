import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../bridge/sportcut_engine.dart';
import '../../editing/domain/suggestion_decision.dart';
import '../../editing/presentation/editing_providers.dart';
import '../../library/domain/match_record.dart';

/// A tuned analysis configuration, once representative footage establishes it.
///
/// Until then the manual review remains available and the analysis control is
/// unavailable. The future tracking integration can provide this value without
/// putting threshold sliders in the user's review flow.
final rallySegmentationConfigProvider = Provider<RallySegmentationConfigDto?>(
  (ref) => null,
);

/// The local analysis result and the decisions made about its candidates.
class RallyReviewState {
  /// Describe a review session.
  const RallyReviewState({
    this.match,
    this.suggestions,
    this.decisions = const <String, SuggestionDecision>{},
    this.running = false,
    this.busy = false,
    this.progress = 0,
    this.stage,
    this.jobId,
    this.loaded = false,
    this.problem,
  });

  /// Match currently being reviewed.
  final MatchRecord? match;

  /// Completed suggestions for the current inputs, when available.
  final RallySuggestionsDto? suggestions;

  /// User decisions in the current generation, keyed by candidate ID.
  final Map<String, SuggestionDecision> decisions;

  /// Whether a segmentation job is in flight.
  final bool running;

  /// Whether a review decision is being written.
  final bool busy;

  /// Progress within the current stage.
  final double progress;

  /// Current or last engine stage label.
  final String? stage;

  /// Job to cancel, while one exists.
  final String? jobId;

  /// Whether initial loading has finished.
  final bool loaded;

  /// Nonfatal input or analysis problem.
  final String? problem;

  /// Visible candidates that the user has not accepted or dismissed.
  List<RallySuggestionDto> get pending => <RallySuggestionDto>[
        for (final candidate
            in suggestions?.candidates ?? const <RallySuggestionDto>[])
          if (!decisions.containsKey(candidate.id)) candidate,
      ];

  /// Replace fields after an operation.
  RallyReviewState copyWith({
    MatchRecord? match,
    RallySuggestionsDto? suggestions,
    Map<String, SuggestionDecision>? decisions,
    bool? running,
    bool? busy,
    double? progress,
    String? stage,
    String? jobId,
    bool? loaded,
    String? problem,
    bool clearSuggestions = false,
    bool clearJob = false,
    bool clearProblem = false,
  }) =>
      RallyReviewState(
        match: match ?? this.match,
        suggestions:
            clearSuggestions ? null : (suggestions ?? this.suggestions),
        decisions: decisions ?? this.decisions,
        running: running ?? this.running,
        busy: busy ?? this.busy,
        progress: progress ?? this.progress,
        stage: stage ?? this.stage,
        jobId: clearJob ? null : (jobId ?? this.jobId),
        loaded: loaded ?? this.loaded,
        problem: clearProblem ? null : (problem ?? this.problem),
      );
}

/// Drives analysis and explicit review without writing a score or reel clip.
class RallyReviewController extends Notifier<RallyReviewState> {
  static const Duration _pollInterval = Duration(milliseconds: 300);

  @override
  RallyReviewState build() => const RallyReviewState();

  /// Open the current generation, if the feature has usable inputs.
  Future<void> open(MatchRecord match) async {
    state = RallyReviewState(match: match);
    await _reload(match);
  }

  /// Start a local segmentation job and follow it to a terminal state.
  Future<void> analyze() async {
    final match = state.match;
    final config = ref.read(rallySegmentationConfigProvider);
    if (match == null || config == null || state.running) {
      return;
    }
    state = state.copyWith(
      running: true,
      progress: 0,
      clearJob: true,
      clearProblem: true,
    );
    try {
      final engine = ref.read(sportcutEngineProvider);
      final handle = await engine.startRallySegmentation(
        matchDir: match.matchDir,
        config: config,
      );
      state = state.copyWith(jobId: handle.jobId);
      while (true) {
        final status = await engine.jobStatus(handle.jobId);
        if (state.match?.id != match.id) {
          return;
        }
        state = state.copyWith(
          stage: status.stage,
          progress: status.progress?.value ?? state.progress,
        );
        switch (status.state) {
          case JobStateDto.completed:
            state = state.copyWith(running: false, clearJob: true);
            await _reload(match);
            return;
          case JobStateDto.cancelled:
            state = state.copyWith(running: false, clearJob: true);
            return;
          case JobStateDto.failed:
            state = state.copyWith(
              running: false,
              clearJob: true,
              problem: status.error ?? 'Rally analysis could not finish.',
            );
            return;
          case JobStateDto.pending:
          case JobStateDto.running:
            await Future<void>.delayed(_pollInterval);
        }
      }
    } on Object catch (error) {
      state = state.copyWith(
        running: false,
        clearJob: true,
        problem: 'Rally analysis is unavailable: $error',
      );
    }
  }

  /// Ask a running analysis job to stop.
  Future<void> cancel() async {
    final jobId = state.jobId;
    if (jobId != null) {
      await ref.read(sportcutEngineProvider).jobCancel(jobId);
    }
  }

  /// Accept a proposal, using adjusted boundaries when supplied.
  Future<void> accept(
    RallySuggestionDto candidate, {
    double? startSeconds,
    double? endSeconds,
  }) async {
    final match = state.match;
    final generationId = state.suggestions?.generationId;
    if (match == null ||
        generationId == null ||
        state.busy ||
        !state.pending.any((item) => item.id == candidate.id)) {
      return;
    }
    state = state.copyWith(busy: true, clearProblem: true);
    try {
      final editing = await ref.read(matchEditingProvider.future);
      await editing.acceptSuggestion(
        match,
        generationId: generationId,
        candidateId: candidate.id,
        startSeconds: startSeconds ?? candidate.startSeconds,
        endSeconds: endSeconds ?? candidate.endSeconds,
      );
      await ref.read(editingControllerProvider.notifier).open(match);
      await _reload(match);
    } on Object catch (error) {
      state = state.copyWith(
        busy: false,
        problem: 'That suggested rally could not be accepted: $error',
      );
    }
  }

  /// Dismiss a proposal only for this input generation.
  Future<void> dismiss(RallySuggestionDto candidate) async {
    final match = state.match;
    final generationId = state.suggestions?.generationId;
    if (match == null ||
        generationId == null ||
        state.busy ||
        !state.pending.any((item) => item.id == candidate.id)) {
      return;
    }
    state = state.copyWith(busy: true, clearProblem: true);
    try {
      final editing = await ref.read(matchEditingProvider.future);
      await editing.dismissSuggestion(
        match,
        generationId: generationId,
        candidateId: candidate.id,
      );
      await _reload(match);
    } on Object catch (error) {
      state = state.copyWith(
        busy: false,
        problem: 'That suggestion could not be dismissed: $error',
      );
    }
  }

  Future<void> _reload(MatchRecord match) async {
    if (state.match?.id != match.id) {
      return;
    }
    final config = ref.read(rallySegmentationConfigProvider);
    if (config == null) {
      state = state.copyWith(
        loaded: true,
        busy: false,
        clearSuggestions: true,
        decisions: const <String, SuggestionDecision>{},
        problem: 'Rally suggestions are waiting for player tracking and '
            'validated analysis settings. Manual marking is available.',
      );
      return;
    }
    try {
      final suggestions =
          await ref.read(sportcutEngineProvider).matchRallySuggestions(
                matchDir: match.matchDir,
                config: config,
              );
      final decisions = suggestions == null
          ? const <SuggestionDecision>[]
          : await (await ref.read(matchEditingProvider.future))
              .suggestionDecisions(
              match,
              generationId: suggestions.generationId,
            );
      state = state.copyWith(
        suggestions: suggestions,
        clearSuggestions: suggestions == null,
        decisions: <String, SuggestionDecision>{
          for (final decision in decisions) decision.candidateId: decision,
        },
        loaded: true,
        busy: false,
        clearProblem: true,
      );
    } on Object catch (error) {
      state = state.copyWith(
        loaded: true,
        busy: false,
        clearSuggestions: true,
        problem: 'Rally suggestions are unavailable: $error',
      );
    }
  }
}

/// The review state for the currently opened match.
final rallyReviewControllerProvider =
    NotifierProvider<RallyReviewController, RallyReviewState>(
  RallyReviewController.new,
);
