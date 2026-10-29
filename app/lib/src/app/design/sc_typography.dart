import 'package:flutter/material.dart';

import 'sportcut_tokens.dart';

const String _displayFamily = 'Archivo';
const String _bodyFamily = 'IBMPlexSans';
const String _monoFamily = 'IBMPlexMono';

const List<FontFeature> _tabularFigures = <FontFeature>[
  FontFeature.tabularFigures(),
];

TextStyle _display(
  double size,
  double height,
  FontWeight weight, {
  required Color color,
  double tracking = -0.025,
}) {
  return TextStyle(
    fontFamily: _displayFamily,
    fontSize: size,
    height: height,
    fontWeight: weight,
    letterSpacing: size * tracking,
    fontFeatures: _tabularFigures,
    fontVariations: <FontVariation>[
      FontVariation('wght', weight.value.toDouble()),
    ],
    color: color,
  );
}

TextStyle _body(
  double size,
  double height,
  FontWeight weight, {
  required Color color,
  double letterSpacing = 0,
}) {
  return TextStyle(
    fontFamily: _bodyFamily,
    fontSize: size,
    height: height,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    fontVariations: <FontVariation>[
      FontVariation('wght', weight.value.toDouble()),
    ],
    color: color,
  );
}

TextStyle _mono(
  double size,
  double height,
  FontWeight weight, {
  required Color color,
  double letterSpacing = 0,
  bool tabular = false,
}) {
  return TextStyle(
    fontFamily: _monoFamily,
    fontSize: size,
    height: height,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    fontFeatures: tabular ? _tabularFigures : null,
    color: color,
  );
}

/// The studio type scale, mirroring `tokens.css` and `studio.html`.
///
/// Archivo carries the display and score roles; IBM Plex Sans carries body,
/// lead, controls, and captions; IBM Plex Mono carries micro-labels, chrome,
/// and timecodes. IBM Plex Mono is capped at the bundled 400 and 500 weights
/// (ADR-0003 D18).
@immutable
class SportcutTypography extends ThemeExtension<SportcutTypography> {
  /// Build a scale.
  const SportcutTypography({
    required this.display64,
    required this.display44,
    required this.display32,
    required this.title24,
    required this.title20,
    required this.lead18,
    required this.body16,
    required this.sm14,
    required this.xs12,
    required this.micro10,
    required this.chrome9,
    required this.timecode11,
    required this.score48,
    required this.score52,
    required this.score64,
    required this.score76,
  });

  /// 64 px reference display.
  final TextStyle display64;

  /// 44 px hero.
  final TextStyle display44;

  /// 32 px screen title.
  final TextStyle display32;

  /// 24 px panel title.
  final TextStyle title24;

  /// 20 px clip heading.
  final TextStyle title20;

  /// 18 px lead paragraph.
  final TextStyle lead18;

  /// 16 px body floor.
  final TextStyle body16;

  /// 14 px control and rail metadata.
  final TextStyle sm14;

  /// 12 px caption and chip.
  final TextStyle xs12;

  /// 10 px micro-label. Callers render it uppercase.
  final TextStyle micro10;

  /// 9 px dense chrome and overlay label. Callers render it uppercase.
  final TextStyle chrome9;

  /// 11 px tabular timecode.
  final TextStyle timecode11;

  /// 48 px tabular score.
  final TextStyle score48;

  /// 52 px tabular score.
  final TextStyle score52;

  /// 64 px tabular score.
  final TextStyle score64;

  /// 76 px tabular score.
  final TextStyle score76;

  /// Build the scale for [palette], so the text carries the theme's ink.
  factory SportcutTypography.fromPalette(SportcutPalette palette) {
    final ink = palette.fg;
    return SportcutTypography(
      display64: _display(
        64,
        1.0,
        FontWeight.w700,
        color: ink,
        tracking: -0.035,
      ),
      display44: _display(
        44,
        1.06,
        FontWeight.w700,
        color: ink,
        tracking: -0.03,
      ),
      display32: _display(32, 1.12, FontWeight.w700, color: ink),
      title24: _display(
        24,
        1.2,
        FontWeight.w600,
        color: ink,
        tracking: -0.02,
      ),
      title20: _display(
        20,
        1.2,
        FontWeight.w700,
        color: ink,
        tracking: -0.02,
      ),
      lead18: _body(18, 1.5, FontWeight.w400, color: ink),
      body16: _body(16, 1.55, FontWeight.w400, color: ink),
      sm14: _body(14, 1.45, FontWeight.w400, color: ink),
      xs12: _body(12, 1.35, FontWeight.w500, color: ink),
      micro10: _mono(
        10,
        1.35,
        FontWeight.w500,
        color: ink,
        letterSpacing: 0.8,
      ),
      chrome9: _mono(
        9,
        1.35,
        FontWeight.w500,
        color: ink,
        letterSpacing: 1.0,
      ),
      timecode11: _mono(
        11,
        1.35,
        FontWeight.w500,
        color: ink,
        tabular: true,
      ),
      score48: _display(
        48,
        0.86,
        FontWeight.w700,
        color: ink,
        tracking: -0.04,
      ),
      score52: _display(
        52,
        0.86,
        FontWeight.w700,
        color: ink,
        tracking: -0.04,
      ),
      score64: _display(
        64,
        0.86,
        FontWeight.w700,
        color: ink,
        tracking: -0.04,
      ),
      score76: _display(
        76,
        0.86,
        FontWeight.w700,
        color: ink,
        tracking: -0.04,
      ),
    );
  }

  /// The scale for the light theme.
  static final SportcutTypography light = SportcutTypography.fromPalette(
    SportcutPalette.light,
  );

  /// The scale for the dark theme.
  static final SportcutTypography dark = SportcutTypography.fromPalette(
    SportcutPalette.dark,
  );

  /// The typography for the current theme.
  static SportcutTypography of(BuildContext context) {
    return Theme.of(context).extension<SportcutTypography>() ??
        (Theme.of(context).brightness == Brightness.dark ? dark : light);
  }

  /// Returns [style] with tabular figures, so numeric columns keep their width.
  static TextStyle withTabular(TextStyle style) {
    return style.copyWith(
      fontFeatures: <FontFeature>[
        const FontFeature.tabularFigures(),
        ...?style.fontFeatures,
      ],
    );
  }

  @override
  SportcutTypography copyWith({
    TextStyle? display64,
    TextStyle? display44,
    TextStyle? display32,
    TextStyle? title24,
    TextStyle? title20,
    TextStyle? lead18,
    TextStyle? body16,
    TextStyle? sm14,
    TextStyle? xs12,
    TextStyle? micro10,
    TextStyle? chrome9,
    TextStyle? timecode11,
    TextStyle? score48,
    TextStyle? score52,
    TextStyle? score64,
    TextStyle? score76,
  }) {
    return SportcutTypography(
      display64: display64 ?? this.display64,
      display44: display44 ?? this.display44,
      display32: display32 ?? this.display32,
      title24: title24 ?? this.title24,
      title20: title20 ?? this.title20,
      lead18: lead18 ?? this.lead18,
      body16: body16 ?? this.body16,
      sm14: sm14 ?? this.sm14,
      xs12: xs12 ?? this.xs12,
      micro10: micro10 ?? this.micro10,
      chrome9: chrome9 ?? this.chrome9,
      timecode11: timecode11 ?? this.timecode11,
      score48: score48 ?? this.score48,
      score52: score52 ?? this.score52,
      score64: score64 ?? this.score64,
      score76: score76 ?? this.score76,
    );
  }

  @override
  SportcutTypography lerp(ThemeExtension<SportcutTypography>? other, double t) {
    if (other is! SportcutTypography) {
      return this;
    }
    return SportcutTypography(
      display64: TextStyle.lerp(display64, other.display64, t)!,
      display44: TextStyle.lerp(display44, other.display44, t)!,
      display32: TextStyle.lerp(display32, other.display32, t)!,
      title24: TextStyle.lerp(title24, other.title24, t)!,
      title20: TextStyle.lerp(title20, other.title20, t)!,
      lead18: TextStyle.lerp(lead18, other.lead18, t)!,
      body16: TextStyle.lerp(body16, other.body16, t)!,
      sm14: TextStyle.lerp(sm14, other.sm14, t)!,
      xs12: TextStyle.lerp(xs12, other.xs12, t)!,
      micro10: TextStyle.lerp(micro10, other.micro10, t)!,
      chrome9: TextStyle.lerp(chrome9, other.chrome9, t)!,
      timecode11: TextStyle.lerp(timecode11, other.timecode11, t)!,
      score48: TextStyle.lerp(score48, other.score48, t)!,
      score52: TextStyle.lerp(score52, other.score52, t)!,
      score64: TextStyle.lerp(score64, other.score64, t)!,
      score76: TextStyle.lerp(score76, other.score76, t)!,
    );
  }
}
