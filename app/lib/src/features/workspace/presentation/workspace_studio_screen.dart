import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analysis/presentation/analysis_providers.dart';
import '../../editing/domain/highlight_clip.dart';
import '../../editing/domain/match_edit.dart';
import '../../editing/domain/rally.dart';
import '../../editing/presentation/editing_providers.dart';
import '../../export/presentation/export_sheet.dart';
import '../../library/domain/match_record.dart';
import '../../library/presentation/import_controller.dart';
import '../../library/presentation/library_providers.dart';
import '../../library/presentation/match_list_entry.dart';
import '../../library/presentation/playback_controller.dart';
import '../../../app/design/sc_motion.dart';
import '../../../app/design/sc_overlay_colors.dart';
import '../../../app/design/sportcut_tokens.dart';
import '../../rally/presentation/rally_review_providers.dart';
import '../../score/presentation/rally_panel.dart';
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

  /// The selected recording's duration, used to clamp the timeline window.
  Duration? _selectedDuration;

  /// The library search text, mirrored into the studio controller.
  final TextEditingController _searchController = TextEditingController();

  /// Lets `⌘K` reach the toolbar search field.
  final FocusNode _searchFocusNode = FocusNode();

  /// Restores keyboard focus to Export when the sheet closes.
  final FocusNode _exportFocusNode = FocusNode();

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
    _exportFocusNode.dispose();
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
    // The session is one at a time; show its review only once it belongs to the
    // selected video, so switching videos never paints the previous match.
    final editing = ref.watch(editingControllerProvider);
    final sessionMatches =
        selectedEntry != null && editing.match?.id == selectedEntry.match.id;
    final edit = sessionMatches ? editing.edit : null;
    final editProblem = sessionMatches ? editing.problem : null;
    final editBusy = sessionMatches && editing.busy;

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

    return _ExportSheetHost(
      open: studio.exportSheetOpen,
      match: selectedEntry?.match,
      recordingAvailable: selectedEntry?.recordingAvailable ?? false,
      exportFocusNode: _exportFocusNode,
      onExported: _refresh,
      onClosed: () {
        if (mounted) {
          studioController.setExportSheet(false);
        }
      },
      child: StudioShortcuts(
        controller: _controller,
        searchQuery: studio.searchQuery,
        selectedRallyId: studio.selectedRallyId,
        exportSheetOpen: studio.exportSheetOpen,
        focusMode: studio.focusMode,
        onScoreRally: _scoreSelectedRally,
        onToggleFocusMode: studioController.toggleFocusMode,
        onSelectExport: _openExportSheet,
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
          exportFocusNode: _exportFocusNode,
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
          edit: edit,
          duration: _durationFor(selectedEntry),
          timelineWindowStart: studio.timelineWindowStart,
          selectedRallyId: studio.selectedRallyId,
          onSeekTimeline: _seekTimeline,
          onSelectRally: _selectTimelineRally,
          onSelectInspectorRally: _selectPanelRally,
          inspectorTab: studio.inspectorTab,
          onInspectorTabChanged: studioController.setInspectorTab,
          editProblem: editProblem,
          editBusy: editBusy,
          onDismissEditProblem: () =>
              ref.read(editingControllerProvider.notifier).clearProblem(),
          onSetKept: _setKept,
          onTrimClip: _trimClip,
          onReorderClips: _reorderClips,
          onKeepTop10: _keepTopTen,
          onSelectClip: _selectTimelineRally,
          onExport: _openExportSheet,
        ),
      ),
    );
  }

  /// Put a rally in the reel, or take it out.
  void _setKept(Rally rally, bool kept) {
    unawaited(
      ref.read(editingControllerProvider.notifier).setKept(rally, kept),
    );
  }

  /// Write a trim chosen in the inspector's Clip tab.
  void _trimClip(HighlightClip clip, double startSeconds, double endSeconds) {
    unawaited(
      ref.read(editingControllerProvider.notifier).trimClip(
            clip.id,
            startSeconds: startSeconds,
            endSeconds: endSeconds,
          ),
    );
  }

  /// Write the reel's identifier order.
  void _reorderClips(List<String> clipIds) {
    unawaited(
      ref.read(editingControllerProvider.notifier).reorderClips(clipIds),
    );
  }

  /// Keep the best ten of the rallies the reel passes back.
  Future<void> _keepTopTen(List<Rally> rallies) async {
    final controller = ref.read(editingControllerProvider.notifier);
    for (final Rally rally in rallies.take(10)) {
      await controller.setKept(rally, true);
    }
  }

  /// Open the export sheet for the selected video.
  ///
  /// The sheet is the only export editor, so the toolbar action, the reel's
  /// mini Export, the stage strip's Export tab, and the `E` shortcut all land
  /// here instead of selecting a centre takeover. A missing recording still
  /// opens the sheet; the form states the block.
  void _openExportSheet() {
    final entry = _selectedEntryFromProvider();
    if (entry == null) {
      _studioController.showToast('Select a video to export.');
      return;
    }
    _studioController.setExportSheet(true);
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

  /// Score the rally selected on the timeline.
  ///
  /// This resolves the same selected rally the Rally panel's winner buttons
  /// use and calls the same [scoreRally] helper, so the shortcut and the
  /// buttons can never disagree. A confirmed rally can be corrected the same
  /// way the row controls correct it. A missing recording disables scoring
  /// outright: the clip it would describe cannot be played.
  void _scoreSelectedRally(bool left) {
    final entry = _selectedEntryFromProvider();
    if (entry == null || !entry.recordingAvailable) {
      return;
    }
    final selectedId =
        ref.read(studioControllerProvider(widget.workspace.id)).selectedRallyId;
    final editing = ref.read(editingControllerProvider);
    final edit = editing.match?.id == entry.match.id ? editing.edit : null;
    Rally? selected;
    for (final rally in edit?.rallies ?? const <Rally>[]) {
      if (rally.id == selectedId) {
        selected = rally;
        break;
      }
    }
    if (selected == null) {
      _studioController.showToast('Select a rally on the timeline.');
      return;
    }
    scoreRally(ref, selected.id, left ? WinnerSide.left : WinnerSide.right);
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
      _selectedDuration = _durationOf(match.durationSeconds);
    });
    _studioController.selectStage(null);
    // The sheet describes the video that was selected when it opened.
    _studioController.setExportSheet(false);
    // A new recording starts with a fresh window and no selected rally.
    _studioController.selectRally(null);
    _studioController.setTimelineWindow(Duration.zero);
    _controller?.dispose();
    _controller = ref.read(playbackControllerFactoryProvider)();
    _controller!.state.addListener(_onPlaybackChanged);
    unawaited(_controller!.load(match.videoPath));
    // One editing session and one rally-review session for the shell, opened
    // once per selected video (FR-SHL-45). Both are shell-owned, so the Rally
    // panel never opens them itself in the studio (PR 6a).
    unawaited(ref.read(editingControllerProvider.notifier).ensureOpen(match));
    unawaited(ref.read(rallyReviewControllerProvider.notifier).open(match));
  }

  /// Select a rally from the Rally tab and seek to it.
  ///
  /// Unlike the timeline's selection, this keeps the inspector on the Rally
  /// tab: the selection came from the tab the user is already reading.
  void _selectPanelRally(Rally rally) {
    _studioController.selectRally(rally.id);
    _seekTimeline(
      Duration(milliseconds: (rally.startSeconds * 1000).round()),
    );
  }

  /// The visible window's start for the selected recording.
  Duration? get _timelineDuration {
    final known = _selectedDuration;
    if (known != null && known > Duration.zero) {
      return known;
    }
    final state = _controller?.state.value;
    if (state == null || state.duration <= Duration.zero) {
      return null;
    }
    return state.duration;
  }

  /// Keep the window on the playhead as playback moves.
  ///
  /// The window is recomputed on every tick, but `windowStartFor` returns the
  /// current start while the playhead is inside it, so the scale moves only
  /// when the playhead leaves the visible window. That is the one rule that
  /// prevents ruler jitter.
  void _onPlaybackChanged() {
    if (!mounted) {
      return;
    }
    final state = _controller?.state.value;
    if (state == null || !state.isReady || state.error != null) {
      return;
    }
    _recentreWindow(state.position, _timelineDuration);
  }

  /// Seek from the timeline and recentre the window if the target is outside.
  void _seekTimeline(Duration target) {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final state = controller.state.value;
    if (!state.isReady || state.error != null) {
      return;
    }
    final duration = _timelineDuration;
    var clamped = target;
    if (clamped < Duration.zero) {
      clamped = Duration.zero;
    }
    if (duration != null && clamped > duration) {
      clamped = duration;
    }
    controller.seek(clamped);
    _recentreWindow(clamped, duration);
  }

  /// Select a rally, open the Clip tab, and seek to its start.
  void _selectTimelineRally(Rally rally) {
    _studioController.selectRally(rally.id);
    _studioController.setInspectorTab(1);
    _seekTimeline(
      Duration(milliseconds: (rally.startSeconds * 1000).round()),
    );
  }

  /// Apply the one recentring rule and write the window only when it moved.
  void _recentreWindow(Duration position, Duration? duration) {
    final current = ref
        .read(studioControllerProvider(widget.workspace.id))
        .timelineWindowStart;
    final next = windowStartFor(
      position,
      timelineWindowFor(duration),
      current: current,
      duration: duration,
    );
    if (next != current) {
      _studioController.setTimelineWindow(next);
    }
  }

  /// A selected video's duration, or null when it is unknown.
  Duration? _durationFor(MatchListEntry? entry) {
    if (entry == null) {
      return null;
    }
    return _durationOf(entry.match.durationSeconds);
  }

  /// Convert a stored duration in seconds, rejecting unusable values.
  Duration? _durationOf(double seconds) {
    if (!seconds.isFinite || seconds <= 0) {
      return null;
    }
    return Duration(milliseconds: (seconds * 1000).round());
  }

  void _selectStage(PipelineStage stage) {
    if (stage == PipelineStage.import) {
      return; // import is a one-time custody action, not a screen
    }
    if (stage == PipelineStage.export) {
      // Export is a sheet, not a centre takeover; the stage stays where it is.
      _openExportSheet();
      return;
    }
    final entry = _selectedEntryFromProvider();
    if (entry == null) {
      return;
    }
    // Every feature is selectable; a stage that needs an earlier one stays
    // openable and explains what is missing in its own view. Prepare analysis
    // opens its panel, and the job starts only from its button.
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
    // Keep the deleted video's place so the selection lands on the next
    // remaining video rather than jumping to the first one (FR-LIB-24).
    final before =
        ref.read(workspaceVideosProvider(widget.workspace.id)).value ??
            const <MatchListEntry>[];
    final removedIndex =
        before.indexWhere((entry) => entry.match.id == match.id);
    final remaining = before
        .where((entry) => entry.match.id != match.id)
        .toList(growable: false);
    final wasSelected = _selectedVideoId == match.id;

    final repository = await ref.read(matchRepositoryProvider.future);
    await repository.deleteMatch(
      match,
      deleteArtifacts: choice.deleteArtifacts,
      deleteRecording: choice.deleteRecording,
    );
    if (!mounted) {
      return;
    }
    _refresh();

    if (wasSelected) {
      if (remaining.isEmpty) {
        setState(() {
          _selectedVideoId = null;
          _selectedDuration = null;
        });
        _controller?.dispose();
        _controller = null;
      } else {
        final int nextIndex;
        if (removedIndex < 0) {
          nextIndex = 0;
        } else if (removedIndex >= remaining.length) {
          nextIndex = remaining.length - 1;
        } else {
          nextIndex = removedIndex;
        }
        _selectVideo(remaining[nextIndex].match);
      }
    }

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

/// Keeps the export sheet's route in step with [StudioState.exportSheetOpen].
///
/// The state is the source of truth: opening sets it true, and the shortcut
/// layer's Escape order or any close action sets it false. The route's own
/// dismiss (Escape or the barrier) finishes here and writes false back, so the
/// flag never claims a sheet that is not on screen. No Escape handler is added
/// on this path; the studio's existing shortcut order stays the only one.
class _ExportSheetHost extends StatefulWidget {
  const _ExportSheetHost({
    required this.open,
    required this.match,
    required this.recordingAvailable,
    required this.exportFocusNode,
    required this.onExported,
    required this.onClosed,
    required this.child,
  });

  final bool open;
  final MatchRecord? match;
  final bool recordingAvailable;
  final FocusNode? exportFocusNode;
  final VoidCallback onExported;
  final VoidCallback onClosed;
  final Widget child;

  @override
  State<_ExportSheetHost> createState() => _ExportSheetHostState();
}

class _ExportSheetHostState extends State<_ExportSheetHost> {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    if (widget.open) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _show());
    }
  }

  @override
  void didUpdateWidget(covariant _ExportSheetHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open && !oldWidget.open) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _show());
    } else if (!widget.open && oldWidget.open) {
      _dismiss();
    }
  }

  Future<void> _show() async {
    if (_showing || !mounted || !widget.open) {
      return;
    }
    final MatchRecord? match = widget.match;
    if (match == null) {
      widget.onClosed();
      return;
    }
    _showing = true;
    final SportcutTokens tokens = SportcutTokens.of(context);
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close export sheet',
      // The barrier is the fixed footage bed, dark in both themes.
      barrierColor: ScOverlayColors.bed.withValues(alpha: 0.62),
      // The sheet is a destination, not decoration: reduced motion removes its
      // transition entirely (FR-SHL-36).
      transitionDuration: ScMotion.duration(context, tokens.motionBase),
      pageBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
      ) =>
          Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(tokens.space6),
              child: FocusTraversalGroup(
                child: ExportSheet(
                  match: match,
                  recordingAvailable: widget.recordingAvailable,
                  onExported: widget.onExported,
                ),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        Widget child,
      ) =>
          FadeTransition(opacity: animation, child: child),
    );
    _showing = false;
    if (mounted) {
      widget.exportFocusNode?.requestFocus();
      widget.onClosed();
    }
  }

  void _dismiss() {
    if (!_showing || !mounted) {
      return;
    }
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
