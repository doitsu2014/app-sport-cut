import 'package:flutter/material.dart';

import '../../../../app/design/sc_metrics.dart';
import '../../../../app/design/sc_typography.dart';
import '../../../../app/design/sportcut_tokens.dart';
import '../../../analysis/presentation/analysis_view.dart';
import '../../../calibration/presentation/calibration_view.dart';
import '../../../export/presentation/export_view.dart';
import '../../../library/domain/match_record.dart';
import '../../../library/presentation/match_list_entry.dart';
import '../../../library/presentation/playback_controller.dart';
import '../../../tracking/presentation/player_tracking_view.dart';
import '../../domain/pipeline_stage.dart';
import 'studio_chrome.dart';
import 'video_preview.dart';

/// One shared preview in the centre of the studio.
///
/// The pane fills its column, keeps the [ScMetrics.previewMinWidth] floor via
/// [LayoutBuilder], and sits on the page ground. Play and Import draw the
/// shared [VideoPreview]; the remaining stages keep their existing feature
/// view, which still owns the centre until PR 7c turns them into panels.
class PreviewPane extends StatelessWidget {
  /// Build the centre pane for the selected [entry].
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
    final palette = SportcutPalette.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final width = constraints.maxWidth < ScMetrics.previewMinWidth
            ? ScMetrics.previewMinWidth
            : constraints.maxWidth;
        final controller = this.controller;
        return ColoredBox(
          color: palette.bg,
          child: SizedBox(
            width: width,
            height: constraints.maxHeight,
            child: Column(
              children: <Widget>[
                CenterHeader(match: entry.match, stage: stage),
                Expanded(
                  child: _centre(entry, facts, controller),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The centre for the current stage.
  ///
  /// Play, Import, Review & score, and Highlights share the one stage without
  /// a feature takeover; Review & score adds the score bug, and its controls
  /// live in the Rally inspector, while Highlights keeps the bug off and puts
  /// the clip details in the Clip inspector (PR 6a/6b). The remaining stages
  /// keep their existing views until PR 7c turns them into panels. Those views
  /// size themselves with `Expanded` and a fixed panel stack, so they cannot
  /// be placed under the stage without editing them.
  Widget _centre(
    MatchListEntry entry,
    Map<String, VideoStageFacts>? facts,
    PlaybackController? controller,
  ) {
    if (stage == null || stage == PipelineStage.import) {
      return VideoPreview(entry: entry, controller: controller);
    }
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return _featureView(entry, facts, controller);
  }

  Widget _featureView(
    MatchListEntry entry,
    Map<String, VideoStageFacts>? facts,
    PlaybackController controller,
  ) {
    switch (stage) {
      case null:
        return VideoPreview(entry: entry, controller: controller);
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
        return VideoPreview(
          entry: entry,
          controller: controller,
          showScoreBug: true,
        );
      case PipelineStage.highlight:
        // The selected clip plays in the shared stage; its details and the
        // reel live in the inspector's Clip tab (PR 6b).
        return VideoPreview(entry: entry, controller: controller);
      case PipelineStage.export:
        return ExportView(match: entry.match, onExported: onRefresh);
      case PipelineStage.analyze:
        return AnalysisView(
          match: entry.match,
          onOpenTracking: () => onSelectStage(PipelineStage.track),
        );
      case PipelineStage.import:
        // Import is not a lens; the center stays on playback.
        return VideoPreview(entry: entry, controller: controller);
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
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final fps = match.frameRate;
    final fpsLabel = fps == null || fps <= 0
        ? null
        : '${fps.toStringAsFixed(fps.roundToDouble() == fps ? 0 : 2)} fps';
    final parts = <String>[
      resolutionLabel(match),
      if (fpsLabel != null) fpsLabel,
    ];
    return Container(
      height: ScMetrics.previewHeaderHeight,
      padding: EdgeInsets.symmetric(horizontal: tokens.space3),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.borderSoft)),
      ),
      child: Row(
        children: <Widget>[
          Text(
            'Preview',
            style: typography.xs12.copyWith(
              color: palette.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: tokens.space2),
          StudioChip(label: stage?.label ?? 'Playback'),
          const Spacer(),
          Text(
            parts.join(' · '),
            style: typography.chrome9.copyWith(color: palette.muted),
          ),
        ],
      ),
    );
  }
}
