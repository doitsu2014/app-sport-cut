import 'package:flutter/material.dart';

import 'sportcut_tokens.dart';

/// The elevation vocabulary from `tokens.css`.
///
/// A surface is either flat, ringed with a hairline, or raised. The focus ring
/// is a separate, theme-aware treatment.
abstract final class ScElevation {
  /// No shadow.
  static const List<BoxShadow> flat = <BoxShadow>[];

  /// A 1 px hairline ring in [border].
  static BoxShadow ring(Color border) {
    return BoxShadow(color: border, spreadRadius: 1);
  }

  /// The light-theme raised shadow.
  static final List<BoxShadow> raisedLight = <BoxShadow>[
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 40,
      offset: const Offset(0, 16),
    ),
  ];

  /// The dark-theme raised shadow.
  static final List<BoxShadow> raisedDark = <BoxShadow>[
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.50),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.45),
      blurRadius: 44,
      offset: const Offset(0, 18),
    ),
  ];
}

/// The 2 px surface gap plus 2 px accent ring from `--focus-ring`.
abstract final class ScFocusRing {
  /// A focus-ring decoration for the current palette.
  ///
  /// The accent shadow is listed first because Flutter paints later shadows
  /// on top: the surface shadow then covers the inner two pixels and leaves a
  /// two-pixel accent ring.
  static BoxDecoration decoration(SportcutPalette palette) {
    return BoxDecoration(
      boxShadow: <BoxShadow>[
        BoxShadow(color: palette.accent, spreadRadius: 4),
        BoxShadow(color: palette.surface, spreadRadius: 2),
      ],
    );
  }

  /// Draw the ring over [child] while [focused], without moving the layout.
  ///
  /// The ring is painted outside the child's bounds, so no padding is added
  /// and the control keeps its measured size. Use this for any pressable the
  /// design layer owns; it is the only way to get the two-pixel surface gap,
  /// because a `BorderSide` can only draw one colour.
  static Widget overlay({
    required SportcutPalette palette,
    required bool focused,
    required Widget child,
  }) {
    if (!focused) {
      return child;
    }
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: decoration(palette),
            ),
          ),
        ),
      ],
    );
  }

  /// A fallback focus treatment for Material widgets the design layer does
  /// not own.
  ///
  /// A `BorderSide` can draw only one colour, so this is a two-pixel accent
  /// border without the surface gap. Design-layer components use [overlay].
  static ButtonStyle style(
    SportcutPalette palette, {
    BorderRadius? borderRadius,
  }) {
    final OutlinedBorder? shape = borderRadius == null
        ? null
        : RoundedRectangleBorder(borderRadius: borderRadius);
    return ButtonStyle(
      side: WidgetStateProperty.resolveWith<BorderSide?>((states) {
        if (states.contains(WidgetState.focused)) {
          return BorderSide(color: palette.accent, width: 2);
        }
        return null;
      }),
      shape:
          shape == null ? null : WidgetStatePropertyAll<OutlinedBorder?>(shape),
    );
  }
}
