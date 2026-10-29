import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/components/sc_actions.dart';
import '../../../app/design/components/sc_banner.dart';
import '../../../app/design/components/sc_empty_state.dart';
import '../../../app/design/components/sc_panel.dart';
import '../../../app/design/components/sc_progress_job.dart';
import '../../../app/design/sc_icons.dart';
import '../../../app/design/sc_typography.dart';
import '../../../app/design/sportcut_tokens.dart';
import '../../../bridge/sportcut_engine.dart';
import '../../library/domain/match_record.dart';
import '../../library/presentation/formatters.dart';
import 'analysis_providers.dart';
import 'artifact_rows.dart';

/// The Prepare analysis work surface in the studio inspector.
///
/// The panel carries what the analysis job needs and what it produced: the
/// prepare and rebuild actions, the running job with its stage label and
/// determinate progress, the busy-elsewhere explanation, the failure banner,
/// and the artifact rows. The preview stays on playback for this stage; the
/// panel is the whole work surface (ADR-0003 D14).
///
/// It reads the app-wide [analysisControllerProvider] directly, like the other
/// stage panels: the job belongs to the controller, so it keeps running when
/// the panel closes and never duplicates its state. The host opens the
/// controller when the stage is selected; the legacy [AnalysisView] does the
/// same for its route.
class AnalysisPanel extends ConsumerWidget {
  /// Build the panel for [match].
  const AnalysisPanel({super.key, required this.match, this.onOpenTracking});

  /// Match whose analysis files are shown.
  final MatchRecord match;

  /// Called when the user wants to review player analysis.
  final VoidCallback? onOpenTracking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AnalysisState state = ref.watch(analysisControllerProvider);
    final AnalysisController controller =
        ref.read(analysisControllerProvider.notifier);
    final SportcutPalette palette = SportcutPalette.of(context);
    final SportcutTokens tokens = SportcutTokens.of(context);
    final SportcutTypography typography = SportcutTypography.of(context);

    final bool viewing = state.matchId == match.id;
    final bool running = state.runningFor(match.id);
    final bool busyElsewhere = state.busyElsewhere(match.id);
    final List<ArtifactDto> artifacts =
        state.manifest?.artifacts ?? const <ArtifactDto>[];
    final List<ArtifactDto> missing = state.missing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          match.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: typography.body16.copyWith(
            color: palette.fg,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: tokens.space1),
        Text(
          _summary(match),
          style: typography.xs12.copyWith(color: palette.muted),
        ),
        SizedBox(height: tokens.space4),
        const ScSectionHeader(label: 'Analysis files'),
        Text(
          'Preparing makes a smaller proxy video, the analysis audio, and '
          'sampled frames. Player analysis needs them. Your recording is not '
          'changed.',
          style: typography.sm14.copyWith(color: palette.fg2),
        ),
        SizedBox(height: tokens.space3),
        if (viewing && state.problem != null) ...<Widget>[
          ScBanner(
            message: state.problem!,
            actionLabel: 'Dismiss',
            onAction: controller.clearProblem,
          ),
          SizedBox(height: tokens.space3),
        ],
        if (running)
          ScProgressJob(
            stageLabel: _stageLabel(state.jobKind, state.stage),
            fraction:
                state.progress > 0 ? state.progress.clamp(0.0, 1.0) : null,
            detail: 'Running in the background. You can switch stages or '
                'videos; the studio keeps following it.',
            onCancel: controller.cancel,
          )
        else if (!viewing || !state.loaded)
          const SizedBox.shrink()
        else if (busyElsewhere && state.unprepared)
          _BusyElsewhere(title: state.runningTitle)
        else if (state.unprepared)
          ScButton(
            label: 'Start preparing analysis',
            icon: ScIcons.play,
            expanded: true,
            onPressed: () => unawaited(controller.prepare(match)),
          )
        else ...<Widget>[
          ScButton(
            label: missing.isEmpty
                ? 'Nothing to rebuild'
                : 'Rebuild ${missing.length} missing '
                    '${missing.length == 1 ? 'file' : 'files'}',
            icon: ScIcons.running,
            variant: ScButtonVariant.secondary,
            expanded: true,
            enabled: missing.isNotEmpty && !busyElsewhere,
            onPressed: missing.isEmpty || busyElsewhere
                ? null
                : () => unawaited(controller.repair(match)),
          ),
          if (busyElsewhere) ...<Widget>[
            SizedBox(height: tokens.space2),
            Text(
              'Another video is being prepared'
              '${state.runningTitle == null ? '' : ' (${state.runningTitle})'}. '
              'This one can start when it finishes.',
              style: typography.xs12.copyWith(color: palette.muted),
            ),
          ],
        ],
        if (onOpenTracking != null) ...<Widget>[
          SizedBox(height: tokens.space3),
          ScButton(
            label: 'Review player analysis',
            icon: ScIcons.running,
            variant: ScButtonVariant.ghost,
            expanded: true,
            onPressed: onOpenTracking,
          ),
        ],
        SizedBox(height: tokens.space4),
        ScSectionHeader(
          label: 'Artifacts',
          count: state.loaded ? artifacts.length : null,
        ),
        SizedBox(height: tokens.space1),
        if (!viewing || !state.loaded)
          const ScProgressJob(
            stageLabel: 'Reading the analysis files…',
            fraction: null,
          )
        else if (artifacts.isEmpty)
          const ScEmptyState(
            message: 'This match has no analysis files yet. Start preparing '
                'analysis to make them.',
            compact: true,
          )
        else
          ArtifactRows(artifacts: artifacts),
      ],
    );
  }

  /// A factual one-line summary of the recording.
  static String _summary(MatchRecord match) {
    final List<String> parts = <String>[
      formatDuration(match.durationSeconds),
      if (match.videoWidth != null && match.videoHeight != null)
        '${match.videoWidth}×${match.videoHeight}',
      if (match.frameRate != null) '${match.frameRate!.toStringAsFixed(2)} fps',
      if (match.hasAudio) 'audio',
    ];
    return parts.join('  ·  ');
  }

  /// The stage label for a running job, including the job kind.
  static String _stageLabel(AnalysisJobKind? kind, String? stage) {
    final String verb =
        kind == AnalysisJobKind.rebuild ? 'Rebuilding' : 'Making';
    return switch (stage) {
      'probe' => 'Reading the recording…',
      'proxy' => '$verb the proxy…',
      'audio' => '$verb the analysis audio…',
      'frames' => 'Sampling frames…',
      'regenerate' => 'Working out what to rebuild…',
      _ => 'Starting…',
    };
  }
}

/// Another match's job holds the engine, so this one cannot start.
class _BusyElsewhere extends StatelessWidget {
  const _BusyElsewhere({required this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    final SportcutTokens tokens = SportcutTokens.of(context);
    final SportcutTypography typography = SportcutTypography.of(context);
    final SportcutPalette palette = SportcutPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Another video is being prepared${title == null ? '' : ' ($title)'}. '
          'This one can start when it finishes.',
          style: typography.sm14.copyWith(color: palette.fg2),
        ),
        SizedBox(height: tokens.space3),
        const ScButton(
          label: 'Start preparing analysis',
          icon: ScIcons.play,
          expanded: true,
          onPressed: null,
        ),
      ],
    );
  }
}
