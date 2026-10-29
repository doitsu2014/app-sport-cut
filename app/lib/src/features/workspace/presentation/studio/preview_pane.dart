import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/design/sc_metrics.dart';
import '../../../../app/design/sc_typography.dart';
import '../../../../app/design/sportcut_tokens.dart';
import '../../../analysis/presentation/analysis_view.dart';
import '../../../calibration/presentation/calibration_overlay_host.dart';
import '../../../export/presentation/export_view.dart';
import '../../../library/domain/match_record.dart';
import '../../../library/presentation/match_list_entry.dart';
import '../../../library/presentation/playback_controller.dart';
import '../../../tracking/presentation/player_tracking_providers.dart';
import '../../../tracking/presentation/tracking_overlay.dart';
import '../../domain/pipeline_stage.dart';
import 'studio_chrome.dart';
import 'video_preview.dart';

/// One shared preview in the centre of the studio.
///
/// The pane fills its column, keeps the [ScMetrics.previewMinWidth] floor via
/// [LayoutBuilder], and sits on the page ground. Play, Import, Mark court,
/// Player analysis, Review & score, and Highlights draw the shared
/// [VideoPreview]; Mark court and Player analysis add their overlay to its
/// aspect-fit box. Prepare analysis and Export still keep their existing view
/// until PR 7a and PR 7b turn them into panels.
class PreviewPane extends StatelessWidget {
  /// Build the centre pane for the selected [entry].
  const PreviewPane({
    super.key,
    required this.entry,
    required this.controller,
    required this.stage,
    required this.onSelectStage,
    required this.onRefresh,
  });

  /// The selected video.
  final MatchListEntry entry;

  /// The shared player for the selected video, or null until it is ready.
  final PlaybackController? controller;

  /// The selected feature, where null means playback.
  final PipelineStage? stage;

  /// Open another feature.
  final void Function(PipelineStage) onSelectStage;

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
                  child: _centre(entry, controller),
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
  /// Play, Import, Mark court, Player analysis, Review & score, and Highlights
  /// share the one stage without a feature takeover; Review & score adds the
  /// score bug, and its controls live in the Rally inspector. Mark court and
  /// Player analysis draw their stage overlays here and put every control in
  /// the stage-aware inspector (D14). Prepare analysis and Export keep their
  /// existing views until their own panel PRs land.
  Widget _centre(MatchListEntry entry, PlaybackController? controller) {
    if (stage == null || stage == PipelineStage.import) {
      return VideoPreview(entry: entry, controller: controller);
    }
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return _featureView(entry, controller);
  }

  Widget _featureView(MatchListEntry entry, PlaybackController controller) {
    switch (stage) {
      case null:
        return VideoPreview(entry: entry, controller: controller);
      case PipelineStage.calibrate:
        // The inspector's CalibrationPanel owns orientation, save, and cancel;
        // the stage only draws the corners inside the footage's aspect box.
        return VideoPreview(
          entry: entry,
          controller: controller,
          overlay: CalibrationOverlayHost(match: entry.match),
        );
      case PipelineStage.track:
        // Boxes share the stage's aspect box; the inspector's TrackingPanel
        // owns the readouts, the legend, and the analysis actions.
        return _TrackingStage(entry: entry, controller: controller);
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

/// Opens the tracking session once and draws the stage overlay.
///
/// The host sits above [VideoPreview] so the session is opened even when the
/// recording is missing and the stage paints [ScMissingRecording] instead of
/// its overlay: the inspector can still report the tracks already produced.
class _TrackingStage extends ConsumerStatefulWidget {
  const _TrackingStage({required this.entry, required this.controller});

  final MatchListEntry entry;
  final PlaybackController controller;

  @override
  ConsumerState<_TrackingStage> createState() => _TrackingStageState();
}

class _TrackingStageState extends ConsumerState<_TrackingStage> {
  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(covariant _TrackingStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.match.id != widget.entry.match.id) {
      _open();
    }
  }

  /// Read this match's tracks, starting at the beginning.
  void _open() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        ref
            .read(playerTrackingControllerProvider.notifier)
            .open(widget.entry.match),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return VideoPreview(
      entry: widget.entry,
      controller: widget.controller,
      overlay: TrackingOverlay(
        match: widget.entry.match,
        controller: widget.controller,
      ),
    );
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
