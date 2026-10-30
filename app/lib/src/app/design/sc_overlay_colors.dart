import 'package:flutter/material.dart';

/// The fixed colours drawn over footage.
///
/// These do not follow the theme: the preview is always dark because it is a
/// video bed (ADR-0003 D13 and D16).
abstract final class ScOverlayColors {
  /// The stage bed. ADR-0003 D16 fixes this value and supersedes the
  /// `#0A0F0C` wording in earlier design/BRD text.
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

  /// The calibration scrim: dark enough that chalk markings hold 3:1 over
  /// footage, inside the design contract's 32-56 % range. It uses the fixed
  /// stage bed from ADR-0003 D16, not the superseded `#0A0F0C` value.
  static Color get calibrationScrim => bed.withValues(alpha: 0.52);
}
