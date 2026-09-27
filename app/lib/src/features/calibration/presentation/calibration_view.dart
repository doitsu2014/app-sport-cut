import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bridge/sportcut_engine.dart';
import '../../library/domain/match_record.dart';
import '../../library/presentation/playback_controller.dart';
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

/// Court calibration, rendered over a caller-owned playback controller.
///
/// The caller owns the controller's lifecycle; this view only renders it. The
/// save flow reports the updated match through [onSaved] rather than popping a
/// route, so the studio can refresh its own state without navigating.
class CalibrationView extends ConsumerStatefulWidget {
  /// Build the calibration view over an already-managed controller.
  const CalibrationView({
    super.key,
    required this.match,
    required this.controller,
    this.onSaved,
  });

  /// Match being calibrated.
  final MatchRecord match;

  /// Playback backend, loaded and owned by the caller.
  final PlaybackController controller;

  /// Called with the updated match after a successful save.
  final void Function(MatchRecord updated)? onSaved;

  @override
  ConsumerState<CalibrationView> createState() => _CalibrationViewState();
}

class _CalibrationViewState extends ConsumerState<CalibrationView> {
  @override
  void initState() {
    super.initState();
    // Point the shared controller at this match; opening the same match again
    // is a no-op, and a different match restores that match's parked session.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(calibrationControllerProvider.notifier).open(widget.match);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calibrationControllerProvider);
    final controller = ref.read(calibrationControllerProvider.notifier);
    final playback = widget.controller;

    return Column(
      children: <Widget>[
        Expanded(
          child: ValueListenableBuilder<PlaybackState>(
            valueListenable: playback.state,
            builder: (context, current, _) => _Stage(
              playback: current,
              surface: playback.buildSurface(context),
              corners: state.corners,
              geometry: state.geometry,
              onCornerMoved: controller.nudgeCorner,
              onCornerReleased: (_) => unawaited(controller.project()),
            ),
          ),
        ),
        ValueListenableBuilder<PlaybackState>(
          valueListenable: playback.state,
          builder: (context, current, _) => _Scrubber(
            state: current,
            onPlayPause: () => current.isPlaying
                ? unawaited(playback.pause())
                : unawaited(playback.play()),
            onSeek: (progress) {
              final duration = current.duration.inMilliseconds;
              if (duration <= 0) {
                return;
              }
              unawaited(
                playback.seek(
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
    );
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final updated = await ref
        .read(calibrationControllerProvider.notifier)
        .save(widget.match);
    if (updated == null || !mounted) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text('Court marked for ${updated.title}')),
    );
    widget.onSaved?.call(updated);
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
                  if (geometry != null && geometry!.net.length == 2)
                    Positioned(
                      left: ((geometry!.net[0].x + geometry!.net[1].x) / 2) *
                          size.width,
                      top: ((geometry!.net[0].y + geometry!.net[1].y) / 2) *
                          size.height,
                      child: const FractionalTranslation(
                        translation: Offset(-0.5, -1.6),
                        child: _NetChip(),
                      ),
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
class _CornerHandle extends StatefulWidget {
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
  State<_CornerHandle> createState() => _CornerHandleState();
}

class _CornerHandleState extends State<_CornerHandle> {
  bool _armed = false;

  @override
  Widget build(BuildContext context) {
    final corner = widget.corner;
    final box = widget.box;
    return Positioned(
      left: corner.x * box.width - _handleRadius,
      top: corner.y * box.height - _handleRadius,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (_) => setState(() => _armed = true),
        onPanUpdate: (details) => widget.onMoved(
          widget.index,
          details.delta.dx / box.width,
          details.delta.dy / box.height,
        ),
        onPanEnd: (_) {
          setState(() => _armed = false);
          widget.onReleased(widget.index);
        },
        onPanCancel: () => setState(() => _armed = false),
        child: Container(
          width: _handleRadius * 2,
          height: _handleRadius * 2,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _armed
                ? Color.lerp(_handleColor, Colors.white, 0.12)!
                : _handleColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: _armed ? 3 : 2),
          ),
          child: Text(
            '${widget.index + 1}',
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

/// The floating label that marks where the engine projects the net.
class _NetChip extends StatelessWidget {
  const _NetChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _handleColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'PROJECTED NET',
        style: TextStyle(
          color: Colors.black,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
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
/// clearly visible.
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
