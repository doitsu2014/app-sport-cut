import 'package:flutter/material.dart';

import '../../../../app/design/sc_metrics.dart';
import '../../../../app/design/sc_typography.dart';
import '../../../../app/design/sportcut_tokens.dart';

/// The 30 px status bar at the bottom of the home screen.
///
/// It carries the local-only promise on the left and what the library holds on
/// the right: the workspace count, the video count, and a missing recording
/// count only when there is one.
class HomeStatusBar extends StatelessWidget {
  /// Build the home status bar.
  const HomeStatusBar({
    super.key,
    required this.workspaceCount,
    required this.videoCount,
    required this.missingCount,
  });

  /// How many workspaces the library holds.
  final int workspaceCount;

  /// How many videos those workspaces hold.
  final int videoCount;

  /// How many of those videos have no readable recording.
  final int missingCount;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final style = typography.micro10.copyWith(color: palette.muted);
    final workspaceLabel =
        workspaceCount == 1 ? '1 workspace' : '$workspaceCount workspaces';
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
          Text('$workspaceLabel · $videoLabel', style: style),
          if (missingCount > 0) ...<Widget>[
            Text(' · ', style: style),
            Text(
              missingLabel,
              style: style.copyWith(color: palette.danger),
            ),
          ],
          const Spacer(),
        ],
      ),
    );
  }
}
