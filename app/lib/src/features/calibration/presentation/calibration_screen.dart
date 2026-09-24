import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bridge/sportcut_engine.dart';
import '../../library/domain/match_record.dart';
import '../../library/presentation/playback_controller.dart';
import '../../library/presentation/library_providers.dart';
import '../domain/court_calibration.dart';
import 'calibration_controller.dart';

/// How the corner order reads to the user, in the order the handles are
/// numbered.
const List<String> _cornerHints = <String>[
  '1 · nearest you, left',
  '2 · nearest you, right',
  '3 · farthest, right',
  '4 · farthest, left',
];

/// Radius of a corner handle, in logical pixels.
const double _handleRadius = 20;

/// Court calibration: marking the court corners so later phases can map image
/// coordinates to court coordinates.
///
/// The user drags four numbered handles onto the court, says which way the court
/// runs, and sees the projected net drawn back over the recording. The projected
/// line is the point of the screen: it is what lets the user check the marking
/// against the painted court rather than trusting four taps.
class CalibrationScreen extends ConsumerStatefulWidget {
  /// Build the calibration screen.
  ///
  /// [controller] is injected by tests; the app uses the platform player.
  const CalibrationScreen({
    required this.match,
    this.controller,
    super.key,
  });

  /// Match being calibrated.
  final MatchRecord match;

  /// Playback backend, when supplied by a test.
  final PlaybackController? controller;

  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends ConsumerState<CalibrationScreen> {
  late final PlaybackController _playback;
  late final bool _ownsPlayback;

  @override
  void initState() {
    super.initState();
    _playback =
        widget.controller ?? ref.read(playbackControllerFactoryProvider)();
    _ownsPlayback = widget.controller == null;
    unawaited(_playback.load(widget.match.videoPath));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(calibrationControllerProvider.notifier).open(widget.match);
    });
  }

  @override
  void dispose() {
    if (_ownsPlayback) {
      unawaited(_playback.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calibrationControllerProvider);
    final controller = ref.read(calibrationControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Court calibration')),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ValueListenableBuilder<PlaybackState>(
              valueListenable: _playback.state,
              builder: (context, playback, _) => _Stage(
                playback: playback,
                surface: _playback.buildSurface(context),
                corners: state.corners,
                geometry: state.geometry,
                onCornerMoved: controller.nudgeCorner,
                onCornerReleased: (_) => unawaited(controller.project()),
              ),
            ),
          ),
          ValueListenableBuilder<PlaybackState>(
            valueListenable: _playback.state,
            builder: (context, playback, _) => _Scrubber(
              state: playback,
              onPlayPause: () => playback.isPlaying
                  ? unawaited(_playback.pause())
                  : unawaited(_playback.play()),
              onSeek: (progress) {
                final duration = playback.duration.inMilliseconds;
                if (duration <= 0) {
                  return;
                }
                unawaited(
                  _playback.seek(
                    Duration(milliseconds: (duration * progress).round()),
                  ),
                );
              },
            ),
          ),
          _Controls(
            state: state,
            onOrientationChanged: (orientation) =>
                unawaited(controller.setOrientation(orientation)),
            onSave: state.isComplete && !state.saving ? _save : null,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final updated =
        await ref.read(calibrationControllerProvider.notifier).save(widget.match);
    if (updated == null || !mounted) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text('Court marked for ${updated.title}')),
    );
    navigator.pop(updated);
  }
}

/// The video, the court drawn over it, and the handles the user drags.
class _Stage extends StatelessWidget {
  const _Stage({
    required this.playback,
    required this.surface,
    required this.corners,
    required this.geometry,
    required this.onCornerMoved,
    required this.onCornerReleased,
  });

  final PlaybackState playback;
  final Widget surface;
  final List<CourtCorner> corners;
  final CourtGeometryDto? geometry;
  final void Function(int index, double dx, double dy) onCornerMoved;
  final void Function(int index) onCornerReleased;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          // The same box the video is drawn in, at the same ratio. A position
          // divided by this box's size is the normalized coordinate the
          // recording's frames share, which is what makes a marked corner mean
          // the same thing everywhere.
          aspectRatio: playback.aspectRatio,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned.fill(child: surface),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _CourtPainter(
                          corners: corners,
                          net: geometry?.net,
                        ),
                      ),
                    ),
                  ),
                  for (var index = 0; index < corners.length; index++)
                    _CornerHandle(
                      index: index,
                      corner: corners[index],
                      box: size,
                      onMoved: onCornerMoved,
                      onReleased: onCornerReleased,
                    ),
                  if (playback.error != null)
                    Positioned.fill(
                      child: _PlaybackProblem(message: playback.error!),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One draggable corner, numbered and labelled.
class _CornerHandle extends StatelessWidget {
  const _CornerHandle({
    required this.index,
    required this.corner,
    required this.box,
    required this.onMoved,
    required this.onReleased,
  });

  final int index;
  final CourtCorner corner;
  final Size box;
  final void Function(int index, double dx, double dy) onMoved;
  final void Function(int index) onReleased;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: corner.x * box.width - _handleRadius,
      top: corner.y * box.height - _handleRadius,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => onMoved(
          index,
          details.delta.dx / box.width,
          details.delta.dy / box.height,
        ),
        onPanEnd: (_) => onReleased(index),
        child: Container(
          width: _handleRadius * 2,
          height: _handleRadius * 2,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _handleColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// The colour of every corner handle.
const Color _handleColor = Color(0xFFFFC107);

/// Draws the marked court and the net the engine projected.
class _CourtPainter extends CustomPainter {
  const _CourtPainter({required this.corners, required this.net});

  final List<CourtCorner> corners;
  final List<CourtCornerDto>? net;

  @override
  void paint(Canvas canvas, Size size) {
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white70;

    final path = Path();
    for (var index = 0; index < corners.length; index++) {
      final point = _offset(corners[index], size);
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    if (corners.length > 2) {
      path.close();
    }
    canvas.drawPath(path, edge);

    final net = this.net;
    if (net == null || net.length != 2) {
      return;
    }
    // Where the two sides divide. This is the line the user checks the marking
    // against, because it is the one part of the projection the four corners do
    // not already show.
    canvas.drawLine(
      _offset(CourtCorner(x: net[0].x, y: net[0].y), size),
      _offset(CourtCorner(x: net[1].x, y: net[1].y), size),
      Paint()
        ..strokeWidth = 3
        ..color = Colors.amber,
    );
  }

  Offset _offset(CourtCorner corner, Size size) =>
      Offset(corner.x * size.width, corner.y * size.height);

  @override
  bool shouldRepaint(_CourtPainter oldDelegate) =>
      oldDelegate.corners != corners || oldDelegate.net != net;
}

/// Timeline scrubbing, so the user can stop on a moment where the court is
/// clearly visible rather than marking corners over a blur or a crowd.
class _Scrubber extends StatelessWidget {
  const _Scrubber({
    required this.state,
    required this.onPlayPause,
    required this.onSeek,
  });

  final PlaybackState state;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final enabled = state.isReady && state.error == null;
    return ColoredBox(
      color: Colors.black,
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: enabled ? onPlayPause : null,
            color: Colors.white,
            icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
            tooltip: state.isPlaying ? 'Pause' : 'Play',
          ),
          Expanded(
            child: Slider(
              value: state.progress,
              onChanged: enabled ? onSeek : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// The instructions, the orientation choice, and the save action.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.state,
    required this.onOrientationChanged,
    required this.onSave,
  });

  final CalibrationState state;
  final ValueChanged<CourtOrientation> onOrientationChanged;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Drag each handle onto a corner of the court, starting with the '
              'one nearest you.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              children: <Widget>[
                for (final hint in _cornerHints)
                  Text(hint, style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Which way does the court run?',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            SegmentedButton<CourtOrientation>(
              segments: const <ButtonSegment<CourtOrientation>>[
                ButtonSegment<CourtOrientation>(
                  value: CourtOrientation.away,
                  label: Text('Away from you'),
                ),
                ButtonSegment<CourtOrientation>(
                  value: CourtOrientation.across,
                  label: Text('Across the view'),
                ),
              ],
              selected: <CourtOrientation>{state.orientation},
              onSelectionChanged: (selection) =>
                  onOrientationChanged(selection.first),
            ),
            if (state.problem != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                state.problem!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    state.isComplete
                        ? (state.isProjected
                            ? 'The amber line is the net the engine projects '
                                'from your corners. Adjust until it sits on the '
                                'real one.'
                            : 'Marking the court…')
                        : 'Place all four corners to see the projected net.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.check),
                  label: Text(state.stored ? 'Update court' : 'Save court'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaybackProblem extends StatelessWidget {
  const _PlaybackProblem({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black54,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            message,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
