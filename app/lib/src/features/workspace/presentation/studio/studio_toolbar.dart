import 'package:flutter/material.dart';

import '../../../../app/design/components/sc_actions.dart';
import '../../../../app/design/components/sc_search_field.dart';
import '../../../../app/design/sc_icons.dart';
import '../../../../app/design/sc_metrics.dart';
import '../../../../app/design/sc_tints.dart';
import '../../../../app/design/sc_typography.dart';
import '../../../../app/design/sportcut_tokens.dart';
import '../../domain/workspace.dart';

/// The studio toolbar: back, wordmark, breadcrumb, command search, rail and
/// focus toggles, delete, and the single primary action, Export.
///
/// The leading edge is padded by [ScMetrics.trafficLightInset] so the native
/// macOS traffic lights never sit under a control (ADR-0003 D6). Import is
/// deliberately absent: it lives in the video-rail footer (ADR-0003 D4). The
/// widget is data-in / callback-out and reads no provider.
class StudioToolbar extends StatelessWidget {
  /// Build the toolbar for [workspace].
  const StudioToolbar({
    super.key,
    required this.workspace,
    required this.searchController,
    required this.libraryVisible,
    required this.inspectorVisible,
    required this.focusMode,
    required this.onBack,
    required this.onToggleLibrary,
    required this.onToggleInspector,
    required this.onToggleFocusMode,
    required this.onDelete,
    required this.onExport,
    this.searchFocusNode,
  });

  /// The workspace named in the breadcrumb.
  final Workspace workspace;

  /// The search field's controller, owned by the composition root.
  ///
  /// The field writes the query into the controller; `⌘K` focuses it through
  /// [searchFocusNode].
  final TextEditingController searchController;

  /// The search field's focus node, so `⌘K` can reach it.
  final FocusNode? searchFocusNode;

  /// Whether the video rail is showing.
  final bool libraryVisible;

  /// Whether the inspector rail is showing.
  final bool inspectorVisible;

  /// Whether focus mode is engaged.
  final bool focusMode;

  /// Return to the workspace list.
  final VoidCallback onBack;

  /// Show or hide the video rail.
  final VoidCallback onToggleLibrary;

  /// Show or hide the inspector rail.
  final VoidCallback onToggleInspector;

  /// Toggle focus mode.
  final VoidCallback onToggleFocusMode;

  /// Delete the workspace.
  final VoidCallback onDelete;

  /// Open the export sheet.
  final VoidCallback onExport;

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
      height: ScMetrics.toolbarHeight,
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
          ScIconButton(
            icon: ScIcons.chevronLeft,
            label: 'Back to workspaces',
            onPressed: onBack,
          ),
          SizedBox(width: tokens.space2),
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
              'Workspace / ${workspace.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: breadcrumb,
            ),
          ),
          SizedBox(width: tokens.space3),
          ScSearchField(
            controller: searchController,
            focusNode: searchFocusNode,
            hint: 'Search videos',
            clearLabel: 'Clear search',
          ),
          SizedBox(width: tokens.space2),
          ScToolbarButton(
            icon: ScIcons.viewSidebar,
            label: 'Toggle library',
            selected: libraryVisible,
            onPressed: onToggleLibrary,
          ),
          Transform.flip(
            flipX: true,
            child: ScToolbarButton(
              icon: ScIcons.viewSidebar,
              label: 'Toggle inspector',
              selected: inspectorVisible,
              onPressed: onToggleInspector,
            ),
          ),
          ScToolbarButton(
            icon: focusMode ? ScIcons.fullscreenExit : ScIcons.fullscreen,
            label: 'Focus mode (F)',
            selected: focusMode,
            onPressed: onToggleFocusMode,
          ),
          SizedBox(width: tokens.space1),
          ScIconButton(
            icon: ScIcons.delete,
            label: 'Delete workspace',
            onPressed: onDelete,
          ),
          SizedBox(width: tokens.space2),
          SizedBox(
            height: ScMetrics.toolButton,
            child: ScButton.compact(
              label: 'Export',
              icon: ScIcons.download,
              onPressed: onExport,
            ),
          ),
        ],
      ),
    );
  }
}
