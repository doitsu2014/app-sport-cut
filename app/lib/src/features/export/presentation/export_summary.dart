import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../app/design/components/sc_panel.dart';
import '../../../app/design/sc_typography.dart';
import '../../../app/design/sportcut_tokens.dart';
import '../../editing/domain/match_edit.dart';
import '../../library/domain/match_record.dart';
import '../../library/presentation/formatters.dart';
import 'export_providers.dart';

/// What the next render will produce, stated before it starts.
///
/// The headline carries the clip count, the runtime (title card, padding, and
/// clip spans), and the size of a reel already rendered in this session. The
/// two supporting lines state the overlay and audio choices, so the user never
/// has to infer what will be burned in or mixed (FR-EXP-09…FR-EXP-11).
class ExportSummary extends StatelessWidget {
  /// Build the summary for [edit].
  const ExportSummary({
    super.key,
    required this.edit,
    required this.match,
    this.includeScoreOverlays = true,
    this.reel,
  });

  /// The review the export will render.
  final MatchEdit edit;

  /// The recording the reel comes from, for the runtime clamp.
  final MatchRecord match;

  /// Whether score overlays will be burned in.
  final bool includeScoreOverlays;

  /// A reel already rendered in this session, when there is one.
  final ExportedReel? reel;

  @override
  Widget build(BuildContext context) {
    final SportcutPalette palette = SportcutPalette.of(context);
    final SportcutTokens tokens = SportcutTokens.of(context);
    final SportcutTypography typography = SportcutTypography.of(context);
    final String runtime = formatDuration(
      producedRuntimeSeconds(edit, match),
    );

    return ScPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '${edit.clips.length} clips · $runtime · ${_sizeLabel(reel)}',
            style: typography.sm14.copyWith(
              color: palette.fg,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: tokens.space2),
          Text(
            _overlayLine(),
            style: typography.xs12.copyWith(color: palette.muted),
          ),
          SizedBox(height: tokens.space1),
          Text(
            _audioLine(),
            style: typography.xs12.copyWith(color: palette.muted),
          ),
        ],
      ),
    );
  }

  /// Whether a scoreboard is burned in, and from which score.
  String _overlayLine() {
    if (!includeScoreOverlays) {
      return 'Score overlays are off for this export.';
    }
    final score = edit.score;
    if (score.isEmpty) {
      return 'No score confirmed yet, so no scoreboard will be burned in.';
    }
    return 'Scoreboard through ${score.left}–${score.right}.';
  }

  /// Which audio the reel carries.
  String _audioLine() {
    final String? music = edit.exportSettings.musicPath;
    final bool hasMusic = music != null && music.isNotEmpty;
    if (hasMusic && match.hasAudio) {
      return 'Match audio and ${p.basename(music)}.';
    }
    if (hasMusic) {
      return '${p.basename(music)} only; the recording has no audio.';
    }
    if (match.hasAudio) {
      return 'No music; match audio only.';
    }
    return 'No music; the recording has no audio.';
  }

  /// The produced size, when a reel already exists.
  String _sizeLabel(ExportedReel? rendered) {
    if (rendered == null) {
      return '—';
    }
    try {
      final File file = File(rendered.path);
      if (!file.existsSync()) {
        return '—';
      }
      return formatBytes(file.lengthSync());
    } on Object {
      return '—';
    }
  }
}
