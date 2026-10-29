import 'dart:async';
import 'dart:math' as math;

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
import 'player_tracking_providers.dart';
import 'tracking_overlay.dart';

/// The Player analysis work surface in the studio inspector.
///
/// The panel carries the quality readouts, the colour legend, window
/// navigation, the analysis action and its cancel, the prerequisites when the
/// court or the analysis files are missing, and the manual-review escape hatch.
/// The boxes themselves live on the shared preview in `TrackingOverlay`.
///
/// The panel is data-in / callback-out except for the tracking controller it
/// reads directly, which is what lets the stage and the panel describe the same
/// five-second window. It never applies an analysis result on its own: the
/// action and the cancel are explicit taps, and the host refreshes only through
/// [onAnalyzed].
class TrackingPanel extends ConsumerWidget {
  /// Build the Player analysis panel for [match].
  const TrackingPanel({
    super.key,
    required this.match,
    this.calibrated = true,
    this.analysisReady = true,
    this.onMarkCourt,
    this.onPrepare,
    this.onAnalyzed,
    this.onOpenScore,
  });

  /// Match being analyzed.
  final MatchRecord match;

  /// Whether the court is marked; false offers the Mark court action.
  final bool calibrated;

  /// Whether the analysis proxy and frames exist; false offers Prepare.
  final bool analysisReady;

  /// Called to mark the court.
  final VoidCallback? onMarkCourt;

  /// Called to prepare the analysis files.
  final VoidCallback? onPrepare;

  /// Called after a player-analysis run finishes and publishes new tracks.
  final VoidCallback? onAnalyzed;

  /// Called to review rallies without player tracks.
  final VoidCallback? onOpenScore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(playerTrackingControllerProvider);
    final controller = ref.read(playerTrackingControllerProvider.notifier);
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final tracks = tracking.tracks;
    final prerequisite = _prerequisite();
    final windowReady = tracking.windowEnd > tracking.windowStart;
    final canAnalyze = prerequisite == null && !tracking.running;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (tracking.problem != null) ...<Widget>[
          ScBanner(message: tracking.problem!, tone: ScBannerTone.danger),
          SizedBox(height: tokens.space3),
        ],
        if (prerequisite != null) ...<Widget>[
          ScBanner(
            message: prerequisite.message,
            actionLabel: prerequisite.actionLabel,
            onAction: prerequisite.onAction,
            tone: ScBannerTone.warning,
          ),
          SizedBox(height: tokens.space3),
        ],
        if (tracking.running) ...<Widget>[
          ScProgressJob(
            stageLabel: _stageLabel(tracking.stage),
            fraction: tracking.progress,
            detail: 'Player analysis',
            onCancel: () => unawaited(controller.cancel()),
          ),
          SizedBox(height: tokens.space3),
        ] else ...<Widget>[
          ScButton(
            label: tracks == null ? 'Analyze players' : 'Rebuild tracks',
            icon: ScIcons.review,
            expanded: true,
            enabled: canAnalyze,
            onPressed:
                canAnalyze ? () => unawaited(_analyze(ref)) : null,
          ),
          SizedBox(height: tokens.space2),
        ],
        ScButton(
          label: 'Review rallies manually',
          variant: ScButtonVariant.ghost,
          expanded: true,
          onPressed: onOpenScore,
        ),
        SizedBox(height: tokens.space3),
        const ScDivider(),
        SizedBox(height: tokens.space3),
        if (!tracking.loaded)
          Text(
            'Reading player tracks…',
            style: typography.xs12.copyWith(color: palette.muted),
          )
        else if (tracks == null)
          const ScEmptyState(
            message: 'No player tracks detected. Run player analysis, or '
                'review rallies manually.',
            icon: ScIcons.review,
            compact: true,
          )
        else ...<Widget>[
          const ScSectionHeader(label: 'Quality'),
          ScMetaList(
            items: <(String, String)>[
              ('Detections', _countLabel(tracks.count)),
              ('Coverage', '${(tracks.countQuality * 100).round()}%'),
              ('Gaps', '${tracks.gaps.length}'),
              if (windowReady)
                (
                  'Window',
                  '${formatDuration(tracking.windowStart)} – '
                      '${formatDuration(tracking.windowEnd)}',
                ),
            ],
          ),
          SizedBox(height: tokens.space3),
          _windowNavigation(context, ref, tracking),
          SizedBox(height: tokens.space3),
          TrackingLegend(
            colors: TrackingSideColors.of(palette),
            onFootage: false,
          ),
          for (final PlayerGapDto gap in tracks.gaps.take(3)) ...<Widget>[
            SizedBox(height: tokens.space2),
            Text(
              'Track #${gap.trackId} unseen from '
              '${formatDuration(gap.time.startSeconds)} to '
              '${formatDuration(gap.time.endSeconds)}',
              style: typography.xs12.copyWith(color: palette.muted),
            ),
          ],
          if (tracks.count == ObservedPlayerCountDto.unknown) ...<Widget>[
            SizedBox(height: tokens.space2),
            Text(
              'Player count is uncertain; check the video before confirming '
              'match details.',
              style: typography.xs12.copyWith(color: palette.muted),
            ),
          ],
        ],
      ],
    );
  }

  /// The prerequisite that blocks a new analysis run, if any.
  ({String message, String actionLabel, VoidCallback? onAction})?
      _prerequisite() {
    if (!calibrated) {
      return (
        message: 'Player analysis needs the court marked first.',
        actionLabel: 'Mark court',
        onAction: onMarkCourt,
      );
    }
    if (!analysisReady) {
      return (
        message: 'Player analysis needs the analysis files prepared first.',
        actionLabel: 'Prepare analysis',
        onAction: onPrepare,
      );
    }
    return null;
  }

  /// Run player analysis and tell the host that new tracks may exist.
  ///
  /// The callback runs on every outcome, matching the old view: a cancelled or
  /// failed run can still have written nothing, so refreshing is cheap and
  /// never leaves the rail stale.
  Future<void> _analyze(WidgetRef ref) async {
    await ref.read(playerTrackingControllerProvider.notifier).analyze(match);
    onAnalyzed?.call();
  }

  /// Move the loaded window one five-second step backward or forward.
  ///
  /// The controller loads a five-second window centred two seconds before the
  /// position it is given, so the caller passes the desired window start plus
  /// two seconds; the engine clamps the first window at zero.
  Widget _windowNavigation(
    BuildContext context,
    WidgetRef ref,
    PlayerTrackingState tracking,
  ) {
    final tokens = SportcutTokens.of(context);
    final enabled = tracking.loaded && !tracking.loading && !tracking.running;
    return Row(
      children: <Widget>[
        Expanded(
          child: ScButton.compact(
            label: 'Previous',
            icon: ScIcons.chevronLeft,
            variant: ScButtonVariant.ghost,
            enabled: enabled,
            onPressed: enabled ? () => _stepWindow(ref, forward: false) : null,
          ),
        ),
        SizedBox(width: tokens.space2),
        Expanded(
          child: ScButton.compact(
            label: 'Next',
            icon: ScIcons.chevronRight,
            variant: ScButtonVariant.ghost,
            enabled: enabled,
            onPressed: enabled ? () => _stepWindow(ref, forward: true) : null,
          ),
        ),
      ],
    );
  }

  /// Load the window before or after the current one.
  void _stepWindow(WidgetRef ref, {required bool forward}) {
    final tracking = ref.read(playerTrackingControllerProvider);
    final start = forward
        ? tracking.windowEnd
        : math.max(0.0, tracking.windowStart - 5.0);
    unawaited(
      ref
          .read(playerTrackingControllerProvider.notifier)
          .loadWindow(match, start + 2.0),
    );
  }

  /// The observed-player count in words.
  static String _countLabel(ObservedPlayerCountDto count) => switch (count) {
        ObservedPlayerCountDto.two => 'Two players observed',
        ObservedPlayerCountDto.four => 'Four players observed',
        ObservedPlayerCountDto.unknown => 'Player count unknown',
      };

  /// The engine's stage name in user-facing words.
  static String _stageLabel(String? stage) => switch (stage) {
        'frames' => 'Sampling frames…',
        'person_detection' => 'Finding people…',
        'player_tracking' || 'player_analysis' => 'Following players…',
        'publish_tracks' => 'Saving player tracks…',
        _ => 'Analyzing players…',
      };
}
