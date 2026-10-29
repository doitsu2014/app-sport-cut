import 'package:flutter/material.dart';

import '../../../app/design/components/sc_banner.dart';
import '../../../app/design/components/sc_progress_job.dart';
import '../../../app/design/sc_typography.dart';
import '../../../app/design/sportcut_tokens.dart';
import 'export_providers.dart';
import 'export_success.dart';

/// The stage label the engine last reported, in the user's words.
///
/// Every stage keeps a label, so progress never runs without one (FR-EXP-23).
String exportStageLabel(String? stage) => switch (stage) {
      'prepare' => 'Reading the recording…',
      'render' => 'Rendering the reel…',
      'finalize' => 'Finishing the file…',
      _ => 'Exporting the highlight reel…',
    };

/// A render in flight: its stage, its determinate bar, and its cancel action.
///
/// The bar is determinate whenever the engine has reported a fraction; before
/// the first report it stays an empty track, never an unexplained spinner. The
/// render keeps running in the app-wide controller if the sheet is closed.
class ExportProgress extends StatelessWidget {
  /// Build the progress block.
  const ExportProgress({
    super.key,
    required this.stageLabel,
    required this.fraction,
    this.onCancel,
  });

  /// The stage the job is running, for example "Rendering the reel…".
  final String stageLabel;

  /// Completion in the range 0 to 1, or null when none has arrived yet.
  final double? fraction;

  /// Stop the render cooperatively.
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return ScProgressJob(
      stageLabel: stageLabel,
      fraction: fraction,
      detail: 'Rendering happens on this device. Closing the sheet does not '
          'stop it; cancel to stop.',
      onCancel: onCancel,
    );
  }
}

/// A failed render, with the reason and the reel from earlier.
///
/// The app-wide controller discards its success state on failure, so the host
/// keeps the last rendered reel and passes it here. When there is one it stays
/// visible and shareable, and the message says it is the earlier reel
/// (FR-EXP-25). The host draws the form and render control below this block.
class ExportFailure extends StatelessWidget {
  /// Build the failure block.
  const ExportFailure({
    super.key,
    required this.message,
    this.previousReel,
    this.onPlay,
  });

  /// Why the render failed, as the engine stated it.
  final String message;

  /// The reel rendered earlier in this session, when there is one.
  final ExportedReel? previousReel;

  /// Play the earlier reel.
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final SportcutTokens tokens = SportcutTokens.of(context);
    final SportcutTypography typography = SportcutTypography.of(context);
    final SportcutPalette palette = SportcutPalette.of(context);
    final ExportedReel? previous = previousReel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ScBanner(message: message, tone: ScBannerTone.danger),
        if (previous != null) ...<Widget>[
          SizedBox(height: tokens.space3),
          Text(
            'The reel from earlier is still available.',
            style: typography.xs12.copyWith(color: palette.muted),
          ),
          SizedBox(height: tokens.space2),
          ExportSuccess(
            reel: previous,
            note: 'The new render failed, so this is the reel from before.',
            onPlay: onPlay,
          ),
        ],
      ],
    );
  }
}
