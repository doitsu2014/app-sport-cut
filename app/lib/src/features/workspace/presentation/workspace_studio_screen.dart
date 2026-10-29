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
import 'studio/studio_controller.dart';
import 'studio/studio_dialogs.dart';
import 'studio/studio_shortcuts.dart';
import 'studio/studio_shell.dart';
import 'workspace_providers.dart';

/// The composition root for the studio.
///
/// Every provider watch, listener, controller, and handler lives here; the
/// frame itself is [StudioShell]. The studio owns one playback controller per
/// selected video and hands it to whichever feature view is showing, so Play
/// and the pipeline stages share a seamless preview.
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

  /// The library search text, mirrored into the studio controller.
  final TextEditingController _searchController = TextEditingController();

  /// Lets `⌘K` reach the toolbar search field.
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_syncSearchQuery);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _searchController.removeListener(_syncSearchQuery);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Keep the ephemeral search query in step with the field's text.
  void _syncSearchQuery() {
    if (!mounted) {
      return;
    }
    ref
        .read(studioControllerProvider(widget.workspace.id).notifier)
        .setSearchQuery(_searchController.text);
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
    final studio = ref.watch(studioControllerProvider(widget.workspace.id));
    final studioController =
        ref.read(studioControllerProvider(widget.workspace.id).notifier);

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
    // keeping the first clip flips Export; refresh the stage facts so the strip
    // and inspector show the new state rather than a stale one.
    ref.listen(editingControllerProvider, (previous, next) {
      if (_editHasScore(previous?.edit) != _editHasScore(next.edit) ||
          _editHasClips(previous?.edit) != _editHasClips(next.edit)) {
        _refresh();
      }
    });

    if (loadedEntries != null && loadedEntries.isNotEmpty) {
      _ensureSelection(loadedEntries);
    }

    final runningForSelected =
        selectedEntry != null && analysis.runningFor(selectedEntry.match.id);
    final stageStates = selectedEntry == null
        ? const <PipelineStage, StageState>{}
        : _statesFor(selectedEntry, facts);
    final videosError =
        videos.hasError && !videos.hasValue ? '${videos.error}' : null;

    return StudioShortcuts(
      controller: _controller,
      searchQuery: studio.searchQuery,
      selectedRallyId: studio.selectedRallyId,
      exportSheetOpen: studio.exportSheetOpen,
      focusMode: studio.focusMode,
      onScoreRally: _scoreSelectedRally,
      onToggleFocusMode: studioController.toggleFocusMode,
      onSelectExport: () => _selectStage(PipelineStage.export),
      onFocusSearch: _focusSearch,
      onCloseExportSheet: () => studioController.setExportSheet(false),
      onExitFocusMode: studioController.restoreRailsAfterFocus,
      onClearSearch: _clearSearch,
      onToast: studioController.showToast,
      child: StudioShell(
        workspace: widget.workspace,
        videos: loadedEntries,
        videosError: videosError,
        selectedEntry: selectedEntry,
        facts: facts,
        stageStates: stageStates,
        selectedStage: studio.selectedStage,
        runningStage: runningForSelected ? PipelineStage.analyze : null,
        runningFraction: runningForSelected ? analysis.progress : null,
        controller: _controller,
        importRunning: import.isRunning,
        importDescription: import.description,
        searchController: _searchController,
        searchFocusNode: _searchFocusNode,
        searchQuery: studio.searchQuery,
        onClearSearch: _clearSearch,
        toastMessage: studio.toastMessage,
        onToastShown: () => studioController.showToast(null),
        libraryVisible: studio.libraryVisible,
        inspectorVisible: studio.inspectorVisible,
        focusMode: studio.focusMode,
        onBack: () => Navigator.of(context).maybePop(),
        onToggleLibrary: studioController.toggleLibrary,
        onToggleInspector: studioController.toggleInspector,
        onToggleFocusMode: studioController.toggleFocusMode,
        onDeleteWorkspace: _confirmDeleteWorkspace,
        onSelectVideo: (entry) => _selectVideo(entry.match),
        onDeleteVideo: (entry) => _confirmDeleteMatch(entry.match),
        onImport: _import,
        onCancelImport: () =>
            ref.read(importControllerProvider.notifier).cancel(),
        onRetry: () => ref.invalidate(
          workspaceVideosProvider(widget.workspace.id),
        ),
        onSelectStage: _selectStageFromStrip,
        onPrepare: _startPreparing,
        onRefresh: _refresh,
      ),
    );
  }

  /// Select a stage from the strip or inspector, where null is Play.
  void _selectStageFromStrip(PipelineStage? stage) {
    if (stage == null) {
      _studioController.selectStage(null);
      return;
    }
    _selectStage(stage);
  }

  /// Focus the toolbar search and select what is already there.
  void _focusSearch() {
    _searchFocusNode.requestFocus();
    _searchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _searchController.text.length,
    );
  }

  /// Clear the field and the ephemeral query together.
  void _clearSearch() {
    _searchController.clear();
    _studioController.clearSearch();
  }

  /// Score the selected rally.
  ///
  /// The score panel arrives in PR 6a; until then there is no selected rally,
  /// so this stays a no-op that keeps the shortcut wiring one line away. A
  /// missing recording disables scoring outright: the clip it would describe
  /// cannot be played.
  void _scoreSelectedRally(bool left) {
    final entry = _selectedEntryFromProvider();
    if (entry == null || !entry.recordingAvailable) {
      return;
    }
  }

  StudioController get _studioController =>
      ref.read(studioControllerProvider(widget.workspace.id).notifier);

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
      // The facts are still loading: report no state rather than a wrong one.
      return const <PipelineStage, StageState>{};
    }
    return resolveStageStates(videoFacts);
  }

  void _selectVideo(MatchRecord match) {
    if (match.id == _selectedVideoId && _controller != null) {
      return;
    }
    setState(() {
      _selectedVideoId = match.id;
    });
    _studioController.selectStage(null);
    _controller?.dispose();
    _controller = ref.read(playbackControllerFactoryProvider)();
    unawaited(_controller!.load(match.videoPath));
    // One editing session for the shell, opened once per selected video
    // (FR-SHL-45). Feature views reached from the studio read this session.
    unawaited(ref.read(editingControllerProvider.notifier).ensureOpen(match));
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
    _studioController.selectStage(stage);
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
    _studioController.selectStage(PipelineStage.analyze);
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
