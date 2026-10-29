import 'package:flutter/material.dart';

import '../../../../app/design/sc_metrics.dart';
import '../../../../app/design/sportcut_tokens.dart';
import '../../../library/presentation/match_list_entry.dart';
import '../../domain/pipeline_stage.dart';
import 'studio_chrome.dart';

/// The status bar along the bottom of the studio.
class StudioStatusBar extends StatelessWidget {
  /// Build the status bar.
  const StudioStatusBar({
    super.key,
    required this.videoCount,
    required this.missingCount,
    required this.entry,
    required this.stage,
    required this.facts,
  });

  /// How many videos the workspace holds.
  final int videoCount;

  /// How many of those videos have no readable recording.
  final int missingCount;

  /// The selected video, or null when none is chosen.
  final MatchListEntry? entry;

  /// The selected feature, where null means playback.
  final PipelineStage? stage;

  /// Stage facts for the selected video, or null while loading.
  final VideoStageFacts? facts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = SportcutTokens.of(context);
    final score = entry?.score;
    final statusStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final ready = facts?.hasSelectedClips;
    final String readyLabel;
    if (ready == null) {
      readyLabel = 'Checking';
    } else if (ready) {
      readyLabel = 'Ready to export';
    } else {
      readyLabel = 'Needs a clip';
    }
    return Container(
      height: ScMetrics.statusHeight,
      padding: EdgeInsets.symmetric(horizontal: tokens.space3),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: tokens.space1 + 2),
          Text('On-device · No cloud', style: statusStyle),
          SizedBox(width: tokens.space3),
          Text(
            '$videoCount ${videoCount == 1 ? 'video' : 'videos'}',
            style: statusStyle,
          ),
          if (missingCount > 0) ...<Widget>[
            SizedBox(width: tokens.space3),
            Text(
              '$missingCount missing',
              style: statusStyle?.copyWith(color: scheme.error),
            ),
          ],
          const Spacer(),
          if (score != null) ...<Widget>[
            Text(
              'Score ${score.left}–${score.right}',
              style: statusStyle,
            ),
            SizedBox(width: tokens.space3),
          ],
          Text(
            entry == null ? 'No video selected' : (stage?.label ?? 'Playback'),
            style: statusStyle,
          ),
          SizedBox(width: tokens.space2),
          if (entry != null) StudioChip(label: readyLabel),
        ],
      ),
    );
  }
}
