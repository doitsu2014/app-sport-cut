import 'package:flutter/material.dart';

import 'sc_icons.dart';
import 'sportcut_tokens.dart';

/// The shell's status vocabulary.
///
/// A status is always a word plus an icon, never colour alone: the colour is
/// a reinforcement, not the only signal.
enum ScStatus {
  /// Ready for the next action.
  ready('Ready', ScIcons.checkCircle),

  /// A job is running.
  running('Analyzing', ScIcons.running),

  /// Finished.
  done('Done', ScIcons.check),

  /// A prerequisite is missing.
  blocked('Blocked', ScIcons.blocked),

  /// Finished, but the user must confirm something.
  needsReview('Needs review', ScIcons.review),

  /// Nothing has started.
  idle('Idle', ScIcons.idle);

  const ScStatus(this.label, this.icon);

  /// The human-readable label. Callers may render it uppercase in chrome.
  final String label;

  /// The icon that reinforces the label.
  final IconData icon;

  /// The colour role for [palette].
  Color resolveColor(SportcutPalette palette) {
    switch (this) {
      case ScStatus.ready:
      case ScStatus.done:
        return palette.success;
      case ScStatus.running:
        return palette.accent;
      case ScStatus.blocked:
        return palette.danger;
      case ScStatus.needsReview:
        return palette.warn;
      case ScStatus.idle:
        return palette.muted;
    }
  }

  /// The full presentation for [palette]: word, icon, and colour together.
  ScStatusStyle resolve(SportcutPalette palette) {
    return ScStatusStyle(
      label: label,
      icon: icon,
      color: resolveColor(palette),
    );
  }
}

/// A resolved status: the label, icon, and colour a chip or row renders.
@immutable
class ScStatusStyle {
  /// Build one resolved status.
  const ScStatusStyle({
    required this.label,
    required this.icon,
    required this.color,
  });

  /// The word shown beside the icon.
  final String label;

  /// The reinforcing icon.
  final IconData icon;

  /// The state colour.
  final Color color;
}
