import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/sc_metrics.dart';
import '../../../app/design/sc_overlay_colors.dart';
import '../../../app/design/sc_tints.dart';
import '../../../app/design/sc_typography.dart';
import '../../../app/design/sportcut_tokens.dart';
import '../../../bridge/sportcut_engine.dart';
import '../../library/domain/match_record.dart';
import '../../library/presentation/formatters.dart';
import '../../library/presentation/playback_controller.dart';
import 'player_tracking_providers.dart';

/// A loose detection outline.
const double _boxStrokeLoose = 1;

/// An outline for a detection that belongs to a track.
const double _boxStrokeTracked = 2;

/// How far, in seconds, a sampled frame may be from the play position.
const double _frameToleranceSeconds = 0.3;

/// The opacity of a candidate the engine did not select for the court.
const double _offCourtAlpha = 0.45;

/// The opacity of the chalk for an observation with no reliable side.
const double _unknownAlpha = 0.62;

/// The opacity of the small bed plate behind a box label.
const double _labelBedAlpha = 0.72;

/// The single local palette for player boxes drawn over the footage.
///
/// This is the only place tracking names a colour. Every value is derived from
/// the fixed [ScOverlayColors] chalk and signal or from the themed
/// [SportcutPalette], so no raw hex appears in the tracking feature. The
/// letter and the name travel with each swatch in [TrackingLegend], so colour
/// is never the only thing that identifies a side.
@immutable
class TrackingSideColors {
  /// Build a side palette from resolved colours.
  const TrackingSideColors({
    required this.left,
    required this.right,
    required this.unknown,
  });

  /// Resolve the palette for [palette].
  factory TrackingSideColors.of(SportcutPalette palette) {
    return TrackingSideColors(
      // The stage signal is fixed, so the left side reads the same in both
      // themes over the footage bed.
      left: ScOverlayColors.signal,
      // Lift the warning tone toward the chalk so it keeps its contrast on the
      // fixed dark bed in the light theme as well.
      right: Color.lerp(ScOverlayColors.ink, palette.warn, 0.55)!,
      unknown: ScOverlayColors.ink.withValues(alpha: _unknownAlpha),
    );
  }

  /// The first court half.
  final Color left;

  /// The second court half.
  final Color right;

  /// An uncertain or off-court observation.
  final Color unknown;

  /// The colour for [side].
  Color forSide(PlayerCourtSideDto side) => switch (side) {
        PlayerCourtSideDto.first => left,
        PlayerCourtSideDto.second => right,
        PlayerCourtSideDto.unknown => unknown,
      };

  /// The short letter drawn on a box.
  static String letter(PlayerCourtSideDto side) => switch (side) {
        PlayerCourtSideDto.first => 'L',
        PlayerCourtSideDto.second => 'R',
        PlayerCourtSideDto.unknown => '?',
      };

  /// The word the legend prints beside the swatch.
  static String name(PlayerCourtSideDto side) => switch (side) {
        PlayerCourtSideDto.first => 'Left',
        PlayerCourtSideDto.second => 'Right',
        PlayerCourtSideDto.unknown => 'Unknown',
      };
}

/// The key for the three box colours.
///
/// Every entry prints its letter and its name next to the swatch, so the
/// legend never depends on colour alone. On the footage it uses the fixed
/// chalk ink; on a panel it uses the themed secondary ink.
class TrackingLegend extends StatelessWidget {
  /// Build the legend for [colors].
  const TrackingLegend({
    super.key,
    required this.colors,
    this.onFootage = true,
  });

  /// The side palette to show.
  final TrackingSideColors colors;

  /// Whether the legend is drawn on the fixed dark footage bed.
  final bool onFootage;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final labelColor = onFootage ? ScOverlayColors.ink : palette.fg2;

    return Wrap(
      spacing: tokens.space3,
      runSpacing: tokens.space1,
      children: <Widget>[
        for (final PlayerCourtSideDto side in PlayerCourtSideDto.values)
          _LegendEntry(
            color: colors.forSide(side),
            letter: TrackingSideColors.letter(side),
            name: TrackingSideColors.name(side),
            labelColor: labelColor,
          ),
      ],
    );
  }
}

/// One swatch and its words.
class _LegendEntry extends StatelessWidget {
  const _LegendEntry({
    required this.color,
    required this.letter,
    required this.name,
    required this.labelColor,
  });

  final Color color;
  final String letter;
  final String name;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: ScMetrics.chip / 2,
          height: ScMetrics.chip / 2,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(ScMetrics.radiusThumb),
          ),
        ),
        SizedBox(width: tokens.space1),
        Text(
          '$letter $name',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: typography.chrome9.copyWith(color: labelColor),
        ),
      ],
    );
  }
}

/// Detected players drawn over the shared preview for the current window.
///
/// The overlay reads the same five-second window the panel reports and draws
/// the boxes of the sampled frame nearest the play position. Each box carries
/// its side letter, and the legend carries the letters, names, and colours; a
/// frame with no detections draws nothing at all, so the app never paints a
/// box it did not observe.
///
/// The overlay also keeps the window in step with playback: when the playhead
/// leaves the loaded window it asks the controller for the window around it,
/// which is the behaviour the old tracking view owned.
class TrackingOverlay extends ConsumerStatefulWidget {
  /// Build the tracking overlay for [match] over [controller].
  const TrackingOverlay({
    super.key,
    required this.match,
    required this.controller,
  });

  /// The match whose tracks are shown.
  final MatchRecord match;

  /// The shared player, loaded and owned by the caller.
  final PlaybackController controller;

  @override
  ConsumerState<TrackingOverlay> createState() => _TrackingOverlayState();
}

class _TrackingOverlayState extends ConsumerState<TrackingOverlay> {
  /// The play position the nearest frame is chosen from, in seconds.
  double _positionSeconds = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.state.addListener(_onPlayback);
  }

  @override
  void didUpdateWidget(covariant TrackingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.state.removeListener(_onPlayback);
      widget.controller.state.addListener(_onPlayback);
    }
  }

  @override
  void dispose() {
    widget.controller.state.removeListener(_onPlayback);
    super.dispose();
  }

  /// Redraw for the new play position and keep the loaded window in step.
  void _onPlayback() {
    if (!mounted) {
      return;
    }
    final position =
        widget.controller.state.value.position.inMilliseconds / 1000.0;
    if (position != _positionSeconds) {
      setState(() => _positionSeconds = position);
    }
    _followWindow(position);
  }

  /// Load the window around [position] when it leaves the current one.
  void _followWindow(double position) {
    final tracking = ref.read(playerTrackingControllerProvider);
    if (!tracking.loaded ||
        tracking.loading ||
        tracking.tracks == null ||
        position >= widget.match.durationSeconds) {
      return;
    }
    if (position < tracking.windowStart || position >= tracking.windowEnd) {
      unawaited(
        ref
            .read(playerTrackingControllerProvider.notifier)
            .loadWindow(widget.match, position),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracking = ref.watch(playerTrackingControllerProvider);
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final colors = TrackingSideColors.of(palette);
    final frame = _nearestFrame(tracking.tracks, _positionSeconds);
    final hasWindow = tracking.windowEnd > tracking.windowStart;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final box = Size(constraints.maxWidth, constraints.maxHeight);
        if (box.isEmpty) {
          return const SizedBox.shrink();
        }
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            IgnorePointer(
              child: CustomPaint(
                painter: _TrackingPainter(
                  frame: frame,
                  colors: colors,
                  labelStyle: typography.chrome9,
                  labelPadding: tokens.space1,
                  labelRadius: tokens.radiusSm,
                ),
              ),
            ),
            Positioned(
              top: tokens.space2,
              left: tokens.space2,
              child: IgnorePointer(
                child: _OverlayPlate(
                  child: TrackingLegend(colors: colors),
                ),
              ),
            ),
            if (hasWindow)
              Positioned(
                top: tokens.space2,
                right: tokens.space2,
                child: IgnorePointer(
                  child: _OverlayPlate(
                    child: Text(
                      '${formatDuration(tracking.windowStart)} – '
                      '${formatDuration(tracking.windowEnd)}',
                      style: typography.timecode11.copyWith(
                        color: ScOverlayColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// The sampled frame nearest [position], when one is close enough.
  static PlayerTrackFrameDto? _nearestFrame(
    PlayerTracksDto? tracks,
    double position,
  ) {
    if (tracks == null || tracks.frames.isEmpty) {
      return null;
    }
    PlayerTrackFrameDto? nearest;
    var distance = double.infinity;
    for (final PlayerTrackFrameDto frame in tracks.frames) {
      final double difference = (frame.timestampSeconds - position).abs();
      if (difference < distance) {
        nearest = frame;
        distance = difference;
      }
    }
    return distance <= _frameToleranceSeconds ? nearest : null;
  }
}

/// A small dark plate that keeps overlay copy legible on bright footage.
class _OverlayPlate extends StatelessWidget {
  const _OverlayPlate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = SportcutTokens.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space2,
        vertical: tokens.space1,
      ),
      decoration: BoxDecoration(
        color: ScTints.scrim(ScOverlayColors.bed),
        borderRadius: BorderRadius.circular(tokens.radiusSm),
      ),
      child: child,
    );
  }
}

/// Paints one frame's boxes and their side letters.
class _TrackingPainter extends CustomPainter {
  const _TrackingPainter({
    required this.frame,
    required this.colors,
    required this.labelStyle,
    required this.labelPadding,
    required this.labelRadius,
  });

  final PlayerTrackFrameDto? frame;
  final TrackingSideColors colors;
  final TextStyle labelStyle;
  final double labelPadding;
  final double labelRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = this.frame;
    if (frame == null) {
      return;
    }
    for (final PlayerObservationDto person in frame.people) {
      final double x = (person.boxX * size.width).clamp(0.0, size.width);
      final double y = (person.boxY * size.height).clamp(0.0, size.height);
      final double right =
          ((person.boxX + person.boxWidth) * size.width).clamp(0.0, size.width);
      final double bottom = ((person.boxY + person.boxHeight) * size.height)
          .clamp(0.0, size.height);
      if (right <= x || bottom <= y) {
        continue;
      }

      final color = colors.forSide(person.side);
      final onCourt = person.selection == PersonSelectionDto.onCourt;
      final paint = Paint()
        ..color = onCourt ? color : color.withValues(alpha: _offCourtAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth =
            person.trackId == null ? _boxStrokeLoose : _boxStrokeTracked;
      canvas.drawRect(Rect.fromLTRB(x, y, right, bottom), paint);
      _paintLabel(
        canvas,
        Offset(x, y),
        TrackingSideColors.letter(person.side),
        color,
      );
    }
  }

  /// Draw the side letter in a small plate at the box's top-left corner.
  void _paintLabel(Canvas canvas, Offset origin, String text, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: labelStyle.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double width = painter.width + labelPadding * 2;
    final double height = painter.height + labelPadding;
    final double top = math.max(0, origin.dy - height);
    final rect = Rect.fromLTWH(origin.dx, top, width, height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(labelRadius)),
      Paint()..color = ScOverlayColors.bed.withValues(alpha: _labelBedAlpha),
    );
    painter.paint(
      canvas,
      Offset(origin.dx + labelPadding, top + labelPadding / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _TrackingPainter oldDelegate) {
    return oldDelegate.frame != frame ||
        oldDelegate.colors.left != colors.left ||
        oldDelegate.colors.right != colors.right ||
        oldDelegate.colors.unknown != colors.unknown ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.labelPadding != labelPadding ||
        oldDelegate.labelRadius != labelRadius;
  }
}
