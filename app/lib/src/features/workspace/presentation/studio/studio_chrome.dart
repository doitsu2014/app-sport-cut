import 'package:flutter/material.dart';

import '../../../../app/design/sc_typography.dart';
import '../../../../app/design/sportcut_tokens.dart';
import '../../../library/domain/match_record.dart';

/// A short resolution label for a recorded video.
///
/// Returns an em dash when the height is unknown, and a shorthand such as
/// `1080p` for the common sizes.
String resolutionLabel(MatchRecord match) {
  final height = match.videoHeight;
  if (height == null || height <= 0) {
    return '—';
  }
  if (height >= 1080) {
    return '1080p';
  }
  if (height >= 720) {
    return '720p';
  }
  if (height >= 480) {
    return '480p';
  }
  return '${height}p';
}

/// A small uppercase pill used by the preview header.
class StudioChip extends StatelessWidget {
  /// Build a chip showing [label].
  const StudioChip({super.key, required this.label});

  /// The text to show, uppercased by the chip.
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space2,
        vertical: tokens.space1 / 2,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: palette.borderSoft),
        borderRadius: BorderRadius.circular(tokens.radiusPill),
      ),
      child: Text(
        label.toUpperCase(),
        style: typography.chrome9.copyWith(color: palette.muted),
      ),
    );
  }
}
