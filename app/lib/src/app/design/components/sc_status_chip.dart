import 'package:flutter/material.dart';

import '../sc_metrics.dart';
import '../sc_status.dart';
import '../sc_typography.dart';
import '../sportcut_tokens.dart';

/// A compact status chip: an icon and the word, never colour alone.
///
/// The chip is passive; it takes the resolved [ScStatus] and an optional
/// detail such as a running percentage. It reads only the theme extensions.
class ScStatusChip extends StatelessWidget {
  /// Build a status chip.
  const ScStatusChip({super.key, required this.status, this.detail});

  /// The state to present.
  final ScStatus status;

  /// Extra detail for [ScStatus.running], such as `42%`.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final style = status.resolve(palette);

    final word = status == ScStatus.running && detail != null
        ? '${style.label.toUpperCase()} $detail'
        : style.label.toUpperCase();

    return Container(
      height: ScMetrics.chip,
      padding: EdgeInsets.symmetric(horizontal: tokens.space2),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          style.color.withValues(alpha: 0.10),
          palette.surface,
        ),
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        border: Border.all(
          color: Color.alphaBlend(
            style.color.withValues(alpha: 0.45),
            palette.surface,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(style.icon, size: tokens.space3, color: style.color),
          SizedBox(width: tokens.space1),
          Text(
            word,
            style: typography.chrome9.copyWith(color: style.color),
          ),
        ],
      ),
    );
  }
}
