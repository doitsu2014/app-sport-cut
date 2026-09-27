import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/presentation/import_controller.dart';
import '../../library/presentation/library_providers.dart';
import 'workspace_providers.dart';
import 'workspace_studio_screen.dart';

/// The home screen: the list of workspaces.
///
/// A workspace is a loose folder of recordings. Tapping one opens its videos;
/// with none yet, the empty state offers to create one or import straight into
/// a freshly created workspace.
class WorkspaceScreen extends ConsumerWidget {
  /// Build the workspace home screen.
  const WorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaces = ref.watch(workspaceListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sportcut'),
        actions: <Widget>[
          IconButton(
            onPressed: () => _createWorkspace(context, ref),
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'New workspace',
          ),
        ],
      ),
      body: workspaces.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _WorkspacesError(
          message: '$error',
          onRetry: () => ref.invalidate(workspaceListProvider),
        ),
        data: (items) => items.isEmpty
            ? _EmptyWorkspaces(
                onNewWorkspace: () => _createWorkspace(context, ref),
                onImport: () => _import(context, ref),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final workspace = items[index];
                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(workspace.title),
                      subtitle: const Text('Workspace'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => WorkspaceStudioScreen(
                            workspace: workspace,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _createWorkspace(BuildContext context, WidgetRef ref) async {
    final title = await _askWorkspaceTitle(context);
    if (title == null) {
      return;
    }
    final repository = await ref.read(matchRepositoryProvider.future);
    final workspace = await repository.createWorkspace(title: title);
    ref.invalidate(workspaceListProvider);
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => WorkspaceStudioScreen(workspace: workspace),
        ),
      );
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome =
        await ref.read(importControllerProvider.notifier).start();
    switch (outcome) {
      case ImportSucceeded(:final match):
        ref.invalidate(workspaceListProvider);
        messenger.showSnackBar(
          SnackBar(content: Text('Imported ${match.title}')),
        );
      case ImportFailed(:final problem):
        messenger.showSnackBar(SnackBar(content: Text(problem.message)));
      case ImportDeclined():
        break; // the user cancelled, or an import was already running
    }
  }

  Future<String?> _askWorkspaceTitle(BuildContext context) async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New workspace'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'e.g. Thursday club night',
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    return title;
  }
}

class _EmptyWorkspaces extends StatelessWidget {
  const _EmptyWorkspaces({
    required this.onNewWorkspace,
    required this.onImport,
  });

  final VoidCallback onNewWorkspace;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.folder_outlined,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('No workspaces yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Group your recordings into a workspace to review and build '
              'highlights.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onNewWorkspace,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('New workspace'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.add),
              label: const Text('Import a video'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspacesError extends StatelessWidget {
  const _WorkspacesError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(
              'The workspaces could not be read',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
