import 'package:flutter/material.dart';

import '../sc_elevation.dart';
import '../sc_icons.dart';
import '../sc_metrics.dart';
import '../sc_typography.dart';
import '../sportcut_tokens.dart';

/// The feedback tone a banner, toast, or transient message carries.
///
/// The tone names the state; it is never the only signal, because the message
/// text always describes what happened.
enum ScBannerTone {
  /// A neutral confirmation or piece of information.
  info,

  /// Work in progress or a condition worth noticing.
  warning,

  /// A failure or a blocked action.
  danger,
}

/// The tint applied to a banner background, over the surface.
const double _fillAlpha = 0.06;

/// The tint applied to a banner border, over the surface.
const double _borderAlpha = 0.4;

/// A persistent, in-layout message.
///
/// A banner stays until the condition clears, unlike a toast. The background
/// and border are tinted from the tone colour with [Color.alphaBlend], so both
/// themes resolve without a new palette entry. The message wraps to two lines
/// and then ellipsizes.
class ScBanner extends StatelessWidget {
  /// Build a banner.
  const ScBanner({
    required this.message,
    this.actionLabel,
    this.onAction,
    this.tone = ScBannerTone.danger,
    this.icon,
    super.key,
  });

  /// The sentence describing the condition.
  final String message;

  /// The action that resolves the condition, shown only with [onAction].
  final String? actionLabel;

  /// Invoked by the action.
  final VoidCallback? onAction;

  /// The tone that colours the icon, border, and background.
  final ScBannerTone tone;

  /// Overrides the tone's default icon.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final toneColor = _toneColor(palette);
    final label = actionLabel;
    final action = onAction;

    return Semantics(
      container: true,
      child: Container(
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            toneColor.withValues(alpha: _fillAlpha),
            palette.surface,
          ),
          border: Border.all(
            color: Color.alphaBlend(
              toneColor.withValues(alpha: _borderAlpha),
              palette.surface,
            ),
          ),
          borderRadius: BorderRadius.circular(tokens.radiusMd),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: tokens.space3,
          vertical: tokens.space3,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.only(top: tokens.space1 / 2),
              child: Icon(
                icon ?? _toneIcon(tone),
                size: ScIcons.toolbarSize,
                color: toneColor,
                semanticLabel: tone.resolveLabel,
              ),
            ),
            SizedBox(width: tokens.space3),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: typography.sm14.copyWith(color: palette.fg2),
              ),
            ),
            if (label != null && action != null) ...<Widget>[
              SizedBox(width: tokens.space3),
              _BannerAction(label: label, onPressed: action),
            ],
          ],
        ),
      ),
    );
  }

  Color _toneColor(SportcutPalette palette) {
    switch (tone) {
      case ScBannerTone.info:
        return palette.success;
      case ScBannerTone.warning:
        return palette.warn;
      case ScBannerTone.danger:
        return palette.danger;
    }
  }

  IconData _toneIcon(ScBannerTone bannerTone) {
    switch (bannerTone) {
      case ScBannerTone.info:
        return ScIcons.checkCircle;
      case ScBannerTone.warning:
        return ScIcons.warning;
      case ScBannerTone.danger:
        return ScIcons.error;
    }
  }
}

/// The word a banner icon announces to assistive technology.
extension on ScBannerTone {
  /// The label that accompanies the icon, so colour is not the only signal.
  String get resolveLabel {
    switch (this) {
      case ScBannerTone.info:
        return 'Information';
      case ScBannerTone.warning:
        return 'Warning';
      case ScBannerTone.danger:
        return 'Error';
    }
  }
}

/// The compact secondary action in a banner.
class _BannerAction extends StatefulWidget {
  const _BannerAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_BannerAction> createState() => _BannerActionState();
}

class _BannerActionState extends State<_BannerAction> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);

    return ScFocusRing.overlay(
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
            hoverColor: palette.surfaceWarm,
            child: Container(
              constraints: const BoxConstraints(
                minHeight: ScMetrics.buttonCompact,
              ),
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: tokens.space3),
              decoration: BoxDecoration(
                border: Border.all(color: palette.border),
                borderRadius: BorderRadius.circular(tokens.radiusSm),
              ),
              child: Text(
                widget.label,
                style: typography.xs12.copyWith(
                  color: palette.fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
