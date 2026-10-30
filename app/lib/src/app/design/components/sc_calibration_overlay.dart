import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../sc_elevation.dart';
import '../sc_metrics.dart';
import '../sc_motion.dart';
import '../sc_overlay_colors.dart';
import '../sc_typography.dart';
import '../sportcut_tokens.dart';

/// Engine court geometry, normalized to the displayed frame.
///
/// The host builds this from the engine's returned outline and net. The overlay
/// paints it and never derives a court of its own.
@immutable
class ScCourtGeometry {
  /// Build a geometry value.
  const ScCourtGeometry({required this.outline, required this.net});

  /// The four court corners, in the order they were marked.
  final List<Offset> outline;

  /// The two net endpoints.
  final List<Offset> net;

  /// Whether the payload can be painted: four finite outline points and two
  /// finite net points, each inside the normalized frame.
  bool get isValid =>
      outline.length == 4 &&
      net.length == 2 &&
      outline.every(_isInsideFrame) &&
      net.every(_isInsideFrame);

  static bool _isInsideFrame(Offset point) =>
      point.dx.isFinite &&
      point.dy.isFinite &&
      point.dx >= 0 &&
      point.dx <= 1 &&
      point.dy >= 0 &&
      point.dy <= 1;

  @override
  bool operator ==(Object other) =>
      other is ScCourtGeometry &&
      listEquals(other.outline, outline) &&
      listEquals(other.net, net);

  @override
  int get hashCode => Object.hash(Object.hashAll(outline), Object.hashAll(net));
}

/// How the corner order reads to the user, in handle order.
const List<String> _cornerNames = <String>[
  'nearest left',
  'nearest right',
  'farthest right',
  'farthest left',
];

/// The fixed scrim the calibration surface draws beneath the stage transport.
///
/// It is a separate widget so the studio can paint it below the floating
/// transport while the court markings stay above it. Drawing the scrim inside
/// [ScCalibrationOverlay] would dim the transport's timecodes and scrubber.
class ScCalibrationScrim extends StatelessWidget {
  /// Build the scrim.
  const ScCalibrationScrim({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: ScOverlayColors.calibrationScrim);
  }
}

/// The court calibration overlay.
///
/// The overlay is a pure presentation surface: it paints the four normalised
/// corners of [corners] inside [box], the engine's court outline and dashed net
/// from [geometry], and one instruction line. It never reads a controller or
/// provider and never derives a court of its own.
///
/// Corner order follows the calibration contract: 0 is the near-left corner,
/// 1 the near-right, 2 the far-right, and 3 the far-left. Coordinates are
/// normalised to 0..1 and clamped into the box before painting.
///
/// A handle draws at [ScMetrics.courtHandleVisual] inside a
/// [ScMetrics.courtHandleHit] hit region. It takes the accent fill only while
/// the pointer is down on it; the caller-supplied [activeIndex] gets a neutral
/// ring instead. Every other handle is neutral.
class ScCalibrationOverlay extends StatefulWidget {
  /// Build a calibration overlay.
  const ScCalibrationOverlay({
    super.key,
    required this.box,
    required this.corners,
    required this.activeIndex,
    required this.onSelect,
    required this.onDrag,
    this.geometry,
    this.instruction = 'Drag a handle; the dashed line is the net the engine '
        'projects.',
  });

  /// The aspect-fit box the normalised corners are mapped into.
  final Size box;

  /// Four normalised corner positions, each within 0..1 on both axes.
  final List<Offset> corners;

  /// The corner the caller is treating as active, or -1 when idle.
  final int activeIndex;

  /// Called when a corner is pressed, with its index.
  final ValueChanged<int> onSelect;

  /// Called while a corner is dragged, with its index and the pointer's
  /// clamped normalised position inside [box].
  final void Function(int index, Offset normalizedPosition) onDrag;

  /// The engine's projected outline and net, or null when nothing has been
  /// projected yet (an uncalibrated match or a rejected court).
  final ScCourtGeometry? geometry;

  /// The one instruction line above the court.
  final String instruction;

  @override
  State<ScCalibrationOverlay> createState() => _ScCalibrationOverlayState();
}

class _ScCalibrationOverlayState extends State<ScCalibrationOverlay> {
  @override
  Widget build(BuildContext context) {
    final tokens = SportcutTokens.of(context);
    final type = SportcutTypography.of(context);
    final geometry = widget.geometry?.isValid ?? false ? widget.geometry : null;

    return SizedBox(
      width: widget.box.width,
      height: widget.box.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          // A flat, full-width band, not a floating pill or card. The opaque
          // bed keeps the 12 px line at body-text contrast over any footage.
          // It is painted below the court and handles so neither is hidden.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: ColoredBox(
                color: ScOverlayColors.bed,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.space3,
                    vertical: tokens.space1,
                  ),
                  child: Text(
                    widget.instruction,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: type.xs12.copyWith(color: ScOverlayColors.ink),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedSwitcher(
                duration: ScMotion.duration(context, tokens.motionBase),
                reverseDuration:
                    ScMotion.duration(context, tokens.motionBase * 0.7),
                switchInCurve: SportcutTokens.easeStandard,
                switchOutCurve: Curves.easeIn,
                child: geometry == null
                    ? const SizedBox.shrink(key: ValueKey<String>('no-court'))
                    : SizedBox.expand(
                        key: ValueKey<ScCourtGeometry>(geometry),
                        child: CustomPaint(
                          painter: _CourtPainter(
                            geometry: geometry,
                            color: ScOverlayColors.ink,
                            dash: tokens.radiusSm,
                            gap: tokens.radiusSm + ScMetrics.hairline,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          for (var index = 0; index < widget.corners.length; index++)
            ScCourtHandle(
              index: index,
              point: _clampPoint(widget.corners[index]),
              box: widget.box,
              active: index == widget.activeIndex,
              onSelect: widget.onSelect,
              onDrag: widget.onDrag,
            ),
        ],
      ),
    );
  }
}

/// One draggable, numbered corner with a hit region larger than its visual.
///
/// [point] is the normalised corner position inside [box]. The
/// [ScMetrics.courtHandleHit] square is the gesture surface, so the whole hit
/// region receives the pan; the [ScMetrics.courtHandleVisual] circle is
/// centred inside it. It takes the accent fill only while a confirmed drag is
/// under way (`onPanStart` to `onPanEnd`/`onPanCancel`); the caller-supplied
/// [activeIndex] gets a neutral ring instead. Every other handle is neutral.
class ScCourtHandle extends StatefulWidget {
  /// Build a corner handle.
  const ScCourtHandle({
    super.key,
    required this.index,
    required this.point,
    required this.box,
    required this.active,
    required this.onSelect,
    required this.onDrag,
  });

  /// The zero-based corner index.
  final int index;

  /// The normalised corner position inside [box].
  final Offset point;

  /// The box the normalised positions are mapped into.
  final Size box;

  /// Whether the caller treats this corner as active.
  final bool active;

  /// Called when the handle is pressed, with its index.
  final ValueChanged<int> onSelect;

  /// Called while the handle is dragged, with its index and the pointer's
  /// clamped normalised position inside [box].
  final void Function(int index, Offset normalizedPosition) onDrag;

  @override
  State<ScCourtHandle> createState() => _ScCourtHandleState();
}

class _ScCourtHandleState extends State<ScCourtHandle> {
  bool _pressed = false;
  bool _dragging = false;
  bool _hovered = false;
  bool _focused = false;

  /// The handle's top-left corner in box coordinates.
  Offset get _origin {
    return Offset(
      widget.point.dx * widget.box.width - ScMetrics.courtHandleHit / 2,
      widget.point.dy * widget.box.height - ScMetrics.courtHandleHit / 2,
    );
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final Offset local = details.localPosition + _origin;
    widget.onDrag(
      widget.index,
      Offset(
        (local.dx / widget.box.width).clamp(0.0, 1.0).toDouble(),
        (local.dy / widget.box.height).clamp(0.0, 1.0).toDouble(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final type = SportcutTypography.of(context);
    final dragging = _dragging;
    final emphasized = dragging || widget.active || _hovered || _focused;
    final borderColor = dragging
        ? ScOverlayColors.signal
        : ScOverlayColors.ink.withValues(alpha: emphasized ? 1 : 0.82);
    final cornerName = widget.index < _cornerNames.length
        ? _cornerNames[widget.index]
        : 'corner ${widget.index + 1}';

    return Positioned(
      left: _origin.dx,
      top: _origin.dy,
      width: ScMetrics.courtHandleHit,
      height: ScMetrics.courtHandleHit,
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) {
          setState(() => _focused = value);
          if (!value) {
            widget.onSelect(-1);
          }
        },
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (intent) {
              widget.onSelect(widget.index);
              return null;
            },
          ),
        },
        child: ScFocusRing.overlay(
          palette: palette,
          focused: _focused,
          child: MouseRegion(
            cursor: _pressed
                ? SystemMouseCursors.grabbing
                : SystemMouseCursors.grab,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) {
                setState(() => _pressed = true);
                widget.onSelect(widget.index);
              },
              onPointerUp: (_) => setState(() => _pressed = false),
              onPointerCancel: (_) => setState(() => _pressed = false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => setState(() => _dragging = true),
                onPanUpdate: _handlePanUpdate,
                onPanEnd: (_) => setState(() => _dragging = false),
                onPanCancel: () => setState(() => _dragging = false),
                child: Semantics(
                  button: true,
                  label: 'Corner ${widget.index + 1}: $cornerName',
                  hint: 'Drag to the court boundary',
                  onTap: () => widget.onSelect(widget.index),
                  child: Center(
                    child: AnimatedContainer(
                      duration: ScMotion.duration(context, tokens.motionFast),
                      curve: SportcutTokens.easeStandard,
                      width: ScMetrics.courtHandleVisual,
                      height: ScMetrics.courtHandleVisual,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dragging
                            ? ScOverlayColors.signal
                            : ScOverlayColors.bed,
                        border: Border.all(
                          color: borderColor,
                          width: ScMetrics.handleBorder,
                        ),
                      ),
                      child: Text(
                        '${widget.index + 1}',
                        style: type.micro10.copyWith(
                          color: dragging
                              ? ScOverlayColors.bed
                              : ScOverlayColors.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws the engine's court outline and its dashed net.
class _CourtPainter extends CustomPainter {
  const _CourtPainter({
    required this.geometry,
    required this.color,
    required this.dash,
    required this.gap,
  });

  /// The engine geometry to draw.
  final ScCourtGeometry geometry;

  /// The stroke colour.
  final Color color;

  /// Dash length in logical pixels.
  final double dash;

  /// Gap length in logical pixels.
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    if (!geometry.isValid || size.isEmpty) {
      return;
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = ScMetrics.courtOutline
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.butt;

    final outline = <Offset>[
      for (final point in geometry.outline) _scale(_clampPoint(point), size),
    ];
    canvas.drawPath(Path()..addPolygon(outline, true), paint);

    paint.strokeWidth = ScMetrics.hairline;
    _drawDashed(
      canvas,
      _scale(_clampPoint(geometry.net[0]), size),
      _scale(_clampPoint(geometry.net[1]), size),
      paint,
      size.longestSide * 4,
    );
  }

  Offset _scale(Offset point, Size size) {
    return Offset(point.dx * size.width, point.dy * size.height);
  }

  void _drawDashed(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    double limit,
  ) {
    final delta = end - start;
    final length = delta.distance;
    // A clamped payload can never exceed the diagonal, but the guard keeps a
    // pathological value from spinning this loop on the UI thread.
    if (length <= 0 || dash <= 0 || length > limit) {
      return;
    }
    final direction = delta / length;
    var travelled = 0.0;
    while (travelled < length) {
      final next = math.min(travelled + dash, length);
      canvas.drawLine(
        start + direction * travelled,
        start + direction * next,
        paint,
      );
      travelled = next + gap;
    }
  }

  @override
  bool shouldRepaint(_CourtPainter oldDelegate) {
    return oldDelegate.geometry != geometry ||
        oldDelegate.color != color ||
        oldDelegate.dash != dash ||
        oldDelegate.gap != gap;
  }
}

/// Maps two normalised points into 0..1, so stray values never escape the box.
Offset _clampPoint(Offset point) {
  return Offset(
    math.min(math.max(point.dx, 0.0), 1.0),
    math.min(math.max(point.dy, 0.0), 1.0),
  );
}
