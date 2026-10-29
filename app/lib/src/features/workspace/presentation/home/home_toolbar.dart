import 'package:flutter/material.dart';

import '../../../../app/design/components/sc_actions.dart';
import '../../../../app/design/sc_icons.dart';
import '../../../../app/design/sc_metrics.dart';
import '../../../../app/design/sc_tints.dart';
import '../../../../app/design/sc_typography.dart';
import '../../../../app/design/sportcut_tokens.dart';

/// The home toolbar: the same 52 px band as the studio, with the traffic-light
/// inset, the wordmark, and the two actions the library already offered.
///
/// New workspace is the one primary action; importing a recording is the
/// secondary action beside it, so the home never hides an action the screen
/// used to offer. The widget is data-in / callback-out and reads no provider.
class HomeToolbar extends StatelessWidget {
  /// Build the home toolbar.
  const HomeToolbar({
    super.key,
    required this.onCreateWorkspace,
    required this.onImport,
    required this.importRunning,
  });

  /// Open the create-workspace dialog.
  final VoidCallback onCreateWorkspace;

  /// Ask for a recording to import.
  final VoidCallback onImport;

  /// Whether an import is already running.
  final bool importRunning;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final wordmark = typography.display32.copyWith(
      fontSize: typography.sm14.fontSize,
      letterSpacing: 0,
    );
    final breadcrumb = typography.micro10.copyWith(color: palette.muted);

    return Container(
      constraints: const BoxConstraints(minHeight: ScMetrics.toolbarHeight),
      padding: EdgeInsets.only(
        left: ScMetrics.trafficLightInset,
        right: tokens.space3,
      ),
      decoration: BoxDecoration(
        color: ScTints.toolbarSurface(palette.surface, palette.bg),
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: <Widget>[
          Text('Sportcut', maxLines: 1, style: wordmark),
          SizedBox(width: tokens.space3),
          Container(
            width: tokens.space1 / 4,
            height: tokens.space4,
            color: palette.border,
          ),
          SizedBox(width: tokens.space3),
          Expanded(
            child: Text(
              'Workspaces',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: breadcrumb,
            ),
          ),
          SizedBox(width: tokens.space3),
          ScButton.compact(
            label: 'Import video',
            icon: ScIcons.upload,
            variant: ScButtonVariant.secondary,
            loading: importRunning,
            onPressed: onImport,
          ),
          SizedBox(width: tokens.space2),
          ScButton.compact(
            label: 'New workspace',
            icon: ScIcons.add,
            onPressed: onCreateWorkspace,
          ),
        ],
      ),
    );
  }
}
