import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/components/sc_actions.dart';
import '../../../app/design/components/sc_banner.dart';
import '../../../app/design/components/sc_empty_state.dart';
import '../../../app/design/components/sc_panel.dart';
import '../../../app/design/components/sc_pressable.dart';
import '../../../app/design/components/sc_scoreboard.dart';
import '../../../app/design/sc_icons.dart';
import '../../../app/design/sc_metrics.dart';
import '../../../app/design/sc_typography.dart';
import '../../../app/design/sportcut_tokens.dart';
import '../../../bridge/sportcut_engine.dart';
import '../../editing/domain/match_edit.dart';
import '../../editing/domain/rally.dart';
import '../../editing/domain/score_event.dart';
import '../../editing/domain/score_timeline.dart';
import '../../editing/presentation/editing_providers.dart';
import '../../library/domain/match_record.dart';
import '../../library/presentation/formatters.dart';
import '../../library/presentation/playback_controller.dart';
import '../../rally/presentation/rally_review_providers.dart';
import 'last_rallies_panel.dart';
import 'rally_mark_controls.dart';
import 'rally_suggestions_panel.dart';
import 'serving_sides_providers.dart';

/// Scores [rallyId] for [side].
///
/// The inspector's winner buttons and the studio's L/R shortcut both call this
/// one function, so the two paths cannot disagree about how a rally is scored.
void scoreRally(WidgetRef ref, String rallyId, WinnerSide side) {
  ref.read(editingControllerProvider.notifier).setWinner(rallyId, side);
}

/// The Rally inspector: score, mark rallies manually, and review suggestions.
///
/// The panel is a [ConsumerStatefulWidget] because it is the least-risk move
/// from the old `ScoreView`: it reads the editing session, the rally-review
/// session, and the serving sides directly, while its host passes only the
/// match, the shared player, and the selected rally. Nothing is applied
/// automatically: every winner and every suggestion comes from an explicit tap.
///
/// [ownsSession] is true only for the legacy `ScoreView` route. The studio's
/// shell opens the editing and rally-review sessions once per selected video,
/// so the panel must not open them a second time there.
class RallyPanel extends ConsumerStatefulWidget {
  /// Build the rally inspector.
  const RallyPanel({
    super.key,
    required this.match,
    this.controller,
    this.ownsSession = false,
    this.selectedRallyId,
    this.onSelectRally,
    this.recordingAvailable = true,
  });

  /// The match being reviewed.
  final MatchRecord match;

  /// The shared player, or null when no player is available.
  final PlaybackController? controller;

  /// Whether this panel opens the editing and rally-review sessions itself.
  final bool ownsSession;

  /// The selected rally, when the host keeps the selection.
  final String? selectedRallyId;

  /// Reports a rally selected in this panel, when the host wants to track it.
  final ValueChanged<Rally>? onSelectRally;

  /// Whether the match's recording can still be read.
  final bool recordingAvailable;

  @override
  ConsumerState<RallyPanel> createState() => _RallyPanelState();
}

class _RallyPanelState extends ConsumerState<RallyPanel> {
  /// Where the user marked the start of the rally being built, in seconds.
  double? _pendingStart;

  /// The selected rally, kept in step with [RallyPanel.selectedRallyId].
  String? _selectedRallyId;

  final FocusNode _leftWinnerFocus = FocusNode(debugLabel: 'Rally left winner');
  final FocusNode _rightWinnerFocus =
      FocusNode(debugLabel: 'Rally right winner');

  @override
  void initState() {
    super.initState();
    _selectedRallyId = widget.selectedRallyId;
    if (widget.ownsSession) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openSessions();
        }
      });
    }
  }

  @override
  void didUpdateWidget(RallyPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedRallyId != widget.selectedRallyId) {
      _selectedRallyId = widget.selectedRallyId;
    }
    if (oldWidget.match.id != widget.match.id) {
      _pendingStart = null;
      _selectedRallyId = widget.selectedRallyId;
      if (widget.ownsSession) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _openSessions();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _leftWinnerFocus.dispose();
    _rightWinnerFocus.dispose();
    super.dispose();
  }

  /// Open both sessions for the legacy route.
  ///
  /// The studio host owns this, so [RallyPanel.ownsSession] keeps it to the
  /// route that still composes the panel directly.
  void _openSessions() {
    unawaited(ref.read(editingControllerProvider.notifier).open(widget.match));
    unawaited(
      ref.read(rallyReviewControllerProvider.notifier).open(widget.match),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final editing = ref.watch(editingControllerProvider);
    final review = ref.watch(rallyReviewControllerProvider);
    final canAnalyze = ref.watch(rallySegmentationConfigProvider) != null;
    final sides =
        ref.watch(servingSidesProvider).value ?? const <String, RallySideDto>{};

    final sessionMatch = editing.match;
    final edit = sessionMatch?.id == widget.match.id ? editing.edit : null;
    final problem =
        sessionMatch?.id == widget.match.id ? editing.problem : null;
    final rallies = edit?.rallies ?? const <Rally>[];
    final score = edit?.score;

    WinnerSide? currentServer;
    for (final rally in rallies) {
      if (rally.isScored) {
        currentServer = rally.winnerSide;
      }
    }
    final firstSide = rallies.isEmpty ? null : sides[rallies.first.id];
    final servingLeft = currentServer != null
        ? currentServer == WinnerSide.left
        : firstSide != RallySideDto.right;

    final selected = _selectedFrom(rallies);
    final canScore =
        selected != null && !editing.busy && widget.recordingAvailable;
    final reviewForMatch = review.match?.id == widget.match.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (problem != null) ...<Widget>[
          ScBanner(
            message: problem,
            actionLabel: 'Dismiss',
            onAction: () =>
                ref.read(editingControllerProvider.notifier).clearProblem(),
            tone: ScBannerTone.danger,
          ),
          SizedBox(height: tokens.space3),
        ],
        ScPanel(
          padding: EdgeInsets.all(tokens.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ScScoreboard(
                leftLabel: 'L · Left',
                rightLabel: 'R · Right',
                leftScore: score?.left ?? 0,
                rightScore: score?.right ?? 0,
                servingLeft: servingLeft,
              ),
              SizedBox(height: tokens.space2),
              ScServingLine(
                leftName: 'Left',
                rightName: 'Right',
                servingLeft: servingLeft,
                serveLabel: 'serving',
              ),
              SizedBox(height: tokens.space3),
              ScWinnerButtons(
                leftLabel: 'L',
                rightLabel: 'R',
                enabled: canScore,
                leftFocusNode: _leftWinnerFocus,
                rightFocusNode: _rightWinnerFocus,
                onConfirm: (left) => _scoreSelected(selected, left),
              ),
              SizedBox(height: tokens.space2),
              Text(
                _scoreHelp(selected, editing.busy),
                style: typography.xs12.copyWith(color: palette.muted),
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.space4),
        const ScSectionHeader(label: 'Manual marking'),
        _markControls(editing.busy),
        SizedBox(height: tokens.space3),
        LastRalliesPanel(
          rallies: rallies,
          score: score ?? _emptyScore,
          onSelect: _selectRally,
        ),
        SizedBox(height: tokens.space3),
        RallySuggestionsPanel(
          review: reviewForMatch ? review : const RallyReviewState(),
          canAnalyze: canAnalyze && reviewForMatch,
          rallies: rallies,
          busy: editing.busy,
          onAnalyze: () =>
              ref.read(rallyReviewControllerProvider.notifier).analyze(),
          onCancel: () =>
              ref.read(rallyReviewControllerProvider.notifier).cancel(),
          onAccept: (candidate) => ref
              .read(rallyReviewControllerProvider.notifier)
              .accept(candidate),
          onAdjust: _adjustSuggestion,
          onDismiss: (candidate) => ref
              .read(rallyReviewControllerProvider.notifier)
              .dismiss(candidate),
        ),
        SizedBox(height: tokens.space3),
        _rallyList(rallies, sides, editing.busy, edit),
      ],
    );
  }

  /// The empty timeline used before the editing session loads.
  ScoreTimeline get _emptyScore =>
      ScoreTimeline.fromRallies(widget.match.id, const <Rally>[]);

  /// The current selection, resolved against [rallies].
  Rally? _selectedFrom(List<Rally> rallies) {
    final id = _selectedRallyId;
    if (id == null) {
      return null;
    }
    for (final rally in rallies) {
      if (rally.id == id) {
        return rally;
      }
    }
    return null;
  }

  String _scoreHelp(Rally? selected, bool busy) {
    if (!widget.recordingAvailable) {
      return 'The recording is missing, so its rallies cannot be scored.';
    }
    if (busy) {
      return 'Saving the last change…';
    }
    if (selected == null) {
      return 'Select a rally to confirm who won it.';
    }
    if (selected.isScored) {
      return 'One tap changes the confirmed winner. The score and serving side '
          'follow.';
    }
    return 'One tap confirms the selected rally. The score and serving side '
        'follow.';
  }

  /// Score the selected rally from the scoreboard's L/R buttons.
  void _scoreSelected(Rally? selected, bool left) {
    if (selected == null || !widget.recordingAvailable) {
      return;
    }
    scoreRally(ref, selected.id, left ? WinnerSide.left : WinnerSide.right);
    final node = left ? _leftWinnerFocus : _rightWinnerFocus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        node.requestFocus();
      }
    });
  }

  /// Mark the start at the player's current position.
  Widget _markControls(bool busy) {
    final controller = widget.controller;
    if (controller == null) {
      return RallyMarkControls(
        pendingStart: _pendingStart,
        busy: busy,
        ready: false,
        onMarkStart: () {},
        onMarkEnd: null,
        onCancel: _cancelMark,
      );
    }
    return ValueListenableBuilder<PlaybackState>(
      valueListenable: controller.state,
      builder: (context, playback, _) => RallyMarkControls(
        pendingStart: _pendingStart,
        busy: busy,
        ready: playback.isReady && widget.recordingAvailable,
        onMarkStart: () => setState(
          () => _pendingStart = playback.position.inMilliseconds / 1000,
        ),
        onMarkEnd: _pendingStart == null || !widget.recordingAvailable
            ? null
            : () => _addRally(
                  _pendingStart!,
                  playback.position.inMilliseconds / 1000,
                ),
        onCancel: _cancelMark,
      ),
    );
  }

  void _cancelMark() {
    setState(() => _pendingStart = null);
  }

  Future<void> _addRally(double startSeconds, double endSeconds) async {
    setState(() => _pendingStart = null);
    await ref.read(editingControllerProvider.notifier).markRally(
          startSeconds: startSeconds,
          endSeconds: endSeconds,
        );
  }

  /// Select a rally and tell the host, which owns the studio's selected id.
  void _selectRally(Rally rally) {
    setState(() => _selectedRallyId = rally.id);
    widget.onSelectRally?.call(rally);
  }

  /// The full rally list: keep, remove, winner state, and selection.
  Widget _rallyList(
    List<Rally> rallies,
    Map<String, RallySideDto> sides,
    bool busy,
    MatchEdit? edit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ScSectionHeader(label: 'Rallies', count: rallies.length),
        if (rallies.isEmpty)
          const ScEmptyState(
            message: 'No rallies yet. Scrub to a point, mark its start and '
                'end, and say who won it.',
            icon: ScIcons.scoreboard,
            compact: true,
          )
        else
          for (var index = 0; index < rallies.length; index++) ...<Widget>[
            if (index > 0) const ScDivider(),
            _RallyTile(
              rally: rallies[index],
              index: index,
              kept: edit?.isKept(rallies[index]) ?? false,
              score: edit?.score.atRally(rallies[index].id),
              suggested: _suggestedFor(rallies[index], sides),
              selected: _selectedRallyId == rallies[index].id,
              busy: busy,
              onSelect: () => _selectRally(rallies[index]),
              onWinner: (side) => scoreRally(ref, rallies[index].id, side),
              onKeep: (kept) => ref
                  .read(editingControllerProvider.notifier)
                  .setKept(rallies[index], kept),
              onRemove: () => ref
                  .read(editingControllerProvider.notifier)
                  .removeRally(rallies[index].id),
            ),
          ],
      ],
    );
  }

  WinnerSide? _suggestedFor(Rally rally, Map<String, RallySideDto> sides) {
    if (rally.isScored) {
      return null;
    }
    final side = sides[rally.id];
    if (side == null) {
      return null;
    }
    return side == RallySideDto.left ? WinnerSide.left : WinnerSide.right;
  }

  Future<void> _adjustSuggestion(RallySuggestionDto candidate) async {
    var range = RangeValues(candidate.startSeconds, candidate.endSeconds);
    final adjusted = await showDialog<RangeValues>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Adjust suggested rally'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '${formatDuration(range.start)}–${formatDuration(range.end)}',
              ),
              RangeSlider(
                values: range,
                min: 0,
                max: widget.match.durationSeconds,
                divisions:
                    widget.match.durationSeconds.ceil().clamp(1, 1000).toInt(),
                onChanged: (next) => setDialogState(() => range = next),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: range.end > range.start
                  ? () => Navigator.pop(dialogContext, range)
                  : null,
              child: const Text('Accept rally'),
            ),
          ],
        ),
      ),
    );
    if (adjusted == null || !mounted) {
      return;
    }
    await ref.read(rallyReviewControllerProvider.notifier).accept(
          candidate,
          startSeconds: adjusted.start,
          endSeconds: adjusted.end,
        );
  }
}

/// One rally row: its span, score, keep state, and the two winner controls.
class _RallyTile extends StatelessWidget {
  const _RallyTile({
    required this.rally,
    required this.index,
    required this.kept,
    required this.score,
    required this.suggested,
    required this.selected,
    required this.busy,
    required this.onSelect,
    required this.onWinner,
    required this.onKeep,
    required this.onRemove,
  });

  final Rally rally;
  final int index;
  final bool kept;
  final ScoreEvent? score;
  final WinnerSide? suggested;
  final bool selected;
  final bool busy;
  final VoidCallback onSelect;
  final ValueChanged<WinnerSide> onWinner;
  final ValueChanged<bool> onKeep;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final scored = rally.isScored;
    final scoreLine = score;
    final numberStyle = SportcutTypography.withTabular(typography.timecode11);
    final status = scored && scoreLine != null
        ? 'Confirmed · ${scoreLine.leftScore}–${scoreLine.rightScore}'
        : suggested == null
            ? 'Tap the side that won it'
            : 'Suggested: ${suggested == WinnerSide.left ? 'Left' : 'Right'}'
                ' · tap to confirm';

    return ScPressable(
      onTap: onSelect,
      selected: selected,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space2,
        vertical: tokens.space1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Point ${index + 1} · ${formatDuration(rally.startSeconds)}'
                  '–${formatDuration(rally.endSeconds)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: numberStyle.copyWith(color: palette.fg),
                ),
              ),
              ScIconButton(
                icon: kept ? Icons.star_rounded : Icons.star_border_rounded,
                label: kept ? 'Remove from reel' : 'Keep in reel',
                size: ScMetrics.toolButton,
                enabled: !busy,
                onPressed: () => onKeep(!kept),
              ),
              ScIconButton(
                icon: ScIcons.delete,
                label: 'Remove rally',
                size: ScMetrics.toolButton,
                enabled: !busy,
                onPressed: onRemove,
              ),
            ],
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SportcutTypography.withTabular(typography.xs12)
                      .copyWith(color: palette.muted),
                ),
              ),
              _WinnerChip(
                label: 'L',
                selected: rally.winnerSide == WinnerSide.left,
                suggested: !scored && suggested == WinnerSide.left,
                onTap: busy ? null : () => onWinner(WinnerSide.left),
              ),
              SizedBox(width: tokens.space1),
              _WinnerChip(
                label: 'R',
                selected: rally.winnerSide == WinnerSide.right,
                suggested: !scored && suggested == WinnerSide.right,
                onTap: busy ? null : () => onWinner(WinnerSide.right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One compact L or R winner control on a rally row.
class _WinnerChip extends StatelessWidget {
  const _WinnerChip({
    required this.label,
    required this.selected,
    required this.suggested,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool suggested;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final radius = BorderRadius.circular(tokens.radiusSm);
    final hint = suggested && !selected;

    return Semantics(
      button: true,
      selected: selected,
      label: hint ? '$label suggested' : '$label side',
      child: ScPressable(
        onTap: onTap,
        borderRadius: radius,
        child: SizedBox(
          width: ScMetrics.iconButton,
          height: ScMetrics.iconButton,
          child: Center(
            child: Container(
              width: ScMetrics.toolButton,
              height: ScMetrics.buttonCompact,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? palette.surfaceWarm : palette.surface,
                borderRadius: radius,
                border: Border.all(
                  color: selected
                      ? palette.border
                      : (hint ? palette.muted : palette.borderSoft),
                ),
              ),
              child: Text(
                hint ? '·$label' : label,
                style: typography.xs12.copyWith(
                  color: selected ? palette.fg : palette.fg2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
