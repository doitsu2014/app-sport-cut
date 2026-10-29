import 'package:flutter/material.dart';

import '../../../../app/design/components/sc_actions.dart';
import '../../../../app/design/components/sc_empty_state.dart';
import '../../../../app/design/components/sc_library.dart';
import '../../../../app/design/components/sc_progress_job.dart';
import '../../../../app/design/sc_icons.dart';
import '../../../../app/design/sc_tints.dart';
import '../../../../app/design/sc_typography.dart';
import '../../../../app/design/sportcut_tokens.dart';
import '../../../library/presentation/formatters.dart';
import '../../../library/presentation/match_list_entry.dart';
import 'studio_chrome.dart';

/// The left rail: the workspace head, the video list, and the import footer.
///
/// Rows use [ScVideoRow] so selection is the warm surface plus a hairline ring
/// and a check, and a missing recording says so in words (ADR-0003 D5, D8).
/// The rail reads no provider: the composition root passes the resolved list
/// and the callbacks.
class VideoRail extends StatelessWidget {
  /// Build the rail for [entries].
  const VideoRail({
    super.key,
    required this.workspaceTitle,
    required this.entries,
    required this.selectedId,
    required this.importRunning,
    required this.importDescription,
    required this.onSelect,
    required this.onDelete,
    required this.onImport,
    required this.onCancelImport,
    required this.onRetry,
    this.importFraction,
    this.loading = false,
    this.error,
  });

  /// The workspace title shown at the top of the rail.
  final String workspaceTitle;

  /// The videos to list.
  final List<MatchListEntry> entries;

  /// The selected video's id, or null until one is chosen.
  final String? selectedId;

  /// Whether an import is running.
  final bool importRunning;

  /// What the running import is doing.
  final String importDescription;

  /// Completion of the running import in the range 0 to 1, when the
  /// controller exposes one.
  final double? importFraction;

  /// Whether the video list is still loading.
  final bool loading;

  /// Why the video list could not be read, when it could not.
  final String? error;

  /// Select a video.
  final void Function(MatchListEntry) onSelect;

  /// Delete a video.
  final void Function(MatchListEntry) onDelete;

  /// Start importing a recording.
  final VoidCallback onImport;

  /// Cancel the running import.
  final VoidCallback onCancelImport;

  /// Retry reading the video list.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final missing = entries.where((entry) => !entry.recordingAvailable).length;
    final countLine = _countLine(entries.length, missing);

    return Container(
      decoration: BoxDecoration(
        color: ScTints.railSurface(palette.surface, palette.bg),
        border: Border(right: BorderSide(color: palette.border)),
      ),
      child: Column(
        children: <Widget>[
          Container(
            padding: EdgeInsets.fromLTRB(
              tokens.space3,
              tokens.space3,
              tokens.space3,
              tokens.space2,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: palette.borderSoft),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  workspaceTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.title20.copyWith(
                    fontSize: typography.lead18.fontSize,
                  ),
                ),
                SizedBox(height: tokens.space1 / 2),
                Text(
                  countLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.micro10.copyWith(color: palette.muted),
                ),
              ],
            ),
          ),
          ScSectionLabel(label: 'Videos', count: entries.length),
          Expanded(child: _body(context)),
          _footer(context, countLine),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final tokens = SportcutTokens.of(context);
    final error = this.error;
    if (error != null) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(tokens.space2),
        child: ScEmptyState(
          compact: true,
          message: 'The videos could not be read.\n$error',
          actionLabel: 'Try again',
          onAction: onRetry,
          icon: ScIcons.error,
        ),
      );
    }
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (entries.isEmpty) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(tokens.space2),
        child: ScEmptyState(
          compact: true,
          message: 'No videos in this workspace.',
          actionLabel: importRunning ? null : 'Import video',
          onAction: importRunning ? null : onImport,
          icon: ScIcons.movie,
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.all(tokens.space2),
      itemCount: entries.length,
      separatorBuilder: (BuildContext context, int index) =>
          SizedBox(height: tokens.space1),
      itemBuilder: (BuildContext context, int index) {
        final entry = entries[index];
        final score = entry.score;
        return ScVideoRow(
          title: entry.match.title,
          meta: '${resolutionLabel(entry.match)} · '
              '${formatDuration(entry.match.durationSeconds)}',
          score: score == null ? null : '${score.left}–${score.right}',
          selected: entry.match.id == selectedId,
          missing: !entry.recordingAvailable,
          onTap: () => onSelect(entry),
          onDelete: () => onDelete(entry),
        );
      },
    );
  }

  Widget _footer(BuildContext context, String countLine) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);

    return Container(
      padding: EdgeInsets.all(tokens.space3),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.borderSoft)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (importRunning) ...<Widget>[
            ScProgressJob(
              stageLabel: 'Importing',
              fraction: importFraction,
              detail: importDescription,
              onCancel: onCancelImport,
            ),
            SizedBox(height: tokens.space2),
          ],
          ScButton.compact(
            label: 'Import video',
            icon: ScIcons.add,
            enabled: !importRunning,
            expanded: true,
            onPressed: onImport,
          ),
          SizedBox(height: tokens.space2),
          Text(
            countLine,
            textAlign: TextAlign.center,
            style: typography.chrome9.copyWith(color: palette.muted),
          ),
        ],
      ),
    );
  }

  String _countLine(int count, int missing) {
    final videos = count == 1 ? '1 video' : '$count videos';
    final missingLabel = missing == 1 ? '1 missing' : '$missing missing';
    return '$videos · $missingLabel';
  }
}
