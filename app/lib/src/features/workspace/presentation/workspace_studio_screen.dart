import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calibration/presentation/calibration_view.dart';
import '../../editing/domain/match_edit.dart';
import '../../editing/presentation/editing_providers.dart';
import '../../export/presentation/export_view.dart';
import '../../highlights/presentation/highlights_view.dart';
import '../../library/domain/match_import_exception.dart';
import '../../library/domain/match_record.dart';
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

    // Scoring the first rally flips Review & score from ready to done; refresh
    // the stage facts so the rail shows the check rather than a stale state.
    ref.listen(editingControllerProvider, (previous, next) {
      if (_editHasScore(previous?.edit) != _editHasScore(next.edit)) {
        _refresh();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workspace.title),
        actions: <Widget>[
          IconButton(
            onPressed: import.isRunning ? null : _import,
            icon: const Icon(Icons.add),
            tooltip: 'Import video',
          ),
          IconButton(
            onPressed: import.isRunning
                ? null
                : () => _selectStage(PipelineStage.analyze),
            icon: const Icon(Icons.settings_input_component),
            tooltip: 'Prepare analysis',
          ),
          IconButton(
            onPressed: () => _confirmDeleteWorkspace(),
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete workspace',
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
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
                final facts = ref
                    .watch(workspaceVideoFactsProvider(widget.workspace.id))
                    .value;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _VideoRail(
                      entries: entries,
                      selectedId: _selectedVideoId,
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
                      onSelectPlay: () => setState(() => _selectedStage = null),
                      onSelectStage: _selectStage,
                    ),
                  ],
                );
              },
            ),
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
        for (final stage in PipelineStage.values) stage: StageState.blocked,
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
        return PlayerTrackingView(
          match: entry.match,
          controller: controller,
          // Manual review is always available, even without detected tracks.
          onOpenScore: () =>
              setState(() => _selectedStage = PipelineStage.score),
        );
      case PipelineStage.score:
        return ScoreView(match: entry.match, controller: controller);
      case PipelineStage.highlight:
        return HighlightsView(match: entry.match);
      case PipelineStage.export:
        return ExportView(match: entry.match);
      case PipelineStage.import:
      case PipelineStage.analyze:
        // Import is not a lens, and prepare-analysis is a background job; the
        // center stays on playback in both cases.
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
    final facts = ref
        .read(workspaceVideoFactsProvider(widget.workspace.id))
        .value;
    final state = _statesFor(entry, facts)[stage] ?? StageState.blocked;
    if (state == StageState.blocked) {
      _showBlocked(stage);
      return;
    }
    switch (stage) {
      case PipelineStage.import:
        return;
      case PipelineStage.calibrate:
        setState(() => _selectedStage = stage);
      case PipelineStage.analyze:
        unawaited(_generateArtifacts(entry.match));
      case PipelineStage.track:
      case PipelineStage.score:
      case PipelineStage.highlight:
      case PipelineStage.export:
        setState(() => _selectedStage = stage);
    }
  }

  MatchListEntry? _selectedEntryFromProvider() {
    final entries = ref
        .read(workspaceVideosProvider(widget.workspace.id))
        .value;
    if (entries == null) {
      return null;
    }
    return _selectedEntry(entries);
  }

  Future<void> _generateArtifacts(MatchRecord match) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repository = await ref.read(matchRepositoryProvider.future);
      final manifest = await repository.generateArtifacts(match);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Analysis files ready: ${manifest.artifacts.length} artifacts',
          ),
        ),
      );
      _refresh();
    } on MatchImportException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _showBlocked(PipelineStage stage) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Finish the earlier steps first before ${stage.label.toLowerCase()}.',
        ),
      ),
    );
  }

  void _refresh() {
    ref.invalidate(workspaceVideosProvider(widget.workspace.id));
    ref.invalidate(workspaceVideoFactsProvider(widget.workspace.id));
  }

  bool _editHasScore(MatchEdit? edit) => edit != null && !edit.score.isEmpty;

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

class _VideoRail extends StatefulWidget {
  const _VideoRail({
    required this.entries,
    required this.selectedId,
    required this.onSelect,
    required this.onDelete,
  });

  final List<MatchListEntry> entries;
  final String? selectedId;
  final void Function(MatchListEntry) onSelect;
  final void Function(MatchListEntry) onDelete;

  @override
  State<_VideoRail> createState() => _VideoRailState();
}

class _VideoRailState extends State<_VideoRail> {
  String? _hoveredId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 200,
      child: ListView(
        children: <Widget>[
          for (final entry in widget.entries)
            MouseRegion(
              onEnter: (_) => setState(() => _hoveredId = entry.match.id),
              onExit: (_) => setState(() => _hoveredId = null),
              child: ListTile(
                selected: entry.match.id == widget.selectedId,
                selectedTileColor: scheme.secondaryContainer,
                title: Text(entry.match.title, maxLines: 1),
                leading: Icon(
                  entry.recordingAvailable
                      ? Icons.movie_outlined
                      : Icons.videocam_off_outlined,
                ),
                subtitle: entry.score == null
                    ? null
                    : Text('Score ${entry.score!.left}–${entry.score!.right}'),
                onTap: () => widget.onSelect(entry),
                trailing: IgnorePointer(
                  ignoring: _hoveredId != entry.match.id,
                  child: AnimatedOpacity(
                    opacity: _hoveredId == entry.match.id ? 1 : 0,
                    duration: const Duration(milliseconds: 120),
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete video',
                      onPressed: () => widget.onDelete(entry),
                    ),
                  ),
                ),
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
    required this.onSelectPlay,
    required this.onSelectStage,
  });

  final Map<PipelineStage, StageState> states;
  final PipelineStage? selectedStage;
  final VoidCallback onSelectPlay;
  final void Function(PipelineStage) onSelectStage;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: ListView(
        children: <Widget>[
          _FeatureItem(
            label: 'Play',
            selected: selectedStage == null,
            icon: Icons.play_circle_outline,
            state: null,
            onTap: onSelectPlay,
          ),
          for (final stage in PipelineStage.values.where(
            (stage) =>
                stage != PipelineStage.import &&
                stage != PipelineStage.analyze,
          ))
            _FeatureItem(
              label: stage.label,
              selected: selectedStage == stage,
              icon: _stageIcon(stage),
              state: states[stage],
              onTap: () => onSelectStage(stage),
            ),
        ],
      ),
    );
  }

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

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
    this.state,
  });

  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;
  final StageState? state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = state == StageState.done;
    final ready = state == StageState.ready;
    final blocked = state == StageState.blocked;

    // Selected wins over every other state: the lens you are looking at is
    // the active menu item. Next (the stage to do first) and ready (an
    // actionable-but-later stage) stay distinct when nothing is selected.
    final Color? tileColor;
    final Color color;
    final FontWeight weight;
    if (selected) {
      tileColor = scheme.secondaryContainer;
      color = scheme.onSecondaryContainer;
      weight = FontWeight.w700;
    } else if (ready) {
      tileColor = null;
      color = scheme.primary;
      weight = FontWeight.w700;
    } else if (done) {
      tileColor = null;
      color = scheme.onSurfaceVariant;
      weight = FontWeight.w400;
    } else if (blocked) {
      tileColor = null;
      color = scheme.onSurfaceVariant.withValues(alpha: 0.45);
      weight = FontWeight.w400;
    } else {
      tileColor = null;
      color = scheme.onSurface;
      weight = FontWeight.w400;
    }

    return ListTile(
      tileColor: tileColor,
      leading: Icon(icon, size: 20, color: color),
      title: Text(
        label,
        style: TextStyle(color: color, fontWeight: weight),
      ),
      trailing: done
          ? Icon(Icons.check, size: 16, color: scheme.primary)
          : null,
      onTap: onTap,
      dense: true,
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
            Text('No videos yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Import a recording to review it and build highlights.',
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
