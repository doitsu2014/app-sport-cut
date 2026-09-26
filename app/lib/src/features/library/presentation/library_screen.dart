import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../domain/match_import_exception.dart';
import '../domain/match_record.dart';
import 'formatters.dart';
import 'import_controller.dart';
import 'library_providers.dart';
import 'match_list_entry.dart';

/// Match library: the home screen.
///
/// Shows every stored match with its title, duration, creation date, and the
/// media metadata read when it was imported. An empty library is a normal state
/// that offers to import a recording, and a match whose recording has gone
/// missing stays listed and says so.
class LibraryScreen extends ConsumerWidget {
  /// Build the library screen.
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(matchListProvider);
    final import = ref.watch(importControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sportcut'),
        actions: <Widget>[
          IconButton(
            onPressed: import.isRunning ? null : () => _import(context, ref),
            icon: const Icon(Icons.add),
            tooltip: 'Import video',
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (import.isRunning)
            _ImportProgress(
              description: import.description,
              onCancel: () =>
                  ref.read(importControllerProvider.notifier).cancel(),
            ),
          Expanded(
            child: matches.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _LibraryError(
                message: '$error',
                onRetry: () => ref.invalidate(matchListProvider),
              ),
              data: (entries) => entries.isEmpty
                  ? _EmptyLibrary(
                      importRunning: import.isRunning,
                      onImport: () => _import(context, ref),
                    )
                  : _MatchList(
                      entries: entries,
                      onOpen: (entry) => _open(context, entry),
                      onReview: (entry) => _review(context, entry),
                      onCalibrate: (entry) =>
                          _calibrate(context, ref, entry),
                      onGenerate: (entry) =>
                          _generateArtifacts(context, ref, entry),
                      onPlayers: (entry) => _players(context, entry),
                      onDelete: (entry) => _confirmDelete(context, ref, entry),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await ref.read(importControllerProvider.notifier).start();
    switch (outcome) {
      case ImportSucceeded(:final match):
        messenger.showSnackBar(
          SnackBar(content: Text('Imported ${match.title}')),
        );
      case ImportFailed(:final problem):
        messenger.showSnackBar(SnackBar(content: Text(problem.message)));
      case ImportDeclined():
        break; // the user cancelled, or an import was already running
    }
  }

  Future<void> _generateArtifacts(
    BuildContext context,
    WidgetRef ref,
    MatchListEntry entry,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!entry.recordingAvailable) {
      messenger.showSnackBar(
        SnackBar(content: Text(_unavailableMessage(entry.match))),
      );
      return;
    }
    try {
      final repository = await ref.read(matchRepositoryProvider.future);
      final manifest = await repository.generateArtifacts(entry.match);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Analysis files ready: ${manifest.artifacts.length} artifacts',
          ),
        ),
      );
    } on MatchImportException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _open(BuildContext context, MatchListEntry entry) {
    if (!entry.recordingAvailable) {
      // Playback would open onto a missing file and fail without saying why.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_unavailableMessage(entry.match))),
      );
      return;
    }
    Navigator.of(context).pushNamed(AppRoutes.player, arguments: entry.match);
  }

  /// Open the player-analysis review: detect people, follow tracks, assign sides.
  void _players(BuildContext context, MatchListEntry entry) {
    Navigator.of(context).pushNamed(
      AppRoutes.playerTracking,
      arguments: entry.match,
    );
  }

  /// Open the review session: marking rallies, confirming winners, scoring.
  ///
  /// Review needs the recording, so a match whose copy has gone is reported the
  /// same way playing it is.
  void _review(BuildContext context, MatchListEntry entry) {
    if (!entry.recordingAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_unavailableMessage(entry.match))),
      );
      return;
    }
    Navigator.of(context).pushNamed(AppRoutes.score, arguments: entry.match);
  }

  /// Open court calibration: marking the four corners of the court.
  ///
  /// Calibration reads the recording, so a match whose copy has gone is reported
  /// the same way playing it is.
  Future<void> _calibrate(
    BuildContext context,
    WidgetRef ref,
    MatchListEntry entry,
  ) async {
    if (!entry.recordingAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_unavailableMessage(entry.match))),
      );
      return;
    }
    final saved = await Navigator.of(context).pushNamed(
      AppRoutes.calibration,
      arguments: entry.match,
    );
    // A saved court is a change to the match, so the list is re-read; a screen
    // the user simply backed out of changed nothing.
    if (saved is MatchRecord) {
      ref.invalidate(matchListProvider);
    }
  }

  static String _unavailableMessage(MatchRecord match) =>
      'The recording for ${match.title} is no longer available on this device.';

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    MatchListEntry entry,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showDialog<_DeleteChoice>(
      context: context,
      builder: (dialogContext) => _DeleteMatchDialog(match: entry.match),
    );
    if (choice == null) {
      return;
    }

    final repository = await ref.read(matchRepositoryProvider.future);
    await repository.deleteMatch(
      entry.match,
      deleteArtifacts: choice.deleteArtifacts,
      deleteRecording: choice.deleteRecording,
    );
    ref.invalidate(matchListProvider);

    messenger.showSnackBar(
      SnackBar(content: Text('Deleted ${entry.match.title}')),
    );
  }
}

class _ImportProgress extends StatelessWidget {
  const _ImportProgress({required this.description, required this.onCancel});

  final String description;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        children: <Widget>[
          const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(description, style: theme.textTheme.bodyMedium),
                ),
                TextButton(onPressed: onCancel, child: const Text('Cancel')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onImport, required this.importRunning});

  final VoidCallback onImport;
  final bool importRunning;

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
              onPressed: importRunning ? null : onImport,
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
    required this.entries,
    required this.onOpen,
    required this.onReview,
    required this.onCalibrate,
    required this.onGenerate,
    required this.onPlayers,
    required this.onDelete,
  });

  final List<MatchListEntry> entries;
  final void Function(MatchListEntry) onOpen;
  final void Function(MatchListEntry) onReview;
  final void Function(MatchListEntry) onCalibrate;
  final void Function(MatchListEntry) onGenerate;
  final void Function(MatchListEntry) onPlayers;
  final void Function(MatchListEntry) onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final match = entry.match;
        return ListTile(
          title: Text(match.title),
          isThreeLine: true,
          subtitle: _MatchSubtitle(entry: entry),
          leading: Icon(
            entry.recordingAvailable
                ? Icons.movie_outlined
                : Icons.videocam_off_outlined,
          ),
          onTap: () => onOpen(entry),
          trailing: PopupMenuButton<String>(
            tooltip: 'Match actions',
            onSelected: (value) {
              switch (value) {
                case 'open':
                  onOpen(entry);
                case 'review':
                  onReview(entry);
                case 'calibrate':
                  onCalibrate(entry);
                case 'generate':
                  onGenerate(entry);
                case 'players':
                  onPlayers(entry);
                case 'delete':
                  onDelete(entry);
              }
            },
            itemBuilder: (context) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'open', child: Text('Play')),
              PopupMenuItem<String>(
                value: 'review',
                child: Text('Review and score'),
              ),
              PopupMenuItem<String>(
                value: 'calibrate',
                child: Text('Mark the court'),
              ),
              PopupMenuItem<String>(
                value: 'generate',
                child: Text('Prepare analysis files'),
              ),
              PopupMenuItem<String>(
                value: 'players',
                child: Text('Player analysis'),
              ),
              PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
            ],
          ),
        );
      },
    );
  }
}

class _MatchSubtitle extends StatelessWidget {
  const _MatchSubtitle({required this.entry});

  final MatchListEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final match = entry.match;
    final score = entry.score;
    final summary = formatMediaSummary(
      width: match.videoWidth,
      height: match.videoHeight,
      frameRate: match.frameRate,
      hasAudio: match.hasAudio,
      bytes: match.sourceBytes,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '${formatDuration(match.durationSeconds)}  ·  '
          '${formatMatchDate(match.createdAt)}',
        ),
        if (score != null)
          Text(
            'Score ${score.left}–${score.right}',
            style: theme.textTheme.bodySmall,
          ),
        if (summary.isNotEmpty)
          Text(summary, style: theme.textTheme.bodySmall),
        if (!entry.recordingAvailable)
          Text(
            'Recording unavailable',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error),
          ),
      ],
    );
  }
}

class _DeleteChoice {
  const _DeleteChoice({
    required this.deleteArtifacts,
    required this.deleteRecording,
  });

  final bool deleteArtifacts;
  final bool deleteRecording;
}

class _DeleteMatchDialog extends StatefulWidget {
  const _DeleteMatchDialog({required this.match});

  final MatchRecord match;

  @override
  State<_DeleteMatchDialog> createState() => _DeleteMatchDialogState();
}

class _DeleteMatchDialogState extends State<_DeleteMatchDialog> {
  bool _deleteArtifacts = false;
  bool _deleteRecording = false;

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
          CheckboxListTile(
            value: _deleteRecording,
            onChanged: (value) =>
                setState(() => _deleteRecording = value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Also delete the stored recording copy'),
            subtitle: const Text('The copy Sportcut made for this match'),
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
            _DeleteChoice(
              deleteArtifacts: _deleteArtifacts,
              deleteRecording: _deleteRecording,
            ),
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
