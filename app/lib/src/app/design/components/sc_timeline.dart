import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../sc_elevation.dart';
import '../sc_metrics.dart';
import '../sc_motion.dart';
import '../sc_tints.dart';
import '../sc_typography.dart';
import '../sportcut_tokens.dart';

/// Hairline width used by the playhead and control outlines.
const double _hairline = 1;

/// Width of the selected segment's outline.
const double _selectedOutline = 2;

/// The keyboard shortcuts that activate a timeline control.
const Map<ShortcutActivator, Intent> _activationShortcuts =
    <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
};

/// The scale drawn above the timeline tracks.
///
/// Labels are spaced evenly between [windowStart] and
/// `windowStart + windowLength`. The first label is left-aligned and the last
/// right-aligned, so a label never overflows the track, matching the studio's
/// ruler.
class ScRuler extends StatelessWidget {
  /// Build a ruler for one timeline window.
  const ScRuler({
    super.key,
    required this.windowStart,
    required this.windowLength,
    required this.ticks,
    required this.style,
    this.color,
    this.height = ScMetrics.timelineRuler,
  });

  /// Time at the left edge of the window.
  final Duration windowStart;

  /// Length of the working window.
  final Duration windowLength;

  /// Number of labels across the track. Values below one draw nothing.
  final int ticks;

  /// The text style for the labels, usually a mono caption.
  final TextStyle style;

  /// Overrides the label colour; defaults to the palette's muted ink.
  final Color? color;

  /// The track height. Callers scale it with the text scale so labels never
  /// clip (FR-SHL-35).
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final resolved = style.copyWith(color: color ?? palette.muted);
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(
        painter: _RulerPainter(
          windowStart: windowStart,
          windowLength: windowLength,
          ticks: ticks,
          style: resolved,
          textScaler: MediaQuery.textScalerOf(context),
        ),
      ),
    );
  }
}

/// Paints the ruler labels at their fractional positions.
class _RulerPainter extends CustomPainter {
  const _RulerPainter({
    required this.windowStart,
    required this.windowLength,
    required this.ticks,
    required this.style,
    required this.textScaler,
  });

  final Duration windowStart;
  final Duration windowLength;
  final int ticks;
  final TextStyle style;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    if (ticks <= 0 || size.width <= 0) {
      return;
    }
    for (var index = 0; index < ticks; index++) {
      final ratio = ticks == 1 ? 0.0 : index / (ticks - 1);
      final offset = windowLength * ratio;
      final painter = TextPainter(
        text: TextSpan(text: _formatShort(windowStart + offset), style: style),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      final x = ratio * size.width;
      final alignedX = switch (index) {
        0 => x,
        _ when index == ticks - 1 => x - painter.width,
        _ => x - painter.width / 2,
      };
      painter.paint(
          canvas, Offset(alignedX, (size.height - painter.height) / 2));
      painter.dispose();
    }
  }

  @override
  bool shouldRepaint(_RulerPainter oldDelegate) {
    return oldDelegate.windowStart != windowStart ||
        oldDelegate.windowLength != windowLength ||
        oldDelegate.ticks != ticks ||
        oldDelegate.style != style ||
        oldDelegate.textScaler != textScaler;
  }
}

/// The state a rally segment shows on the timeline.
enum ScRallySegmentState {
  /// A candidate rally the user has not kept.
  unkept,

  /// A rally the user kept for the reel.
  kept,

  /// A rally whose winner has been recorded.
  scored,

  /// Downtime between rallies.
  rest,
}

/// One rally segment on the rally track.
///
/// The segment positions itself with [left] and [width] in logical pixels, so
/// it must be placed directly inside a [Stack]. Its drawn height is
/// [ScMetrics.rallySegmentHitTarget] and its width never drops below
/// [ScMetrics.rallySegmentMinWidth]. It paints the state [state] and reports
/// taps through [onTap] and [onDoubleTap].
class ScRallySegment extends StatefulWidget {
  /// Build a rally segment.
  const ScRallySegment({
    super.key,
    required this.index,
    required this.left,
    required this.width,
    required this.state,
    this.selected = false,
    this.onTap,
    this.onDoubleTap,
  });

  /// Zero-based rally index. The label shows the one-based rally number.
  final int index;

  /// Left edge in logical pixels, relative to the track.
  final double left;

  /// Requested width in logical pixels; clamped to the minimum.
  final double width;

  /// The rally's keep and score state.
  final ScRallySegmentState state;

  /// Whether the segment has the 2 px foreground outline.
  final bool selected;

  /// Called on a single click.
  final VoidCallback? onTap;

  /// Called on a double click.
  final VoidCallback? onDoubleTap;

  @override
  State<ScRallySegment> createState() => _ScRallySegmentState();
}

class _ScRallySegmentState extends State<ScRallySegment> {
  bool _hovered = false;
  bool _focused = false;

  bool get _interactive => widget.onTap != null || widget.onDoubleTap != null;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final type = SportcutTypography.of(context);
    final width = math.max(widget.width, ScMetrics.rallySegmentMinWidth);
    final border = Border.all(
      color: widget.selected ? palette.fg : palette.border,
      width: widget.selected ? _selectedOutline : _hairline,
    );
    final label =
        widget.state == ScRallySegmentState.rest ? '' : '${widget.index + 1}';

    return Positioned(
      left: widget.left,
      width: width,
      top: 0,
      bottom: 0,
      child: Center(
        child: FocusableActionDetector(
          enabled: _interactive,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          shortcuts: _activationShortcuts,
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (intent) {
                widget.onTap?.call();
                return null;
              },
            ),
          },
          child: MouseRegion(
            cursor: _interactive
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: ScFocusRing.overlay(
              palette: palette,
              focused: _focused,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onTap,
                onDoubleTap: widget.onDoubleTap,
                child: Semantics(
                  button: _interactive,
                  selected: widget.selected,
                  label: _semanticLabel(),
                  onTap: _interactive ? widget.onTap : null,
                  child: AnimatedContainer(
                    duration: ScMotion.duration(context, tokens.motionFast),
                    constraints: const BoxConstraints(
                      minWidth: ScMetrics.rallySegmentMinWidth,
                      minHeight: ScMetrics.rallySegmentHitTarget,
                    ),
                    alignment: Alignment.center,
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      color: _fill(palette),
                      border: border,
                      borderRadius: BorderRadius.circular(tokens.radiusSm),
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.chrome9.copyWith(color: _ink(palette)),
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

  Color _fill(SportcutPalette palette) {
    final surface = palette.surface;
    final hovered = _hovered && _interactive;
    return switch (widget.state) {
      ScRallySegmentState.rest => palette.surfaceWarm,
      ScRallySegmentState.unkept => hovered
          ? ScTints.kept(palette.accent, surface)
          : ScTints.rally(palette.accent, surface),
      ScRallySegmentState.kept => hovered
          ? ScTints.keptHover(palette.accent, surface)
          : ScTints.kept(palette.accent, surface),
      ScRallySegmentState.scored => hovered
          ? ScTints.keptHover(palette.success, surface)
          : ScTints.kept(palette.success, surface),
    };
  }

  Color _ink(SportcutPalette palette) {
    return switch (widget.state) {
      ScRallySegmentState.rest => palette.muted,
      ScRallySegmentState.unkept => palette.fg2,
      ScRallySegmentState.kept || ScRallySegmentState.scored => palette.fg,
    };
  }

  String _semanticLabel() {
    return switch (widget.state) {
      ScRallySegmentState.rest => 'Rest',
      ScRallySegmentState.unkept => 'Rally ${widget.index + 1}, not kept',
      ScRallySegmentState.kept => 'Rally ${widget.index + 1}, kept',
      ScRallySegmentState.scored => 'Rally ${widget.index + 1}, scored',
    };
  }
}

/// A small score marker on the score track.
///
/// The chip sizes to its [label] with [ScMetrics.chip] as both the height and
/// the minimum width. [selected] marks the winning side with the accent border
/// and ink; the chip only behaves as a control when [onTap] is supplied.
class ScScoreChip extends StatefulWidget {
  /// Build a score chip.
  const ScScoreChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  /// The side or score text, usually `L` or `R`.
  final String label;

  /// Whether the chip carries the accent treatment.
  final bool selected;

  /// Called on a click; leaving it null makes the chip a static marker.
  final VoidCallback? onTap;

  @override
  State<ScScoreChip> createState() => _ScScoreChipState();
}

class _ScScoreChipState extends State<ScScoreChip> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final type = SportcutTypography.of(context);
    final interactive = widget.onTap != null;
    final chip = AnimatedContainer(
      duration: ScMotion.duration(context, tokens.motionFast),
      constraints: const BoxConstraints(
        minWidth: ScMetrics.chip,
        minHeight: ScMetrics.chip,
      ),
      padding: EdgeInsets.symmetric(horizontal: tokens.space1),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _hovered && interactive ? palette.surfaceWarm : palette.surface,
        border: Border.all(
          color: widget.selected ? palette.accent : palette.controlBorder,
          width: _hairline,
        ),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
      ),
      child: Text(
        widget.label,
        maxLines: 1,
        softWrap: false,
        style: type.chrome9.copyWith(
          color: widget.selected ? palette.accent : palette.fg2,
        ),
      ),
    );

    if (!interactive) {
      return Semantics(
        selected: widget.selected,
        label: widget.label,
        child: chip,
      );
    }

    return FocusableActionDetector(
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      shortcuts: _activationShortcuts,
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (intent) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: ScFocusRing.overlay(
          palette: palette,
          focused: _focused,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: Semantics(
              button: true,
              selected: widget.selected,
              label: widget.label,
              onTap: widget.onTap,
              child: chip,
            ),
          ),
        ),
      ),
    );
  }
}

/// The timeline playhead: a 1 px accent line spanning the tracks.
///
/// The line positions itself with [x] in logical pixels, so it must be placed
/// directly inside a [Stack]. [color] overrides the accent for a caller that
/// needs a different signal.
class ScPlayhead extends StatelessWidget {
  /// Build a playhead at [x].
  const ScPlayhead({super.key, required this.x, this.color});

  /// Left edge in logical pixels, relative to the track area.
  final double x;

  /// Overrides the accent line colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    return Positioned(
      left: x,
      top: 0,
      bottom: 0,
      width: _hairline,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: ColoredBox(color: color ?? palette.accent),
        ),
      ),
    );
  }
}

/// The timeline key: the rally states, plus the optional rest and playhead.
///
/// Every swatch carries a word, so the legend never relies on colour alone.
/// [showRest] and [showPlayhead] hide entries the current dock does not draw.
class ScTimelineLegend extends StatelessWidget {
  /// Build a legend.
  const ScTimelineLegend({
    super.key,
    required this.showRest,
    required this.showPlayhead,
  });

  /// Whether the rest swatch is shown.
  final bool showRest;

  /// Whether the playhead swatch is shown.
  final bool showPlayhead;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    return Wrap(
      spacing: tokens.space4,
      runSpacing: tokens.space2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        _LegendItem(
          label: 'Rally',
          color: ScTints.rally(palette.accent, palette.surface),
        ),
        _LegendItem(
          label: 'Kept',
          color: ScTints.kept(palette.accent, palette.surface),
        ),
        _LegendItem(
          label: 'Scored',
          color: ScTints.kept(palette.success, palette.surface),
        ),
        if (showRest) _LegendItem(label: 'Rest', color: palette.surfaceWarm),
        if (showPlayhead)
          _LegendItem(label: 'Playhead', color: palette.accent, line: true),
      ],
    );
  }
}

/// One labelled swatch in [ScTimelineLegend].
class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.label,
    required this.color,
    this.line = false,
  });

  final String label;
  final Color color;
  final bool line;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final type = SportcutTypography.of(context);
    const size = ScMetrics.chip / 2;
    final radius = BorderRadius.circular(tokens.radiusSm / 2);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: size,
          height: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: line ? null : color,
              border: Border.all(color: palette.border, width: _hairline),
              borderRadius: radius,
            ),
            child: line
                ? Center(
                    child: SizedBox(
                      width: _hairline,
                      height: size,
                      child: ColoredBox(color: color),
                    ),
                  )
                : null,
          ),
        ),
        SizedBox(width: tokens.space2),
        Text(
          label.toUpperCase(),
          style: type.chrome9.copyWith(color: palette.muted),
        ),
      ],
    );
  }
}

/// Formats a duration as `minutes:seconds`, matching the studio ruler.
String _formatShort(Duration time) {
  final seconds = math.max(0, time.inSeconds);
  final minutes = seconds ~/ Duration.secondsPerMinute;
  final remainder = seconds % Duration.secondsPerMinute;
  return '$minutes:${remainder.toString().padLeft(2, '0')}';
}
