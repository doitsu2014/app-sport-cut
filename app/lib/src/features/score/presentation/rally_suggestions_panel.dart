import 'package:flutter/material.dart';

import '../../../app/design/components/sc_actions.dart';
import '../../../app/design/components/sc_banner.dart';
import '../../../app/design/components/sc_panel.dart';
import '../../../app/design/components/sc_progress_job.dart';
import '../../../app/design/sc_typography.dart';
import '../../../app/design/sportcut_tokens.dart';
import '../../../bridge/sportcut_engine.dart';
import '../../editing/domain/rally.dart';
import '../../library/presentation/formatters.dart';
import '../../rally/presentation/rally_review_providers.dart';

/// The engine's rally candidates, waiting for an explicit decision.
///
/// A candidate is never applied on its own: accept, adjust, and dismiss are
/// the only paths, and every one of them writes a decision first. The widget is
/// data-in / callback-out and has no expander or fixed-height list.
class RallySuggestionsPanel extends StatelessWidget {
  /// Build the suggestion section.
  const RallySuggestionsPanel({
    super.key,
    required this.review,
    required this.canAnalyze,
    required this.rallies,
    required this.busy,
    required this.onAnalyze,
    required this.onCancel,
    required this.onAccept,
    required this.onAdjust,
    required this.onDismiss,
  });

  /// The rally-review session.
  final RallyReviewState review;

  /// Whether segmentation has the inputs it needs.
  final bool canAnalyze;

  /// The match's rallies, used to flag candidates that overlap a reviewed one.
  final List<Rally> rallies;

  /// Whether a review change is being written.
  final bool busy;

  /// Starts a segmentation run.
  final VoidCallback onAnalyze;

  /// Cancels a running segmentation job.
  final VoidCallback onCancel;

  /// Accepts a candidate as proposed.
  final ValueChanged<RallySuggestionDto> onAccept;

  /// Opens the adjustment dialog for a candidate.
  final ValueChanged<RallySuggestionDto> onAdjust;

  /// Dismisses a candidate for this generation.
  final ValueChanged<RallySuggestionDto> onDismiss;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final suggestions = review.suggestions;
    final pending = review.pending;
    final problem = review.problem;
    final restCount =
        suggestions?.timeline.where((span) => span.kind == 'rest').length ?? 0;
    final unknownCount =
        suggestions?.timeline.where((span) => span.kind == 'unknown').length ??
            0;
    final status = review.running
        ? 'Analyzing player motion…'
        : suggestions == null
            ? 'Manual marking is available.'
            : '$restCount rest · $unknownCount unknown intervals';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ScSectionHeader(
          label: 'Rally suggestions',
          count: pending.isEmpty ? null : pending.length,
        ),
        Text(status, style: typography.xs12.copyWith(color: palette.muted)),
        if (problem != null) ...<Widget>[
          SizedBox(height: tokens.space2),
          ScBanner(message: problem, tone: ScBannerTone.warning),
        ],
        SizedBox(height: tokens.space2),
        if (review.running)
          ScProgressJob(
            stageLabel: review.stage ?? 'Preparing analysis…',
            fraction: review.progress,
            onCancel: onCancel,
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: ScButton.compact(
              label: 'Analyze rallies',
              variant: ScButtonVariant.secondary,
              enabled: canAnalyze && !busy,
              onPressed: onAnalyze,
            ),
          ),
        if (suggestions != null && pending.isEmpty) ...<Widget>[
          SizedBox(height: tokens.space2),
          Text(
            'No unreviewed suggestions. You can still mark rallies.',
            style: typography.xs12.copyWith(color: palette.muted),
          ),
        ],
        if (pending.isNotEmpty) ...<Widget>[
          SizedBox(height: tokens.space2),
          for (final candidate in pending) ...<Widget>[
            _SuggestionTile(
              candidate: candidate,
              overlaps: _overlaps(candidate),
              busy: busy || review.busy,
              onAccept: () => onAccept(candidate),
              onAdjust: () => onAdjust(candidate),
              onDismiss: () => onDismiss(candidate),
            ),
            SizedBox(height: tokens.space2),
          ],
        ],
      ],
    );
  }

  /// Whether [candidate] overlaps a rally the user already reviewed.
  bool _overlaps(RallySuggestionDto candidate) {
    for (final rally in rallies) {
      if (rally.startSeconds < candidate.endSeconds &&
          rally.endSeconds > candidate.startSeconds) {
        return true;
      }
    }
    return false;
  }
}

/// One unresolved rally candidate.
class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.candidate,
    required this.overlaps,
    required this.busy,
    required this.onAccept,
    required this.onAdjust,
    required this.onDismiss,
  });

  final RallySuggestionDto candidate;
  final bool overlaps;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onAdjust;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final meta = overlaps
        ? 'Overlaps a reviewed rally · adjust or dismiss'
        : 'Signal quality ${(candidate.quality * 100).round()}%'
            '${candidate.audioAvailable ? ' · audio available' : ' · motion only'}';

    return Container(
      padding: EdgeInsets.all(tokens.space3),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.borderSoft),
        borderRadius: BorderRadius.circular(tokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '${formatDuration(candidate.startSeconds)}–'
            '${formatDuration(candidate.endSeconds)}',
            style: SportcutTypography.withTabular(typography.timecode11)
                .copyWith(color: palette.fg),
          ),
          SizedBox(height: tokens.space1),
          Text(
            meta,
            style: typography.xs12.copyWith(
              color: overlaps ? palette.warn : palette.muted,
            ),
          ),
          SizedBox(height: tokens.space2),
          Row(
            children: <Widget>[
              Expanded(
                child: ScButton.compact(
                  label: 'Accept',
                  variant: ScButtonVariant.secondary,
                  enabled: !busy && !overlaps,
                  onPressed: onAccept,
                ),
              ),
              SizedBox(width: tokens.space1),
              Expanded(
                child: ScButton.compact(
                  label: 'Adjust',
                  variant: ScButtonVariant.ghost,
                  enabled: !busy,
                  onPressed: onAdjust,
                ),
              ),
              SizedBox(width: tokens.space1),
              Expanded(
                child: ScButton.compact(
                  label: 'Dismiss',
                  variant: ScButtonVariant.ghost,
                  enabled: !busy,
                  onPressed: onDismiss,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
