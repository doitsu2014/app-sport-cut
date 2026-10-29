import 'package:flutter/material.dart';

/// The Sportcut palette, mirroring `tokens.css`.
///
/// Colors live here rather than in a seed because the system needs a cool
/// chalk ground, a graphite studio ground, and explicit borders — none of
/// which a Material 3 seed derives on its own.
@immutable
class SportcutPalette extends ThemeExtension<SportcutPalette> {
  /// Build one palette.
  const SportcutPalette({
    required this.bg,
    required this.surface,
    required this.surfaceWarm,
    required this.fg,
    required this.fg2,
    required this.muted,
    required this.meta,
    required this.border,
    required this.borderSoft,
    required this.controlBorder,
    required this.accent,
    required this.accentOn,
    required this.accentHover,
    required this.accentActive,
    required this.success,
    required this.warn,
    required this.danger,
  });

  /// Page ground.
  final Color bg;

  /// Raised surface.
  final Color surface;

  /// Recessed surface.
  final Color surfaceWarm;

  /// Primary text.
  final Color fg;

  /// Secondary text.
  final Color fg2;

  /// Supporting text.
  final Color muted;

  /// Strong metadata.
  final Color meta;

  /// Divider and control border.
  final Color border;

  /// Hairline.
  final Color borderSoft;

  /// Outline of an interactive control.
  ///
  /// Unlike [border], which is a decorative hairline, this outline must reach
  /// the 3:1 non-text contrast floor against every surface it can sit on
  /// (FR-SHL-32). Use it for inputs, checkboxes, selects, and secondary
  /// button and selection outlines.
  final Color controlBorder;

  /// The single signal color.
  final Color accent;

  /// Text on the signal.
  final Color accentOn;

  /// Signal under the pointer.
  final Color accentHover;

  /// Signal while pressed.
  final Color accentActive;

  /// Success state.
  final Color success;

  /// Warning state.
  final Color warn;

  /// Failure state.
  final Color danger;

  /// Cool chalk, low-glare light theme.
  static const SportcutPalette light = SportcutPalette(
    bg: Color(0xFFF1F3EF),
    surface: Color(0xFFFFFFFF),
    surfaceWarm: Color(0xFFE8ECE7),
    fg: Color(0xFF101713),
    fg2: Color(0xFF39443D),
    muted: Color(0xFF5C6860),
    meta: Color(0xFF4A554E),
    border: Color(0xFFC7D0C8),
    borderSoft: Color(0xFFDFE5DF),
    controlBorder: Color(0xFF7E8A81),
    accent: Color(0xFF0E6E45),
    accentOn: Color(0xFFFFFFFF),
    accentHover: Color(0xFF0B603B),
    accentActive: Color(0xFF095433),
    success: Color(0xFF157347),
    warn: Color(0xFF8A5A00),
    danger: Color(0xFFB42318),
  );

  /// Graphite editing booth.
  static const SportcutPalette dark = SportcutPalette(
    bg: Color(0xFF0B100D),
    surface: Color(0xFF121814),
    surfaceWarm: Color(0xFF182019),
    fg: Color(0xFFEDF2EC),
    fg2: Color(0xFFBCC6BE),
    muted: Color(0xFF8B978F),
    meta: Color(0xFFA7B3AA),
    border: Color(0xFF2B342E),
    borderSoft: Color(0xFF1E2721),
    controlBorder: Color(0xFF606C64),
    accent: Color(0xFF46D08D),
    accentOn: Color(0xFF04140C),
    accentHover: Color(0xFF63DEA4),
    accentActive: Color(0xFF7BE6B2),
    success: Color(0xFF57C98F),
    warn: Color(0xFFE3B24E),
    danger: Color(0xFFF27B70),
  );

  /// The palette for the current theme.
  static SportcutPalette of(BuildContext context) {
    return Theme.of(context).extension<SportcutPalette>() ??
        (Theme.of(context).brightness == Brightness.dark ? dark : light);
  }

  @override
  SportcutPalette copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceWarm,
    Color? fg,
    Color? fg2,
    Color? muted,
    Color? meta,
    Color? border,
    Color? borderSoft,
    Color? controlBorder,
    Color? accent,
    Color? accentOn,
    Color? accentHover,
    Color? accentActive,
    Color? success,
    Color? warn,
    Color? danger,
  }) {
    return SportcutPalette(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceWarm: surfaceWarm ?? this.surfaceWarm,
      fg: fg ?? this.fg,
      fg2: fg2 ?? this.fg2,
      muted: muted ?? this.muted,
      meta: meta ?? this.meta,
      border: border ?? this.border,
      borderSoft: borderSoft ?? this.borderSoft,
      controlBorder: controlBorder ?? this.controlBorder,
      accent: accent ?? this.accent,
      accentOn: accentOn ?? this.accentOn,
      accentHover: accentHover ?? this.accentHover,
      accentActive: accentActive ?? this.accentActive,
      success: success ?? this.success,
      warn: warn ?? this.warn,
      danger: danger ?? this.danger,
    );
  }

  @override
  SportcutPalette lerp(ThemeExtension<SportcutPalette>? other, double t) {
    if (other is! SportcutPalette) {
      return this;
    }
    return SportcutPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceWarm: Color.lerp(surfaceWarm, other.surfaceWarm, t)!,
      fg: Color.lerp(fg, other.fg, t)!,
      fg2: Color.lerp(fg2, other.fg2, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      meta: Color.lerp(meta, other.meta, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSoft: Color.lerp(borderSoft, other.borderSoft, t)!,
      controlBorder: Color.lerp(controlBorder, other.controlBorder, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentOn: Color.lerp(accentOn, other.accentOn, t)!,
      accentHover: Color.lerp(accentHover, other.accentHover, t)!,
      accentActive: Color.lerp(accentActive, other.accentActive, t)!,
      success: Color.lerp(success, other.success, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

/// Fixed values the color scheme cannot carry: spacing, shape, motion, and
/// the footage overlay colours.
@immutable
class SportcutTokens extends ThemeExtension<SportcutTokens> {
  /// Build the token set.
  const SportcutTokens({
    required this.overlayBed,
    required this.overlayInk,
    required this.overlaySignal,
    required this.space1,
    required this.space2,
    required this.space3,
    required this.space4,
    required this.space5,
    required this.space6,
    required this.space8,
    required this.space12,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusPill,
    required this.motionFast,
    required this.motionBase,
  });

  /// Footage bed for overlays.
  final Color overlayBed;

  /// Chalk on footage.
  final Color overlayInk;

  /// Signal on footage.
  final Color overlaySignal;

  /// 4.
  final double space1;

  /// 8.
  final double space2;

  /// 12.
  final double space3;

  /// 16.
  final double space4;

  /// 20.
  final double space5;

  /// 24.
  final double space6;

  /// 32.
  final double space8;

  /// 48.
  final double space12;

  /// 6.
  final double radiusSm;

  /// 10.
  final double radiusMd;

  /// 14.
  final double radiusLg;

  /// Pills.
  final double radiusPill;

  /// 120ms.
  final Duration motionFast;

  /// 180ms.
  final Duration motionBase;

  /// Tokens for the light theme.
  static const SportcutTokens light = SportcutTokens(
    overlayBed: Color(0xFF050806),
    overlayInk: Color(0xFFF2F5F0),
    overlaySignal: Color(0xFF46D08D),
    space1: 4,
    space2: 8,
    space3: 12,
    space4: 16,
    space5: 20,
    space6: 24,
    space8: 32,
    space12: 48,
    radiusSm: 6,
    radiusMd: 10,
    radiusLg: 14,
    radiusPill: 9999,
    motionFast: Duration(milliseconds: 120),
    motionBase: Duration(milliseconds: 180),
  );

  /// Tokens for the dark theme.
  ///
  /// Spacing, shape, motion, and the footage overlay are fixed, so the two
  /// token sets are identical today.
  static const SportcutTokens dark = light;

  /// The tokens for the current theme.
  static SportcutTokens of(BuildContext context) {
    return Theme.of(context).extension<SportcutTokens>() ??
        (Theme.of(context).brightness == Brightness.dark ? dark : light);
  }

  @override
  SportcutTokens copyWith({
    Color? overlayBed,
    Color? overlayInk,
    Color? overlaySignal,
    double? space1,
    double? space2,
    double? space3,
    double? space4,
    double? space5,
    double? space6,
    double? space8,
    double? space12,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusPill,
    Duration? motionFast,
    Duration? motionBase,
  }) {
    return SportcutTokens(
      overlayBed: overlayBed ?? this.overlayBed,
      overlayInk: overlayInk ?? this.overlayInk,
      overlaySignal: overlaySignal ?? this.overlaySignal,
      space1: space1 ?? this.space1,
      space2: space2 ?? this.space2,
      space3: space3 ?? this.space3,
      space4: space4 ?? this.space4,
      space5: space5 ?? this.space5,
      space6: space6 ?? this.space6,
      space8: space8 ?? this.space8,
      space12: space12 ?? this.space12,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusPill: radiusPill ?? this.radiusPill,
      motionFast: motionFast ?? this.motionFast,
      motionBase: motionBase ?? this.motionBase,
    );
  }

  @override
  SportcutTokens lerp(ThemeExtension<SportcutTokens>? other, double t) {
    if (other is! SportcutTokens) {
      return this;
    }
    return SportcutTokens(
      overlayBed: Color.lerp(overlayBed, other.overlayBed, t)!,
      overlayInk: Color.lerp(overlayInk, other.overlayInk, t)!,
      overlaySignal: Color.lerp(overlaySignal, other.overlaySignal, t)!,
      space1: _lerp(space1, other.space1, t),
      space2: _lerp(space2, other.space2, t),
      space3: _lerp(space3, other.space3, t),
      space4: _lerp(space4, other.space4, t),
      space5: _lerp(space5, other.space5, t),
      space6: _lerp(space6, other.space6, t),
      space8: _lerp(space8, other.space8, t),
      space12: _lerp(space12, other.space12, t),
      radiusSm: _lerp(radiusSm, other.radiusSm, t),
      radiusMd: _lerp(radiusMd, other.radiusMd, t),
      radiusLg: _lerp(radiusLg, other.radiusLg, t),
      radiusPill: _lerp(radiusPill, other.radiusPill, t),
      motionFast: t < 0.5 ? motionFast : other.motionFast,
      motionBase: t < 0.5 ? motionBase : other.motionBase,
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}
