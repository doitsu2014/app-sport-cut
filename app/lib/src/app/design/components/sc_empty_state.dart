import 'package:flutter/material.dart';

import '../sc_elevation.dart';
import '../sc_icons.dart';
import '../sc_metrics.dart';
import '../sc_typography.dart';
import '../sportcut_tokens.dart';

/// A factual empty state.
///
/// One sentence says what is absent, and one optional action says what to do
/// next. There is no illustration; a caller that needs a visual cue passes an
/// [icon], which is the studio's icon vocabulary rather than artwork.
class ScEmptyState extends StatelessWidget {
  /// Build an empty state.
  const ScEmptyState({
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.compact = false,
    super.key,
  });

  /// The single factual sentence, for example "No videos in this workspace."
  final String message;

  /// The next action's label, shown only with [onAction].
  final String? actionLabel;

  /// Invoked by the next action.
  final VoidCallback? onAction;

  /// An optional icon from the studio vocabulary.
  final IconData? icon;

  /// Tightens the padding for a rail or an inspector panel.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final leadingIcon = icon;
    final label = actionLabel;
    final action = onAction;

    return Semantics(
      container: true,
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.borderSoft),
          borderRadius: BorderRadius.circular(tokens.radiusLg),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: tokens.space4,
          vertical: compact ? tokens.space4 : tokens.space6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            if (leadingIcon != null) ...<Widget>[
              Icon(
                leadingIcon,
                size: compact
                    ? ScIcons.toolbarSize
                    : ScMetrics.chip + tokens.space1,
                color: palette.muted,
              ),
              SizedBox(height: tokens.space2),
            ],
            ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: ScMetrics.libraryWidth),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: typography.sm14.copyWith(
                  color: palette.fg2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (label != null && action != null) ...<Widget>[
              SizedBox(height: tokens.space2),
              _EmptyAction(label: label, onPressed: action),
            ],
          ],
        ),
      ),
    );
  }
}

/// The accent text action under an empty state.
class _EmptyAction extends StatefulWidget {
  const _EmptyAction({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  State<_EmptyAction> createState() => _EmptyActionState();
}

class _EmptyActionState extends State<_EmptyAction> {
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
              child: Text(
                widget.label,
                style: typography.xs12.copyWith(
                  color: palette.accent,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: palette.accent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
