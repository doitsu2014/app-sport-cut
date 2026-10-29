import 'package:flutter/widgets.dart';

/// The studio's motion policy.
///
/// Transitions are decoration: pressing, hovering, opening a sheet, or moving a
/// toast. When the platform asks for reduced motion
/// ([MediaQueryData.disableAnimations]) they collapse to zero. The media that
/// must never animate — the score bug, the scrubber, and the video frame — do
/// not use this helper because they never transition at all (FR-SHL-36).
abstract final class ScMotion {
  /// [base] unless the platform asked for reduced motion.
  static Duration duration(BuildContext context, Duration base) {
    return reduced(context) ? Duration.zero : base;
  }

  /// Whether the platform asked for reduced motion.
  static bool reduced(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }
}
