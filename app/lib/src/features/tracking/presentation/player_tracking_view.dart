import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/sportcut_tokens.dart';
import '../../library/domain/match_record.dart';
import '../../library/presentation/match_list_entry.dart';
import '../../library/presentation/playback_controller.dart';
import '../../workspace/presentation/studio/video_preview.dart';
import 'player_tracking_providers.dart';
import 'tracking_overlay.dart';
import 'tracking_panel.dart';

/// Review detected people and their court-side tracks beside the recording.
///
/// The legacy route composes the same two pieces the studio does: the shared
/// [VideoPreview] with [TrackingOverlay] on its stage, and [TrackingPanel] as
/// the work surface below. The caller owns [controller]'s lifecycle, so the
/// studio can share one player across Play, Calibration, and this view.
///
/// The view opens the tracking session once per match, as the old view did.
/// That keeps the panel populated even when the recording itself is missing:
/// the stage then shows its honest missing state, but the tracks that were
/// already produced are still reportable.
class PlayerTrackingView extends ConsumerStatefulWidget {
  /// Build the tracking view over an already-managed controller.
  const PlayerTrackingView({
    super.key,
    required this.match,
    required this.controller,
    this.onOpenScore,
    this.onAnalyzed,
    this.calibrated = true,
    this.analysisReady = true,
    this.onMarkCourt,
    this.onPrepare,
  });

  /// Match being analyzed.
  final MatchRecord match;

  /// Playback backend, loaded and owned by the caller.
  final PlaybackController controller;

  /// Called when the user wants to review rallies.
  final VoidCallback? onOpenScore;

  /// Called after a player-analysis run finishes and publishes new tracks.
  final VoidCallback? onAnalyzed;

  /// Whether the court is marked.
  final bool calibrated;

  /// Whether the analysis proxy/frames exist.
  final bool analysisReady;

  /// Called to mark the court.
  final VoidCallback? onMarkCourt;

  /// Called to prepare the analysis files.
  final VoidCallback? onPrepare;

  @override
  ConsumerState<PlayerTrackingView> createState() =>
      _PlayerTrackingViewState();
}

class _PlayerTrackingViewState extends ConsumerState<PlayerTrackingView> {
  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(covariant PlayerTrackingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.id != widget.match.id) {
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
            .open(widget.match),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SportcutTokens.of(context);
    return Column(
      children: <Widget>[
        Expanded(
          flex: 3,
          child: VideoPreview(
            entry: MatchListEntry(
              match: widget.match,
              recordingAvailable: true,
            ),
            controller: widget.controller,
            overlay: TrackingOverlay(
              match: widget.match,
              controller: widget.controller,
            ),
          ),
        ),
        Flexible(
          flex: 2,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(tokens.space4),
            child: TrackingPanel(
              match: widget.match,
              calibrated: widget.calibrated,
              analysisReady: widget.analysisReady,
              onMarkCourt: widget.onMarkCourt,
              onPrepare: widget.onPrepare,
              onAnalyzed: widget.onAnalyzed,
              onOpenScore: widget.onOpenScore,
            ),
          ),
        ),
      ],
    );
  }
}
