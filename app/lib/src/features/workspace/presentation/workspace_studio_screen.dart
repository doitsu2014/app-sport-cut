import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/sc_metrics.dart';
import '../../../app/design/sc_overlay_colors.dart';
import '../../../app/design/sportcut_tokens.dart';
import '../../analysis/presentation/analysis_providers.dart';
import '../../analysis/presentation/analysis_view.dart';
import '../../calibration/presentation/calibration_view.dart';
import '../../editing/domain/match_edit.dart';
import '../../editing/presentation/editing_providers.dart';
import '../../export/presentation/export_view.dart';
import '../../highlights/presentation/highlights_view.dart';
import '../../library/domain/match_record.dart';
import '../../library/presentation/formatters.dart';
import '../../library/presentation/import_controller.dart';
import '../../library/presentation/library_providers.dart';
import '../../library/presentation/match_list_entry.dart';
import '../../library/presentation/playback_controller.dart';
import '../../library/presentation/player_view.dart';
import '../../score/presentation/score_view.dart';
import '../../tracking/presentation/player_tracking_view.dart';
import '../domain/pipeline_stage.dart';
import '../domain/workspace.dart';
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
          _StudioToolbar(
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
            _ImportProgress(
              description: import.description,
              onCancel: () =>
                  ref.read(importControllerProvider.notifier).cancel(),
            ),
          Expanded(
            child: videos.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _StudioError(
                message: '$error',
                onRetry: () => ref.invalidate(
                  workspaceVideosProvider(widget.workspace.id),
                ),
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return _EmptyStudio(
                    importRunning: import.isRunning,
                    onImport: _import,
                  );
                }
                _ensureSelection(entries);
                final selected = _selectedEntry(entries);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _VideoRail(
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
                          : _buildCenter(selected, facts),
                    ),
                    const VerticalDivider(width: 1),
                    _FeatureRail(
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
          _StudioStatusBar(
            videoCount: loadedEntries?.length ?? 0,
            missingCount: missingCount,
            entry: selectedEntry,
            stage: _selectedStage,
            facts: selectedEntry == null
                ? null
                : facts?[selectedEntry.match.id],
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

  Widget _buildCenter(
    MatchListEntry entry,
    Map<String, VideoStageFacts>? facts,
  ) {
    final controller = _controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Column(
        children: <Widget>[
          _CenterHeader(match: entry.match, stage: _selectedStage),
          Expanded(child: _featureView(entry, facts, controller)),
        ],
      ),
    );
  }

  Widget _featureView(
    MatchListEntry entry,
    Map<String, VideoStageFacts>? facts,
    PlaybackController controller,
  ) {
    switch (_selectedStage) {
      case null:
        return PlayerView(controller: controller);
      case PipelineStage.calibrate:
        return CalibrationView(
          match: entry.match,
          controller: controller,
          onSaved: (_) => _refresh(),
        );
      case PipelineStage.track:
        final videoFacts = facts?[entry.match.id];
        return PlayerTrackingView(
          match: entry.match,
          controller: controller,
          calibrated: videoFacts?.calibrated ?? false,
          analysisReady: videoFacts?.analysisReady ?? false,
          onMarkCourt: () =>
              setState(() => _selectedStage = PipelineStage.calibrate),
          onPrepare: () => _startPreparing(entry.match),
          // The track job writes a new artifact; refresh the rail so done and
          // ready states do not stay stale after the action.
          onAnalyzed: _refresh,
          // Manual review is always available, even without detected tracks.
          onOpenScore: () =>
              setState(() => _selectedStage = PipelineStage.score),
        );
      case PipelineStage.score:
        return ScoreView(match: entry.match, controller: controller);
      case PipelineStage.highlight:
        return HighlightsView(match: entry.match);
      case PipelineStage.export:
        return ExportView(match: entry.match, onExported: _refresh);
      case PipelineStage.analyze:
        return AnalysisView(
          match: entry.match,
          onOpenTracking: () =>
              setState(() => _selectedStage = PipelineStage.track),
        );
      case PipelineStage.import:
        // Import is not a lens; the center stays on playback.
        return PlayerView(controller: controller);
    }
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
    final choice = await showDialog<_DeleteChoice>(
      context: context,
      builder: (dialogContext) => _DeleteMatchDialog(match: match),
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
    final choice = await showDialog<_DeleteChoice>(
      context: context,
      builder: (dialogContext) =>
          _DeleteWorkspaceDialog(workspace: widget.workspace),
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

String _resolutionLabel(MatchRecord match) {
  final height = match.videoHeight;
  if (height == null || height <= 0) {
    return '—';
  }
  if (height >= 1080) {
    return '1080p';
  }
  if (height >= 720) {
    return '720p';
  }
  if (height >= 480) {
    return '480p';
  }
  return '${height}p';
}

class _StudioToolbar extends StatelessWidget {
  const _StudioToolbar({
    required this.workspace,
    required this.videoCount,
    required this.importRunning,
    required this.showImport,
    required this.onBack,
    required this.onImport,
    required this.onDelete,
  });

  final Workspace workspace;
  final int videoCount;
  final bool importRunning;
  final bool showImport;
  final VoidCallback onBack;
  final VoidCallback onImport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = SportcutTokens.of(context);
    return Container(
      height: ScMetrics.toolbarHeight,
      padding: EdgeInsets.symmetric(horizontal: tokens.space4),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onBack,
            tooltip: 'Back to workspaces',
            icon: const Icon(Icons.arrow_back, size: 18),
          ),
          SizedBox(width: tokens.space2),
          Text(
            'Sportcut',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 14,
              height: 1.1,
              letterSpacing: -0.01,
            ),
          ),
          SizedBox(width: tokens.space3),
          Container(width: 1, height: 16, color: scheme.outlineVariant),
          SizedBox(width: tokens.space3),
          Expanded(
            child: Text(
              workspace.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (videoCount > 0) ...<Widget>[
            _StudioChip(
              label: '$videoCount ${videoCount == 1 ? 'video' : 'videos'}',
            ),
            SizedBox(width: tokens.space2),
          ],
          if (showImport) ...<Widget>[
            FilledButton.icon(
              onPressed: importRunning ? null : onImport,
              icon: const Icon(Icons.add, size: 16),
              label: Text(importRunning ? 'Importing' : 'Import'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 30),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: theme.textTheme.labelLarge?.copyWith(fontSize: 12),
              ),
            ),
            SizedBox(width: tokens.space2),
          ],
          IconButton(
            onPressed: onDelete,
            tooltip: 'Delete workspace',
            icon: const Icon(Icons.delete_outline, size: 18),
          ),
        ],
      ),
    );
  }
}

class _CenterHeader extends StatelessWidget {
  const _CenterHeader({required this.match, required this.stage});

  final MatchRecord match;
  final PipelineStage? stage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = SportcutTokens.of(context);
    final fps = match.frameRate;
    final fpsLabel = fps == null || fps <= 0
        ? null
        : '${fps.toStringAsFixed(fps.roundToDouble() == fps ? 0 : 2)} fps';
    final parts = <String>[
      _resolutionLabel(match),
      if (fpsLabel != null) fpsLabel,
    ];
    return Container(
      height: 40,
      padding: EdgeInsets.symmetric(horizontal: tokens.space3),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: <Widget>[
          Text(
            'Preview',
            style: theme.textTheme.labelLarge?.copyWith(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
          SizedBox(width: tokens.space2),
          _StudioChip(label: stage?.label ?? 'Playback'),
          const Spacer(),
          Text(
            parts.join(' · '),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioStatusBar extends StatelessWidget {
  const _StudioStatusBar({
    required this.videoCount,
    required this.missingCount,
    required this.entry,
    required this.stage,
    required this.facts,
  });

  final int videoCount;
  final int missingCount;
  final MatchListEntry? entry;
  final PipelineStage? stage;
  final VideoStageFacts? facts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = SportcutTokens.of(context);
    final score = entry?.score;
    final statusStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final ready = facts?.hasSelectedClips;
    final String readyLabel;
    if (ready == null) {
      readyLabel = 'Checking';
    } else if (ready) {
      readyLabel = 'Ready to export';
    } else {
      readyLabel = 'Needs a clip';
    }
    return Container(
      height: ScMetrics.statusHeight,
      padding: EdgeInsets.symmetric(horizontal: tokens.space3),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: tokens.space1 + 2),
          Text('On-device · No cloud', style: statusStyle),
          SizedBox(width: tokens.space3),
          Text(
            '$videoCount ${videoCount == 1 ? 'video' : 'videos'}',
            style: statusStyle,
          ),
          if (missingCount > 0) ...<Widget>[
            SizedBox(width: tokens.space3),
            Text(
              '$missingCount missing',
              style: statusStyle?.copyWith(color: scheme.error),
            ),
          ],
          const Spacer(),
          if (score != null) ...<Widget>[
            Text(
              'Score ${score.left}–${score.right}',
              style: statusStyle,
            ),
            SizedBox(width: tokens.space3),
          ],
          Text(
            entry == null ? 'No video selected' : (stage?.label ?? 'Playback'),
            style: statusStyle,
          ),
          SizedBox(width: tokens.space2),
          if (entry != null)
            _StudioChip(label: readyLabel),
        ],
      ),
    );
  }
}

class _StudioChip extends StatelessWidget {
  const _StudioChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = SportcutTokens.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space2 - 1,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(tokens.radiusPill),
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          fontSize: 9,
          letterSpacing: 0.06,
        ),
      ),
    );
  }
}

class _VideoRail extends StatelessWidget {
  const _VideoRail({
    required this.entries,
    required this.selectedId,
    required this.busyId,
    required this.onSelect,
    required this.onDelete,
  });

  final List<MatchListEntry> entries;
  final String? selectedId;

  /// Video whose analysis files are being prepared in the background.
  final String? busyId;
  final void Function(MatchListEntry) onSelect;
  final void Function(MatchListEntry) onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = SportcutTokens.of(context);
    return Container(
      width: ScMetrics.libraryWidth,
      color: scheme.surface,
      child: Column(
        children: <Widget>[
          _RailHeader(label: 'Videos', trailing: '${entries.length}'),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.all(tokens.space2),
              itemCount: entries.length,
              separatorBuilder: (context, index) =>
                  SizedBox(height: tokens.space1),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _VideoRailTile(
                  entry: entry,
                  selected: entry.match.id == selectedId,
                  busy: entry.match.id == busyId,
                  onSelect: () => onSelect(entry),
                  onDelete: () => onDelete(entry),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoRailTile extends StatelessWidget {
  const _VideoRailTile({
    required this.entry,
    required this.selected,
    required this.busy,
    required this.onSelect,
    required this.onDelete,
  });

  final MatchListEntry entry;
  final bool selected;
  final bool busy;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = SportcutTokens.of(context);
    final missing = !entry.recordingAvailable;
    final score = entry.score;
    final scoreLabel = score == null
        ? formatDuration(entry.match.durationSeconds)
        : 'Score ${score.left}–${score.right}';
    final meta = missing
        ? 'Recording missing'
        : '${_resolutionLabel(entry.match)} · $scoreLabel';

    return Material(
      color: selected ? scheme.surfaceContainerHighest : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        side: BorderSide(
          color: selected ? scheme.outlineVariant : Colors.transparent,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onSelect,
        child: Padding(
          padding: EdgeInsets.all(tokens.space2),
          child: Row(
            children: <Widget>[
              _VideoThumb(entry: entry),
              SizedBox(width: tokens.space2),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.match.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 12,
                        height: 1.3,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: missing
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Padding(
                  padding: EdgeInsets.only(left: tokens.space1),
                  child: Icon(
                    Icons.check_circle,
                    size: 14,
                    color: scheme.primary,
                  ),
                ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: _BusySpinner(
                    tooltip: 'Preparing analysis in the background',
                  ),
                )
              else
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'Delete video',
                  icon: const Icon(Icons.delete_outline, size: 18),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(28, 28),
                    padding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoThumb extends StatelessWidget {
  const _VideoThumb({required this.entry});

  final MatchListEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final available = entry.recordingAvailable;
    return Container(
      width: 52,
      height: 30,
      decoration: BoxDecoration(
        // The footage bed is fixed in both themes; this is a thumbnail, not
        // UI chrome.
        color: ScOverlayColors.thumbnailBed,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Center(
            child: Icon(
              available ? Icons.movie_outlined : Icons.error_outline,
              size: 14,
              color: available ? Colors.white70 : scheme.error,
            ),
          ),
          if (available)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(170),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  formatDuration(entry.match.durationSeconds),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    height: 1.4,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RailHeader extends StatelessWidget {
  const _RailHeader({required this.label, this.trailing});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = SportcutTokens.of(context);
    return Container(
      height: 38,
      padding: EdgeInsets.symmetric(horizontal: tokens.space3),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            Text(
              trailing!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _FeatureRail extends StatelessWidget {
  const _FeatureRail({
    required this.states,
    required this.selectedStage,
    required this.busyStages,
    required this.onSelectPlay,
    required this.onSelectStage,
  });

  final Map<PipelineStage, StageState> states;
  final PipelineStage? selectedStage;

  /// Stages with a job running in the background for the selected video.
  final Set<PipelineStage> busyStages;
  final VoidCallback onSelectPlay;
  final void Function(PipelineStage) onSelectStage;

  /// Features that read the match.
  static const List<PipelineStage> _analysis = <PipelineStage>[
    PipelineStage.calibrate,
    PipelineStage.analyze,
    PipelineStage.track,
    PipelineStage.score,
  ];

  /// Features that shape the highlight.
  static const List<PipelineStage> _studio = <PipelineStage>[
    PipelineStage.highlight,
    PipelineStage.export,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = SportcutTokens.of(context);
    final doneCount =
        states.values.where((state) => state == StageState.done).length;
    return Container(
      width: ScMetrics.inspectorWidth,
      color: scheme.surface,
      child: Column(
        children: <Widget>[
          _RailHeader(
            label: 'Pipeline',
            trailing: '$doneCount / ${PipelineStage.values.length}',
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(tokens.space2),
              children: <Widget>[
                _FeatureRow(
                  label: 'Play',
                  selected: selectedStage == null,
                  icon: Icons.play_circle_outline,
                  done: false,
                  ready: false,
                  onTap: onSelectPlay,
                ),
                const _SectionHeader(label: 'Analysis'),
                for (final stage in _analysis) _item(stage),
                const _SectionHeader(label: 'Studio'),
                for (final stage in _studio) _item(stage),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _FeatureRow _item(PipelineStage stage) => _FeatureRow(
        label: stage.label,
        selected: selectedStage == stage,
        icon: _stageIcon(stage),
        done: states[stage] == StageState.done,
        ready: states[stage] == StageState.ready,
        busy: busyStages.contains(stage),
        onTap: () => onSelectStage(stage),
      );

  static IconData _stageIcon(PipelineStage stage) => switch (stage) {
        PipelineStage.import => Icons.download_done,
        PipelineStage.calibrate => Icons.grid_on,
        PipelineStage.analyze => Icons.settings_input_component,
        PipelineStage.track => Icons.person_search,
        PipelineStage.score => Icons.scoreboard,
        PipelineStage.highlight => Icons.star_outline,
        PipelineStage.export => Icons.ios_share,
      };
}

/// A small uppercase label separating the rail's two sections.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.label,
    required this.selected,
    required this.icon,
    required this.done,
    required this.ready,
    this.busy = false,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final IconData icon;
  final bool done;
  final bool ready;

  /// Whether this feature's job is running in the background.
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = SportcutTokens.of(context);
    final palette = SportcutPalette.of(context);
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;

    return Material(
      color: selected ? scheme.surfaceContainerHighest : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        side: BorderSide(
          color: selected ? scheme.outlineVariant : Colors.transparent,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.space3,
            vertical: tokens.space2,
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: color),
              SizedBox(width: tokens.space2),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (busy)
                const _BusySpinner(tooltip: 'Running in the background')
              else if (done)
                Icon(Icons.check, size: 15, color: palette.success)
              else if (ready)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small indeterminate spinner marking work that runs in the background.
class _BusySpinner extends StatelessWidget {
  const _BusySpinner({required this.tooltip});

  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: const SizedBox.square(
        dimension: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _ImportProgress extends StatelessWidget {
  const _ImportProgress({required this.description, required this.onCancel});

  final String description;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        children: <Widget>[
          const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(description, style: theme.textTheme.bodyMedium),
                ),
                TextButton(onPressed: onCancel, child: const Text('Cancel')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStudio extends StatelessWidget {
  const _EmptyStudio({required this.onImport, required this.importRunning});

  final VoidCallback onImport;
  final bool importRunning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.sports_tennis_outlined,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('No videos in this workspace', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Import a match recording to review it and build highlights.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: importRunning ? null : onImport,
              icon: const Icon(Icons.add),
              label: const Text('Import video'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudioError extends StatelessWidget {
  const _StudioError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(
              'The videos could not be read',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _DeleteChoice {
  const _DeleteChoice({
    required this.deleteArtifacts,
    required this.deleteRecording,
  });

  final bool deleteArtifacts;
  final bool deleteRecording;
}

class _DeleteMatchDialog extends StatefulWidget {
  const _DeleteMatchDialog({required this.match});

  final MatchRecord match;

  @override
  State<_DeleteMatchDialog> createState() => _DeleteMatchDialogState();
}

class _DeleteMatchDialogState extends State<_DeleteMatchDialog> {
  bool _deleteArtifacts = false;
  bool _deleteRecording = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Delete video?'),
      content: _DeleteBody(
        summary: '${widget.match.title} will be removed from the workspace.',
        deleteArtifacts: _deleteArtifacts,
        deleteRecording: _deleteRecording,
        onArtifactsChanged: (value) =>
            setState(() => _deleteArtifacts = value),
        onRecordingChanged: (value) =>
            setState(() => _deleteRecording = value),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(
            _DeleteChoice(
              deleteArtifacts: _deleteArtifacts,
              deleteRecording: _deleteRecording,
            ),
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

class _DeleteWorkspaceDialog extends StatefulWidget {
  const _DeleteWorkspaceDialog({required this.workspace});

  final Workspace workspace;

  @override
  State<_DeleteWorkspaceDialog> createState() => _DeleteWorkspaceDialogState();
}

class _DeleteWorkspaceDialogState extends State<_DeleteWorkspaceDialog> {
  bool _deleteArtifacts = false;
  bool _deleteRecording = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Delete workspace?'),
      content: _DeleteBody(
        summary: '${widget.workspace.title} and all its videos will be '
            'removed. The original recordings are never deleted.',
        deleteArtifacts: _deleteArtifacts,
        deleteRecording: _deleteRecording,
        onArtifactsChanged: (value) =>
            setState(() => _deleteArtifacts = value),
        onRecordingChanged: (value) =>
            setState(() => _deleteRecording = value),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(
            _DeleteChoice(
              deleteArtifacts: _deleteArtifacts,
              deleteRecording: _deleteRecording,
            ),
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

class _DeleteBody extends StatelessWidget {
  const _DeleteBody({
    required this.summary,
    required this.deleteArtifacts,
    required this.deleteRecording,
    required this.onArtifactsChanged,
    required this.onRecordingChanged,
  });

  final String summary;
  final bool deleteArtifacts;
  final bool deleteRecording;
  final ValueChanged<bool> onArtifactsChanged;
  final ValueChanged<bool> onRecordingChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(summary),
        const SizedBox(height: 12),
        CheckboxListTile(
          value: deleteArtifacts,
          onChanged: (value) => onArtifactsChanged(value ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Also delete analysis files'),
          subtitle: const Text('Proxy, audio, and sampled frames'),
        ),
        CheckboxListTile(
          value: deleteRecording,
          onChanged: (value) => onRecordingChanged(value ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Also delete the stored recording copy'),
          subtitle: const Text('The copy Sportcut made for this video'),
        ),
      ],
    );
  }
}
