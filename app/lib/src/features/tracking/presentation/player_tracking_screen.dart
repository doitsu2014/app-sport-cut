import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../bridge/sportcut_engine.dart';
import '../../library/domain/match_record.dart';
import '../../library/presentation/formatters.dart';
import '../../library/presentation/library_providers.dart';
import '../../library/presentation/playback_controller.dart';
import 'player_tracking_providers.dart';

/// Review detected people and their court-side tracks beside the recording.
class PlayerTrackingScreen extends ConsumerStatefulWidget {
  const PlayerTrackingScreen({required this.match, super.key});

  final MatchRecord match;

  @override
  ConsumerState<PlayerTrackingScreen> createState() =>
      _PlayerTrackingScreenState();
}

class _PlayerTrackingScreenState extends ConsumerState<PlayerTrackingScreen> {
  late final PlaybackController _playback;

  @override
  void initState() {
    super.initState();
    _playback = ref.read(playbackControllerFactoryProvider)();
    _playback.state.addListener(_refreshWindow);
    unawaited(_playback.load(widget.match.videoPath));
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
    _playback.state.removeListener(_refreshWindow);
    unawaited(_playback.dispose());
    super.dispose();
  }

  void _refreshWindow() {
    if (!mounted) {
      return;
    }
    final position = _playback.state.value.position.inMilliseconds / 1000.0;
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
    return Scaffold(
      appBar: AppBar(title: const Text('Player analysis')),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ValueListenableBuilder<PlaybackState>(
              valueListenable: _playback.state,
              builder: (context, playback, _) {
                final position = playback.position.inMilliseconds / 1000.0;
                return _VideoOverlay(
                  playback: playback,
                  surface: _playback.buildSurface(context),
                  frame: _nearestFrame(tracking.tracks, position),
                );
              },
            ),
          ),
          ValueListenableBuilder<PlaybackState>(
            valueListenable: _playback.state,
            builder: (context, playback, _) => Row(
              children: <Widget>[
                IconButton(
                  tooltip: playback.isPlaying ? 'Pause' : 'Play',
                  onPressed: playback.isReady
                      ? () => unawaited(playback.isPlaying
                          ? _playback.pause()
                          : _playback.play())
                      : null,
                  icon:
                      Icon(playback.isPlaying ? Icons.pause : Icons.play_arrow),
                ),
                Expanded(
                  child: Slider(
                    value: playback.progress,
                    onChanged: playback.isReady
                        ? (fraction) => unawaited(_playback.seek(Duration(
                              milliseconds:
                                  (playback.duration.inMilliseconds * fraction)
                                      .round(),
                            )))
                        : null,
                  ),
                ),
                Text(formatDuration(
                  playback.position.inMilliseconds / 1000.0,
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
                      label:
                          Text(tracking.running ? 'Cancel' : 'Analyze players'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pushNamed(
                        AppRoutes.score,
                        arguments: widget.match,
                      ),
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
                  Text(
                    'Blue: court half 1   Orange: court half 2   '
                    'Grey: uncertain or off court',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    '${tracking.tracks!.usableCoverage.length} usable spans · '
                    '${tracking.tracks!.gaps.length} track gaps in this view',
                    style: theme.textTheme.bodySmall,
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
      ),
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
