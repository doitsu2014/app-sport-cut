import 'package:flutter/material.dart';

import '../../../../app/design/sc_metrics.dart';
import '../../../../app/design/sc_typography.dart';
import '../../../../app/design/sportcut_tokens.dart';
import '../../../library/presentation/match_list_entry.dart';
import '../../domain/pipeline_stage.dart';

/// The 30 px status bar along the bottom of the studio.
///
/// The left side carries the on-device promise and the video counts; the right
/// side carries the current score and export readiness. Readiness is sentence
/// case — `Checking`, `Ready to export`, `Needs a clip` — because the uppercase
/// READY/ANALYZING vocabulary belongs to the stage strip (FR-SHL-14).
class StudioStatusBar extends StatelessWidget {
  /// Build the status bar.
  const StudioStatusBar({
    super.key,
    required this.videoCount,
    required this.missingCount,
    required this.entry,
    required this.facts,
    required this.stageLabel,
  });

  /// How many videos the workspace holds.
  final int videoCount;

  /// How many of those videos have no readable recording.
  final int missingCount;

  /// The selected video, or null when none is chosen.
  final MatchListEntry? entry;

  /// Stage facts for the selected video, or null while loading.
  final VideoStageFacts? facts;

  /// The selected stage's compact label, where Play is the shared preview.
  final String stageLabel;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final style = typography.micro10.copyWith(color: palette.muted);
    final scoreStyle = SportcutTypography.withTabular(
      style.copyWith(color: palette.fg2),
    );
    final score = entry?.score;
    final ready = facts?.hasSelectedClips;
    final String readyLabel;
    if (ready == null) {
      readyLabel = 'Checking';
    } else if (ready) {
      readyLabel = 'Ready to export';
    } else {
      readyLabel = 'Needs a clip';
    }
    final videoLabel = videoCount == 1 ? '1 video' : '$videoCount videos';
    final missingLabel =
        missingCount == 1 ? '1 missing' : '$missingCount missing';
    final dot = tokens.space1 + tokens.space1 / 4;

    return Container(
      constraints: const BoxConstraints(minHeight: ScMetrics.statusHeight),
      padding: EdgeInsets.symmetric(horizontal: tokens.space3),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(
              color: palette.accent,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: tokens.space1 + tokens.space1 / 2),
          Text('On-device · No cloud', style: style),
          SizedBox(width: tokens.space3),
          Text('$videoLabel · ', style: style),
          Text(
            missingLabel,
            style: style.copyWith(
              color: missingCount > 0 ? palette.danger : palette.muted,
            ),
          ),
          const Spacer(),
          if (score != null) ...<Widget>[
            Text(
              'Score ${score.left}–${score.right}',
              style: scoreStyle,
            ),
            SizedBox(width: tokens.space3),
          ],
          if (entry != null) ...<Widget>[
            Text(
              readyLabel,
              style: style.copyWith(
                color: ready == true ? palette.accent : palette.muted,
              ),
            ),
            SizedBox(width: tokens.space1 + tokens.space1 / 2),
            Flexible(
              child: Text(
                '· $stageLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style.copyWith(color: palette.fg2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
