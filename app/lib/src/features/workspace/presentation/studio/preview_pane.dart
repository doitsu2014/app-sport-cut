import 'package:flutter/material.dart';

import '../../../../app/design/sportcut_tokens.dart';
import '../../../analysis/presentation/analysis_view.dart';
import '../../../calibration/presentation/calibration_view.dart';
import '../../../export/presentation/export_view.dart';
import '../../../highlights/presentation/highlights_view.dart';
import '../../../library/domain/match_record.dart';
import '../../../library/presentation/match_list_entry.dart';
import '../../../library/presentation/playback_controller.dart';
import '../../../library/presentation/player_view.dart';
import '../../../score/presentation/score_view.dart';
import '../../../tracking/presentation/player_tracking_view.dart';
import '../../domain/pipeline_stage.dart';
import 'studio_chrome.dart';

/// One shared preview in the center of the studio.
///
/// The pane shows the preview header and whichever feature view the selected
/// stage names, handing every view the same playback controller.
class PreviewPane extends StatelessWidget {
  /// Build the center pane for the selected [entry].
  const PreviewPane({
    super.key,
    required this.entry,
    required this.facts,
    required this.controller,
    required this.stage,
    required this.onSelectStage,
    required this.onPrepare,
    required this.onRefresh,
  });

  /// The selected video.
  final MatchListEntry entry;

  /// Stage facts for every video in the workspace, or null while loading.
  final Map<String, VideoStageFacts>? facts;

  /// The shared player for the selected video, or null until it is ready.
  final PlaybackController? controller;

  /// The selected feature, where null means playback.
  final PipelineStage? stage;

  /// Open another feature.
  final void Function(PipelineStage) onSelectStage;

  /// Open the prepare screen and start its background job.
  final void Function(MatchRecord) onPrepare;

  /// Refresh the rail after a feature writes an artifact.
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Column(
        children: <Widget>[
          CenterHeader(match: entry.match, stage: stage),
          Expanded(child: _featureView(entry, facts, controller)),
        ],
      ),
    );
  }

  Widget _featureView(
    MatchListEntry entry,
    Map<String, VideoStageFacts>? facts,
    PlaybackController controller,
  ) {
    switch (stage) {
      case null:
        return PlayerView(controller: controller);
      case PipelineStage.calibrate:
        return CalibrationView(
          match: entry.match,
          controller: controller,
          onSaved: (_) => onRefresh(),
        );
      case PipelineStage.track:
        final videoFacts = facts?[entry.match.id];
        return PlayerTrackingView(
          match: entry.match,
          controller: controller,
          calibrated: videoFacts?.calibrated ?? false,
          analysisReady: videoFacts?.analysisReady ?? false,
          onMarkCourt: () => onSelectStage(PipelineStage.calibrate),
          onPrepare: () => onPrepare(entry.match),
          // The track job writes a new artifact; refresh the rail so done and
          // ready states do not stay stale after the action.
          onAnalyzed: onRefresh,
          // Manual review is always available, even without detected tracks.
          onOpenScore: () => onSelectStage(PipelineStage.score),
        );
      case PipelineStage.score:
        return ScoreView(match: entry.match, controller: controller);
      case PipelineStage.highlight:
        return HighlightsView(match: entry.match);
      case PipelineStage.export:
        return ExportView(match: entry.match, onExported: onRefresh);
      case PipelineStage.analyze:
        return AnalysisView(
          match: entry.match,
          onOpenTracking: () => onSelectStage(PipelineStage.track),
        );
      case PipelineStage.import:
        // Import is not a lens; the center stays on playback.
        return PlayerView(controller: controller);
    }
  }
}

/// The strip above the preview naming the feature and the video's format.
class CenterHeader extends StatelessWidget {
  /// Build the header for [match] at [stage].
  const CenterHeader({super.key, required this.match, required this.stage});

  /// The video whose format is shown.
  final MatchRecord match;

  /// The feature showing, where null means playback.
  final PipelineStage? stage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = SportcutTokens.of(context);
    final fps = match.frameRate;
    final fpsLabel = fps == null || fps <= 0
        ? null
        : '${fps.toStringAsFixed(fps.roundToDouble() == fps ? 0 : 2)} fps';
    final parts = <String>[
      resolutionLabel(match),
      if (fpsLabel != null) fpsLabel,
    ];
    return Container(
      height: 40,
      padding: EdgeInsets.symmetric(horizontal: tokens.space3),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: <Widget>[
          Text(
            'Preview',
            style: theme.textTheme.labelLarge?.copyWith(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
          SizedBox(width: tokens.space2),
          StudioChip(label: stage?.label ?? 'Playback'),
          const Spacer(),
          Text(
            parts.join(' · '),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The error state shown when the video list cannot be read.
class StudioError extends StatelessWidget {
  /// Build the error state.
  const StudioError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  /// The error text to show.
  final String message;

  /// Retry loading the videos.
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
              'The videos could not be read',
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
