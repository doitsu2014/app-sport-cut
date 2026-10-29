import 'package:flutter/material.dart';

import '../../../../app/design/sc_metrics.dart';
import '../../../../app/design/sc_overlay_colors.dart';
import '../../../../app/design/sportcut_tokens.dart';
import '../../../library/presentation/formatters.dart';
import '../../../library/presentation/match_list_entry.dart';
import 'studio_chrome.dart';

/// The left rail listing every video in the workspace.
class VideoRail extends StatelessWidget {
  /// Build the rail for [entries].
  const VideoRail({
    super.key,
    required this.entries,
    required this.selectedId,
    required this.busyId,
    required this.onSelect,
    required this.onDelete,
  });

  /// The videos to list.
  final List<MatchListEntry> entries;

  /// The selected video's id, or null until one is chosen.
  final String? selectedId;

  /// Video whose analysis files are being prepared in the background.
  final String? busyId;

  /// Select a video.
  final void Function(MatchListEntry) onSelect;

  /// Delete a video.
  final void Function(MatchListEntry) onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = SportcutTokens.of(context);
    return Container(
      width: ScMetrics.libraryWidth,
      color: scheme.surface,
      child: Column(
        children: <Widget>[
          RailHeader(label: 'Videos', trailing: '${entries.length}'),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.all(tokens.space2),
              itemCount: entries.length,
              separatorBuilder: (context, index) =>
                  SizedBox(height: tokens.space1),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return VideoRailTile(
                  entry: entry,
                  selected: entry.match.id == selectedId,
                  busy: entry.match.id == busyId,
                  onSelect: () => onSelect(entry),
                  onDelete: () => onDelete(entry),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One selectable video in the [VideoRail].
class VideoRailTile extends StatelessWidget {
  /// Build a tile for [entry].
  const VideoRailTile({
    super.key,
    required this.entry,
    required this.selected,
    required this.busy,
    required this.onSelect,
    required this.onDelete,
  });

  /// The video this tile represents.
  final MatchListEntry entry;

  /// Whether this is the selected video.
  final bool selected;

  /// Whether this video's analysis files are being prepared.
  final bool busy;

  /// Select this video.
  final VoidCallback onSelect;

  /// Delete this video.
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = SportcutTokens.of(context);
    final missing = !entry.recordingAvailable;
    final score = entry.score;
    final scoreLabel = score == null
        ? formatDuration(entry.match.durationSeconds)
        : 'Score ${score.left}–${score.right}';
    final meta = missing
        ? 'Recording missing'
        : '${resolutionLabel(entry.match)} · $scoreLabel';

    return Material(
      color: selected ? scheme.surfaceContainerHighest : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        side: BorderSide(
          color: selected ? scheme.outlineVariant : Colors.transparent,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onSelect,
        child: Padding(
          padding: EdgeInsets.all(tokens.space2),
          child: Row(
            children: <Widget>[
              VideoThumb(entry: entry),
              SizedBox(width: tokens.space2),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.match.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 12,
                        height: 1.3,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: missing ? scheme.error : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Padding(
                  padding: EdgeInsets.only(left: tokens.space1),
                  child: Icon(
                    Icons.check_circle,
                    size: 14,
                    color: scheme.primary,
                  ),
                ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: BusySpinner(
                    tooltip: 'Preparing analysis in the background',
                  ),
                )
              else
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'Delete video',
                  icon: const Icon(Icons.delete_outline, size: 18),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(28, 28),
                    padding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The small fixed-size thumbnail on a rail tile.
class VideoThumb extends StatelessWidget {
  /// Build the thumbnail for [entry].
  const VideoThumb({super.key, required this.entry});

  /// The video whose thumbnail is shown.
  final MatchListEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final available = entry.recordingAvailable;
    return Container(
      width: 52,
      height: 30,
      decoration: BoxDecoration(
        // The footage bed is fixed in both themes; this is a thumbnail, not
        // UI chrome.
        color: ScOverlayColors.thumbnailBed,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Center(
            child: Icon(
              available ? Icons.movie_outlined : Icons.error_outline,
              size: 14,
              color: available ? Colors.white70 : scheme.error,
            ),
          ),
          if (available)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(170),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  formatDuration(entry.match.durationSeconds),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    height: 1.4,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The progress strip shown while an import is running.
class ImportProgress extends StatelessWidget {
  /// Build the strip for the running import.
  const ImportProgress({
    super.key,
    required this.description,
    required this.onCancel,
  });

  /// What the import is doing right now.
  final String description;

  /// Cancel the running import.
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

/// The empty state shown when a workspace has no videos yet.
class EmptyStudio extends StatelessWidget {
  /// Build the empty state.
  const EmptyStudio(
      {super.key, required this.onImport, required this.importRunning});

  /// Start importing a recording.
  final VoidCallback onImport;

  /// Whether an import is already running.
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
            Text('No videos in this workspace',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Import a match recording to review it and build highlights.',
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
