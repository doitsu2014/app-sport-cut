import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/design/components/sc_actions.dart';
import '../../../app/design/sc_icons.dart';
import '../../../app/design/sc_typography.dart';
import '../../../app/design/sportcut_tokens.dart';
import '../../library/presentation/formatters.dart';
import 'export_providers.dart';

/// The finished reel: its engine-produced name, clip count, and runtime.
///
/// The runtime is the one captured when the render finished, so it includes
/// the title card and the padding the engine actually wrote (FR-EXP-13). The
/// existing completion actions stay here: play the reel and hand the file to
/// the macOS share sheet. The render control lives in the form the host draws
/// beside this card, so "render again" keeps the settings editable. [note] is
/// set when this reel is the earlier one kept after a failed re-render
/// (FR-EXP-25).
class ExportSuccess extends StatelessWidget {
  /// Build the success block for [reel].
  const ExportSuccess({
    super.key,
    required this.reel,
    this.note,
    this.onPlay,
    this.onDone,
  });

  /// The reel the engine produced.
  final ExportedReel reel;

  /// An extra line explaining a kept earlier reel.
  final String? note;

  /// Play the reel in the shared player.
  final VoidCallback? onPlay;

  /// Close the export sheet.
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final SportcutPalette palette = SportcutPalette.of(context);
    final SportcutTokens tokens = SportcutTokens.of(context);
    final SportcutTypography typography = SportcutTypography.of(context);
    final String? noteText = note;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: Icon(
            ScIcons.checkCircle,
            size: tokens.space8,
            color: palette.success,
          ),
        ),
        SizedBox(height: tokens.space2),
        Text(
          'Highlight reel exported',
          textAlign: TextAlign.center,
          style: typography.title20.copyWith(color: palette.fg),
        ),
        SizedBox(height: tokens.space1),
        Text(
          '${reel.fileName} · ${reel.clipCount} clips · '
          '${formatDuration(reel.durationSeconds)}',
          textAlign: TextAlign.center,
          style: typography.xs12.copyWith(color: palette.muted),
        ),
        if (noteText != null) ...<Widget>[
          SizedBox(height: tokens.space2),
          Text(
            noteText,
            textAlign: TextAlign.center,
            style: typography.xs12.copyWith(color: palette.warn),
          ),
        ],
        SizedBox(height: tokens.space4),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: tokens.space2,
          runSpacing: tokens.space2,
          children: <Widget>[
            if (onPlay != null)
              ScButton.compact(
                label: 'Play the reel',
                icon: ScIcons.play,
                variant: ScButtonVariant.secondary,
                onPressed: onPlay,
              ),
            ScButton.compact(
              label: 'Save or share',
              icon: ScIcons.download,
              onPressed: () => _share(reel),
            ),
            if (onDone != null)
              ScButton.compact(
                label: 'Done',
                variant: ScButtonVariant.secondary,
                onPressed: onDone,
              ),
          ],
        ),
      ],
    );
  }

  static Future<void> _share(ExportedReel reel) async {
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(reel.path)],
        text: 'Badminton highlights',
      ),
    );
  }
}
