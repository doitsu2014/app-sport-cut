import 'package:flutter/material.dart';

import '../../../../app/design/components/sc_actions.dart';
import '../../../../app/design/components/sc_pressable.dart';
import '../../../../app/design/sc_icons.dart';
import '../../../../app/design/sc_metrics.dart';
import '../../../../app/design/sc_typography.dart';
import '../../../../app/design/sportcut_tokens.dart';
import 'workspace_summary.dart';

/// The month names used by the row's one-line date.
const List<String> _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// A workspace in the home list.
///
/// The whole row is an [ScPressable], so hover, press, focus, and the selected
/// state all come from the studio's interaction language rather than Material's
/// list defaults. The delete action sits beside the pressable surface rather
/// than inside it, so a row never contains two nested buttons.
class WorkspaceRow extends StatelessWidget {
  /// Build a workspace row.
  const WorkspaceRow({
    super.key,
    required this.summary,
    required this.selected,
    required this.onOpen,
    required this.onDelete,
  });

  /// The workspace and the counts shown in the row.
  final WorkspaceSummary summary;

  /// Whether this is the workspace last opened from the home screen.
  final bool selected;

  /// Open the workspace.
  final VoidCallback onOpen;

  /// Ask to delete the workspace.
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final workspace = summary.workspace;

    return Row(
      children: <Widget>[
        Expanded(
          child: ScPressable(
            selected: selected,
            onTap: onOpen,
            borderRadius: BorderRadius.circular(tokens.radiusMd),
            padding: EdgeInsets.symmetric(
              horizontal: tokens.space3,
              vertical: tokens.space2,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: ScMetrics.rowRich),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    workspace.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.body16.copyWith(
                      color: palette.fg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: tokens.space1 / 2),
                  Text.rich(
                    TextSpan(
                      style: typography.xs12.copyWith(color: palette.muted),
                      children: <InlineSpan>[
                        TextSpan(text: _meta()),
                        if (summary.missingCount > 0)
                          TextSpan(
                            text: ' · $_missingLabel',
                            style: typography.xs12.copyWith(
                              color: palette.danger,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: tokens.space1),
        ScIconButton(
          icon: ScIcons.delete,
          label: 'Delete ${workspace.title}',
          onPressed: onDelete,
        ),
        SizedBox(width: tokens.space2),
      ],
    );
  }

  /// The video count and the newest video's date, or the creation date.
  ///
  /// The catalog has no last-played timestamp, so the row names what it can
  /// honestly show: the newest video's date. An empty workspace shows when it
  /// was created instead.
  String _meta() {
    final count =
        summary.videoCount == 1 ? '1 video' : '${summary.videoCount} videos';
    final lastVideoAt = summary.lastVideoAt;
    if (lastVideoAt != null) {
      return '$count · Last video ${_dateLabel(lastVideoAt)}';
    }
    return 'No videos · Created ${_dateLabel(summary.workspace.createdAt)}';
  }

  /// The plural missing count, for the row's danger suffix.
  String get _missingLabel => summary.missingCount == 1
      ? '1 missing'
      : '${summary.missingCount} missing';

  /// A compact `12 Oct` date, with the year when it is not the current one.
  String _dateLabel(DateTime date) {
    final year = date.year == DateTime.now().year ? '' : ' ${date.year}';
    return '${date.day} ${_months[date.month - 1]}$year';
  }
}
