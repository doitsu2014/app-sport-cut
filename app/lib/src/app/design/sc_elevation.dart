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
  /// Draw the ring over [child] while [focused], without moving the layout.
  ///
  /// The ring is painted outside the child's bounds, so no padding is added
  /// and the control keeps its measured size. A [BoxShadow] cannot be used:
  /// it fills the whole box with its colour before blurring, which would
  /// cover the child. This paints two strokes instead — [palette.surface]
  /// from the edge to two pixels, [palette.accent] from two to four.
  static Widget overlay({
    required SportcutPalette palette,
    required bool focused,
    required Widget child,
    BorderRadius? borderRadius,
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
            child: CustomPaint(
              painter: _FocusRingPainter(palette, borderRadius),
            ),
          ),
        ),
      ],
    );
  }

  /// The focus decoration as a box decoration, for widgets that can host one.
  ///
  /// Prefer [overlay]: a decorated box needs four pixels of padding to show
  /// the ring, which changes layout.
  static BoxDecoration decoration(
    SportcutPalette palette, {
    BorderRadius? borderRadius,
  }) {
    return BoxDecoration(
      borderRadius: borderRadius,
      boxShadow: <BoxShadow>[
        BoxShadow(color: palette.accent, spreadRadius: 2),
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

/// Paints the focus ring outside its box: surface from 0–2 px, accent 2–4 px.
class _FocusRingPainter extends CustomPainter {
  const _FocusRingPainter(this.palette, this.borderRadius);

  final SportcutPalette palette;
  final BorderRadius? borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect base = RRect.fromRectAndRadius(
      Offset.zero & size,
      borderRadius?.topLeft ?? Radius.zero,
    );
    final Paint paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas
      ..drawRRect(base.inflate(1), paint..color = palette.surface)
      ..drawRRect(base.inflate(3), paint..color = palette.accent);
  }

  @override
  bool shouldRepaint(_FocusRingPainter oldDelegate) {
    return oldDelegate.palette != palette ||
        oldDelegate.borderRadius != borderRadius;
  }
}
