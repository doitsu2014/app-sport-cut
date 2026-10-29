import 'package:flutter/material.dart';

import '../sc_metrics.dart';
import '../sc_typography.dart';
import '../sportcut_tokens.dart';
import 'sc_pressable.dart';

/// A raised studio panel with a hairline border and a rounded corner.
///
/// Panels are grouping surfaces, not cards: keep them unbordered from each
/// other and use [ScSectionHeader] and [ScDivider] for internal rhythm.
class ScPanel extends StatelessWidget {
  /// Build a panel.
  const ScPanel({super.key, this.padding, required this.child});

  /// The internal padding. Defaults to [SportcutTokens.space4].
  final EdgeInsetsGeometry? padding;

  /// The panel content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);

    return Container(
      padding: padding ?? EdgeInsets.all(tokens.space4),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        border: Border.all(color: palette.borderSoft),
      ),
      child: child,
    );
  }
}

/// An uppercase mono label for the top of a rail, with a trailing count and
/// optional actions.
class ScRailHeader extends StatelessWidget {
  /// Build a rail header.
  const ScRailHeader({
    super.key,
    required this.label,
    this.count,
    this.actions = const <Widget>[],
  });

  /// The label, rendered uppercase.
  final String label;

  /// An optional count shown at the trailing edge.
  final int? count;

  /// Optional controls shown after the count.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final labelStyle = typography.chrome9.copyWith(color: palette.muted);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space3,
        vertical: tokens.space1 + tokens.space1 / 2,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
          if (count != null) Text(count.toString(), style: labelStyle),
          for (final action in actions) ...<Widget>[
            SizedBox(width: tokens.space1),
            action,
          ],
        ],
      ),
    );
  }
}

/// An uppercase mono section label with an optional count and trailing
/// widget.
class ScSectionHeader extends StatelessWidget {
  /// Build a section header.
  const ScSectionHeader({
    super.key,
    required this.label,
    this.count,
    this.trailing,
  });

  /// The label, rendered uppercase.
  final String label;

  /// An optional count shown before [trailing].
  final int? count;

  /// An optional control at the trailing edge.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final labelStyle = typography.chrome9.copyWith(color: palette.muted);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.space2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
          if (count != null) Text(count.toString(), style: labelStyle),
          if (trailing != null) ...<Widget>[
            SizedBox(width: tokens.space2),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// A one-pixel hairline rule.
class ScDivider extends StatelessWidget {
  /// Build a divider.
  const ScDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);

    return Container(
      height: tokens.space1 / 4,
      color: palette.borderSoft,
    );
  }
}

/// A small pill tag, optionally selectable and pressable.
class ScTag extends StatelessWidget {
  /// Build a tag.
  const ScTag({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  /// The tag text.
  final String label;

  /// Whether the tag is active.
  final bool selected;

  /// Called when the tag is tapped. A null callback renders a passive tag.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);

    final tag = Container(
      height: ScMetrics.chip,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: tokens.space2),
      decoration: BoxDecoration(
        color: selected
            ? Color.alphaBlend(
                palette.accent.withValues(alpha: 0.10),
                palette.surface,
              )
            : palette.surface.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        border: Border.all(
          color: selected
              ? Color.alphaBlend(
                  palette.accent.withValues(alpha: 0.50),
                  palette.surface,
                )
              : palette.border,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: typography.chrome9.copyWith(
          color: selected ? palette.accent : palette.muted,
        ),
      ),
    );

    if (onTap == null) {
      return tag;
    }

    return ScPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusPill),
      child: tag,
    );
  }
}

/// A two-column definition list of metadata pairs.
class ScMetaList extends StatelessWidget {
  /// Build a metadata list from `(label, value)` pairs.
  const ScMetaList({super.key, required this.items});

  /// The label/value pairs, in display order.
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final labelStyle = typography.xs12.copyWith(color: palette.muted);
    final valueStyle = typography.xs12.copyWith(color: palette.fg2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (String label, String value) in items)
          Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.space1 / 2),
            child: Row(
              children: <Widget>[
                Text(label, style: labelStyle),
                SizedBox(width: tokens.space3),
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: valueStyle,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
