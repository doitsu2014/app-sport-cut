import 'package:flutter/material.dart';

import '../../../app/design/components/sc_panel.dart';
import '../../../app/design/components/sc_pipeline_row.dart';
import '../../../app/design/sc_metrics.dart';
import '../../../app/design/sc_status.dart';
import '../../../app/design/sc_typography.dart';
import '../../../app/design/sportcut_tokens.dart';
import '../../../bridge/sportcut_engine.dart';
import '../../library/presentation/formatters.dart';

/// The artifacts the analysis job produced, as compact studio rows.
///
/// Each row carries the artifact kind, its manifest state, the size the engine
/// reported, and the path it lives at. The state is a [ScStatus] word plus
/// icon, so the row never relies on colour alone. A [DataTable] is deliberately
/// not used: the inspector is 320 px wide and the four facts read better as a
/// stacked row than as columns.
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

/// One artifact: kind and state on the pipeline row, path and size beneath.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ScPipelineRow(
          number: number,
          name: artifact.kind,
          status: _status(artifact.state),
          trailing: Text(
            bytes == null ? '—' : formatBytes(bytes),
            style: typography.timecode11.copyWith(color: palette.muted),
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

  /// Map a manifest state onto the shell's status vocabulary.
  ScStatus _status(ArtifactStateDto state) => switch (state) {
        ArtifactStateDto.final_ => ScStatus.done,
        ArtifactStateDto.nonFinal => ScStatus.needsReview,
        ArtifactStateDto.missing => ScStatus.blocked,
      };
}
