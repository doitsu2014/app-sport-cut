import 'package:flutter/material.dart';

import '../sc_metrics.dart';
import '../sc_status.dart';
import '../sc_typography.dart';
import '../sportcut_tokens.dart';
import 'sc_pressable.dart';

/// One row in a pipeline or job list.
///
/// A 24 px mono number identifies the stage, the name carries the work, and
/// the resolved [ScStatus] supplies the state word, a done check, a running
/// percentage, or the blocked danger icon. Pass [onTap] to make the row
/// pressable; pass [selected] for the current stage.
class ScPipelineRow extends StatelessWidget {
  /// Build a pipeline row.
  const ScPipelineRow({
    super.key,
    required this.number,
    required this.name,
    required this.status,
    this.detail,
    this.trailing,
    this.onTap,
    this.selected = false,
  }) : assert(
          status != ScStatus.running || detail != null,
          'A running stage needs a percentage detail',
        );

  /// The one-based stage number, shown in a 24 px mono column.
  final int number;

  /// The stage or job name.
  final String name;

  /// The state to present.
  final ScStatus status;

  /// Extra detail, such as a running percentage. Required when [status] is
  /// [ScStatus.running].
  final String? detail;

  /// An optional control at the trailing edge.
  final Widget? trailing;

  /// Called when the row is tapped or activated from the keyboard. A null
  /// callback renders a passive row.
  final VoidCallback? onTap;

  /// Whether the row represents the current stage.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final style = status.resolve(palette);
    final isBlocked = status == ScStatus.blocked;

    final statusView = switch (status) {
      ScStatus.done => Icon(
          status.icon,
          size: tokens.space4,
          color: style.color,
          semanticLabel: status.label,
        ),
      ScStatus.running => Text(
          detail!,
          style: typography.chrome9.copyWith(color: style.color),
        ),
      _ => Text(
          status.label.toUpperCase(),
          style: typography.chrome9.copyWith(color: style.color),
        ),
    };

    final body = SizedBox(
      height: ScMetrics.rowCompact,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: ScMetrics.courtHandleVisual,
            child: Text(
              number.toString().padLeft(2, '0'),
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: typography.timecode11.copyWith(color: palette.muted),
            ),
          ),
          SizedBox(width: tokens.space3),
          if (isBlocked) ...<Widget>[
            Icon(
              status.icon,
              size: tokens.space4,
              color: style.color,
            ),
            SizedBox(width: tokens.space2),
          ],
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.sm14.copyWith(
                color: isBlocked ? style.color : palette.fg,
              ),
            ),
          ),
          SizedBox(width: tokens.space2),
          statusView,
          if (trailing != null) ...<Widget>[
            SizedBox(width: tokens.space2),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap != null) {
      return ScPressable(
        onTap: onTap,
        selected: selected,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        padding: EdgeInsets.symmetric(horizontal: tokens.space2),
        child: body,
      );
    }

    if (selected) {
      final radius = BorderRadius.circular(tokens.radiusSm);
      return Container(
        padding: EdgeInsets.symmetric(horizontal: tokens.space2),
        decoration: BoxDecoration(
          color: palette.surfaceWarm,
          borderRadius: radius,
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: palette.border),
        ),
        child: body,
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.space2),
      child: body,
    );
  }
}
