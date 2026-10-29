import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../sc_elevation.dart';
import '../sc_icons.dart';
import '../sc_metrics.dart';
import '../sc_typography.dart';
import '../sportcut_tokens.dart';

/// Hairline width for the net and control outlines.
const double _hairline = 1;

/// Border width of a corner handle, from the calibration overlay contract.
const double _handleBorderWidth = 2;

/// The court calibration overlay.
///
/// The overlay is a pure presentation surface: it paints the four normalised
/// corners of [corners] inside [box], the dashed net between the two side
/// lines, and one instruction line. It never reads a controller or provider.
///
/// Corner order follows the calibration contract: 0 is the near-left corner,
/// 1 the near-right, 2 the far-right, and 3 the far-left. The net is drawn
/// between the midpoints of the two side lines (0–3 and 1–2). Coordinates are
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
    this.instruction = 'Drag each corner to the court boundary.',
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

  /// The one instruction line above the court.
  final String instruction;

  @override
  State<ScCalibrationOverlay> createState() => _ScCalibrationOverlayState();
}

class _ScCalibrationOverlayState extends State<ScCalibrationOverlay> {
  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final type = SportcutTypography.of(context);
    final net = _netEndpoints(widget.corners);

    return SizedBox(
      width: widget.box.width,
      height: widget.box.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _NetPainter(
                  endpoints: net,
                  color: palette.muted,
                  dash: tokens.radiusSm,
                  gap: tokens.radiusSm + _hairline,
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
          Positioned(
            top: tokens.space2,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.surface,
                    border: Border.all(
                      color: palette.border,
                      width: _hairline,
                    ),
                    borderRadius: BorderRadius.circular(tokens.radiusPill),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.space3,
                      vertical: tokens.space1,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          ScIcons.cropFree,
                          size: ScIcons.toolbarSize,
                          color: palette.fg2,
                        ),
                        SizedBox(width: tokens.space2),
                        Flexible(
                          child: Text(
                            widget.instruction,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: type.micro10.copyWith(color: palette.fg2),
                          ),
                        ),
                      ],
                    ),
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

/// One draggable, numbered corner with a hit region larger than its visual.
///
/// [point] is the normalised corner position inside [box]. The
/// [ScMetrics.courtHandleHit] square is the gesture surface, so the whole hit
/// region receives the pan; the [ScMetrics.courtHandleVisual] circle is
/// centred inside it. [active] draws a neutral ring, while the accent fill
/// appears only while the pointer is down.
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
    final type = SportcutTypography.of(context);
    final borderColor = _pressed
        ? palette.accent
        : (widget.active || _hovered ? palette.fg : palette.fg2);

    return Positioned(
      left: _origin.dx,
      top: _origin.dy,
      width: ScMetrics.courtHandleHit,
      height: ScMetrics.courtHandleHit,
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) => setState(() => _focused = value),
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
                onPanUpdate: _handlePanUpdate,
                child: Semantics(
                  button: true,
                  label: 'Corner ${widget.index + 1}',
                  hint: 'Drag to the court boundary',
                  onTap: () => widget.onSelect(widget.index),
                  child: Center(
                    child: Container(
                      width: ScMetrics.courtHandleVisual,
                      height: ScMetrics.courtHandleVisual,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _pressed ? palette.accent : palette.surface,
                        border: Border.all(
                          color: borderColor,
                          width: _handleBorderWidth,
                        ),
                      ),
                      child: Text(
                        '${widget.index + 1}',
                        style: type.micro10.copyWith(
                          color: _pressed ? palette.accentOn : palette.fg2,
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

/// Draws the dashed net between two normalised endpoints.
class _NetPainter extends CustomPainter {
  const _NetPainter({
    required this.endpoints,
    required this.color,
    required this.dash,
    required this.gap,
  });

  /// The two normalised net endpoints.
  final List<Offset> endpoints;

  /// The stroke colour.
  final Color color;

  /// Dash length in logical pixels.
  final double dash;

  /// Gap length in logical pixels.
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    if (endpoints.length != 2) {
      return;
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = _hairline
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;
    _drawDashed(
      canvas,
      _scale(endpoints[0], size),
      _scale(endpoints[1], size),
      paint,
    );
  }

  Offset _scale(Offset point, Size size) {
    return Offset(point.dx * size.width, point.dy * size.height);
  }

  void _drawDashed(Canvas canvas, Offset start, Offset end, Paint paint) {
    final delta = end - start;
    final length = delta.distance;
    if (length <= 0 || dash <= 0) {
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
  bool shouldRepaint(_NetPainter oldDelegate) {
    return !_sameEndpoints(oldDelegate.endpoints, endpoints) ||
        oldDelegate.color != color ||
        oldDelegate.dash != dash ||
        oldDelegate.gap != gap;
  }

  static bool _sameEndpoints(List<Offset> a, List<Offset> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
  }
}

/// Maps two normalised points into 0..1, so stray values never escape the box.
Offset _clampPoint(Offset point) {
  return Offset(
    math.min(math.max(point.dx, 0.0), 1.0),
    math.min(math.max(point.dy, 0.0), 1.0),
  );
}

/// The net endpoints for [corners], or an empty list when the court is not
/// complete.
List<Offset> _netEndpoints(List<Offset> corners) {
  if (corners.length != 4) {
    return const <Offset>[];
  }
  return <Offset>[
    _clampPoint((corners[0] + corners[3]) / 2),
    _clampPoint((corners[1] + corners[2]) / 2),
  ];
}
