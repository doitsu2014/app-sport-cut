import 'package:flutter/material.dart';

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

/// A small uppercase pill used by the toolbar, preview header, and status bar.
class StudioChip extends StatelessWidget {
  /// Build a chip showing [label].
  const StudioChip({super.key, required this.label});

  /// The text to show, uppercased by the chip.
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = SportcutTokens.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space2 - 1,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(tokens.radiusPill),
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          fontSize: 9,
          letterSpacing: 0.06,
        ),
      ),
    );
  }
}

/// A small uppercase label separating the rail's two sections.
class SectionHeader extends StatelessWidget {
  /// Build a section header for [label].
  const SectionHeader({super.key, required this.label});

  /// The section name, uppercased by the header.
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// The header strip at the top of a rail or pane.
class RailHeader extends StatelessWidget {
  /// Build a rail header for [label].
  const RailHeader({super.key, required this.label, this.trailing});

  /// The rail name, uppercased by the header.
  final String label;

  /// Optional text shown at the far end, usually a count.
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = SportcutTokens.of(context);
    return Container(
      height: 38,
      padding: EdgeInsets.symmetric(horizontal: tokens.space3),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            Text(
              trailing!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// A small indeterminate spinner marking work that runs in the background.
class BusySpinner extends StatelessWidget {
  /// Build a spinner with the given tooltip.
  const BusySpinner({super.key, required this.tooltip});

  /// The tooltip explaining what is running.
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: const SizedBox.square(
        dimension: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
