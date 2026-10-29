import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../sc_elevation.dart';
import '../sc_icons.dart';
import '../sc_metrics.dart';
import '../sc_overlay_colors.dart';
import '../sc_typography.dart';
import '../sportcut_tokens.dart';

/// The distance a seek control moves per activation.
const Duration _seekStep = Duration(seconds: 5);

/// The reverse step, kept const so the keyboard map stays const.
const Duration _seekStepBack = Duration(seconds: -5);

/// The disabled opacity for the whole bar.
const double _disabledOpacity = 0.45;

/// The hover wash over a transport button.
const double _hoverTintAlpha = 0.10;

/// The ink opacity of an icon at rest.
const double _restIconAlpha = 0.72;

/// The ink opacity of the elapsed timecode.
const double _positionInkAlpha = 0.86;

/// The ink opacity of the total timecode.
const double _durationInkAlpha = 0.42;

/// The ink opacity of the scrubber track.
const double _trackInkAlpha = 0.18;

/// The ink opacity of the bar border.
const double _borderInkAlpha = 0.16;

/// The bar surface opacity over the footage.
const double _barAlpha = 0.9;

/// The label announced for the scrubber.
const String _seekLabel = 'Seek through the match';

/// The floating playback bar that sits over the footage.
///
/// It carries play/pause, a five-second seek in each direction, a scrubber,
/// and tabular timecodes. It follows ADR-0003 D12 and exposes no volume
/// control: the playback layer has no volume API.
class ScTransport extends StatelessWidget {
  /// Build a transport bar.
  const ScTransport({
    super.key,
    required this.playing,
    required this.enabled,
    required this.position,
    required this.duration,
    required this.onPlayPause,
    required this.onSeekBackward,
    required this.onSeekForward,
    required this.onSeek,
    this.playLabel = 'Play',
    this.pauseLabel = 'Pause',
    this.width,
  });

  /// Whether playback is running.
  final bool playing;

  /// Whether the controls accept input.
  final bool enabled;

  /// The current playback position.
  final Duration position;

  /// The recording's duration.
  final Duration duration;

  /// Toggles play and pause.
  final VoidCallback onPlayPause;

  /// Seeks five seconds backward.
  final VoidCallback onSeekBackward;

  /// Seeks five seconds forward.
  final VoidCallback onSeekForward;

  /// Seeks to a position chosen on the scrubber.
  final ValueChanged<Duration> onSeek;

  /// The accessible label for the play state.
  final String playLabel;

  /// The accessible label for the pause state.
  final String pauseLabel;

  /// A fixed bar width, or null to fill the available width.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final typography = SportcutTypography.of(context);
    final tokens = SportcutTokens.of(context);
    const ink = ScOverlayColors.ink;
    final timeStyle = SportcutTypography.withTabular(typography.timecode11);

    final bar = SizedBox(
      width: width,
      child: Semantics(
        container: true,
        label: 'Playback controls',
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.space3,
            vertical: tokens.space2,
          ),
          decoration: BoxDecoration(
            color: ScOverlayColors.bed.withValues(alpha: _barAlpha),
            borderRadius: BorderRadius.circular(tokens.radiusMd),
            border: Border.all(color: ink.withValues(alpha: _borderInkAlpha)),
            boxShadow: ScElevation.raisedDark,
          ),
          child: Row(
            children: <Widget>[
              _StageIconButton(
                label: 'Back 5 seconds',
                icon: ScIcons.rewind,
                enabled: enabled,
                onPressed: onSeekBackward,
              ),
              SizedBox(width: tokens.space1),
              _StageIconButton(
                label: playing ? pauseLabel : playLabel,
                icon: playing ? ScIcons.pause : ScIcons.play,
                enabled: enabled,
                accent: true,
                onPressed: onPlayPause,
              ),
              SizedBox(width: tokens.space1),
              _StageIconButton(
                label: 'Forward 5 seconds',
                icon: ScIcons.forward,
                enabled: enabled,
                onPressed: onSeekForward,
              ),
              SizedBox(width: tokens.space2),
              Text(
                _formatClock(position),
                style: timeStyle.copyWith(
                  color: ink.withValues(alpha: _positionInkAlpha),
                ),
              ),
              SizedBox(width: tokens.space2),
              Expanded(
                child: _Scrubber(
                  position: position,
                  duration: duration,
                  enabled: enabled,
                  onSeek: onSeek,
                ),
              ),
              SizedBox(width: tokens.space2),
              Text(
                _formatClock(duration),
                style: timeStyle.copyWith(
                  color: ink.withValues(alpha: _durationInkAlpha),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (enabled) {
      return bar;
    }
    return Opacity(
      opacity: _disabledOpacity,
      child: IgnorePointer(child: bar),
    );
  }
}

/// One square, icon-only transport control.
class _StageIconButton extends StatefulWidget {
  const _StageIconButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.enabled,
    this.accent = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;
  final bool accent;

  @override
  State<_StageIconButton> createState() => _StageIconButtonState();
}

class _StageIconButtonState extends State<_StageIconButton> {
  bool _focused = false;
  bool _hovered = false;

  void _activate() {
    if (widget.enabled) {
      widget.onPressed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    const ink = ScOverlayColors.ink;
    final hovered = widget.enabled && _hovered;
    final background = widget.accent
        ? ScOverlayColors.signal
        : ink.withValues(alpha: hovered ? _hoverTintAlpha : 0);
    final iconColor = widget.accent
        ? ScOverlayColors.bed
        : (hovered ? ink : ink.withValues(alpha: _restIconAlpha));

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.label,
      excludeSemantics: true,
      child: Tooltip(
        message: widget.label,
        excludeFromSemantics: true,
        child: FocusableActionDetector(
          enabled: widget.enabled,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          onShowHoverHighlight: (value) => setState(() => _hovered = value),
          mouseCursor: widget.enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          shortcuts: _activateShortcuts,
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (intent) {
                _activate();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.enabled ? _activate : null,
            child: ScFocusRing.overlay(
              palette: palette,
              focused: _focused,
              child: SizedBox.square(
                dimension: ScMetrics.iconButton,
                child: Center(
                  child: Container(
                    width: ScMetrics.buttonCompact,
                    height: ScMetrics.buttonCompact,
                    decoration: BoxDecoration(
                      color: background,
                      shape:
                          widget.accent ? BoxShape.circle : BoxShape.rectangle,
                      borderRadius: widget.accent
                          ? null
                          : BorderRadius.circular(tokens.radiusSm),
                    ),
                    child: Icon(
                      widget.icon,
                      size: ScMetrics.toolbarIcon,
                      color: iconColor,
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

/// The seek track. It follows the pointer immediately and exposes keyboard
/// and semantics actions, so it is usable without a mouse.
class _Scrubber extends StatefulWidget {
  const _Scrubber({
    required this.position,
    required this.duration,
    required this.enabled,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final bool enabled;
  final ValueChanged<Duration> onSeek;

  @override
  State<_Scrubber> createState() => _ScrubberState();
}

class _ScrubberState extends State<_Scrubber> {
  bool _focused = false;

  double get _fraction {
    final total = widget.duration.inMicroseconds;
    if (total <= 0) {
      return 0;
    }
    return (widget.position.inMicroseconds / total).clamp(0, 1).toDouble();
  }

  void _seekFraction(double fraction) {
    final total = widget.duration.inMicroseconds;
    if (total <= 0) {
      return;
    }
    var micros = (total * fraction).round();
    if (micros < 0) {
      micros = 0;
    }
    if (micros > total) {
      micros = total;
    }
    widget.onSeek(Duration(microseconds: micros));
  }

  void _nudge(Duration delta) {
    if (!widget.enabled) {
      return;
    }
    final total = widget.duration.inMicroseconds;
    var micros = widget.position.inMicroseconds + delta.inMicroseconds;
    if (micros < 0) {
      micros = 0;
    }
    if (total > 0 && micros > total) {
      micros = total;
    }
    widget.onSeek(Duration(microseconds: micros));
  }

  void _seekAt(double dx, double width) {
    if (width <= 0) {
      return;
    }
    _seekFraction((dx / width).clamp(0, 1).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    const ink = ScOverlayColors.ink;
    final fraction = _fraction;

    return Semantics(
      container: true,
      slider: true,
      enabled: widget.enabled,
      label: _seekLabel,
      value: _formatClock(widget.position),
      increasedValue: _formatClock(widget.position + _seekStep),
      decreasedValue: _formatClock(widget.position - _seekStep),
      onIncrease: widget.enabled ? () => _nudge(_seekStep) : null,
      onDecrease: widget.enabled ? () => _nudge(_seekStepBack) : null,
      child: FocusableActionDetector(
        enabled: widget.enabled,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        mouseCursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        shortcuts: _seekShortcuts,
        actions: <Type, Action<Intent>>{
          _SeekIntent: CallbackAction<_SeekIntent>(
            onInvoke: (intent) {
              _nudge(intent.delta);
              return null;
            },
          ),
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final trackHeight = tokens.space1;
            final thumb = tokens.space3;
            final usable = width > thumb ? width - thumb : 0.0;
            final thumbLeft = usable * fraction;
            final trackTop = (ScMetrics.iconButton - trackHeight) / 2;
            final thumbTop = (ScMetrics.iconButton - thumb) / 2;
            final trackRadius = BorderRadius.circular(tokens.radiusPill);

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: widget.enabled
                  ? (details) => _seekAt(details.localPosition.dx, width)
                  : null,
              onHorizontalDragStart: widget.enabled
                  ? (details) => _seekAt(details.localPosition.dx, width)
                  : null,
              onHorizontalDragUpdate: widget.enabled
                  ? (details) => _seekAt(details.localPosition.dx, width)
                  : null,
              child: ScFocusRing.overlay(
                palette: palette,
                focused: _focused,
                child: SizedBox(
                  height: ScMetrics.iconButton,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Positioned(
                        left: 0,
                        right: 0,
                        top: trackTop,
                        height: trackHeight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: ink.withValues(alpha: _trackInkAlpha),
                            borderRadius: trackRadius,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: trackTop,
                        height: trackHeight,
                        width: thumbLeft + thumb / 2,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: ScOverlayColors.signal,
                            borderRadius: trackRadius,
                          ),
                        ),
                      ),
                      Positioned(
                        left: thumbLeft,
                        top: thumbTop,
                        width: thumb,
                        height: thumb,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            color: ScOverlayColors.signal,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A keyboard seek request.
class _SeekIntent extends Intent {
  const _SeekIntent(this.delta);

  final Duration delta;
}

/// The two keys that activate a focused transport control.
const Map<ShortcutActivator, Intent> _activateShortcuts =
    <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
};

/// The arrow keys that seek a focused scrubber.
const Map<ShortcutActivator, Intent> _seekShortcuts =
    <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.arrowLeft): _SeekIntent(_seekStepBack),
  SingleActivator(LogicalKeyboardKey.arrowRight): _SeekIntent(_seekStep),
};

/// Format a duration as a two-digit, tabular-friendly clock.
String _formatClock(Duration value) {
  final totalSeconds = value.inSeconds < 0 ? 0 : value.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(hours)}:${two(minutes)}:${two(seconds)}';
}
