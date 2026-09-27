import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bridge/sportcut_engine.dart';
import '../../library/domain/match_record.dart';
import '../../library/presentation/formatters.dart';
import '../../library/presentation/playback_controller.dart';
import 'player_tracking_providers.dart';

/// Review detected people and their court-side tracks beside the recording.
///
/// Rendered over a caller-owned [controller], so the studio can share one
/// player across Play, Calibration, and this view.
class PlayerTrackingView extends ConsumerStatefulWidget {
  /// Build the tracking view over an already-managed controller.
  const PlayerTrackingView({
    super.key,
    required this.match,
    required this.controller,
    this.onOpenScore,
  });

  /// Match being analyzed.
  final MatchRecord match;

  /// Playback backend, loaded and owned by the caller.
  final PlaybackController controller;

  /// Called when the user wants to review rallies; the studio switches to the
  /// score feature and the route wrapper pushes the score screen.
  final VoidCallback? onOpenScore;

  @override
  ConsumerState<PlayerTrackingView> createState() =>
      _PlayerTrackingViewState();
}

class _PlayerTrackingViewState extends ConsumerState<PlayerTrackingView> {
  @override
  void initState() {
    super.initState();
    widget.controller.state.addListener(_refreshWindow);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          ref
              .read(playerTrackingControllerProvider.notifier)
              .open(widget.match),
        );
      }
    });
  }

  @override
  void dispose() {
    widget.controller.state.removeListener(_refreshWindow);
    super.dispose();
  }

  void _refreshWindow() {
    if (!mounted) {
      return;
    }
    final position =
        widget.controller.state.value.position.inMilliseconds / 1000.0;
    final tracking = ref.read(playerTrackingControllerProvider);
    if (tracking.loaded &&
        !tracking.loading &&
        tracking.tracks != null &&
        position < widget.match.durationSeconds &&
        (position < tracking.windowStart || position >= tracking.windowEnd)) {
      unawaited(ref
          .read(playerTrackingControllerProvider.notifier)
          .loadWindow(widget.match, position));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracking = ref.watch(playerTrackingControllerProvider);
    final controller = ref.read(playerTrackingControllerProvider.notifier);
    final theme = Theme.of(context);
    final playback = widget.controller;
    final dark = theme.brightness == Brightness.dark;

    return Column(
      children: <Widget>[
        Expanded(
          child: ValueListenableBuilder<PlaybackState>(
            valueListenable: playback.state,
            builder: (context, current, _) {
              final position = current.position.inMilliseconds / 1000.0;
              return _VideoOverlay(
                playback: current,
                surface: playback.buildSurface(context),
                frame: _nearestFrame(tracking.tracks, position),
              );
            },
          ),
        ),
        ValueListenableBuilder<PlaybackState>(
          valueListenable: playback.state,
          builder: (context, current, _) => Row(
            children: <Widget>[
              IconButton(
                tooltip: current.isPlaying ? 'Pause' : 'Play',
                onPressed: current.isReady
                    ? () => unawaited(current.isPlaying
                        ? playback.pause()
                        : playback.play())
                    : null,
                icon: Icon(current.isPlaying ? Icons.pause : Icons.play_arrow),
              ),
              Expanded(
                child: Slider(
                  value: current.progress,
                  onChanged: current.isReady
                      ? (fraction) => unawaited(playback.seek(Duration(
                            milliseconds:
                                (current.duration.inMilliseconds * fraction)
                                    .round(),
                          )))
                      : null,
                ),
              ),
              Text(formatDuration(
                current.position.inMilliseconds / 1000.0,
              )),
              const SizedBox(width: 12),
            ],
          ),
        ),
        SizedBox(
          height: 230,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: <Widget>[
              if (tracking.problem != null)
                Text(
                  tracking.problem!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              if (tracking.running) ...<Widget>[
                LinearProgressIndicator(value: tracking.progress),
                const SizedBox(height: 8),
                Text(_stageLabel(tracking.stage)),
              ],
              Row(
                children: <Widget>[
                  FilledButton.tonalIcon(
                    onPressed: tracking.running
                        ? () => unawaited(controller.cancel())
                        : () => unawaited(controller.analyze(widget.match)),
                    icon: Icon(tracking.running
                        ? Icons.stop_circle_outlined
                        : Icons.person_search_outlined),
                    label: Text(tracking.running ? 'Cancel' : 'Analyze players'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: widget.onOpenScore,
                    child: const Text('Review rallies manually'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (!tracking.loaded)
                const Text('Reading player tracks…')
              else if (tracking.tracks == null)
                const Text(
                  'No player tracks are available yet. You can still review '
                  'rallies manually.',
                )
              else ...<Widget>[
                Text(
                  '${_countLabel(tracking.tracks!.count)} · '
                  'quality ${(tracking.tracks!.countQuality * 100).round()}%',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: 'Blue',
                        style: TextStyle(
                          color: dark
                              ? Colors.lightBlueAccent
                              : Colors.lightBlue.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const TextSpan(text: ': court half 1   '),
                      TextSpan(
                        text: 'Orange',
                        style: TextStyle(
                          color: dark
                              ? Colors.orangeAccent
                              : Colors.orange.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const TextSpan(text: ': court half 2   '),
                      const TextSpan(text: 'Grey: uncertain or off court'),
                    ],
                  ),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _ReadoutChip(
                      label: 'coverage '
                          '${(tracking.tracks!.countQuality * 100).round()}%',
                    ),
                    _ReadoutChip(label: '${tracking.tracks!.gaps.length} gaps'),
                    ValueListenableBuilder<PlaybackState>(
                      valueListenable: playback.state,
                      builder: (context, current, _) => _ReadoutChip(
                        label: '${formatPosition(current.position)} / '
                            '${formatPosition(current.duration)}',
                      ),
                    ),
                  ],
                ),
                for (final gap in tracking.tracks!.gaps.take(3))
                  Text(
                    'Track #${gap.trackId} unseen from '
                    '${formatDuration(gap.time.startSeconds)} to '
                    '${formatDuration(gap.time.endSeconds)}',
                    style: theme.textTheme.bodySmall,
                  ),
                if (tracking.tracks!.count == ObservedPlayerCountDto.unknown)
                  const Text(
                    'Player count is uncertain; check the video before '
                    'confirming match details.',
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static PlayerTrackFrameDto? _nearestFrame(
    PlayerTracksDto? tracks,
    double position,
  ) {
    if (tracks == null || tracks.frames.isEmpty) {
      return null;
    }
    PlayerTrackFrameDto? nearest;
    var distance = double.infinity;
    for (final frame in tracks.frames) {
      final difference = (frame.timestampSeconds - position).abs();
      if (difference < distance) {
        nearest = frame;
        distance = difference;
      }
    }
    return distance <= 0.3 ? nearest : null;
  }

  static String _countLabel(ObservedPlayerCountDto count) => switch (count) {
        ObservedPlayerCountDto.two => 'Two players observed',
        ObservedPlayerCountDto.four => 'Four players observed',
        ObservedPlayerCountDto.unknown => 'Player count unknown',
      };

  static String _stageLabel(String? stage) => switch (stage) {
        'frames' => 'Sampling frames…',
        'person_detection' => 'Finding people…',
        'player_tracking' || 'player_analysis' => 'Following players…',
        'publish_tracks' => 'Saving player tracks…',
        _ => 'Analyzing players…',
      };
}

/// A bordered readout chip for the tracking summary strip.
class _ReadoutChip extends StatelessWidget {
  const _ReadoutChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFeatures: tabularFigures,
        ),
      ),
    );
  }
}

class _VideoOverlay extends StatelessWidget {
  const _VideoOverlay({
    required this.playback,
    required this.surface,
    required this.frame,
  });

  final PlaybackState playback;
  final Widget surface;
  final PlayerTrackFrameDto? frame;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Colors.black,
        child: Center(
          child: AspectRatio(
            aspectRatio: playback.aspectRatio,
            child: Stack(
              children: <Widget>[
                Positioned.fill(child: surface),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _TracksPainter(frame)),
                  ),
                ),
                if (playback.error != null)
                  Center(
                    child: Text(
                      playback.error!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

class _TracksPainter extends CustomPainter {
  const _TracksPainter(this.frame);

  final PlayerTrackFrameDto? frame;

  @override
  void paint(Canvas canvas, Size size) {
    for (final person in frame?.people ?? const <PlayerObservationDto>[]) {
      final color = switch (person.side) {
        PlayerCourtSideDto.first => Colors.lightBlueAccent,
        PlayerCourtSideDto.second => Colors.orangeAccent,
        PlayerCourtSideDto.unknown => Colors.white70,
      };
      final x = (person.boxX * size.width).clamp(0.0, size.width);
      final y = (person.boxY * size.height).clamp(0.0, size.height);
      final right =
          ((person.boxX + person.boxWidth) * size.width).clamp(0.0, size.width);
      final bottom = ((person.boxY + person.boxHeight) * size.height)
          .clamp(0.0, size.height);
      if (right <= x || bottom <= y) {
        continue;
      }
      final paint = Paint()
        ..color = person.selection == PersonSelectionDto.onCourt
            ? color
            : color.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = person.trackId == null ? 1 : 2;
      canvas.drawRect(Rect.fromLTRB(x, y, right, bottom), paint);
      if (person.trackId != null) {
        final label = TextPainter(
          text: TextSpan(
            text: '#${person.trackId}',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, Offset(x, math.max(0, y - label.height)));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TracksPainter oldDelegate) =>
      oldDelegate.frame != frame;
}
