import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/design/components/sc_calibration_overlay.dart';
import '../../../../app/design/sc_metrics.dart';
import '../../../../app/design/sc_typography.dart';
import '../../../../app/design/sportcut_tokens.dart';
import '../../../analysis/presentation/analysis_providers.dart';
import '../../../calibration/presentation/calibration_overlay_host.dart';
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
/// [LayoutBuilder], and sits on the page ground. Every stage keeps the shared
/// [VideoPreview] in the centre: Mark court and Player analysis add their
/// overlay to its aspect-fit box, and Prepare analysis and Export leave the
/// playback untouched because their work surfaces are the inspector panel and
/// the export sheet.
class PreviewPane extends StatelessWidget {
  /// Build the centre pane for the selected [entry].
  const PreviewPane({
    super.key,
    required this.entry,
    required this.controller,
    required this.stage,
    required this.onSelectStage,
  });

  /// The selected video.
  final MatchListEntry entry;

  /// The shared player for the selected video, or null until it is ready.
  final PlaybackController? controller;

  /// The selected feature, where null means playback.
  final PipelineStage? stage;

  /// Open another feature.
  final void Function(PipelineStage) onSelectStage;

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
  /// Every stage shares the one stage without a feature takeover; Review &
  /// score adds the score bug, and its controls live in the Rally inspector.
  /// Mark court and Player analysis draw their stage overlays here and put
  /// every control in the stage-aware inspector (D14). Prepare analysis opens
  /// its job and still plays here; Export opens the sheet and the playback
  /// stays mounted behind it.
  Widget _centre(MatchListEntry entry, PlaybackController? controller) {
    if (stage == null || stage == PipelineStage.import) {
      return VideoPreview(entry: entry, controller: controller);
    }
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return _featureView(entry, controller, stage!);
  }

  Widget _featureView(
    MatchListEntry entry,
    PlaybackController controller,
    PipelineStage stage,
  ) {
    switch (stage) {
      case PipelineStage.calibrate:
        // The inspector's CalibrationPanel owns orientation, save, and cancel;
        // the stage only draws the corners inside the footage's aspect box.
        return VideoPreview(
          entry: entry,
          controller: controller,
          transportAccent: false,
          underlay: const ScCalibrationScrim(),
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
        // The export sheet is the only editor; the centre stays on playback.
        return VideoPreview(entry: entry, controller: controller);
      case PipelineStage.analyze:
        // The panel in the inspector is the work surface; this host only opens
        // the app-wide analysis controller so the panel and the stage strip
        // see the manifest and the running job.
        return _AnalysisStage(entry: entry, controller: controller);
      case PipelineStage.import:
        // Import is not a lens; the center stays on playback.
        return VideoPreview(entry: entry, controller: controller);
    }
  }
}

/// Opens the analysis controller once and leaves playback on the stage.
///
/// The inspector's [AnalysisPanel] owns the prepare, rebuild, and artifact
/// controls; this host exists only so selecting Prepare analysis reads the
/// match's manifest and follows its job even when the inspector is hidden. The
/// preview itself is the ordinary [VideoPreview], with no takeover.
class _AnalysisStage extends ConsumerStatefulWidget {
  const _AnalysisStage({required this.entry, required this.controller});

  final MatchListEntry entry;
  final PlaybackController controller;

  @override
  ConsumerState<_AnalysisStage> createState() => _AnalysisStageState();
}

class _AnalysisStageState extends ConsumerState<_AnalysisStage> {
  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(covariant _AnalysisStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.match.id != widget.entry.match.id) {
      _open();
    }
  }

  /// Read this match's manifest; opening the same match is harmless.
  void _open() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        ref.read(analysisControllerProvider.notifier).open(widget.entry.match),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return VideoPreview(
      entry: widget.entry,
      controller: widget.controller,
    );
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
      constraints: const BoxConstraints(
        minHeight: ScMetrics.previewHeaderHeight,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space3,
        vertical: tokens.space1,
      ),
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
