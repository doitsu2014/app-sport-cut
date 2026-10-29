import 'package:flutter/material.dart';

import '../sc_overlay_colors.dart';
import '../sc_tints.dart';
import '../sc_typography.dart';
import '../sportcut_tokens.dart';

/// The ink opacity for rally metadata and side labels.
const double _metaInkAlpha = 0.58;

/// The ink opacity for the timecode.
const double _timecodeInkAlpha = 0.86;

/// The ink opacity for the score colon.
const double _colonInkAlpha = 0.38;

/// The signal opacity for the serving pill border.
const double _pillBorderAlpha = 0.42;

/// The in-frame score overlay drawn over footage.
///
/// The bug uses the fixed overlay ink and signal in both themes (ADR-0003
/// D16); it is footage chrome, not UI chrome. It never animates a score: the
/// digits change in place, so the eye can compare them between rallies.
class ScScoreBug extends StatelessWidget {
  /// Build the score bug for the current rally.
  const ScScoreBug({
    super.key,
    required this.rallyIndex,
    required this.rallyTotal,
    required this.leftScore,
    required this.rightScore,
    required this.leftLabel,
    required this.rightLabel,
    required this.servingLeft,
    required this.timecode,
    this.live = false,
  });

  /// The one-based index of the current rally.
  final int rallyIndex;

  /// How many rallies the match has.
  final int rallyTotal;

  /// The left side's score.
  final int leftScore;

  /// The right side's score.
  final int rightScore;

  /// The label for the left side, for example `L · Left side`.
  final String leftLabel;

  /// The label for the right side, for example `R · Right side`.
  final String rightLabel;

  /// Whether the left side is serving.
  final bool servingLeft;

  /// The match timecode shown beside the live marker.
  final String timecode;

  /// Whether the live marker is shown.
  final bool live;

  @override
  Widget build(BuildContext context) {
    final typography = SportcutTypography.of(context);
    final tokens = SportcutTokens.of(context);
    const ink = ScOverlayColors.ink;
    final servingLabel = servingLeft ? leftLabel : rightLabel;
    final summary = 'Rally $rallyIndex of $rallyTotal. '
        '$leftLabel $leftScore, $rightLabel $rightScore. '
        '$servingLabel serving. $timecode${live ? ', live' : ''}.';

    return Semantics(
      container: true,
      label: summary,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                ScTints.scrim(ScOverlayColors.bed),
                ScOverlayColors.bed.withValues(alpha: 0),
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.space5,
              vertical: tokens.space4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'RALLY $rallyIndex / $rallyTotal',
                      style: typography.chrome9.copyWith(
                        color: ink.withValues(alpha: _metaInkAlpha),
                      ),
                    ),
                    const Spacer(),
                    if (live) ...<Widget>[
                      _LiveDot(size: tokens.space2 - tokens.space1 / 2),
                      SizedBox(width: tokens.space1),
                    ],
                    Text(
                      timecode,
                      style: SportcutTypography.withTabular(
                        typography.timecode11,
                      ).copyWith(
                        color: ink.withValues(alpha: _timecodeInkAlpha),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.space3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: _BugSide(
                        label: leftLabel,
                        score: leftScore,
                        serving: servingLeft,
                        alignEnd: false,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: tokens.space3,
                      ),
                      child: Text(
                        ':',
                        style: typography.title24.copyWith(
                          color: ink.withValues(alpha: _colonInkAlpha),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _BugSide(
                        label: rightLabel,
                        score: rightScore,
                        serving: !servingLeft,
                        alignEnd: true,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.space2),
                Row(
                  children: <Widget>[
                    _ServePill(label: 'Serve $servingLabel'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One labelled score in the bug.
class _BugSide extends StatelessWidget {
  const _BugSide({
    required this.label,
    required this.score,
    required this.serving,
    required this.alignEnd,
  });

  final String label;
  final int score;
  final bool serving;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final typography = SportcutTypography.of(context);
    final tokens = SportcutTokens.of(context);
    const ink = ScOverlayColors.ink;
    final scoreStyle = SportcutTypography.withTabular(
      typography.score64,
    ).copyWith(color: ink);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: typography.chrome9.copyWith(
            color: serving
                ? ScOverlayColors.signal
                : ink.withValues(alpha: _metaInkAlpha),
          ),
        ),
        SizedBox(height: tokens.space2),
        Container(
          padding: EdgeInsets.only(bottom: tokens.space1),
          decoration: serving
              ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: ScOverlayColors.signal,
                      width: tokens.space1 / 2,
                    ),
                  ),
                )
              : null,
          child: Text('$score', style: scoreStyle),
        ),
      ],
    );
  }
}

/// The pill that names the serving side in words.
class _ServePill extends StatelessWidget {
  const _ServePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final typography = SportcutTypography.of(context);
    final tokens = SportcutTokens.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space2,
        vertical: tokens.space1,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        border: Border.all(
          color: ScOverlayColors.signal.withValues(alpha: _pillBorderAlpha),
        ),
      ),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: typography.chrome9.copyWith(color: ScOverlayColors.signal),
      ),
    );
  }
}

/// The six-pixel live marker.
class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: ScOverlayColors.liveDot,
        shape: BoxShape.circle,
      ),
    );
  }
}
