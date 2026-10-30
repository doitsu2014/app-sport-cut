import 'package:flutter/material.dart';

import '../../../app/design/components/sc_calibration_overlay.dart';
import '../../../app/design/sportcut_tokens.dart';
import '../../library/domain/match_record.dart';
import '../../library/presentation/match_list_entry.dart';
import '../../library/presentation/playback_controller.dart';
import '../../workspace/presentation/studio/video_preview.dart';
import 'calibration_overlay_host.dart';
import 'calibration_panel.dart';

/// Court calibration on the legacy full-screen route.
///
/// The stage and the work surface are the same two pieces the studio composes:
/// [VideoPreview] carries [CalibrationOverlayHost] in its aspect-fit box, and
/// [CalibrationPanel] carries orientation, save, cancel, and the hint. The
/// caller owns the controller's lifecycle; this view only renders it.
///
/// The save flow still reports the updated match through [onSaved] rather than
/// popping a route, so the studio can refresh its own state without navigating
/// and the legacy route can pop with the refreshed match.
class CalibrationView extends StatelessWidget {
  /// Build the calibration view over an already-managed controller.
  const CalibrationView({
    super.key,
    required this.match,
    required this.controller,
    this.onSaved,
  });

  /// Match being calibrated.
  final MatchRecord match;

  /// Playback backend, loaded and owned by the caller.
  final PlaybackController controller;

  /// Called with the updated match after a successful save.
  final void Function(MatchRecord updated)? onSaved;

  @override
  Widget build(BuildContext context) {
    final tokens = SportcutTokens.of(context);
    return Column(
      children: <Widget>[
        Expanded(
          flex: 3,
          child: VideoPreview(
            entry: MatchListEntry(match: match, recordingAvailable: true),
            controller: controller,
            transportAccent: false,
            underlay: const ScCalibrationScrim(),
            overlay: CalibrationOverlayHost(match: match),
          ),
        ),
        Flexible(
          flex: 2,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(tokens.space4),
            child: CalibrationPanel(
              match: match,
              onSaved: onSaved,
              onCancel: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
      ],
    );
  }
}
