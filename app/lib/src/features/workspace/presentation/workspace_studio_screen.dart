import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analysis/presentation/analysis_providers.dart';
import '../../editing/domain/match_edit.dart';
import '../../editing/presentation/editing_providers.dart';
import '../../library/domain/match_record.dart';
import '../../library/presentation/import_controller.dart';
import '../../library/presentation/library_providers.dart';
import '../../library/presentation/match_list_entry.dart';
import '../../library/presentation/playback_controller.dart';
import '../domain/pipeline_stage.dart';
import '../domain/workspace.dart';
import 'studio/inspector_pane.dart';
import 'studio/preview_pane.dart';
import 'studio/studio_dialogs.dart';
import 'studio/studio_status_bar.dart';
import 'studio/studio_toolbar.dart';
import 'studio/video_rail.dart';
import 'workspace_providers.dart';

/// The three-pane workspace studio.
///
/// Videos on the left, one shared preview in the center, and the features as a
/// vertical rail on the right. The studio owns one playback controller per
/// selected video and hands it to whichever feature view is showing, so Play
/// and Calibrate share a seamless preview. Features that are not yet embedded
/// keep opening their existing full-screen route.
class WorkspaceStudioScreen extends ConsumerStatefulWidget {
  /// Build the studio for a workspace.
  const WorkspaceStudioScreen({super.key, required this.workspace});

  /// The workspace whose videos are shown.
  final Workspace workspace;

  @override
  ConsumerState<WorkspaceStudioScreen> createState() =>
      _WorkspaceStudioScreenState();
}

class _WorkspaceStudioScreenState extends ConsumerState<WorkspaceStudioScreen> {
  /// The shared player for the selected video.
  PlaybackController? _controller;

  /// The selected video, or null until the first video is chosen.
  String? _selectedVideoId;

  /// The selected feature, where null means playback.
  PipelineStage? _selectedStage;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videos = ref.watch(workspaceVideosProvider(widget.workspace.id));
    final import = ref.watch(importControllerProvider);
    final analysis = ref.watch(analysisControllerProvider);
    final facts =
        ref.watch(workspaceVideoFactsProvider(widget.workspace.id)).value;
    final loadedEntries = videos.value;
    final selectedEntry =
        loadedEntries == null ? null : _selectedEntry(loadedEntries);
    final missingCount = loadedEntries == null
        ? 0
        : loadedEntries.where((entry) => !entry.recordingAvailable).length;

    // Preparing analysis runs in the background; announce how it ended, even
    // if the user has moved to another feature or video, and refresh the rail.
    ref.listen(analysisControllerProvider, (previous, next) {
      final outcome = next.lastOutcome;
      if (outcome == null || identical(outcome, previous?.lastOutcome)) {
        return;
      }
      _refresh();
      final what = outcome.kind == AnalysisJobKind.prepare
          ? 'Preparing analysis'
          : 'Rebuilding analysis files';
      final message = outcome.succeeded
          ? 'Analysis files ready for ${outcome.title}'
          : outcome.message ?? '$what for ${outcome.title} was stopped';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    });

    // Scoring the first rally flips Review & score from ready to done, and
    // keeping the first clip flips Export; refresh the stage facts so the rail
    // shows the check rather than a stale state.
    ref.listen(editingControllerProvider, (previous, next) {
      if (_editHasScore(previous?.edit) != _editHasScore(next.edit) ||
          _editHasClips(previous?.edit) != _editHasClips(next.edit)) {
        _refresh();
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: Column(
        children: <Widget>[
          StudioToolbar(
            workspace: widget.workspace,
            videoCount: loadedEntries?.length ?? 0,
            importRunning: import.isRunning,
            showImport: loadedEntries == null || loadedEntries.isNotEmpty,
            onBack: () {
              Navigator.of(context).maybePop();
            },
            onImport: _import,
            onDelete: _confirmDeleteWorkspace,
          ),
          if (import.isRunning)
            ImportProgress(
              description: import.description,
              onCancel: () =>
                  ref.read(importControllerProvider.notifier).cancel(),
            ),
          Expanded(
            child: videos.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => StudioError(
                message: '$error',
                onRetry: () => ref.invalidate(
                  workspaceVideosProvider(widget.workspace.id),
                ),
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return EmptyStudio(
                    importRunning: import.isRunning,
                    onImport: _import,
                  );
                }
                _ensureSelection(entries);
                final selected = _selectedEntry(entries);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    VideoRail(
                      entries: entries,
                      selectedId: _selectedVideoId,
                      busyId: analysis.running ? analysis.runningMatchId : null,
                      onSelect: (entry) => _selectVideo(entry.match),
                      onDelete: (entry) => _confirmDeleteMatch(entry.match),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: selected == null
                          ? const SizedBox.shrink()
                          : PreviewPane(
                              entry: selected,
                              facts: facts,
                              controller: _controller,
                              stage: _selectedStage,
                              onSelectStage: (stage) =>
                                  setState(() => _selectedStage = stage),
                              onPrepare: _startPreparing,
                              onRefresh: _refresh,
                            ),
                    ),
                    const VerticalDivider(width: 1),
                    InspectorPane(
                      states: selected == null
                          ? const <PipelineStage, StageState>{}
                          : _statesFor(selected, facts),
                      selectedStage: _selectedStage,
                      busyStages: selected != null &&
                              analysis.runningFor(selected.match.id)
                          ? const <PipelineStage>{PipelineStage.analyze}
                          : const <PipelineStage>{},
                      onSelectPlay: () => setState(() => _selectedStage = null),
                      onSelectStage: _selectStage,
                    ),
                  ],
                );
              },
            ),
          ),
          StudioStatusBar(
            videoCount: loadedEntries?.length ?? 0,
            missingCount: missingCount,
            entry: selectedEntry,
            stage: _selectedStage,
            facts:
                selectedEntry == null ? null : facts?[selectedEntry.match.id],
          ),
        ],
      ),
    );
  }

  /// Pick the first video once, so the studio opens with something in view.
  void _ensureSelection(List<MatchListEntry> entries) {
    if (_selectedVideoId != null &&
        entries.any((entry) => entry.match.id == _selectedVideoId)) {
      return;
    }
    final first = entries.first.match;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _selectVideo(first);
      }
    });
  }

  MatchListEntry? _selectedEntry(List<MatchListEntry> entries) {
    for (final entry in entries) {
      if (entry.match.id == _selectedVideoId) {
        return entry;
      }
    }
    return null;
  }

  Map<PipelineStage, StageState> _statesFor(
    MatchListEntry entry,
    Map<String, VideoStageFacts>? facts,
  ) {
    final videoFacts = facts?[entry.match.id];
    if (videoFacts == null) {
      return <PipelineStage, StageState>{
        for (final stage in PipelineStage.values) stage: StageState.idle,
      };
    }
    return resolveStageStates(videoFacts);
  }

  void _selectVideo(MatchRecord match) {
    if (match.id == _selectedVideoId && _controller != null) {
      return;
    }
    setState(() {
      _selectedVideoId = match.id;
      _selectedStage = null;
    });
    _controller?.dispose();
    _controller = ref.read(playbackControllerFactoryProvider)();
    unawaited(_controller!.load(match.videoPath));
  }

  void _selectStage(PipelineStage stage) {
    if (stage == PipelineStage.import) {
      return; // import is a one-time custody action, not a screen
    }
    final entry = _selectedEntryFromProvider();
    if (entry == null) {
      return;
    }
    // Every feature is selectable; a stage that needs an earlier one stays
    // openable and explains what is missing in its own view. Prepare analysis
    // opens its screen, and the job starts only from its button.
    setState(() => _selectedStage = stage);
  }

  MatchListEntry? _selectedEntryFromProvider() {
    final entries =
        ref.read(workspaceVideosProvider(widget.workspace.id)).value;
    if (entries == null) {
      return null;
    }
    return _selectedEntry(entries);
  }

  /// Show the prepare screen and start its background job.
  void _startPreparing(MatchRecord match) {
    setState(() => _selectedStage = PipelineStage.analyze);
    unawaited(ref.read(analysisControllerProvider.notifier).prepare(match));
  }

  void _refresh() {
    if (!mounted) {
      return;
    }
    ref.invalidate(workspaceVideosProvider(widget.workspace.id));
    ref.invalidate(workspaceVideoFactsProvider(widget.workspace.id));
  }

  bool _editHasScore(MatchEdit? edit) => edit != null && !edit.score.isEmpty;

  bool _editHasClips(MatchEdit? edit) => edit != null && edit.clips.isNotEmpty;

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await ref
        .read(importControllerProvider.notifier)
        .start(workspaceId: widget.workspace.id);
    switch (outcome) {
      case ImportSucceeded(:final match):
        _refresh();
        _selectVideo(match);
        messenger.showSnackBar(
          SnackBar(content: Text('Imported ${match.title}')),
        );
      case ImportFailed(:final problem):
        messenger.showSnackBar(SnackBar(content: Text(problem.message)));
      case ImportDeclined():
        break; // the user cancelled, or an import was already running
    }
  }

  Future<void> _confirmDeleteMatch(MatchRecord match) async {
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showDialog<DeleteChoice>(
      context: context,
      builder: (dialogContext) => DeleteMatchDialog(match: match),
    );
    if (choice == null) {
      return;
    }
    final repository = await ref.read(matchRepositoryProvider.future);
    await repository.deleteMatch(
      match,
      deleteArtifacts: choice.deleteArtifacts,
      deleteRecording: choice.deleteRecording,
    );
    _refresh();
    messenger.showSnackBar(SnackBar(content: Text('Deleted ${match.title}')));
  }

  Future<void> _confirmDeleteWorkspace() async {
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showDialog<DeleteChoice>(
      context: context,
      builder: (dialogContext) =>
          DeleteWorkspaceDialog(workspace: widget.workspace),
    );
    if (choice == null) {
      return;
    }
    final repository = await ref.read(matchRepositoryProvider.future);
    await repository.deleteWorkspace(
      widget.workspace,
      deleteArtifacts: choice.deleteArtifacts,
      deleteRecording: choice.deleteRecording,
    );
    ref.invalidate(workspaceListProvider);
    if (mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text('Deleted ${widget.workspace.title}')),
      );
      Navigator.of(context).pop();
    }
  }
}
