import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bridge/sportcut_engine.dart';
import '../../editing/domain/match_edit.dart';
import '../../editing/domain/rally.dart';
import '../../editing/domain/score_event.dart';
import '../../editing/presentation/editing_providers.dart';
import '../../library/domain/match_record.dart';
import '../../library/presentation/formatters.dart';
import '../../library/presentation/playback_controller.dart';
import '../../rally/presentation/rally_review_providers.dart';
import 'serving_sides_providers.dart';

/// The rally timeline: mark a point, say who won it, watch the score follow.
///
/// Rendered over a caller-owned [controller], so the studio can share one
/// player across features.
class ScoreView extends ConsumerStatefulWidget {
  /// Build the score view over an already-managed controller.
  const ScoreView({super.key, required this.match, required this.controller});

  /// Match being reviewed.
  final MatchRecord match;

  /// Playback backend, loaded and owned by the caller.
  final PlaybackController controller;

  @override
  ConsumerState<ScoreView> createState() => _ScoreViewState();
}

class _ScoreViewState extends ConsumerState<ScoreView> {
  /// Where the user marked the start of the rally being built.
  double? _pendingStart;

  @override
  void initState() {
    super.initState();
    // Loading here is what makes a session survive leaving and coming back:
    // every open reads the records the last one wrote.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref.read(editingControllerProvider.notifier).open(widget.match),
      );
      unawaited(
        ref.read(rallyReviewControllerProvider.notifier).open(widget.match),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editingControllerProvider);
    final edit = state.edit;
    final problem = state.problem;
    final review = ref.watch(rallyReviewControllerProvider);
    final canAnalyze = ref.watch(rallySegmentationConfigProvider) != null;
    final serving = ref.watch(servingSidesProvider).value ??
        const <String, RallySideDto>{};
    WinnerSide? currentServer;
    for (final rally in edit?.rallies ?? const <Rally>[]) {
      if (rally.isScored) {
        currentServer = rally.winnerSide;
      }
    }
    final playback = widget.controller;

    return Column(
      children: <Widget>[
        if (problem != null)
          _ProblemBanner(
            message: problem,
            onDismiss: () =>
                ref.read(editingControllerProvider.notifier).clearProblem(),
          ),
        _Scoreboard(edit: edit, server: currentServer),
        Expanded(
          child: ColoredBox(
            color: Colors.black,
            child: Center(child: playback.buildSurface(context)),
          ),
        ),
        ValueListenableBuilder<PlaybackState>(
          valueListenable: playback.state,
          builder: (context, current, _) => _MarkControls(
            playback: current,
            pendingStart: _pendingStart,
            busy: state.busy,
            onPlayPause: () =>
                current.isPlaying ? playback.pause() : playback.play(),
            onSeek: (progress) {
              if (current.duration.inMilliseconds == 0) {
                return;
              }
              playback.seek(
                Duration(
                  milliseconds:
                      (current.duration.inMilliseconds * progress).round(),
                ),
              );
            },
            onMarkStart: () => setState(
              () => _pendingStart = current.position.inMilliseconds / 1000,
            ),
            onMarkEnd: _pendingStart == null
                ? null
                : () => _addRally(
                      _pendingStart!,
                      current.position.inMilliseconds / 1000,
                    ),
            onCancel: () => setState(() => _pendingStart = null),
          ),
        ),
        _RallySuggestionsPanel(
          review: review,
          canAnalyze: canAnalyze,
          rallies: edit?.rallies ?? const <Rally>[],
          busy: state.busy,
          onAnalyze: () =>
              ref.read(rallyReviewControllerProvider.notifier).analyze(),
          onCancel: () =>
              ref.read(rallyReviewControllerProvider.notifier).cancel(),
          onAccept: (candidate) =>
              ref.read(rallyReviewControllerProvider.notifier).accept(candidate),
          onAdjust: _adjustSuggestion,
          onDismiss: (candidate) => ref
              .read(rallyReviewControllerProvider.notifier)
              .dismiss(candidate),
        ),
        if (edit != null)
          Expanded(
            child: _RallyList(
              edit: edit,
              serving: serving,
              busy: state.busy,
              onSeekTo: (rally) => playback.seek(
                Duration(
                  milliseconds: (rally.startSeconds * 1000).round(),
                ),
              ),
              onWinner: (rally, side) => ref
                  .read(editingControllerProvider.notifier)
                  .setWinner(rally.id, side),
              onKeep: (rally, kept) => ref
                  .read(editingControllerProvider.notifier)
                  .setKept(rally, kept),
              onRemove: (rally) => ref
                  .read(editingControllerProvider.notifier)
                  .removeRally(rally.id),
            ),
          ),
      ],
    );
  }

  Future<void> _addRally(double startSeconds, double endSeconds) async {
    setState(() => _pendingStart = null);
    await ref.read(editingControllerProvider.notifier).markRally(
          startSeconds: startSeconds,
          endSeconds: endSeconds,
        );
  }

  Future<void> _adjustSuggestion(RallySuggestionDto candidate) async {
    var range = RangeValues(candidate.startSeconds, candidate.endSeconds);
    final adjusted = await showDialog<RangeValues>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Adjust suggested rally'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '${formatDuration(range.start)}–${formatDuration(range.end)}',
              ),
              RangeSlider(
                values: range,
                min: 0,
                max: widget.match.durationSeconds,
                divisions:
                    widget.match.durationSeconds.ceil().clamp(1, 1000).toInt(),
                onChanged: (next) => setDialogState(() => range = next),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: range.end > range.start
                  ? () => Navigator.pop(dialogContext, range)
                  : null,
              child: const Text('Accept rally'),
            ),
          ],
        ),
      ),
    );
    if (adjusted == null || !mounted) {
      return;
    }
    await ref.read(rallyReviewControllerProvider.notifier).accept(
          candidate,
          startSeconds: adjusted.start,
          endSeconds: adjusted.end,
        );
  }
}

class _RallySuggestionsPanel extends StatelessWidget {
  const _RallySuggestionsPanel({
    required this.review,
    required this.canAnalyze,
    required this.rallies,
    required this.busy,
    required this.onAnalyze,
    required this.onCancel,
    required this.onAccept,
    required this.onAdjust,
    required this.onDismiss,
  });

  final RallyReviewState review;
  final bool canAnalyze;
  final List<Rally> rallies;
  final bool busy;
  final VoidCallback onAnalyze;
  final VoidCallback onCancel;
  final ValueChanged<RallySuggestionDto> onAccept;
  final ValueChanged<RallySuggestionDto> onAdjust;
  final ValueChanged<RallySuggestionDto> onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suggestions = review.suggestions;
    final pending = review.pending;
    final restCount =
        suggestions?.timeline.where((span) => span.kind == 'rest').length ?? 0;
    final unknownCount =
        suggestions?.timeline.where((span) => span.kind == 'unknown').length ??
            0;

    return ExpansionTile(
      title: Text(
          'Rally suggestions${pending.isEmpty ? '' : ' (${pending.length})'}'),
      subtitle: Text(
        review.running
            ? 'Analyzing player motion…'
            : suggestions == null
                ? 'Manual marking is available'
                : '$restCount rest · $unknownCount unknown intervals',
        style: theme.textTheme.bodySmall,
      ),
      children: <Widget>[
        if (review.problem != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(review.problem!, style: theme.textTheme.bodySmall),
          ),
        if (review.running) ...<Widget>[
          LinearProgressIndicator(value: review.progress),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(review.stage ?? 'Preparing analysis…'),
              ),
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
            ],
          ),
        ] else
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: canAnalyze ? onAnalyze : null,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Analyze rallies'),
            ),
          ),
        if (suggestions != null && pending.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child:
                Text('No unreviewed suggestions. You can still mark rallies.'),
          ),
        if (pending.isNotEmpty)
          SizedBox(
            height: 220,
            child: ListView.builder(
              itemCount: pending.length,
              itemBuilder: (context, index) {
                final candidate = pending[index];
                final overlaps = rallies.any(
                  (rally) =>
                      rally.startSeconds < candidate.endSeconds &&
                      rally.endSeconds > candidate.startSeconds,
                );
                return ListTile(
                  title: Text(
                    '${formatDuration(candidate.startSeconds)}–'
                    '${formatDuration(candidate.endSeconds)}',
                  ),
                  subtitle: Text(
                    overlaps
                        ? 'Overlaps a reviewed rally · adjust or dismiss'
                        : 'Signal quality ${(candidate.quality * 100).round()}%'
                            '${candidate.audioAvailable ? ' · audio available' : ' · motion only'}',
                  ),
                  trailing: Wrap(
                    spacing: 0,
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Accept suggestion',
                        onPressed: busy || review.busy || overlaps
                            ? null
                            : () => onAccept(candidate),
                        icon: const Icon(Icons.check),
                      ),
                      IconButton(
                        tooltip: 'Adjust and accept',
                        onPressed: busy || review.busy
                            ? null
                            : () => onAdjust(candidate),
                        icon: const Icon(Icons.tune),
                      ),
                      IconButton(
                        tooltip: 'Dismiss suggestion',
                        onPressed: busy || review.busy
                            ? null
                            : () => onDismiss(candidate),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// The running score, as it stands for the confirmed rallies so far.
class _Scoreboard extends StatelessWidget {
  const _Scoreboard({required this.edit, required this.server});

  final MatchEdit? edit;
  final WinnerSide? server;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = edit?.score;
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          _Side(
            label: 'Left',
            score: score?.left ?? 0,
            serving: server == WinnerSide.left,
          ),
          Text('–', style: theme.textTheme.headlineSmall),
          _Side(
            label: 'Right',
            score: score?.right ?? 0,
            serving: server == WinnerSide.right,
          ),
        ],
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.label,
    required this.score,
    required this.serving,
  });

  final String label;
  final int score;
  final bool serving;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label, style: theme.textTheme.labelMedium),
            if (serving) ...<Widget>[
              const SizedBox(width: 4),
              Tooltip(
                message: 'Serves next',
                child: Icon(
                  Icons.sports_tennis,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
        Text(
          '$score',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: serving ? theme.colorScheme.primary : null,
            fontFeatures: tabularFigures,
          ),
        ),
      ],
    );
  }
}

class _MarkControls extends StatelessWidget {
  const _MarkControls({
    required this.playback,
    required this.pendingStart,
    required this.busy,
    required this.onPlayPause,
    required this.onSeek,
    required this.onMarkStart,
    required this.onMarkEnd,
    required this.onCancel,
  });

  final PlaybackState playback;
  final double? pendingStart;
  final bool busy;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onSeek;
  final VoidCallback onMarkStart;
  final VoidCallback? onMarkEnd;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final start = pendingStart;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                onPressed: playback.isReady ? onPlayPause : null,
                icon: Icon(
                  playback.isPlaying ? Icons.pause : Icons.play_arrow,
                  semanticLabel: playback.isPlaying ? 'Pause' : 'Play',
                ),
              ),
              Text(formatPosition(playback.position)),
              Expanded(
                child: Slider(
                  value: playback.progress,
                  onChanged: playback.isReady ? onSeek : null,
                ),
              ),
              Text(formatPosition(playback.duration)),
            ],
          ),
          Row(
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: playback.isReady && !busy ? onMarkStart : null,
                icon: const Icon(Icons.flag_outlined),
                label: Text(
                  start == null
                      ? 'Mark start'
                      : 'Start at ${formatDuration(start)}',
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: busy ? null : onMarkEnd,
                icon: const Icon(Icons.check),
                label: const Text('Mark end'),
              ),
              if (start != null) ...<Widget>[
                const SizedBox(width: 8),
                TextButton(onPressed: onCancel, child: const Text('Cancel')),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// The marked rallies, each waiting for a winner.
class _RallyList extends StatelessWidget {
  const _RallyList({
    required this.edit,
    required this.serving,
    required this.busy,
    required this.onSeekTo,
    required this.onWinner,
    required this.onKeep,
    required this.onRemove,
  });

  final MatchEdit edit;
  final Map<String, RallySideDto> serving;
  final bool busy;
  final ValueChanged<Rally> onSeekTo;
  final void Function(Rally rally, WinnerSide? side) onWinner;
  final void Function(Rally rally, bool kept) onKeep;
  final ValueChanged<Rally> onRemove;

  @override
  Widget build(BuildContext context) {
    if (edit.rallies.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No rallies yet. Scrub to a point, mark its start and end, and '
            'say who won it.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: edit.rallies.length,
      itemBuilder: (context, index) {
        final rally = edit.rallies[index];
        final side = serving[rally.id];
        final suggested = side == null
            ? null
            : (side == RallySideDto.left ? WinnerSide.left : WinnerSide.right);
        return _RallyTile(
          rally: rally,
          index: index,
          kept: edit.isKept(rally),
          score: edit.score.atRally(rally.id),
          suggested: suggested,
          busy: busy,
          onSeekTo: () => onSeekTo(rally),
          onWinner: (side) => onWinner(rally, side),
          onKeep: (kept) => onKeep(rally, kept),
          onRemove: () => onRemove(rally),
        );
      },
    );
  }
}

class _RallyTile extends StatelessWidget {
  const _RallyTile({
    required this.rally,
    required this.index,
    required this.kept,
    required this.score,
    required this.suggested,
    required this.busy,
    required this.onSeekTo,
    required this.onWinner,
    required this.onKeep,
    required this.onRemove,
  });

  final Rally rally;
  final int index;
  final bool kept;
  final ScoreEvent? score;
  final WinnerSide? suggested;
  final bool busy;
  final VoidCallback onSeekTo;
  final void Function(WinnerSide? side) onWinner;
  final ValueChanged<bool> onKeep;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scored = rally.isScored;
    final scoreLine = score;

    return ListTile(
      onTap: onSeekTo,
      title: Text(
        'Point ${index + 1} · ${formatDuration(rally.startSeconds)}'
        '–${formatDuration(rally.endSeconds)}',
        style: theme.textTheme.bodyLarge?.copyWith(
          fontFeatures: tabularFigures,
        ),
      ),
      subtitle: Text(
        scored && scoreLine != null
            ? 'Confirmed · ${scoreLine.leftScore}–${scoreLine.rightScore}'
            : suggested == null
                ? 'Tap the side that won it'
                : 'Suggested: ${suggested == WinnerSide.left ? 'Left' : 'Right'}'
                    ' · tap to confirm',
        style: theme.textTheme.bodySmall?.copyWith(
          fontFeatures: tabularFigures,
        ),
      ),
      leading: IconButton(
        tooltip: kept ? 'Remove from reel' : 'Keep in reel',
        onPressed: busy ? null : () => onKeep(!kept),
        icon: Icon(
          kept ? Icons.star : Icons.star_border,
          color: kept ? theme.colorScheme.primary : null,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _WinnerButton(
            label: 'L',
            selected: rally.winnerSide == WinnerSide.left,
            suggested: !scored && suggested == WinnerSide.left,
            onPressed: busy ? null : () => onWinner(WinnerSide.left),
          ),
          const SizedBox(width: 4),
          _WinnerButton(
            label: 'R',
            selected: rally.winnerSide == WinnerSide.right,
            suggested: !scored && suggested == WinnerSide.right,
            onPressed: busy ? null : () => onWinner(WinnerSide.right),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Remove rally',
            onPressed: busy ? null : onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}

class _WinnerButton extends StatelessWidget {
  const _WinnerButton({
    required this.label,
    required this.selected,
    this.suggested = false,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final bool suggested;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final picked = selected;
    final hint = suggested && !selected;
    final displayLabel = hint ? '•$label' : label;
    final borderColor = picked ? scheme.primary : scheme.outline;
    final borderWidth = picked ? 2.0 : 1.0;

    return SizedBox(
      width: 44,
      height: 36,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onPressed,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (hint)
              CustomPaint(
                painter: _DashedBorderPainter(
                  color: scheme.outline,
                  radius: 4,
                  strokeWidth: 1,
                ),
              )
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  color: picked
                      ? scheme.primary.withValues(alpha: 0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: borderColor, width: borderWidth),
                ),
              ),
            Center(
              child: Text(
                displayLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: picked ? scheme.primary : scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A dashed rounded border, used for the engine-suggested winner state.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    const dash = 3.0;
    const gap = 2.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth;
}

class _ProblemBanner extends StatelessWidget {
  const _ProblemBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.errorContainer,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close),
            tooltip: 'Dismiss',
          ),
        ],
      ),
    );
  }
}
