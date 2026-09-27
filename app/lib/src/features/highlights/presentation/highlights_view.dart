import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bridge/sportcut_engine.dart';
import '../../editing/domain/highlight_clip.dart';
import '../../editing/domain/match_edit.dart';
import '../../editing/domain/rally.dart';
import '../../editing/presentation/editing_providers.dart';
import '../../library/domain/match_record.dart';
import '../../library/presentation/formatters.dart';
import 'highlight_ranking_providers.dart';

/// The highlight reel: which points made it, in what order, trimmed how.
///
/// A form-style panel with no playback of its own, so the studio hosts it
/// directly in the center pane without a shared player.
class HighlightsView extends ConsumerStatefulWidget {
  /// Build the highlights view.
  const HighlightsView({super.key, required this.match});

  /// Match being reviewed.
  final MatchRecord match;

  @override
  ConsumerState<HighlightsView> createState() => _HighlightsViewState();
}

class _HighlightsViewState extends ConsumerState<HighlightsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref.read(editingControllerProvider.notifier).open(widget.match),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editingControllerProvider);
    final edit = state.edit;
    final controller = ref.read(editingControllerProvider.notifier);
    final ranking = ref.watch(highlightRankingProvider).value ??
        const <String, HighlightRankDto>{};

    if (edit == null) {
      return Center(
        child: state.problem == null
            ? const CircularProgressIndicator()
            : Text(state.problem!),
      );
    }

    final leftOut = edit.rallies.where((rally) => !edit.isKept(rally)).toList()
      ..sort((a, b) => _rankFor(a, ranking).compareTo(_rankFor(b, ranking)));

    return Column(
      children: <Widget>[
        if (state.problem != null)
          MaterialBanner(
            content: Text(state.problem!),
            actions: <Widget>[
              TextButton(
                onPressed: controller.clearProblem,
                child: const Text('Dismiss'),
              ),
            ],
          ),
        Expanded(
          child: edit.clips.isEmpty
              ? const _EmptyReel()
              : ReorderableListView.builder(
                  itemCount: edit.clips.length,
                  onReorderItem: (from, to) {
                    final ids = edit.clips
                        .map((clip) => clip.id)
                        .toList(growable: true);
                    final moved = ids.removeAt(from);
                    ids.insert(to, moved);
                    unawaited(controller.reorderClips(ids));
                  },
                  itemBuilder: (context, index) {
                    final clip = edit.clips[index];
                    return _ClipTile(
                      key: ValueKey<String>(clip.id),
                      clip: clip,
                      index: index,
                      scoreAt: edit.score.atSeconds(clip.effectiveStartSeconds),
                      busy: state.busy,
                      onTrim: () => _trim(context, clip),
                      onRemove: () => controller.setKept(
                        _rallyFor(edit, clip),
                        false,
                      ),
                    );
                  },
                ),
        ),
        if (leftOut.isNotEmpty)
          _LeftOut(
            rallies: leftOut,
            ranking: ranking,
            busy: state.busy,
            onAdd: (rally) => controller.setKept(rally, true),
            onKeepBest: () => _keepBest(leftOut),
          ),
      ],
    );
  }

  Rally _rallyFor(MatchEdit edit, HighlightClip clip) {
    final rallyId = clip.rallyId;
    final rally =
        edit.rallies.where((candidate) => candidate.id == rallyId).firstOrNull;
    if (rally == null) {
      throw StateError('clip ${clip.id} has no rally to remove');
    }
    return rally;
  }

  Future<void> _trim(BuildContext context, HighlightClip clip) async {
    final range = await showDialog<RangeValues>(
      context: context,
      builder: (dialogContext) => _TrimDialog(clip: clip),
    );
    if (range == null) {
      return;
    }
    await ref.read(editingControllerProvider.notifier).trimClip(
          clip.id,
          startSeconds: range.start,
          endSeconds: range.end,
        );
  }

  Future<void> _keepBest(List<Rally> leftOut) async {
    final controller = ref.read(editingControllerProvider.notifier);
    for (final rally in leftOut.take(10)) {
      await controller.setKept(rally, true);
    }
  }
}

/// A rally's suggested rank, or a value that sorts it last when unranked.
int _rankFor(Rally rally, Map<String, HighlightRankDto> ranking) =>
    ranking[rally.id]?.rank ?? 1 << 30;

class _ClipTile extends StatelessWidget {
  const _ClipTile({
    required this.clip,
    required this.index,
    required this.scoreAt,
    required this.busy,
    required this.onTrim,
    required this.onRemove,
    super.key,
  });

  final HighlightClip clip;
  final int index;
  final ({int left, int right}) scoreAt;
  final bool busy;
  final VoidCallback onTrim;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmed = clip.effectiveStartSeconds != clip.startSeconds ||
        clip.effectiveEndSeconds != clip.endSeconds;

    return ListTile(
      leading: const Icon(Icons.drag_handle),
      title: Text(
        '${index + 1}. ${formatDuration(clip.effectiveStartSeconds)}'
        '–${formatDuration(clip.effectiveEndSeconds)}',
        style: theme.textTheme.bodyLarge?.copyWith(
          fontFeatures: tabularFigures,
        ),
      ),
      subtitle: Text(
        'Shows ${scoreAt.left}–${scoreAt.right} · '
        '${formatDuration(clip.durationSeconds)}'
        '${trimmed ? ' (trimmed)' : ''}',
        style: theme.textTheme.bodySmall?.copyWith(
          fontFeatures: tabularFigures,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: 'Trim',
            onPressed: busy ? null : onTrim,
            icon: const Icon(Icons.content_cut),
          ),
          IconButton(
            tooltip: 'Remove from the reel',
            onPressed: busy ? null : onRemove,
            icon: const Icon(Icons.remove_circle_outline),
          ),
        ],
      ),
    );
  }
}

class _TrimDialog extends StatefulWidget {
  const _TrimDialog({required this.clip});

  final HighlightClip clip;

  @override
  State<_TrimDialog> createState() => _TrimDialogState();
}

class _TrimDialogState extends State<_TrimDialog> {
  late RangeValues _range = RangeValues(
    widget.clip.effectiveStartSeconds,
    widget.clip.effectiveEndSeconds,
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Trim clip'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '${formatDuration(_range.start)}–${formatDuration(_range.end)}'
            '  ·  ${formatDuration(_range.end - _range.start)}',
          ),
          RangeSlider(
            values: _range,
            min: widget.clip.startSeconds,
            max: widget.clip.endSeconds,
            onChanged: (values) => setState(() => _range = values),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_range),
          child: const Text('Trim'),
        ),
      ],
    );
  }
}

class _EmptyReel extends StatelessWidget {
  const _EmptyReel();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No clips in the reel yet. Add a rally from the list below, or mark '
          'one on the score timeline.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _LeftOut extends StatelessWidget {
  const _LeftOut({
    required this.rallies,
    required this.ranking,
    required this.busy,
    required this.onAdd,
    required this.onKeepBest,
  });

  final List<Rally> rallies;
  final Map<String, HighlightRankDto> ranking;
  final bool busy;
  final ValueChanged<Rally> onAdd;
  final VoidCallback onKeepBest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Left out (${rallies.length})',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              TextButton(
                onPressed: busy || rallies.isEmpty ? null : onKeepBest,
                child: const Text('Keep top 10'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 72,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: rallies.length,
            itemBuilder: (context, index) {
              final rally = rallies[index];
              final rank = ranking[rally.id];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Tooltip(
                  message: rank == null
                      ? 'Add to the reel'
                      : 'Highlight score ${(rank.score * 100).round()}%',
                  child: ActionChip(
                    avatar: const Icon(Icons.add),
                    label: Text(
                      '${rank == null ? '' : '#${rank.rank} '}'
                      '${formatDuration(rally.startSeconds)}'
                      '–${formatDuration(rally.endSeconds)}',
                      style: const TextStyle(fontFeatures: tabularFigures),
                    ),
                    onPressed: busy ? null : () => onAdd(rally),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
