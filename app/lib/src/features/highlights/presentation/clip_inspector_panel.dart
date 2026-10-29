import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/components/sc_actions.dart';
import '../../../app/design/components/sc_banner.dart';
import '../../../app/design/components/sc_dialog.dart';
import '../../../app/design/components/sc_empty_state.dart';
import '../../../app/design/components/sc_panel.dart';
import '../../../app/design/components/sc_switch.dart';
import '../../../app/design/sc_icons.dart';
import '../../../app/design/sc_typography.dart';
import '../../../app/design/sportcut_tokens.dart';
import '../../../bridge/sportcut_engine.dart';
import '../../editing/domain/highlight_clip.dart';
import '../../editing/domain/match_edit.dart';
import '../../editing/domain/rally.dart';
import '../../library/presentation/formatters.dart';
import 'highlight_ranking_providers.dart';

/// One clip's details in the inspector's Clip tab.
///
/// The panel is data-in / callback-out, with one deliberate exception: it
/// watches [highlightRankingProvider] to show the engine's suggested rank for
/// the selected rally. Every value it edits is reported through a callback so
/// the host keeps owning the editing session; selecting, keeping, and trimming
/// never mutate state here.
///
/// A rally with no clip is still inspectable: the heading, winner, and score
/// come from the rally, and the keep switch adds it to the reel. A kept clip
/// adds its trim and its clip type. Nothing claims a winner or a rank the
/// session does not carry (BRD-009 D14; BRD-007 FR-HLT-09).
class ClipInspectorPanel extends ConsumerWidget {
  /// Build the Clip tab for [edit].
  const ClipInspectorPanel({
    super.key,
    required this.edit,
    this.selectedRallyId,
    this.problem,
    this.busy = false,
    this.onDismissProblem,
    this.onSetKept,
    this.onTrim,
  });

  /// The open match's review, or null while the session loads.
  final MatchEdit? edit;

  /// The rally selected on the timeline or in the reel.
  final String? selectedRallyId;

  /// A trim or keep failure to keep visible until dismissed.
  final String? problem;

  /// Whether an edit is being written.
  final bool busy;

  /// Dismiss the reported [problem].
  final VoidCallback? onDismissProblem;

  /// Put the selected rally in the reel, or take it out.
  final void Function(Rally rally, bool kept)? onSetKept;

  /// Write a trim chosen in the trim dialog.
  final void Function(
    HighlightClip clip,
    double startSeconds,
    double endSeconds,
  )? onTrim;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SportcutTokens tokens = SportcutTokens.of(context);
    final MatchEdit? edit = this.edit;
    final Rally? selected = edit == null ? null : _selected(edit);
    final String? problem = this.problem;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (problem != null) ...<Widget>[
          ScBanner(
            message: problem,
            actionLabel: 'Dismiss',
            onAction: onDismissProblem,
            tone: ScBannerTone.danger,
          ),
          SizedBox(height: tokens.space3),
        ],
        if (edit == null || selected == null)
          const ScEmptyState(
            message: 'No clip selected. Choose a rally on the timeline.',
            icon: ScIcons.movie,
            compact: true,
          )
        else
          _body(context, ref, edit, selected),
      ],
    );
  }

  /// The selected rally, resolved against [edit].
  Rally? _selected(MatchEdit edit) {
    final String? id = selectedRallyId;
    if (id == null) {
      return null;
    }
    for (final Rally rally in edit.rallies) {
      if (rally.id == id) {
        return rally;
      }
    }
    return null;
  }

  /// The selected rally's details.
  Widget _body(
    BuildContext context,
    WidgetRef ref,
    MatchEdit edit,
    Rally rally,
  ) {
    final SportcutPalette palette = SportcutPalette.of(context);
    final SportcutTokens tokens = SportcutTokens.of(context);
    final SportcutTypography typography = SportcutTypography.of(context);

    final HighlightClip? clip = edit.clipForRally(rally.id);
    final bool kept = edit.isKept(rally);
    final bool trimmed = clip != null &&
        (clip.effectiveStartSeconds != clip.startSeconds ||
            clip.effectiveEndSeconds != clip.endSeconds);
    final int index =
        edit.rallies.indexWhere((Rally candidate) => candidate.id == rally.id);
    final String title = index >= 0 ? 'Rally ${index + 1}' : 'Clip';

    final double startSeconds =
        clip?.effectiveStartSeconds ?? rally.startSeconds;
    final double endSeconds = clip?.effectiveEndSeconds ?? rally.endSeconds;
    final double durationSeconds = endSeconds - startSeconds;

    final String winner = _winnerLabel(rally);
    final score = edit.score.atRally(rally.id);
    final String scoreAfter =
        score == null ? 'Not scored' : '${score.leftScore}–${score.rightScore}';
    final String type = clip == null
        ? 'Not in the reel'
        : (trimmed ? 'Trimmed clip' : 'Full rally');

    final AsyncValue<Map<String, HighlightRankDto>> ranking =
        ref.watch(highlightRankingProvider);
    final HighlightRankDto? rank = ranking.value?[rally.id];
    final String rankLabel = _rankLabel(ranking, rally.id);

    final List<String> tags = <String>[
      if (rally.winnerSide != null) '$winner won',
      if (trimmed) 'Trimmed',
      if (rank != null) '#${rank.rank}',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typography.title20.copyWith(color: palette.fg),
              ),
            ),
            SizedBox(width: tokens.space2),
            Text(
              formatDuration(durationSeconds),
              style: SportcutTypography.withTabular(typography.micro10)
                  .copyWith(color: palette.muted),
            ),
          ],
        ),
        SizedBox(height: tokens.space1),
        Text(
          '${formatDuration(startSeconds)} – ${formatDuration(endSeconds)}',
          style: SportcutTypography.withTabular(typography.micro10)
              .copyWith(color: palette.muted),
        ),
        SizedBox(height: tokens.space3),
        ScMetaList(
          items: <(String, String)>[
            ('Winner', winner),
            ('Score after', scoreAfter),
            ('Type', type),
            ('Suggested rank', rankLabel),
          ],
        ),
        if (tags.isNotEmpty) ...<Widget>[
          SizedBox(height: tokens.space3),
          Wrap(
            spacing: tokens.space1,
            runSpacing: tokens.space1,
            children: <Widget>[
              for (final String tag in tags) ScTag(label: tag),
            ],
          ),
        ],
        SizedBox(height: tokens.space3),
        const ScDivider(),
        SizedBox(height: tokens.space2),
        ScSwitch(
          value: kept,
          label: 'Keep as highlight',
          enabled: !busy && onSetKept != null,
          onChanged: (bool value) => onSetKept?.call(rally, value),
        ),
        SizedBox(height: tokens.space1),
        Text(
          'Dismissed clips stay recoverable until export. '
          'Kept clips feed the reel.',
          style: typography.xs12.copyWith(color: palette.muted),
        ),
        SizedBox(height: tokens.space3),
        ScButton.compact(
          label: 'Trim clip',
          icon: Icons.content_cut_rounded,
          variant: ScButtonVariant.secondary,
          expanded: true,
          enabled: clip != null && !busy && onTrim != null,
          onPressed: clip == null ? null : () => _openTrim(context, clip),
        ),
      ],
    );
  }

  /// Open the trim dialog and report the chosen range.
  Future<void> _openTrim(BuildContext context, HighlightClip clip) async {
    final SportcutPalette palette = SportcutPalette.of(context);
    final SportcutTokens tokens = SportcutTokens.of(context);
    final RangeValues? range = await showDialog<RangeValues>(
      context: context,
      builder: (BuildContext dialogContext) => Dialog(
        backgroundColor: palette.surface.withValues(alpha: 0),
        elevation: 0,
        insetPadding: EdgeInsets.all(tokens.space6),
        child: _TrimDialog(clip: clip),
      ),
    );
    if (range == null) {
      return;
    }
    onTrim?.call(clip, range.start, range.end);
  }

  /// A confirmed side's name, or the honest "not confirmed" state.
  String _winnerLabel(Rally rally) => switch (rally.winnerSide) {
        WinnerSide.left => 'Left',
        WinnerSide.right => 'Right',
        null => 'Not confirmed',
      };

  /// The suggested rank, or a labelled state when the engine has no value.
  String _rankLabel(
    AsyncValue<Map<String, HighlightRankDto>> ranking,
    String rallyId,
  ) {
    final HighlightRankDto? rank = ranking.value?[rallyId];
    if (rank != null) {
      return '#${rank.rank}';
    }
    // No rank is never invented: the provider either has no value at all
    // (loading or failed) or it ranked other rallies but not this one.
    return ranking.hasError || ranking.value == null
        ? 'Unavailable'
        : 'Not ranked';
  }
}

/// The trim dialog, restyled as a studio [ScDialog].
///
/// The range stays inside the clip's original rally, which is the same bound
/// the repository enforces; the dialog itself only reports the chosen range,
/// so the write still runs through `trimClip`.
class _TrimDialog extends StatefulWidget {
  const _TrimDialog({required this.clip});

  final HighlightClip clip;

  @override
  State<_TrimDialog> createState() => _TrimDialogState();
}

class _TrimDialogState extends State<_TrimDialog> {
  late RangeValues _range = RangeValues(
    widget.clip.effectiveStartSeconds,
    widget.clip.effectiveEndSeconds,
  );

  @override
  Widget build(BuildContext context) {
    final SportcutPalette palette = SportcutPalette.of(context);
    final SportcutTokens tokens = SportcutTokens.of(context);
    final SportcutTypography typography = SportcutTypography.of(context);

    return ScDialog(
      title: 'Trim clip',
      description: 'Pull the clip inward inside the rally it came from.',
      actions: <Widget>[
        ScButton.compact(
          label: 'Cancel',
          variant: ScButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        ScButton.compact(
          label: 'Trim clip',
          onPressed: () => Navigator.of(context).pop(_range),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '${formatDuration(_range.start)} – ${formatDuration(_range.end)}'
            '  ·  ${formatDuration(_range.end - _range.start)}',
            style: SportcutTypography.withTabular(typography.xs12)
                .copyWith(color: palette.fg2),
          ),
          SizedBox(height: tokens.space2),
          RangeSlider(
            values: _range,
            min: widget.clip.startSeconds,
            max: widget.clip.endSeconds,
            onChanged: (RangeValues values) {
              setState(() => _range = values);
            },
          ),
        ],
      ),
    );
  }
}
