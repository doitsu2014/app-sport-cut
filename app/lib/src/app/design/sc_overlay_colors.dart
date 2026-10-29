import 'package:flutter/material.dart';

/// The fixed colours drawn over footage.
///
/// These do not follow the theme: the preview is always dark because it is a
/// video bed (ADR-0003 D13 and D16).
abstract final class ScOverlayColors {
  /// The stage bed.
  static const Color bed = Color(0xFF050806);

  /// Chalk on footage.
  static const Color ink = Color(0xFFF2F5F0);

  /// Signal on footage.
  static const Color signal = Color(0xFF46D08D);

  /// A live dot.
  static const Color liveDot = signal;

  /// The library thumbnail bed: a muted court green, not UI chrome.
  static const Color thumbnailBed = Color(0xFF0C3B2A);

  /// The scrim over the bed.
  static Color get scrim => bed.withValues(alpha: 0.44);
}
