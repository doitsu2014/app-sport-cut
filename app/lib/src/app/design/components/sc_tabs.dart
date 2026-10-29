import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../sc_metrics.dart';
import '../sc_motion.dart';
import '../sc_typography.dart';
import '../sportcut_tokens.dart';
import 'sc_pressable.dart';

/// One tab in an [ScTabs] tablist.
class ScTab {
  /// Build a tab.
  const ScTab({required this.label, this.icon});

  /// The tab text.
  final String label;

  /// An optional leading icon. It takes the accent colour when selected.
  final IconData? icon;
}

/// A real tablist that changes the visible panel.
///
/// This is navigation, not a filter: use [ScSegmentedControl] for a filter
/// (ADR-0003 D17). Each tab announces itself as a selected button inside its
/// own semantics container, is 26 px high at [ScMetrics.tab], and takes focus
/// in left/right order. Pressing uses [ScPressable].
class ScTabs extends StatelessWidget {
  /// Build a tablist.
  const ScTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    this.expanded = true,
  });

  /// The tabs, in reading order.
  final List<ScTab> tabs;

  /// The zero-based index of the selected tab.
  final int selectedIndex;

  /// Called with the tapped tab index.
  final ValueChanged<int> onChanged;

  /// Whether the tabs divide the available width evenly.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);

    final row = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      children: <Widget>[
        for (var index = 0; index < tabs.length; index++) ...<Widget>[
          if (index > 0) SizedBox(width: tokens.space1 / 2),
          if (expanded)
            Expanded(child: _buildTab(context, index, palette, tokens))
          else
            _buildTab(context, index, palette, tokens),
        ],
      ],
    );

    return Container(
      padding: EdgeInsets.all(tokens.space1),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        border: Border.all(color: palette.borderSoft),
      ),
      child: FocusTraversalGroup(
        child: Semantics(
          role: SemanticsRole.tabBar,
          explicitChildNodes: true,
          child: row,
        ),
      ),
    );
  }

  Widget _buildTab(
    BuildContext context,
    int index,
    SportcutPalette palette,
    SportcutTokens tokens,
  ) {
    final typography = SportcutTypography.of(context);
    final tab = tabs[index];
    final selected = index == selectedIndex;
    final radius = BorderRadius.circular(tokens.radiusSm);
    final icon = tab.icon;

    return Semantics(
      container: true,
      child: Semantics(
        role: SemanticsRole.tab,
        selected: selected,
        button: true,
        label: tab.label,
        onTap: () => onChanged(index),
        excludeSemantics: true,
        child: ScPressable(
          onTap: () => onChanged(index),
          borderRadius: radius,
          child: AnimatedContainer(
            duration: ScMotion.duration(context, tokens.motionFast),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: ScMetrics.tab),
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: tokens.space2),
            decoration: BoxDecoration(
              color: selected
                  ? palette.surface
                  : palette.surface.withValues(alpha: 0),
              borderRadius: radius,
            ),
            foregroundDecoration: selected
                ? BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(color: palette.controlBorder),
                  )
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(
                    icon,
                    size: tokens.space3,
                    color: selected ? palette.accent : palette.muted,
                  ),
                  SizedBox(width: tokens.space1),
                ],
                Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.xs12.copyWith(
                    color: selected ? palette.fg : palette.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
