import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../sc_elevation.dart';
import '../sc_icons.dart';
import '../sc_metrics.dart';
import '../sc_motion.dart';
import '../sc_overlay_colors.dart';
import '../sc_typography.dart';
import '../sportcut_tokens.dart';

/// Ink opacity of the court sketch and the dashed recording border.
const double _thumbnailInkOpacity = 0.30;

/// Hairline width shared by the thumbnail borders.
const double _hairline = 1;

/// The keyboard activations a row and an icon action both accept.
const Map<ShortcutActivator, Intent> _activateShortcuts =
    <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
};

Map<Type, Action<Intent>> _activateActions(VoidCallback onActivate) {
  return <Type, Action<Intent>>{
    ActivateIntent: CallbackAction<ActivateIntent>(
      onInvoke: (ActivateIntent intent) {
        onActivate();
        return null;
      },
    ),
  };
}

/// A library video thumbnail: a dark footage bed with a muted court sketch.
///
/// The bed is fixed dark because it stands for footage (ADR-0003 D13), so it
/// does not follow the theme. A missing recording shows a dashed border and a
/// danger icon instead of the sketch; it never fakes a frame.
class ScVideoThumb extends StatelessWidget {
  /// Build a thumbnail.
  const ScVideoThumb({
    super.key,
    this.width = ScMetrics.thumbWidth,
    this.height = ScMetrics.thumbHeight,
    this.missing = false,
    this.painter,
  });

  /// Thumbnail width. Defaults to [ScMetrics.thumbWidth].
  final double width;

  /// Thumbnail height. Defaults to [ScMetrics.thumbHeight].
  final double height;

  /// Whether the recording is unavailable.
  final bool missing;

  /// An optional widget drawn instead of the court sketch, such as a decoded
  /// frame. Ignored when [missing] is true.
  final Widget? painter;

  @override
  Widget build(BuildContext context) {
    final SportcutPalette palette = SportcutPalette.of(context);
    final BorderRadius radius = BorderRadius.circular(ScMetrics.thumbRadius);

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: missing ? palette.surfaceWarm : ScOverlayColors.thumbnailBed,
            border: missing
                ? null
                : Border.all(color: palette.border, width: _hairline),
          ),
          child: missing
              ? _MissingThumb(palette: palette)
              : _ThumbBody(painter: painter),
        ),
      ),
    );
  }
}

/// The normal thumbnail: the court sketch, or a caller-supplied frame.
class _ThumbBody extends StatelessWidget {
  const _ThumbBody({required this.painter});

  final Widget? painter;

  @override
  Widget build(BuildContext context) {
    final Widget? painter = this.painter;
    if (painter != null) {
      return SizedBox.expand(child: painter);
    }
    return SizedBox.expand(
      child: CustomPaint(
        painter: _CourtSketchPainter(
          color: ScOverlayColors.ink.withValues(alpha: _thumbnailInkOpacity),
        ),
      ),
    );
  }
}

/// The missing thumbnail: a dashed bed plus the danger icon.
class _MissingThumb extends StatelessWidget {
  const _MissingThumb({required this.palette});

  final SportcutPalette palette;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedBorderPainter(
        color: palette.borderSoft,
        radius: ScMetrics.thumbRadius,
      ),
      child: Center(
        child: ExcludeSemantics(
          child: Icon(
            ScIcons.error,
            size: ScIcons.toolbarSize,
            color: palette.danger,
          ),
        ),
      ),
    );
  }
}

/// Draws the inset court rectangle and its dashed net line.
class _CourtSketchPainter extends CustomPainter {
  const _CourtSketchPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _hairline;
    final Rect court = Rect.fromLTWH(
      ScMetrics.thumbCourtInsetX,
      ScMetrics.thumbCourtInsetY,
      size.width - ScMetrics.thumbCourtInsetX * 2,
      size.height - ScMetrics.thumbCourtInsetY * 2,
    );
    if (court.isEmpty) {
      return;
    }
    canvas.drawRect(court, paint);

    final double netX = size.width / 2;
    const double dash = ScMetrics.thumbCourtInsetY / 2;
    for (double y = court.top; y < court.bottom; y += dash * 2) {
      final double end = (y + dash).clamp(court.top, court.bottom).toDouble();
      canvas.drawLine(Offset(netX, y), Offset(netX, end), paint);
    }
  }

  @override
  bool shouldRepaint(_CourtSketchPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Draws a dashed rounded-rectangle border inside [size].
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _hairline;
    final Rect rect = Rect.fromLTWH(
      _hairline / 2,
      _hairline / 2,
      size.width - _hairline,
      size.height - _hairline,
    );
    final Path path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius - _hairline)),
      );
    const double dash = ScMetrics.thumbCourtInsetY / 2;
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double end = (distance + dash).clamp(0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dash * 2;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

/// A video in the library rail.
///
/// One line of title, one line of metadata, an optional tabular score, and an
/// optional delete action. A selected row is the warm surface plus a hairline
/// ring and a check; a missing recording carries the danger icon and the words
/// "Recording missing" instead of its metadata. A row that is both selected and
/// missing keeps the check, while its thumbnail and metadata still carry the
/// missing state (ADR-0003 D5 and D8). The row is data-in / callback-out: it
/// reads no provider and never reaches the engine.
class ScVideoRow extends StatefulWidget {
  /// Build a video row.
  const ScVideoRow({
    super.key,
    required this.title,
    required this.meta,
    this.score,
    this.selected = false,
    this.missing = false,
    this.playing = false,
    this.onTap,
    this.onDelete,
    this.deleteLabel = 'Delete video',
  });

  /// The match title, shown on one line with an ellipsis.
  final String title;

  /// The metadata line, such as resolution and import date. Replaced by
  /// "Recording missing" when [missing] is true.
  final String meta;

  /// An optional tabular score, such as `18–16`.
  final String? score;

  /// Whether this row is the current match.
  final bool selected;

  /// Whether the recording file is unavailable.
  final bool missing;

  /// Whether this match is currently playing.
  final bool playing;

  /// Called when the row is tapped or activated from the keyboard.
  final VoidCallback? onTap;

  /// Called when the delete action is used. The action is hidden when null.
  final VoidCallback? onDelete;

  /// The accessible label for the delete action.
  final String deleteLabel;

  @override
  State<ScVideoRow> createState() => _ScVideoRowState();
}

class _ScVideoRowState extends State<ScVideoRow> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final SportcutPalette palette = SportcutPalette.of(context);
    final SportcutTypography typography = SportcutTypography.of(context);
    final SportcutTokens tokens = SportcutTokens.of(context);
    final bool pressable = widget.onTap != null;
    final bool warm = widget.selected || (pressable && _hovered);

    return ScFocusRing.overlay(
      palette: palette,
      focused: _focused,
      child: FocusableActionDetector(
        enabled: pressable,
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (bool value) {
          setState(() => _focused = value);
        },
        onShowHoverHighlight: (bool value) {
          setState(() => _hovered = value);
        },
        shortcuts: _activateShortcuts,
        actions: _activateActions(() => widget.onTap?.call()),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Semantics(
            button: pressable,
            selected: widget.selected,
            child: AnimatedContainer(
              duration: ScMotion.duration(context, tokens.motionFast),
              constraints: const BoxConstraints(
                minHeight: ScMetrics.rowCompact,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: tokens.space1,
                vertical: tokens.space1,
              ),
              decoration: BoxDecoration(
                color: warm ? palette.surfaceWarm : null,
                borderRadius: BorderRadius.circular(tokens.radiusMd),
                border: Border.all(
                  color: widget.selected
                      ? palette.controlBorder
                      : palette.borderSoft.withValues(alpha: 0),
                  width: _hairline,
                ),
              ),
              child: Row(
                children: <Widget>[
                  ScVideoThumb(missing: widget.missing),
                  SizedBox(width: tokens.space2),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.xs12.copyWith(
                            color: palette.fg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          widget.missing ? 'Recording missing' : widget.meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.xs12.copyWith(
                            color:
                                widget.missing ? palette.danger : palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.score != null) ...<Widget>[
                    SizedBox(width: tokens.space2),
                    Text(
                      widget.score!,
                      maxLines: 1,
                      style: typography.timecode11.copyWith(
                        color: palette.fg2,
                      ),
                    ),
                  ],
                  SizedBox(width: tokens.space1),
                  _RowStateIcon(
                    selected: widget.selected,
                    missing: widget.missing,
                    playing: widget.playing,
                    palette: palette,
                  ),
                  if (widget.onDelete != null)
                    _IconAction(
                      label: widget.deleteLabel,
                      icon: ScIcons.delete,
                      color: palette.muted,
                      onPressed: widget.onDelete!,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The status icon at the end of a library row.
class _RowStateIcon extends StatelessWidget {
  const _RowStateIcon({
    required this.selected,
    required this.missing,
    required this.playing,
    required this.palette,
  });

  final bool selected;
  final bool missing;
  final bool playing;
  final SportcutPalette palette;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return ExcludeSemantics(
        child: Icon(
          ScIcons.check,
          size: ScIcons.toolbarSize,
          color: palette.accent,
        ),
      );
    }
    if (playing) {
      return Icon(
        ScIcons.play,
        size: ScIcons.toolbarSize,
        color: palette.accent,
        semanticLabel: 'Now playing',
      );
    }
    if (missing) {
      return ExcludeSemantics(
        child: Icon(
          ScIcons.warning,
          size: ScIcons.toolbarSize,
          color: palette.danger,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// An icon-only control with a tooltip and a button semantics node.
///
/// The focus ring is drawn by [ScFocusRing.overlay], so the control never
/// relies on Material's focus tint.
class _IconAction extends StatefulWidget {
  const _IconAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  State<_IconAction> createState() => _IconActionState();
}

class _IconActionState extends State<_IconAction> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final SportcutPalette palette = SportcutPalette.of(context);
    return Tooltip(
      message: widget.label,
      child: ScFocusRing.overlay(
        palette: palette,
        focused: _focused,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowFocusHighlight: (bool value) {
            setState(() => _focused = value);
          },
          shortcuts: _activateShortcuts,
          actions: _activateActions(widget.onPressed),
          child: Semantics(
            button: true,
            label: widget.label,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onPressed,
              child: SizedBox(
                width: ScMetrics.iconButton,
                height: ScMetrics.rowCompact,
                child: Center(
                  child: Icon(
                    widget.icon,
                    size: ScIcons.toolbarSize,
                    color: widget.color,
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

/// A rail section label: uppercase mono, with an optional tabular count.
class ScSectionLabel extends StatelessWidget {
  /// Build a section label.
  const ScSectionLabel({super.key, required this.label, this.count});

  /// The label text. Rendered uppercase.
  final String label;

  /// An optional item count shown at the trailing edge.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final SportcutPalette palette = SportcutPalette.of(context);
    final SportcutTypography typography = SportcutTypography.of(context);
    final SportcutTokens tokens = SportcutTokens.of(context);
    final TextStyle style = typography.chrome9.copyWith(color: palette.muted);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.space3,
        tokens.space2,
        tokens.space3,
        tokens.space1,
      ),
      child: Semantics(
        header: true,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
            if (count != null) ...<Widget>[
              SizedBox(width: tokens.space2),
              Text(
                '$count',
                style: SportcutTypography.withTabular(style),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
