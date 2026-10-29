import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/components/sc_actions.dart';
import '../../../app/design/components/sc_clip_row.dart';
import '../../../app/design/components/sc_empty_state.dart';
import '../../../app/design/components/sc_panel.dart';
import '../../../app/design/sc_icons.dart';
import '../../../app/design/sc_metrics.dart';
import '../../../app/design/sc_typography.dart';
import '../../../app/design/sportcut_tokens.dart';
import '../../../bridge/sportcut_engine.dart';
import '../../editing/domain/highlight_clip.dart';
import '../../editing/domain/match_edit.dart';
import '../../editing/domain/rally.dart';
import '../../library/presentation/formatters.dart';
import 'highlight_ranking_providers.dart';

/// The reel: the ordered clips, the rallies left out, and the summary footer.
///
/// The panel is data-in / callback-out, with one deliberate exception: it
/// watches [highlightRankingProvider] so the left-out rail keeps the engine's
/// suggested order and its `#n` labels. It owns no durable state. The only
/// state it keeps is the clips dismissed during this mount, so a row the user
/// just dropped from the reel stays visible and recoverable (BRD-007
/// FR-HLT-18); the zeros and ones themselves still live in the editing session.
///
/// Reordering keeps the `ReorderableListView` interaction `HighlightsView`
/// used: drag a clip by its handle and the new identifier order is written
/// through [onReorder]. Everything else is a compact studio row.
class ReelPanel extends ConsumerStatefulWidget {
  /// Build the reel for [edit].
  const ReelPanel({
    super.key,
    required this.matchId,
    required this.edit,
    this.selectedRallyId,
    this.busy = false,
    this.onSelectClip,
    this.onSetKept,
    this.onReorder,
    this.onKeepTop10,
    this.onExport,
  });

  /// The match the reel belongs to; a change clears the dismissed cache.
  final String matchId;

  /// The match's review.
  final MatchEdit edit;

  /// The selected rally, highlighted in the reel.
  final String? selectedRallyId;

  /// Whether an edit is being written.
  final bool busy;

  /// Select a clip's rally; the host also seeks to it.
  final ValueChanged<Rally>? onSelectClip;

  /// Put a rally in the reel, or take it out.
  final void Function(Rally rally, bool kept)? onSetKept;

  /// Write the reel's new identifier order.
  final void Function(List<String> clipIds)? onReorder;

  /// Keep the best of the rallies [ReelPanel] passes back.
  final void Function(List<Rally> rallies)? onKeepTop10;

  /// Open the Export stage.
  final VoidCallback? onExport;

  @override
  ConsumerState<ReelPanel> createState() => _ReelPanelState();
}

class _ReelPanelState extends ConsumerState<ReelPanel> {
  /// Clips removed from the reel during this mount, keyed by clip id.
  ///
  /// The stored keep operation handles the durable side; this only keeps the
  /// row on screen so "dismiss" reads as a reversible state, not a delete.
  final Map<String, HighlightClip> _dismissed = <String, HighlightClip>{};

  @override
  void didUpdateWidget(covariant ReelPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.matchId != widget.matchId) {
      _dismissed.clear();
      return;
    }
    final Set<String> current = <String>{
      for (final HighlightClip clip in widget.edit.clips) clip.id,
    };
    for (final HighlightClip clip in oldWidget.edit.clips) {
      if (!current.contains(clip.id)) {
        _dismissed[clip.id] = clip;
      }
    }
    _dismissed.removeWhere(
      (String id, HighlightClip clip) => current.contains(id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SportcutTokens tokens = SportcutTokens.of(context);
    final Map<String, HighlightRankDto> ranking =
        ref.watch(highlightRankingProvider).value ??
            const <String, HighlightRankDto>{};

    final Set<String> dismissedRallyIds = <String>{
      for (final HighlightClip clip in _dismissed.values)
        if (clip.rallyId != null) clip.rallyId!,
    };
    final List<Rally> leftOut = widget.edit.rallies
        .where(
          (Rally rally) =>
              !widget.edit.isKept(rally) &&
              !dismissedRallyIds.contains(rally.id),
        )
        .toList()
      ..sort(
        (Rally a, Rally b) =>
            _rankFor(a, ranking).compareTo(_rankFor(b, ranking)),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _summary(context),
        SizedBox(height: tokens.space2),
        if (widget.edit.clips.isEmpty)
          const ScEmptyState(
            message: 'No clips in the reel yet. Add a rally from the left-out '
                'list, or mark one on the score timeline.',
            icon: ScIcons.movie,
            compact: true,
          )
        else
          _reelList(context),
        if (_dismissed.isNotEmpty) ...<Widget>[
          SizedBox(height: tokens.space2),
          ScSectionHeader(
            label: 'Dismissed',
            count: _dismissed.length,
          ),
          for (final HighlightClip clip in _dismissed.values)
            Padding(
              padding: EdgeInsets.only(bottom: tokens.space1),
              child: _clipRow(context, clip, kept: false),
            ),
        ],
        if (leftOut.isNotEmpty) ...<Widget>[
          SizedBox(height: tokens.space2),
          ScSectionHeader(
            label: 'Left out',
            count: leftOut.length,
            trailing: ScButton.compact(
              label: 'Keep top 10',
              variant: ScButtonVariant.ghost,
              enabled: !widget.busy && widget.onKeepTop10 != null,
              onPressed: widget.onKeepTop10 == null
                  ? null
                  : () => widget.onKeepTop10!(leftOut),
            ),
          ),
          SizedBox(
            height: ScMetrics.rowRich + tokens.space4,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: leftOut.length,
              itemBuilder: (BuildContext context, int index) {
                final Rally rally = leftOut[index];
                final HighlightRankDto? rank = ranking[rally.id];
                return Padding(
                  padding: EdgeInsets.only(right: tokens.space1),
                  child: Tooltip(
                    message: rank == null
                        ? 'Add to the reel'
                        : 'Highlight score ${(rank.score * 100).round()}%',
                    child: ScTag(
                      label: '${rank == null ? '' : '#${rank.rank} '}'
                          '${formatDuration(rally.startSeconds)}'
                          '–${formatDuration(rally.endSeconds)}',
                      onTap: widget.busy || widget.onSetKept == null
                          ? null
                          : () => widget.onSetKept!(rally, true),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  /// The reel summary and the mini Export action.
  Widget _summary(BuildContext context) {
    final SportcutPalette palette = SportcutPalette.of(context);
    final SportcutTokens tokens = SportcutTokens.of(context);
    final SportcutTypography typography = SportcutTypography.of(context);
    final int count = widget.edit.clips.length;
    final String clipLabel = count == 1 ? 'clip' : 'clips';

    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '$count $clipLabel · '
                '${formatDuration(widget.edit.reelSeconds)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SportcutTypography.withTabular(typography.sm14).copyWith(
                  color: palette.fg2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: tokens.space1 / 2),
              Text(
                '$count kept · ${_dismissed.length} dismissed',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SportcutTypography.withTabular(typography.micro10)
                    .copyWith(color: palette.muted),
              ),
            ],
          ),
        ),
        if (widget.onExport != null) ...<Widget>[
          SizedBox(width: tokens.space2),
          ScButton.compact(
            label: 'Export',
            icon: ScIcons.download,
            variant: ScButtonVariant.secondary,
            onPressed: widget.onExport,
          ),
        ],
      ],
    );
  }

  /// The ordered reel, reorderable by its leading handle.
  Widget _reelList(BuildContext context) {
    final SportcutPalette palette = SportcutPalette.of(context);
    final SportcutTokens tokens = SportcutTokens.of(context);

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: widget.edit.clips.length,
      onReorderItem: (int from, int to) {
        final List<String> ids = widget.edit.clips
            .map((HighlightClip clip) => clip.id)
            .toList(growable: true);
        final String moved = ids.removeAt(from);
        ids.insert(to, moved);
        widget.onReorder?.call(ids);
      },
      itemBuilder: (BuildContext context, int index) {
        final HighlightClip clip = widget.edit.clips[index];
        return Padding(
          key: ValueKey<String>(clip.id),
          padding: EdgeInsets.only(bottom: tokens.space1),
          child: Row(
            children: <Widget>[
              ReorderableDragStartListener(
                index: index,
                child: Tooltip(
                  message: 'Reorder clip',
                  child: SizedBox(
                    width: ScMetrics.iconButton,
                    height: ScMetrics.rowCompact,
                    child: Center(
                      child: Icon(
                        Icons.drag_handle_rounded,
                        size: ScIcons.toolbarSize,
                        color: palette.muted,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(child: _clipRow(context, clip, kept: true)),
            ],
          ),
        );
      },
    );
  }

  /// One clip row, kept or dismissed.
  Widget _clipRow(
    BuildContext context,
    HighlightClip clip, {
    required bool kept,
  }) {
    final Rally? rally = _rallyFor(clip);
    final ({int left, int right}) score =
        widget.edit.score.atSeconds(clip.effectiveStartSeconds);
    final bool trimmed = clip.effectiveStartSeconds != clip.startSeconds ||
        clip.effectiveEndSeconds != clip.endSeconds;
    final int index = rally == null
        ? -1
        : widget.edit.rallies
            .indexWhere((Rally candidate) => candidate.id == rally.id);
    final String title = index >= 0 ? 'Rally ${index + 1}' : 'Clip';

    return ScClipRow(
      title: title,
      inOut: '${formatDuration(clip.effectiveStartSeconds)} – '
          '${formatDuration(clip.effectiveEndSeconds)}',
      duration: formatDuration(clip.durationSeconds),
      scoreContext: '${score.left}–${score.right}'
          '${trimmed ? ' · trimmed' : ''}',
      kept: kept,
      dismissed: !kept,
      selected: clip.rallyId == widget.selectedRallyId,
      onTap: rally == null || widget.onSelectClip == null
          ? null
          : () => widget.onSelectClip!(rally),
      onToggle: rally == null || widget.onSetKept == null
          ? null
          : () => widget.onSetKept!(rally, !kept),
      toggleLabel: kept ? 'Remove from the reel' : 'Add to the reel',
    );
  }

  /// The rally behind [clip], or null when the clip outlived its rally.
  Rally? _rallyFor(HighlightClip clip) {
    final String? rallyId = clip.rallyId;
    if (rallyId == null) {
      return null;
    }
    for (final Rally rally in widget.edit.rallies) {
      if (rally.id == rallyId) {
        return rally;
      }
    }
    return null;
  }
}

/// A rally's suggested rank, or a value that sorts it last when unranked.
int _rankFor(Rally rally, Map<String, HighlightRankDto> ranking) =>
    ranking[rally.id]?.rank ?? 1 << 30;
