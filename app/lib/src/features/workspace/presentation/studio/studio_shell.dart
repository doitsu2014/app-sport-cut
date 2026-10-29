import 'package:flutter/material.dart';

import '../../../../app/design/components/sc_empty_state.dart';
import '../../../../app/design/components/sc_toast.dart';
import '../../../../app/design/sc_icons.dart';
import '../../../../app/design/sc_metrics.dart';
import '../../../../app/design/sportcut_tokens.dart';
import '../../../editing/domain/match_edit.dart';
import '../../../editing/domain/rally.dart';
import '../../../library/domain/match_record.dart';
import '../../../library/presentation/match_list_entry.dart';
import '../../../library/presentation/playback_controller.dart';
import '../../domain/pipeline_stage.dart';
import '../../domain/workspace.dart';
import 'inspector_pane.dart';
import 'preview_pane.dart';
import 'studio_controller.dart';
import 'stage_strip.dart';
import 'studio_status_bar.dart';
import 'studio_toolbar.dart';
import 'timeline_dock.dart';
import 'video_rail.dart';

/// The studio frame: toolbar, stage strip, three-column workspace, shared
/// timeline dock, and status bar.
///
/// The shell takes already-resolved data and callbacks; it reads no provider.
/// Rail widths narrow at the 1200 px and 1040 px breakpoints, and below the
/// 980 px collapse the panes stack preview, videos, then inspector (ADR-0003
/// D15; FR-SHL-02, FR-SHL-06).
class StudioShell extends StatelessWidget {
  /// Build the studio frame.
  const StudioShell({
    super.key,
    required this.workspace,
    required this.videos,
    required this.videosError,
    required this.selectedEntry,
    required this.facts,
    required this.stageStates,
    required this.selectedStage,
    required this.runningStage,
    required this.runningFraction,
    required this.controller,
    required this.importRunning,
    required this.importDescription,
    required this.searchController,
    required this.libraryVisible,
    required this.inspectorVisible,
    required this.focusMode,
    required this.onBack,
    required this.onToggleLibrary,
    required this.onToggleInspector,
    required this.onToggleFocusMode,
    required this.onDeleteWorkspace,
    required this.onSelectVideo,
    required this.onDeleteVideo,
    required this.onImport,
    required this.onCancelImport,
    required this.onRetry,
    required this.onSelectStage,
    required this.onPrepare,
    required this.onRefresh,
    this.importFraction,
    this.searchFocusNode,
    this.searchQuery = '',
    this.onClearSearch,
    this.toastMessage,
    this.onToastShown,
    this.edit,
    this.duration,
    this.timelineWindowStart = Duration.zero,
    this.selectedRallyId,
    this.onSeekTimeline,
    this.onSelectRally,
  });

  /// The workspace the studio is showing.
  final Workspace workspace;

  /// The videos in the workspace, or null while they load.
  final List<MatchListEntry>? videos;

  /// Why the video list could not be read, when it could not.
  final String? videosError;

  /// The selected video, or null when none is chosen.
  final MatchListEntry? selectedEntry;

  /// Stage facts for every video, or null while they load.
  final Map<String, VideoStageFacts>? facts;

  /// The resolved state of every stage for the selected video.
  final Map<PipelineStage, StageState> stageStates;

  /// The selected stage, where null means Play.
  final PipelineStage? selectedStage;

  /// The stage with a job running, if any.
  final PipelineStage? runningStage;

  /// Progress of the running stage in the range 0 to 1, when known.
  final double? runningFraction;

  /// The shared player for the selected video.
  final PlaybackController? controller;

  /// Whether an import is running.
  final bool importRunning;

  /// What the running import is doing.
  final String importDescription;

  /// Completion of the running import in the range 0 to 1, when known.
  final double? importFraction;

  /// The library search controller, owned by the composition root.
  final TextEditingController searchController;

  /// The search field's focus node, used by the `⌘K` binding.
  final FocusNode? searchFocusNode;

  /// The in-memory search query filtering the video rail.
  final String searchQuery;

  /// Clear the search from the rail's search-empty state.
  final VoidCallback? onClearSearch;

  /// The one-line toast to show, or null when there is none.
  final String? toastMessage;

  /// Called once a toast has been handed to the host, so it can be cleared.
  final VoidCallback? onToastShown;

  /// Whether the video rail is showing.
  final bool libraryVisible;

  /// Whether the inspector is showing.
  final bool inspectorVisible;

  /// Whether focus mode is engaged.
  final bool focusMode;

  /// Return to the workspace list.
  final VoidCallback onBack;

  /// Show or hide the video rail.
  final VoidCallback onToggleLibrary;

  /// Show or hide the inspector.
  final VoidCallback onToggleInspector;

  /// Toggle focus mode.
  final VoidCallback onToggleFocusMode;

  /// Delete the workspace.
  final VoidCallback onDeleteWorkspace;

  /// Select a video.
  final void Function(MatchListEntry) onSelectVideo;

  /// Delete a video.
  final void Function(MatchListEntry) onDeleteVideo;

  /// Start importing a recording.
  final VoidCallback onImport;

  /// Cancel the running import.
  final VoidCallback onCancelImport;

  /// Retry reading the video list.
  final VoidCallback onRetry;

  /// Select a stage, where null selects Play.
  final void Function(PipelineStage?) onSelectStage;

  /// Open the prepare screen and start its background job.
  final void Function(MatchRecord) onPrepare;

  /// Refresh the rail after a feature writes an artifact.
  final VoidCallback onRefresh;

  /// The selected match's review, or null while the session opens.
  final MatchEdit? edit;

  /// The selected recording's duration, or null while it is unknown.
  final Duration? duration;

  /// The left edge of the timeline's visible window.
  final Duration timelineWindowStart;

  /// The rally selected on the timeline, or null when none is.
  final String? selectedRallyId;

  /// Seek from the timeline.
  final ValueChanged<Duration>? onSeekTimeline;

  /// Select a rally on the timeline.
  final ValueChanged<Rally>? onSelectRally;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final videos = this.videos;
    final loading = videos == null && videosError == null;
    final missing = videos == null
        ? 0
        : videos.where((entry) => !entry.recordingAvailable).length;
    final selected = selectedEntry;

    return Scaffold(
      backgroundColor: palette.bg,
      body: _StudioToastOverlay(
        toastMessage: toastMessage,
        onShown: onToastShown,
        child: Column(
          children: <Widget>[
            StudioToolbar(
              workspace: workspace,
              searchController: searchController,
              searchFocusNode: searchFocusNode,
              libraryVisible: libraryVisible,
              inspectorVisible: inspectorVisible,
              focusMode: focusMode,
              onBack: onBack,
              onToggleLibrary: onToggleLibrary,
              onToggleInspector: onToggleInspector,
              onToggleFocusMode: onToggleFocusMode,
              onDelete: onDeleteWorkspace,
              onExport: () => onSelectStage(PipelineStage.export),
            ),
            StageStrip(
              states: stageStates,
              selectedStage: selectedStage,
              runningStage: runningStage,
              runningFraction: runningFraction,
              onSelectStage: onSelectStage,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  if (constraints.maxWidth < ScMetrics.collapseBreakpoint) {
                    return _stacked(context, loading);
                  }
                  final rails = _RailWidths.forWidth(constraints.maxWidth);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (libraryVisible && !focusMode)
                        SizedBox(
                          width: rails.library,
                          child: _videoRail(loading),
                        ),
                      Expanded(child: _preview(context, loading)),
                      if (inspectorVisible && !focusMode)
                        SizedBox(
                          width: rails.inspector,
                          child: _inspector(),
                        ),
                    ],
                  );
                },
              ),
            ),
            _timeline(selected),
            StudioStatusBar(
              videoCount: videos?.length ?? 0,
              missingCount: missing,
              entry: selected,
              facts: selected == null ? null : facts?[selected.match.id],
            ),
          ],
        ),
      ),
    );
  }

  /// The shared 176 px timeline dock.
  ///
  /// The playhead tracks the shared player, so only the dock rebuilds on a
  /// playback tick: the shell and the preview do not. The window start comes
  /// from the studio state; the screen owns the derived rule that moves it.
  Widget _timeline(MatchListEntry? selected) {
    final edit = this.edit;
    final hasSelection = selected != null;
    final recordingAvailable = selected?.recordingAvailable ?? false;
    final loading = !hasSelection || (recordingAvailable && edit == null);

    Widget dock(Duration position, Duration? playbackDuration) {
      final known = duration;
      final effectiveDuration = known != null && known > Duration.zero
          ? known
          : (playbackDuration != null && playbackDuration > Duration.zero
              ? playbackDuration
              : null);
      return TimelineDock(
        edit: edit,
        duration: effectiveDuration,
        position: position,
        windowStart: timelineWindowStart,
        windowLength: timelineWindowFor(effectiveDuration),
        selectedRallyId: selectedRallyId,
        recordingAvailable: recordingAvailable,
        loading: loading,
        onSeek: onSeekTimeline,
        onSelectRally: onSelectRally,
      );
    }

    final player = controller;
    if (player == null) {
      return dock(Duration.zero, null);
    }
    return ValueListenableBuilder<PlaybackState>(
      valueListenable: player.state,
      builder: (BuildContext context, PlaybackState state, Widget? child) =>
          dock(state.position, state.duration),
    );
  }

  Widget _preview(BuildContext context, bool loading) {
    final palette = SportcutPalette.of(context);
    final selected = selectedEntry;
    if (selected == null) {
      if (loading) {
        return const Center(child: CircularProgressIndicator());
      }
      return ColoredBox(
        color: palette.bg,
        child: const Center(
          child: ScEmptyState(
            message: 'Select a video to preview.',
            icon: ScIcons.movie,
          ),
        ),
      );
    }
    return PreviewPane(
      entry: selected,
      facts: facts,
      controller: controller,
      stage: selectedStage,
      onSelectStage: (PipelineStage stage) => onSelectStage(stage),
      onPrepare: onPrepare,
      onRefresh: onRefresh,
    );
  }

  Widget _videoRail(bool loading) {
    return VideoRail(
      workspaceTitle: workspace.title,
      entries: videos ?? const <MatchListEntry>[],
      selectedId: selectedEntry?.match.id,
      loading: loading,
      error: videosError,
      importRunning: importRunning,
      importDescription: importDescription,
      importFraction: importFraction,
      searchQuery: searchQuery,
      onClearSearch: onClearSearch,
      onSelect: onSelectVideo,
      onDelete: onDeleteVideo,
      onImport: onImport,
      onCancelImport: onCancelImport,
      onRetry: onRetry,
    );
  }

  Widget _inspector() {
    return InspectorPane(
      states: stageStates,
      selectedStage: selectedStage,
      runningStage: runningStage,
      runningFraction: runningFraction,
      onSelectPlay: () => onSelectStage(null),
      onSelectStage: (PipelineStage stage) => onSelectStage(stage),
    );
  }

  Widget _stacked(BuildContext context, bool loading) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: ScMetrics.stackedPaneHeight,
            child: _preview(context, loading),
          ),
          if (libraryVisible && !focusMode)
            SizedBox(
              height: ScMetrics.stackedPaneHeight,
              child: _videoRail(loading),
            ),
          if (inspectorVisible && !focusMode)
            SizedBox(
              height: ScMetrics.stackedPaneHeight,
              child: _inspector(),
            ),
        ],
      ),
    );
  }
}

/// The rail widths for one workspace width.
class _RailWidths {
  const _RailWidths(this.library, this.inspector);

  /// The video-rail width.
  final double library;

  /// The inspector width.
  final double inspector;

  /// Pick the widths for [width].
  factory _RailWidths.forWidth(double width) {
    if (width >= ScMetrics.narrowBreakpoint1) {
      return const _RailWidths(
        ScMetrics.libraryWidth,
        ScMetrics.inspectorWidth,
      );
    }
    if (width >= ScMetrics.narrowBreakpoint2) {
      return const _RailWidths(
        ScMetrics.libraryWidthNarrow1,
        ScMetrics.inspectorWidthNarrow1,
      );
    }
    return const _RailWidths(
      ScMetrics.libraryWidthNarrow2,
      ScMetrics.inspectorWidthNarrow2,
    );
  }
}

/// Puts the studio content under one toast host.
///
/// The shell owns the host, not the controller: the screen places a message in
/// the studio state and this widget shows the most recent one, then reports it
/// back so the same message can be raised again later.
class _StudioToastOverlay extends StatefulWidget {
  const _StudioToastOverlay({
    required this.toastMessage,
    required this.child,
    this.onShown,
  });

  final String? toastMessage;
  final VoidCallback? onShown;
  final Widget child;

  @override
  State<_StudioToastOverlay> createState() => _StudioToastOverlayState();
}

class _StudioToastOverlayState extends State<_StudioToastOverlay> {
  final GlobalKey<ScToastHostState> _toastKey = GlobalKey<ScToastHostState>();

  @override
  void didUpdateWidget(_StudioToastOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final message = widget.toastMessage;
    if (message == null || message == oldWidget.toastMessage) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _toastKey.currentState?.show(ScToastData(message: message));
      widget.onShown?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        widget.child,
        ScToastHost(key: _toastKey),
      ],
    );
  }
}
