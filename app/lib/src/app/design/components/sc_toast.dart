import 'dart:async';

import 'package:flutter/material.dart';

import '../sc_elevation.dart';
import '../sc_icons.dart';
import '../sc_metrics.dart';
import '../sc_motion.dart';
import '../sc_typography.dart';
import '../sportcut_tokens.dart';
import 'sc_banner.dart';

/// How long a toast stays on screen before it dismisses itself.
const Duration _toastDuration = Duration(seconds: 4);

/// The accessible name of the dismiss control.
const String _dismissLabel = 'Dismiss notification';

/// The content of one toast.
@immutable
class ScToastData {
  /// Build a toast message.
  const ScToastData({required this.message, this.tone = ScBannerTone.info});

  /// The single line shown to the user.
  final String message;

  /// The tone that colours the leading icon.
  final ScBannerTone tone;
}

/// A transient, one-line confirmation.
///
/// The host owns the toast lifecycle: call
/// `show(ScToastData(...))` through a `GlobalKey<ScToastHostState>`, and the
/// toast dismisses itself after four seconds. Place the host in a [Stack]
/// above the shell content; it ignores pointers while nothing is visible and
/// never holds the only path to recovery.
class ScToastHost extends StatefulWidget {
  /// Build a toast host.
  const ScToastHost({super.key});

  @override
  State<ScToastHost> createState() => ScToastHostState();
}

/// The state a caller reaches through `GlobalKey<ScToastHostState>`.
class ScToastHostState extends State<ScToastHost> {
  ScToastData? _data;
  bool _visible = false;
  Timer? _timer;

  /// Show [data] and restart the four-second dismiss timer.
  void show(ScToastData data) {
    _timer?.cancel();
    setState(() {
      _data = data;
      _visible = true;
    });
    _timer = Timer(_toastDuration, _hide);
  }

  /// Hide the current toast before its timer elapses.
  void hide() {
    _timer?.cancel();
    _hide();
  }

  void _hide() {
    if (!mounted || !_visible) {
      return;
    }
    setState(() => _visible = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) {
      return const SizedBox.shrink();
    }

    final tokens = SportcutTokens.of(context);

    return IgnorePointer(
      ignoring: !_visible,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(
            left: tokens.space3,
            right: tokens.space3,
            bottom: tokens.space8 + tokens.space2,
          ),
          child: AnimatedSlide(
            offset: _visible ? Offset.zero : const Offset(0, 0.25),
            duration: ScMotion.duration(context, tokens.motionFast),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: ScMotion.duration(context, tokens.motionFast),
              curve: Curves.easeOut,
              child: Semantics(
                container: true,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: ScMetrics.dialogConfirm,
                  ),
                  child: ScToast(
                    message: data.message,
                    tone: data.tone,
                    onDismiss: hide,
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

/// The toast surface: a tone icon, one line of text, and a dismiss action.
///
/// [ScToastHost] wraps this in its slide and fade animation. It can also be
/// rendered directly where a persistent inline confirmation is wanted.
class ScToast extends StatelessWidget {
  /// Build a toast surface.
  const ScToast({
    super.key,
    required this.message,
    this.tone = ScBannerTone.info,
    this.onDismiss,
  });

  /// The single line shown to the user.
  final String message;

  /// The tone that colours the leading icon.
  final ScBannerTone tone;

  /// Called when the dismiss control is used. The control is hidden when null.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final dismiss = onDismiss;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        boxShadow: Theme.of(context).brightness == Brightness.dark
            ? ScElevation.raisedDark
            : ScElevation.raisedLight,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.space3,
          vertical: tokens.space2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              _toneIcon(tone),
              size: ScIcons.toolbarSize,
              color: _toneColor(tone, palette),
            ),
            SizedBox(width: tokens.space2),
            Flexible(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.xs12.copyWith(color: palette.fg2),
                ),
              ),
            ),
            if (dismiss != null) ...<Widget>[
              SizedBox(width: tokens.space2),
              _ToastDismiss(label: _dismissLabel, onPressed: dismiss),
            ],
          ],
        ),
      ),
    );
  }

  Color _toneColor(ScBannerTone tone, SportcutPalette palette) {
    switch (tone) {
      case ScBannerTone.info:
        return palette.success;
      case ScBannerTone.warning:
        return palette.warn;
      case ScBannerTone.danger:
        return palette.danger;
    }
  }

  IconData _toneIcon(ScBannerTone tone) {
    switch (tone) {
      case ScBannerTone.info:
        return ScIcons.checkCircle;
      case ScBannerTone.warning:
        return ScIcons.warning;
      case ScBannerTone.danger:
        return ScIcons.error;
    }
  }
}

/// The icon-only dismiss control.
class _ToastDismiss extends StatefulWidget {
  const _ToastDismiss({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  State<_ToastDismiss> createState() => _ToastDismissState();
}

class _ToastDismissState extends State<_ToastDismiss> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);

    return Tooltip(
      message: widget.label,
      child: ScFocusRing.overlay(
        palette: palette,
        focused: _focused,
        child: Semantics(
          button: true,
          label: widget.label,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onPressed,
              onFocusChange: (bool focused) {
                setState(() => _focused = focused);
              },
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              hoverColor: ScMotion.reduced(context)
                  ? palette.surface.withValues(alpha: 0)
                  : palette.surfaceWarm,
              focusColor: palette.surface.withValues(alpha: 0),
              child: SizedBox.square(
                dimension: ScMetrics.iconButton,
                child: Icon(
                  ScIcons.close,
                  size: ScMetrics.chip * 0.8,
                  color: palette.muted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
