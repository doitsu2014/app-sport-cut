import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/components/sc_empty_state.dart';
import '../../../app/design/components/sc_panel.dart';
import '../../../app/design/components/sc_progress_job.dart';
import '../../../app/design/sc_icons.dart';
import '../../../app/design/sc_metrics.dart';
import '../../../app/design/sportcut_tokens.dart';
import '../../../app/router.dart';
import '../../library/presentation/import_controller.dart';
import '../../library/presentation/library_providers.dart';
import '../domain/workspace.dart';
import 'home/home_dialogs.dart';
import 'home/home_status_bar.dart';
import 'home/home_toolbar.dart';
import 'home/workspace_row.dart';
import 'home/workspace_summary.dart';
import 'workspace_providers.dart';

/// The home screen: the list of workspaces.
///
/// A workspace is a loose folder of recordings. Selecting one opens its studio;
/// with none yet, the empty state offers the next action, create one. The
/// screen is the studio family's surface — 52 px toolbar, panel sections, and
/// a 30 px status bar — rather than a Material list.
class WorkspaceScreen extends ConsumerStatefulWidget {
  /// Build the workspace home screen.
  const WorkspaceScreen({super.key});

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  /// The workspace last opened from this screen, for the row's selected state.
  ///
  /// This is ephemeral: it lives only as long as the home widget and is not
  /// written anywhere.
  String? _activeWorkspaceId;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final import = ref.watch(importControllerProvider);
    final summaries = ref.watch(workspaceSummariesProvider);
    final items = summaries.value ?? const <WorkspaceSummary>[];
    final videoCount = items.fold<int>(
      0,
      (int total, WorkspaceSummary item) => total + item.videoCount,
    );
    final missingCount = items.fold<int>(
      0,
      (int total, WorkspaceSummary item) => total + item.missingCount,
    );

    return Scaffold(
      backgroundColor: palette.bg,
      body: Column(
        children: <Widget>[
          HomeToolbar(
            onCreateWorkspace: _createWorkspace,
            onImport: _import,
            importRunning: import.isRunning,
          ),
          if (import.isRunning)
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.space4,
                tokens.space3,
                tokens.space4,
                0,
              ),
              child: ScProgressJob(
                stageLabel: import.description,
                fraction: import.fraction,
                detail: 'Sportcut copies the recording into its own store.',
                onCancel: () =>
                    ref.read(importControllerProvider.notifier).cancel(),
              ),
            ),
          Expanded(child: _body(summaries)),
          HomeStatusBar(
            workspaceCount: items.length,
            videoCount: videoCount,
            missingCount: missingCount,
          ),
        ],
      ),
    );
  }

  /// The list, or the loading, empty, and error state that replaces it.
  Widget _body(AsyncValue<List<WorkspaceSummary>> summaries) {
    return summaries.when(
      loading: () => Center(
        child: Semantics(
          label: 'Reading workspaces',
          child: const CircularProgressIndicator(),
        ),
      ),
      error: (Object error, StackTrace stackTrace) => _centred(
        ScEmptyState(
          message: 'The workspaces could not be read. $error',
          actionLabel: 'Retry',
          onAction: () {
            ref.invalidate(workspaceListProvider);
            ref.invalidate(matchRepositoryProvider);
          },
          icon: ScIcons.error,
        ),
      ),
      data: (List<WorkspaceSummary> items) => items.isEmpty
          ? _centred(
              ScEmptyState(
                message: 'No workspaces yet.',
                actionLabel: 'New workspace',
                onAction: _createWorkspace,
              ),
            )
          : _list(items),
    );
  }

  /// A state card in the middle of the empty content area.
  Widget _centred(Widget child) {
    final tokens = SportcutTokens.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(tokens.space8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: ScMetrics.dialogConfirm),
          child: child,
        ),
      ),
    );
  }

  /// The workspace list as one panel with a section header and rows.
  Widget _list(List<WorkspaceSummary> items) {
    final tokens = SportcutTokens.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: ScMetrics.containerMax),
        child: ListView(
          padding: EdgeInsets.all(tokens.space8),
          children: <Widget>[
            ScPanel(
              padding: EdgeInsets.symmetric(vertical: tokens.space2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: tokens.space4),
                    child: ScSectionHeader(
                      label: 'Workspaces',
                      count: items.length,
                    ),
                  ),
                  for (int index = 0;
                      index < items.length;
                      index++) ...<Widget>[
                    if (index > 0)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: tokens.space4,
                        ),
                        child: const ScDivider(),
                      ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: tokens.space2),
                      child: _row(items[index]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(WorkspaceSummary summary) {
    final workspace = summary.workspace;
    return WorkspaceRow(
      summary: summary,
      selected: workspace.id == _activeWorkspaceId,
      onOpen: () => _openWorkspace(workspace),
      onDelete: () => _deleteWorkspace(workspace),
    );
  }

  /// Open a workspace in the studio through the named route.
  ///
  /// The workspace travels as a [StudioRouteArgs], so the screen is reached the
  /// same way every other route is and the legacy route table stays in charge.
  void _openWorkspace(Workspace workspace) {
    setState(() => _activeWorkspaceId = workspace.id);
    Navigator.of(context).pushNamed(
      AppRoutes.studio,
      arguments: StudioRouteArgs(workspace: workspace),
    );
  }

  Future<void> _createWorkspace() async {
    final title = await showNewWorkspaceDialog(context);
    if (title == null || !mounted) {
      return;
    }
    final repository = await ref.read(matchRepositoryProvider.future);
    final workspace = await repository.createWorkspace(title: title);
    if (!mounted) {
      return;
    }
    ref.invalidate(workspaceListProvider);
    _openWorkspace(workspace);
  }

  Future<void> _deleteWorkspace(Workspace workspace) async {
    final choice = await showDeleteWorkspaceDialog(
      context,
      workspace: workspace,
    );
    if (choice == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final repository = await ref.read(matchRepositoryProvider.future);
    await repository.deleteWorkspace(
      workspace,
      deleteArtifacts: choice.deleteArtifacts,
      deleteRecording: choice.deleteRecording,
    );
    if (!mounted) {
      return;
    }
    ref.invalidate(workspaceListProvider);
    if (_activeWorkspaceId == workspace.id) {
      setState(() => _activeWorkspaceId = null);
    }
    messenger.showSnackBar(
      SnackBar(content: Text('Deleted ${workspace.title}')),
    );
  }

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await ref.read(importControllerProvider.notifier).start();
    switch (outcome) {
      case ImportSucceeded(:final match):
        if (mounted) {
          ref.invalidate(workspaceListProvider);
        }
        messenger.showSnackBar(
          SnackBar(content: Text('Imported ${match.title}')),
        );
      case ImportFailed(:final problem):
        messenger.showSnackBar(SnackBar(content: Text(problem.message)));
      case ImportDeclined():
        break; // the user cancelled, or an import was already running
    }
  }
}
