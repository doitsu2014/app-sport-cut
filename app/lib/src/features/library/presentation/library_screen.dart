import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../domain/match_import_exception.dart';
import '../domain/match_record.dart';
import 'formatters.dart';
import 'library_providers.dart';

/// Match library: the home screen.
///
/// Shows every stored match with its title, duration, and creation date; an
/// empty library is a normal state that offers to import a recording.
class LibraryScreen extends ConsumerWidget {
  /// Build the library screen.
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(matchListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sportcut'),
        actions: <Widget>[
          IconButton(
            onPressed: () => _import(context, ref),
            icon: const Icon(Icons.add),
            tooltip: 'Import video',
          ),
        ],
      ),
      body: matches.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LibraryError(
          message: '$error',
          onRetry: () => ref.invalidate(matchListProvider),
        ),
        data: (list) => list.isEmpty
            ? _EmptyLibrary(onImport: () => _import(context, ref))
            : _MatchList(
                matches: list,
                onOpen: (match) => _open(context, match),
                onGenerate: (match) => _generateArtifacts(context, ref, match),
                onDelete: (match) => _confirmDelete(context, ref, match),
              ),
      ),
    );
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await ref.read(videoFilePickerProvider).pickVideo();
      if (picked == null) {
        return; // the user cancelled
      }
      final repository = await ref.read(matchRepositoryProvider.future);
      final match = await repository.importVideo(picked);
      ref.invalidate(matchListProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('Imported ${match.title}')),
      );
    } on MatchImportException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _generateArtifacts(
    BuildContext context,
    WidgetRef ref,
    MatchRecord match,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repository = await ref.read(matchRepositoryProvider.future);
      final result = await repository.generateArtifacts(match);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Analysis files ready: ${result.manifest.artifacts.length} artifacts',
          ),
        ),
      );
    } on MatchImportException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _open(BuildContext context, MatchRecord match) {
    Navigator.of(context).pushNamed(AppRoutes.player, arguments: match);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    MatchRecord match,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showDialog<_DeleteChoice>(
      context: context,
      builder: (dialogContext) => _DeleteMatchDialog(match: match),
    );
    if (choice == null) {
      return;
    }

    final repository = await ref.read(matchRepositoryProvider.future);
    await repository.deleteMatch(match, deleteArtifacts: choice.deleteArtifacts);
    ref.invalidate(matchListProvider);

    messenger.showSnackBar(SnackBar(content: Text('Deleted ${match.title}')));
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onImport});

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
              Icons.sports_tennis_outlined,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('No matches yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Import a recording to review it and build highlights.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.add),
              label: const Text('Import video'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryError extends StatelessWidget {
  const _LibraryError({required this.message, required this.onRetry});

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
            Text('The library could not be read', style: Theme.of(context).textTheme.titleMedium),
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

class _MatchList extends StatelessWidget {
  const _MatchList({
    required this.matches,
    required this.onOpen,
    required this.onGenerate,
    required this.onDelete,
  });

  final List<MatchRecord> matches;
  final void Function(MatchRecord) onOpen;
  final void Function(MatchRecord) onGenerate;
  final void Function(MatchRecord) onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: matches.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final match = matches[index];
        return ListTile(
          title: Text(match.title),
          subtitle: Text(
            '${formatDuration(match.durationSeconds)}  ·  '
            '${formatMatchDate(match.createdAt)}',
          ),
          leading: const Icon(Icons.movie_outlined),
          onTap: () => onOpen(match),
          trailing: PopupMenuButton<String>(
            tooltip: 'Match actions',
            onSelected: (value) {
              switch (value) {
                case 'open':
                  onOpen(match);
                case 'generate':
                  onGenerate(match);
                case 'delete':
                  onDelete(match);
              }
            },
            itemBuilder: (context) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'open', child: Text('Play')),
              PopupMenuItem<String>(
                value: 'generate',
                child: Text('Prepare analysis files'),
              ),
              PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
            ],
          ),
        );
      },
    );
  }
}

class _DeleteChoice {
  const _DeleteChoice({required this.deleteArtifacts});

  final bool deleteArtifacts;
}

class _DeleteMatchDialog extends StatefulWidget {
  const _DeleteMatchDialog({required this.match});

  final MatchRecord match;

  @override
  State<_DeleteMatchDialog> createState() => _DeleteMatchDialogState();
}

class _DeleteMatchDialogState extends State<_DeleteMatchDialog> {
  bool _deleteArtifacts = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete match?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${widget.match.title} will be removed from the library. The '
            'original recording is never deleted.',
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _deleteArtifacts,
            onChanged: (value) =>
                setState(() => _deleteArtifacts = value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Also delete analysis files'),
            subtitle: const Text('Proxy, audio, and sampled frames'),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _DeleteChoice(deleteArtifacts: _deleteArtifacts),
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
