import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../sc_elevation.dart';
import '../sc_metrics.dart';
import '../sc_typography.dart';
import '../sportcut_tokens.dart';

/// The disabled opacity shared by the score controls.
const double _disabledOpacity = 0.45;

/// A serving indicator that names both sides and marks the server.
///
/// The signal dot and the accented name carry the state together, so the
/// serving side is never marked by colour alone.
class ScServingLine extends StatelessWidget {
  /// Build a serving line for a two-sided score.
  const ScServingLine({
    super.key,
    required this.leftName,
    required this.rightName,
    required this.servingLeft,
    required this.serveLabel,
  });

  /// The name shown for the left side.
  final String leftName;

  /// The name shown for the right side.
  final String rightName;

  /// Whether the left side is serving.
  final bool servingLeft;

  /// The word that closes the line, for example `Serving`.
  final String serveLabel;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final typography = SportcutTypography.of(context);
    final tokens = SportcutTokens.of(context);
    final dotSize = tokens.space1;
    final servingName = servingLeft ? leftName : rightName;
    final semanticLabel =
        servingName.isEmpty ? serveLabel : '$servingName $serveLabel';

    return Semantics(
      container: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Row(
          children: <Widget>[
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: palette.accent,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: tokens.space2),
            Flexible(
              child: Text(
                leftName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typography.xs12.copyWith(
                  color: servingLeft ? palette.accent : palette.muted,
                  fontWeight: servingLeft ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            SizedBox(width: tokens.space2),
            Flexible(
              child: Text(
                rightName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typography.xs12.copyWith(
                  color: servingLeft ? palette.muted : palette.accent,
                  fontWeight: servingLeft ? FontWeight.w500 : FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            SizedBox(width: tokens.space2),
            Text(
              serveLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.xs12.copyWith(color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// One side of a scoreboard: its label, name, score, and serving marker.
///
/// The serving side carries a two-pixel accent underline under its score. The
/// score uses tabular figures so it never shifts as the digits change.
class ScScoreSide extends StatelessWidget {
  /// Build one side of a scoreboard.
  const ScScoreSide({
    super.key,
    required this.label,
    required this.name,
    required this.score,
    required this.serving,
    this.compact = false,
  });

  /// The short side label, for example `L · Left`.
  final String label;

  /// The player or side name. An empty name hides the line.
  final String name;

  /// The score for this side.
  final int score;

  /// Whether this side is serving.
  final bool serving;

  /// Whether to use the 48 px score instead of the 52 px score.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final typography = SportcutTypography.of(context);
    final tokens = SportcutTokens.of(context);
    final scoreStyle = SportcutTypography.withTabular(
      compact ? typography.score48 : typography.score52,
    ).copyWith(color: palette.fg);
    final underline = tokens.space1 / 2;
    final semanticLabel =
        <String>[label, if (name.isNotEmpty) name, '$score'].join(', ');

    return Semantics(
      container: true,
      label: serving ? '$semanticLabel, serving' : semanticLabel,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.micro10.copyWith(
                color: serving ? palette.accent : palette.muted,
              ),
            ),
            SizedBox(height: tokens.space1),
            Container(
              padding: EdgeInsets.only(bottom: tokens.space1),
              decoration: serving
                  ? BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: palette.accent,
                          width: underline,
                        ),
                      ),
                    )
                  : null,
              child: Text('$score', style: scoreStyle),
            ),
            if (name.isNotEmpty) ...<Widget>[
              SizedBox(height: tokens.space1),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typography.sm14.copyWith(
                  color: serving ? palette.fg2 : palette.muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A two-sided scoreboard with a serving word under the score.
///
/// The serving side is marked three ways: an accented label, an accent
/// underline under its score, and the serving word below the row.
class ScScoreboard extends StatelessWidget {
  /// Build a scoreboard for a two-sided score.
  const ScScoreboard({
    super.key,
    required this.leftLabel,
    required this.rightLabel,
    required this.leftScore,
    required this.rightScore,
    required this.servingLeft,
    this.servingLabel,
  });

  /// The short label for the left side.
  final String leftLabel;

  /// The short label for the right side.
  final String rightLabel;

  /// The left side's score.
  final int leftScore;

  /// The right side's score.
  final int rightScore;

  /// Whether the left side is serving.
  final bool servingLeft;

  /// The serving word, or null to derive it from the side label.
  final String? servingLabel;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final typography = SportcutTypography.of(context);
    final tokens = SportcutTokens.of(context);
    final word =
        servingLabel ?? '${servingLeft ? leftLabel : rightLabel} serving';
    final dotSize = tokens.space1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ScScoreSide(
                  label: leftLabel,
                  name: '',
                  score: leftScore,
                  serving: servingLeft,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.space2),
              child: Text(
                ':',
                style: typography.title24.copyWith(color: palette.muted),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: ScScoreSide(
                  label: rightLabel,
                  name: '',
                  score: rightScore,
                  serving: !servingLeft,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: tokens.space2),
        Row(
          children: <Widget>[
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: palette.accent,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: tokens.space1),
            Text(
              word,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.xs12.copyWith(color: palette.accent),
            ),
          ],
        ),
      ],
    );
  }
}

/// The paired L/R buttons that confirm a rally winner.
///
/// The buttons are data-in and callback-out: left reports `true`, right
/// reports `false`. Both keep a 44 px hit target even when the surrounding
/// layout is denser.
class ScWinnerButtons extends StatelessWidget {
  /// Build the winner confirmation row.
  const ScWinnerButtons({
    super.key,
    required this.leftLabel,
    required this.rightLabel,
    required this.onConfirm,
    this.enabled = true,
    this.leftFocusNode,
    this.rightFocusNode,
  });

  /// The short label for the left side.
  final String leftLabel;

  /// The short label for the right side.
  final String rightLabel;

  /// Called with `true` when the left side won, `false` for the right side.
  final ValueChanged<bool> onConfirm;

  /// Whether both buttons accept input.
  final bool enabled;

  /// The focus node for the left button.
  final FocusNode? leftFocusNode;

  /// The focus node for the right button.
  final FocusNode? rightFocusNode;

  @override
  Widget build(BuildContext context) {
    final tokens = SportcutTokens.of(context);
    final row = Row(
      children: <Widget>[
        Expanded(
          child: _WinnerButton(
            label: '$leftLabel won',
            enabled: enabled,
            focusNode: leftFocusNode,
            onPressed: () => onConfirm(true),
          ),
        ),
        SizedBox(width: tokens.space2),
        Expanded(
          child: _WinnerButton(
            label: '$rightLabel won',
            enabled: enabled,
            focusNode: rightFocusNode,
            onPressed: () => onConfirm(false),
          ),
        ),
      ],
    );

    if (enabled) {
      return row;
    }
    return Opacity(
      opacity: _disabledOpacity,
      child: IgnorePointer(child: row),
    );
  }
}

/// One winner confirmation button.
class _WinnerButton extends StatefulWidget {
  const _WinnerButton({
    required this.label,
    required this.onPressed,
    required this.enabled,
    this.focusNode,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;
  final FocusNode? focusNode;

  @override
  State<_WinnerButton> createState() => _WinnerButtonState();
}

class _WinnerButtonState extends State<_WinnerButton> {
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
    final typography = SportcutTypography.of(context);
    final tokens = SportcutTokens.of(context);
    final hovered = widget.enabled && _hovered;

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.label,
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: widget.enabled,
        focusNode: widget.focusNode,
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
          onTap: widget.enabled ? _activate : null,
          child: ScFocusRing.overlay(
            palette: palette,
            focused: _focused,
            child: Container(
              height: ScMetrics.rowCompact,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hovered ? palette.surfaceWarm : palette.surface,
                borderRadius: BorderRadius.circular(tokens.radiusSm),
                border: Border.all(
                  color: hovered ? palette.muted : palette.border,
                ),
              ),
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typography.xs12.copyWith(
                  color: widget.enabled ? palette.fg : palette.muted,
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

/// The two keys that activate a focused winner button.
const Map<ShortcutActivator, Intent> _activateShortcuts =
    <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
};
