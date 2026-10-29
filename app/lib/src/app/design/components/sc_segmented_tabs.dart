import 'package:flutter/material.dart';

import '../sc_elevation.dart';
import '../sc_metrics.dart';
import '../sc_motion.dart';
import '../sc_typography.dart';
import '../sportcut_tokens.dart';
import 'sc_pressable.dart';

/// A segmented control that filters content.
///
/// This is a filter, not navigation (USAGE.md, ADR-0003 D17): pressing an
/// option changes what is shown inside the current panel and never changes
/// the panel itself. The selected segment takes the surface fill and the
/// elevation ring. For panel navigation use [ScTabs].
class ScSegmentedControl extends StatelessWidget {
  /// Build a segmented filter.
  const ScSegmentedControl({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
    this.enabled = true,
  });

  /// The option labels, in reading order.
  final List<String> options;

  /// The zero-based index of the selected option.
  final int selectedIndex;

  /// Called with the tapped option index.
  final ValueChanged<int> onChanged;

  /// Whether the control accepts pointer and keyboard input.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);

    final row = Row(
      mainAxisSize: MainAxisSize.max,
      children: <Widget>[
        for (var index = 0; index < options.length; index++) ...<Widget>[
          if (index > 0) SizedBox(width: tokens.space1 / 2),
          Expanded(
            child: _buildSegment(context, index, palette, tokens),
          ),
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
      child: FocusTraversalGroup(child: row),
    );
  }

  Widget _buildSegment(
    BuildContext context,
    int index,
    SportcutPalette palette,
    SportcutTokens tokens,
  ) {
    final typography = SportcutTypography.of(context);
    final label = options[index];
    final selected = index == selectedIndex;
    final radius = BorderRadius.circular(tokens.radiusSm);

    return Semantics(
      container: true,
      child: Semantics(
        selected: selected,
        button: true,
        enabled: enabled,
        label: label,
        onTap: enabled ? () => onChanged(index) : null,
        excludeSemantics: true,
        child: ScPressable(
          onTap: () => onChanged(index),
          enabled: enabled,
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
              boxShadow: selected
                  ? <BoxShadow>[ScElevation.ring(palette.controlBorder)]
                  : null,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.xs12.copyWith(
                color: selected ? palette.fg : palette.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
