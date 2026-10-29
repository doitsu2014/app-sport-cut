import 'package:flutter/material.dart';

/// Derived surface tints.
///
/// Every value is a `Color.alphaBlend` over a palette colour, so the design
/// layer owns no extra hex values and both themes resolve correctly.
abstract final class ScTints {
  /// An unkept rally segment.
  static Color rally(Color accent, Color surface) {
    return Color.alphaBlend(accent.withValues(alpha: 0.22), surface);
  }

  /// A kept rally segment.
  static Color kept(Color accent, Color surface) {
    return Color.alphaBlend(accent.withValues(alpha: 0.32), surface);
  }

  /// A kept rally segment under the pointer.
  static Color keptHover(Color accent, Color surface) {
    return Color.alphaBlend(accent.withValues(alpha: 0.42), surface);
  }

  /// A pressed toolbar tool.
  static Color pressedTool(Color fg) {
    return fg.withValues(alpha: 0.12);
  }

  /// The toolbar surface, lightly mixed toward the page ground.
  static Color toolbarSurface(Color surface, Color bg) {
    return Color.alphaBlend(surface.withValues(alpha: 0.94), bg);
  }

  /// The rail surface, mixed toward the page ground.
  static Color railSurface(Color surface, Color bg) {
    return Color.alphaBlend(surface.withValues(alpha: 0.96), bg);
  }

  /// The scrim over the footage bed.
  static Color scrim(Color bed) {
    return bed.withValues(alpha: 0.44);
  }
}
