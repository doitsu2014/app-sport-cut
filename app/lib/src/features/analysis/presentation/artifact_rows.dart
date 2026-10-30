import 'package:flutter/material.dart';

import '../../../app/design/components/sc_panel.dart';
import '../../../app/design/sc_icons.dart';
import '../../../app/design/sc_metrics.dart';
import '../../../app/design/sc_typography.dart';
import '../../../app/design/sportcut_tokens.dart';
import '../../../bridge/sportcut_engine.dart';
import '../../library/presentation/formatters.dart';

/// The artifacts the analysis job produced, as compact studio rows.
///
/// Each row carries the artifact kind, a local state badge, the size the engine
/// reported, and the path it lives at. The badge is a READY / PARTIAL / MISSING
/// word with an icon and a semantic colour, so the row never relies on colour
/// alone. A [DataTable] is deliberately not used: the inspector is 320 px wide
/// and the four facts read better as a stacked row than as columns.
class ArtifactRows extends StatelessWidget {
  /// Build rows for [artifacts], in manifest order.
  const ArtifactRows({super.key, required this.artifacts});

  /// Artifacts to list.
  final List<ArtifactDto> artifacts;

  @override
  Widget build(BuildContext context) {
    final SportcutTokens tokens = SportcutTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int index = 0; index < artifacts.length; index += 1) ...<Widget>[
          if (index > 0)
            Padding(
              padding: EdgeInsets.symmetric(vertical: tokens.space1),
              child: const ScDivider(),
            ),
          _ArtifactRow(number: index + 1, artifact: artifacts[index]),
        ],
      ],
    );
  }
}

/// One artifact: kind and state badge on the numbered row, path and size
/// beneath.
class _ArtifactRow extends StatelessWidget {
  const _ArtifactRow({required this.number, required this.artifact});

  final int number;
  final ArtifactDto artifact;

  @override
  Widget build(BuildContext context) {
    final SportcutPalette palette = SportcutPalette.of(context);
    final SportcutTokens tokens = SportcutTokens.of(context);
    final SportcutTypography typography = SportcutTypography.of(context);
    final int? bytes = artifact.sizeBytes;
    final _ArtifactBadge badge = _ArtifactBadge.of(artifact.state, palette);
    final bool isMissing = artifact.state == ArtifactStateDto.missing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.space2),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: ScMetrics.rowCompact),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: ScMetrics.courtHandleVisual,
                  child: Text(
                    number.toString().padLeft(2, '0'),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: typography.timecode11.copyWith(color: palette.muted),
                  ),
                ),
                SizedBox(width: tokens.space3),
                Expanded(
                  child: Text(
                    artifact.kind,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.sm14.copyWith(
                      color: isMissing ? palette.danger : palette.fg,
                    ),
                  ),
                ),
                SizedBox(width: tokens.space2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      badge.icon,
                      size: tokens.space3,
                      color: badge.color,
                    ),
                    SizedBox(width: tokens.space1),
                    Text(
                      badge.word,
                      style: typography.chrome9.copyWith(color: badge.color),
                    ),
                  ],
                ),
                SizedBox(width: tokens.space2),
                Text(
                  bytes == null ? '—' : formatBytes(bytes),
                  style: typography.timecode11.copyWith(color: palette.muted),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            left: ScMetrics.courtHandleVisual + tokens.space3,
            right: tokens.space2,
            bottom: tokens.space1,
          ),
          child: Text(
            artifact.relativePath,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typography.micro10.copyWith(color: palette.muted),
          ),
        ),
      ],
    );
  }
}

/// The analysis inspector's local state vocabulary for one artifact.
///
/// An artifact has exactly three manifest states, so the inspector uses its
/// own READY / PARTIAL / MISSING words rather than the studio's larger status
/// set. The word, icon, and colour always travel together.
class _ArtifactBadge {
  const _ArtifactBadge({
    required this.word,
    required this.icon,
    required this.color,
  });

  /// Resolve the badge for [state] against [palette].
  factory _ArtifactBadge.of(
    ArtifactStateDto state,
    SportcutPalette palette,
  ) {
    return switch (state) {
      ArtifactStateDto.final_ => _ArtifactBadge(
          word: 'READY',
          icon: ScIcons.checkCircle,
          color: palette.success,
        ),
      ArtifactStateDto.nonFinal => _ArtifactBadge(
          word: 'PARTIAL',
          icon: ScIcons.warning,
          color: palette.warn,
        ),
      ArtifactStateDto.missing => _ArtifactBadge(
          word: 'MISSING',
          icon: ScIcons.blocked,
          color: palette.danger,
        ),
    };
  }

  /// The state word, already uppercase.
  final String word;

  /// The icon that reinforces the word.
  final IconData icon;

  /// The semantic state colour.
  final Color color;
}
