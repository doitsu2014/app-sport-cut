import 'package:flutter/material.dart';

import '../../../../app/design/sc_metrics.dart';
import '../../../../app/design/sportcut_tokens.dart';
import '../../domain/workspace.dart';
import 'studio_chrome.dart';

/// The studio toolbar: back, the workspace title, and the global actions.
class StudioToolbar extends StatelessWidget {
  /// Build the toolbar for [workspace].
  const StudioToolbar({
    super.key,
    required this.workspace,
    required this.videoCount,
    required this.importRunning,
    required this.showImport,
    required this.onBack,
    required this.onImport,
    required this.onDelete,
  });

  /// The workspace whose title is shown.
  final Workspace workspace;

  /// How many videos the workspace holds.
  final int videoCount;

  /// Whether an import is running.
  final bool importRunning;

  /// Whether the import action is offered.
  final bool showImport;

  /// Return to the workspace list.
  final VoidCallback onBack;

  /// Start importing a recording.
  final VoidCallback onImport;

  /// Delete the workspace.
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = SportcutTokens.of(context);
    return Container(
      height: ScMetrics.toolbarHeight,
      padding: EdgeInsets.symmetric(horizontal: tokens.space4),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onBack,
            tooltip: 'Back to workspaces',
            icon: const Icon(Icons.arrow_back, size: 18),
          ),
          SizedBox(width: tokens.space2),
          Text(
            'Sportcut',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 14,
              height: 1.1,
              letterSpacing: -0.01,
            ),
          ),
          SizedBox(width: tokens.space3),
          Container(width: 1, height: 16, color: scheme.outlineVariant),
          SizedBox(width: tokens.space3),
          Expanded(
            child: Text(
              workspace.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (videoCount > 0) ...<Widget>[
            StudioChip(
              label: '$videoCount ${videoCount == 1 ? 'video' : 'videos'}',
            ),
            SizedBox(width: tokens.space2),
          ],
          if (showImport) ...<Widget>[
            FilledButton.icon(
              onPressed: importRunning ? null : onImport,
              icon: const Icon(Icons.add, size: 16),
              label: Text(importRunning ? 'Importing' : 'Import'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 30),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: theme.textTheme.labelLarge?.copyWith(fontSize: 12),
              ),
            ),
            SizedBox(width: tokens.space2),
          ],
          IconButton(
            onPressed: onDelete,
            tooltip: 'Delete workspace',
            icon: const Icon(Icons.delete_outline, size: 18),
          ),
        ],
      ),
    );
  }
}
