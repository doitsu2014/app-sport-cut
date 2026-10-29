import 'package:flutter/material.dart';

import '../../../../app/design/components/sc_empty_state.dart';
import '../../../../app/design/components/sc_panel.dart';
import '../../../../app/design/components/sc_pipeline_row.dart';
import '../../../../app/design/components/sc_pressable.dart';
import '../../../../app/design/components/sc_tabs.dart';
import '../../../../app/design/sc_icons.dart';
import '../../../../app/design/sc_metrics.dart';
import '../../../../app/design/sc_status.dart';
import '../../../../app/design/sc_tints.dart';
import '../../../../app/design/sc_typography.dart';
import '../../../../app/design/sportcut_tokens.dart';
import '../../../editing/domain/highlight_clip.dart';
import '../../../editing/domain/match_edit.dart';
import '../../../editing/domain/rally.dart';
import '../../../highlights/presentation/clip_inspector_panel.dart';
import '../../../highlights/presentation/reel_panel.dart';
import '../../../library/domain/match_record.dart';
import '../../../library/presentation/playback_controller.dart';
import '../../../score/presentation/rally_panel.dart';
import '../../domain/pipeline_stage.dart';

/// The right rail: a stage-aware inspector.
///
/// Play, Review & score, and Highlights show the Rally/Clip tablist. The
/// Rally tab hosts [RallyPanel]; the Clip tab hosts [ClipInspectorPanel] and
/// the reel footer hosts [ReelPanel], which together carry the highlight
/// selection (PR 6b). Mark court, Prepare analysis, Player analysis, and
/// Export show their own contextual panel instead (ADR-0003 D14). The compact
/// Pipeline panel stays above the tabs, collapsed by default, so every stage
/// keeps a reachable row without turning the inspector back into a second
/// persistent rail.
///
/// The pane itself reads no provider: the shell passes the resolved pipeline
/// states, the selected match, the review, and every callback, and
/// [RallyPanel] reads the shell-owned editing and rally-review sessions. The
/// pipeline rows keep the existing [onSelectStage]/[onSelectPlay] callbacks.
/// [ClipInspectorPanel] and [ReelPanel] watch the ranking provider for the
/// suggested rank and order, which is the one read they make themselves.
class InspectorPane extends StatelessWidget {
  /// Build the inspector for the selected video's [states].
  const InspectorPane({
    super.key,
    required this.states,
    required this.selectedStage,
    required this.runningStage,
    required this.runningFraction,
    required this.onSelectPlay,
    required this.onSelectStage,
    required this.inspectorTab,
    required this.onInspectorTabChanged,
    this.match,
    this.controller,
    this.selectedRallyId,
    this.onSelectRally,
    this.recordingAvailable = true,
    this.edit,
    this.editBusy = false,
    this.editProblem,
    this.onDismissEditProblem,
    this.onSetKept,
    this.onTrimClip,
    this.onReorderClips,
    this.onKeepTop10,
    this.onSelectClip,
    this.onExport,
  });

  /// The resolved state of every stage for the selected video.
  final Map<PipelineStage, StageState> states;

  /// The selected feature, where null means playback.
  final PipelineStage? selectedStage;

  /// The stage with a job running, if any.
  final PipelineStage? runningStage;

  /// Progress of the running stage in the range 0 to 1, when known.
  final double? runningFraction;

  /// Switch the center back to playback.
  final VoidCallback onSelectPlay;

  /// Open a feature.
  final void Function(PipelineStage) onSelectStage;

  /// The selected inspector tab: 0 is Rally, 1 is Clip.
  final int inspectorTab;

  /// Select an inspector tab.
  final ValueChanged<int> onInspectorTabChanged;

  /// The selected video's match, or null when no video is selected.
  final MatchRecord? match;

  /// The shared player for the selected video.
  final PlaybackController? controller;

  /// The rally selected on the timeline, or null when none is selected.
  final String? selectedRallyId;

  /// Select a rally from the Rally tab.
  final ValueChanged<Rally>? onSelectRally;

  /// Whether the selected match's recording can still be read.
  final bool recordingAvailable;

  /// The selected match's review, or null while the session loads.
  final MatchEdit? edit;

  /// Whether the review is writing a change.
  final bool editBusy;

  /// Why the last review action failed, when it did.
  final String? editProblem;

  /// Clear the reported review failure.
  final VoidCallback? onDismissEditProblem;

  /// Put a rally in the reel, or take it out.
  final void Function(Rally rally, bool kept)? onSetKept;

  /// Write a trim chosen in the Clip tab.
  final void Function(
    HighlightClip clip,
    double startSeconds,
    double endSeconds,
  )? onTrimClip;

  /// Write the reel's identifier order.
  final void Function(List<String> clipIds)? onReorderClips;

  /// Keep the best of the rallies the reel passes back.
  final void Function(List<Rally> rallies)? onKeepTop10;

  /// Select a clip's rally; the host also seeks to it.
  final ValueChanged<Rally>? onSelectClip;

  /// Open the Export stage.
  final VoidCallback? onExport;

  /// Features that read the match.
  static const List<PipelineStage> _analysis = <PipelineStage>[
    PipelineStage.calibrate,
    PipelineStage.analyze,
    PipelineStage.track,
    PipelineStage.score,
  ];

  /// Features that shape the highlight.
  static const List<PipelineStage> _studio = <PipelineStage>[
    PipelineStage.highlight,
    PipelineStage.export,
  ];

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final tab = inspectorTab.clamp(0, 1);
    final showTabs = _showsTabs(selectedStage);
    final doneCount = <PipelineStage>[..._analysis, ..._studio]
        .where((stage) => states[stage] == StageState.done)
        .length;

    return Container(
      decoration: BoxDecoration(
        color: ScTints.railSurface(palette.surface, palette.bg),
        border: Border(left: BorderSide(color: palette.border)),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.space2,
              tokens.space2,
              tokens.space2,
              tokens.space1,
            ),
            child: _PipelinePanel(
              doneCount: doneCount,
              rows: _pipelineRows(),
            ),
          ),
          if (showTabs)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.space2),
              child: ScTabs(
                tabs: const <ScTab>[
                  ScTab(label: 'Rally'),
                  ScTab(label: 'Clip'),
                ],
                selectedIndex: tab,
                onChanged: onInspectorTabChanged,
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                tokens.space3,
                tokens.space3,
                tokens.space3,
                tokens.space4,
              ),
              child: showTabs
                  ? _tabsBody(context, tab)
                  : _contextualBody(context, selectedStage),
            ),
          ),
        ],
      ),
    );
  }

  /// The tab body plus the shared reel footer.
  ///
  /// The reel sits at the end of the inspector's existing scroll body rather
  /// than in a separately docked strip: at the 720 px window minimum a fixed
  /// footer would leave the tab body too little height. The Clip tab already
  /// shows a short panel, so the reel follows it without scrolling.
  Widget _tabsBody(BuildContext context, int tab) {
    final SportcutTokens tokens = SportcutTokens.of(context);
    final MatchEdit? edit = this.edit;
    final MatchRecord? match = this.match;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _tabBody(tab),
        if (match != null && edit != null) ...<Widget>[
          SizedBox(height: tokens.space4),
          const ScDivider(),
          SizedBox(height: tokens.space3),
          ReelPanel(
            matchId: match.id,
            edit: edit,
            selectedRallyId: selectedRallyId,
            busy: editBusy,
            // The failure banner is owned by whichever tab panel is showing:
            // RallyPanel already reports the editing problem on tab 0, and
            // ClipInspectorPanel reports it on tab 1.
            onSelectClip: onSelectClip,
            onSetKept: onSetKept,
            onReorder: onReorderClips,
            onKeepTop10: onKeepTop10,
            onExport: onExport,
          ),
        ],
      ],
    );
  }

  /// Whether [stage] uses the Rally/Clip tablist.
  bool _showsTabs(PipelineStage? stage) =>
      stage == null ||
      stage == PipelineStage.score ||
      stage == PipelineStage.highlight;

  /// The tab body for [tab].
  Widget _tabBody(int tab) {
    final match = this.match;
    if (match == null) {
      return const ScEmptyState(
        message: 'Select a video to review its rallies.',
        icon: ScIcons.scoreboard,
        compact: true,
      );
    }
    if (tab == 1) {
      return ClipInspectorPanel(
        edit: edit,
        selectedRallyId: selectedRallyId,
        problem: editProblem,
        busy: editBusy,
        onDismissProblem: onDismissEditProblem,
        onSetKept: onSetKept,
        onTrim: onTrimClip,
      );
    }
    return RallyPanel(
      match: match,
      controller: controller,
      selectedRallyId: selectedRallyId,
      onSelectRally: onSelectRally,
      recordingAvailable: recordingAvailable,
    );
  }

  /// The placeholder panel for a stage whose own panel has not shipped yet.
  Widget _contextualBody(BuildContext context, PipelineStage? stage) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final label = stage?.label ?? 'Stage';
    return ScPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            label,
            style: typography.body16.copyWith(
              color: palette.fg,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: tokens.space2),
          ScEmptyState(
            message: '$label controls are not available in the inspector yet.',
            compact: true,
          ),
        ],
      ),
    );
  }

  /// The compact pipeline rows, in the order the old rail used.
  List<Widget> _pipelineRows() {
    final playStatus = states.isEmpty ? ScStatus.idle : ScStatus.ready;
    var number = 0;
    return <Widget>[
      ScPipelineRow(
        number: 0,
        name: 'Play',
        status: playStatus,
        selected: selectedStage == null,
        onTap: onSelectPlay,
      ),
      const ScSectionHeader(label: 'Analysis'),
      for (final stage in _analysis) _row(stage, ++number),
      const ScSectionHeader(label: 'Studio'),
      for (final stage in _studio) _row(stage, ++number),
    ];
  }

  Widget _row(PipelineStage stage, int number) {
    final running = stage == runningStage;
    return ScPipelineRow(
      number: number,
      name: stage.label,
      status: _statusFor(stage),
      detail: running ? _percent : null,
      selected: selectedStage == stage,
      onTap: () => onSelectStage(stage),
    );
  }

  /// The state to show for [stage].
  ScStatus _statusFor(PipelineStage stage) {
    if (stage == runningStage) {
      return ScStatus.running;
    }
    return switch (states[stage]) {
      StageState.done => ScStatus.done,
      StageState.ready => ScStatus.ready,
      StageState.idle => ScStatus.blocked,
      null => ScStatus.idle,
    };
  }

  String get _percent {
    final value = (runningFraction ?? 0).clamp(0.0, 1.0);
    return '${(value * 100).round()}%';
  }
}

/// The compact Pipeline panel that keeps every stage reachable.
///
/// It starts collapsed so the Rally/Clip tabs and the panel body keep the
/// inspector's height; the header expands it into a short scrolling list. The
/// [StageStrip] remains the primary stage navigation.
class _PipelinePanel extends StatefulWidget {
  const _PipelinePanel({required this.doneCount, required this.rows});

  final int doneCount;
  final List<Widget> rows;

  @override
  State<_PipelinePanel> createState() => _PipelinePanelState();
}

class _PipelinePanelState extends State<_PipelinePanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);

    return ScPanel(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space2,
        vertical: tokens.space1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ScPressable(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            child: ScRailHeader(
              label: 'Pipeline',
              count: widget.doneCount,
              actions: <Widget>[
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: ScMetrics.toolbarIcon,
                  color: palette.muted,
                ),
              ],
            ),
          ),
          if (_expanded)
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: ScMetrics.rowCompact * 4,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: widget.rows,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
