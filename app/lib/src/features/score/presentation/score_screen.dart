import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../editing/domain/match_edit.dart';
import '../../editing/domain/rally.dart';
import '../../editing/domain/score_event.dart';
import '../../editing/presentation/editing_providers.dart';
import '../../library/domain/match_record.dart';
import '../../library/presentation/formatters.dart';
import '../../library/presentation/library_providers.dart';
import '../../library/presentation/playback_controller.dart';

/// The rally timeline: mark a point, say who won it, watch the score follow.
///
/// With no rally detection, the user is the segmenter, so this screen is where
/// the match's structure comes from. It never proposes a winner: the score only
/// moves when the user taps a side.
class ScoreScreen extends ConsumerStatefulWidget {
  /// Build the screen.
  ///
  /// [controller] is injected by tests; the app uses the platform player.
  const ScoreScreen({required this.match, this.controller, super.key});

  /// Match being reviewed.
  final MatchRecord match;

  /// Playback backend, when supplied by a test.
  final PlaybackController? controller;

  @override
  ConsumerState<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends ConsumerState<ScoreScreen> {
  late final PlaybackController _controller;
  late final bool _ownsController;

  /// Where the user marked the start of the rally being built.
  double? _pendingStart;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ?? ref.read(playbackControllerFactoryProvider)();
    _ownsController = widget.controller == null;
    unawaited(_controller.load(widget.match.videoPath));
    // Loading here is what makes a session survive leaving and coming back:
    // every open reads the records the last one wrote.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref.read(editingControllerProvider.notifier).open(widget.match),
      );
    });
  }

  @override
  void dispose() {
    if (_ownsController) {
      unawaited(_controller.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editingControllerProvider);
    final edit = state.edit;
    final problem = state.problem;

    return Scaffold(
      appBar: AppBar(title: Text(widget.match.title)),
      body: Column(
        children: <Widget>[
          if (problem != null)
            _ProblemBanner(
              message: problem,
              onDismiss: () =>
                  ref.read(editingControllerProvider.notifier).clearProblem(),
            ),
          _Scoreboard(edit: edit),
          Expanded(
            child: ColoredBox(
              color: Colors.black,
              child: Center(child: _controller.buildSurface(context)),
            ),
          ),
          ValueListenableBuilder<PlaybackState>(
            valueListenable: _controller.state,
            builder: (context, playback, _) => _MarkControls(
              playback: playback,
              pendingStart: _pendingStart,
              busy: state.busy,
              onPlayPause: () => playback.isPlaying
                  ? _controller.pause()
                  : _controller.play(),
              onSeek: (progress) {
                if (playback.duration.inMilliseconds == 0) {
                  return;
                }
                _controller.seek(
                  Duration(
                    milliseconds:
                        (playback.duration.inMilliseconds * progress).round(),
                  ),
                );
              },
              onMarkStart: () => setState(
                () => _pendingStart = playback.position.inMilliseconds / 1000,
              ),
              onMarkEnd: _pendingStart == null
                  ? null
                  : () => _addRally(
                        _pendingStart!,
                        playback.position.inMilliseconds / 1000,
                      ),
              onCancel: () => setState(() => _pendingStart = null),
            ),
          ),
          if (edit != null)
            Expanded(
              child: _RallyList(
                edit: edit,
                busy: state.busy,
                onSeekTo: (rally) => _controller.seek(
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
      ),
    );
  }

  Future<void> _addRally(double startSeconds, double endSeconds) async {
    setState(() => _pendingStart = null);
    await ref.read(editingControllerProvider.notifier).markRally(
          startSeconds: startSeconds,
          endSeconds: endSeconds,
        );
  }
}

/// The running score, as it stands for the confirmed rallies so far.
class _Scoreboard extends StatelessWidget {
  const _Scoreboard({required this.edit});

  final MatchEdit? edit;

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
          _Side(label: 'Left', score: score?.left ?? 0),
          Text('–', style: theme.textTheme.headlineSmall),
          _Side(label: 'Right', score: score?.right ?? 0),
        ],
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({required this.label, required this.score});

  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Text(label, style: theme.textTheme.labelMedium),
        Text('$score', style: theme.textTheme.headlineMedium),
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
    required this.busy,
    required this.onSeekTo,
    required this.onWinner,
    required this.onKeep,
    required this.onRemove,
  });

  final MatchEdit edit;
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
        return _RallyTile(
          rally: rally,
          index: index,
          kept: edit.isKept(rally),
          score: edit.score.atRally(rally.id),
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
      ),
      subtitle: Text(
        scored && scoreLine != null
            ? 'Confirmed · ${scoreLine.leftScore}–${scoreLine.rightScore}'
            : 'Tap the side that won it',
        style: theme.textTheme.bodySmall,
      ),
      leading: IconButton(
        tooltip: kept ? 'Remove from reel' : 'Keep in reel',
        onPressed: busy ? null : () => onKeep(!kept),
        icon: Icon(kept ? Icons.star : Icons.star_border),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _WinnerButton(
            label: 'L',
            selected: rally.winnerSide == WinnerSide.left,
            onPressed: busy ? null : () => onWinner(WinnerSide.left),
          ),
          const SizedBox(width: 4),
          _WinnerButton(
            label: 'R',
            selected: rally.winnerSide == WinnerSide.right,
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
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 44,
      height: 40,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor:
              selected ? theme.colorScheme.primaryContainer : null,
        ),
        child: Text(label),
      ),
    );
  }
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
