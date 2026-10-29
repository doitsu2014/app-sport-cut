import 'package:flutter/material.dart';

import '../../../app/design/components/sc_panel.dart';
import '../../../app/design/components/sc_pressable.dart';
import '../../../app/design/sc_typography.dart';
import '../../../app/design/sportcut_tokens.dart';
import '../../editing/domain/rally.dart';
import '../../editing/domain/score_event.dart';
import '../../editing/domain/score_timeline.dart';
import '../../library/presentation/formatters.dart';

/// The last three confirmed rallies and the score each one produced.
///
/// This is a compact recap, not the working list: every rally remains in the
/// [RallyPanel]'s full list. The widget is data-in / callback-out.
class LastRalliesPanel extends StatelessWidget {
  /// Build the recap for [rallies].
  const LastRalliesPanel({
    super.key,
    required this.rallies,
    required this.score,
    this.onSelect,
  });

  /// How many confirmed rallies the recap shows.
  static const int limit = 3;

  /// The match's rallies, in recording order.
  final List<Rally> rallies;

  /// The score derived from the confirmed rallies.
  final ScoreTimeline score;

  /// Selects a rally, when the caller wants the recap to be interactive.
  final ValueChanged<Rally>? onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final select = onSelect;

    final confirmed = <({int number, Rally rally, ScoreEvent event})>[];
    for (var index = 0; index < rallies.length; index++) {
      final rally = rallies[index];
      final event = score.atRally(rally.id);
      if (rally.isScored && event != null) {
        confirmed.add((number: index + 1, rally: rally, event: event));
      }
    }
    final recent = confirmed.length <= limit
        ? confirmed
        : confirmed.sublist(confirmed.length - limit);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ScSectionHeader(label: 'Last rallies', count: recent.length),
        if (recent.isEmpty)
          Text(
            'Confirmed rallies appear here.',
            style: typography.xs12.copyWith(color: palette.muted),
          )
        else
          for (final entry in recent.reversed)
            ScPressable(
              onTap: select == null ? null : () => select(entry.rally),
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              padding: EdgeInsets.symmetric(
                horizontal: tokens.space2,
                vertical: tokens.space1,
              ),
              child: Row(
                children: <Widget>[
                  Text(
                    '${entry.number}',
                    style: typography.timecode11.copyWith(
                      color: palette.muted,
                    ),
                  ),
                  SizedBox(width: tokens.space2),
                  Text(
                    formatDuration(entry.rally.startSeconds),
                    style: typography.timecode11.copyWith(color: palette.fg2),
                  ),
                  const Spacer(),
                  Text(
                    '${entry.event.leftScore}–${entry.event.rightScore}',
                    style: SportcutTypography.withTabular(typography.timecode11)
                        .copyWith(color: palette.fg),
                  ),
                  SizedBox(width: tokens.space2),
                  Text(
                    entry.rally.winnerSide == WinnerSide.left ? 'L' : 'R',
                    style: typography.xs12.copyWith(
                      color: palette.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
