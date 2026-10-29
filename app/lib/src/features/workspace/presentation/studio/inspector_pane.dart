import 'package:flutter/material.dart';

import '../../../../app/design/components/sc_panel.dart';
import '../../../../app/design/components/sc_pipeline_row.dart';
import '../../../../app/design/sc_status.dart';
import '../../../../app/design/sc_tints.dart';
import '../../../../app/design/sportcut_tokens.dart';
import '../../domain/pipeline_stage.dart';

/// The right rail: the pipeline stages as a selectable, stateful list.
///
/// The rows are grouped into the stages that read the match and the stages
/// that shape the reel. The Rally and Clip tabs replace this body later; for
/// now it is the pipeline. The pane reads no provider: the composition root
/// passes the resolved states and callbacks.
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
    final doneCount = <PipelineStage>[..._analysis, ..._studio]
        .where((stage) => states[stage] == StageState.done)
        .length;
    final playStatus = states.isEmpty ? ScStatus.idle : ScStatus.ready;
    var number = 0;
    final analysisRows = <Widget>[
      for (final stage in _analysis) _row(stage, ++number),
    ];
    final studioRows = <Widget>[
      for (final stage in _studio) _row(stage, ++number),
    ];

    return Container(
      decoration: BoxDecoration(
        color: ScTints.railSurface(palette.surface, palette.bg),
        border: Border(left: BorderSide(color: palette.border)),
      ),
      child: Column(
        children: <Widget>[
          ScRailHeader(label: 'Pipeline', count: doneCount),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(tokens.space2),
              children: <Widget>[
                ScPipelineRow(
                  number: 0,
                  name: 'Play',
                  status: playStatus,
                  selected: selectedStage == null,
                  onTap: onSelectPlay,
                ),
                const ScSectionHeader(label: 'Analysis'),
                ...analysisRows,
                const ScSectionHeader(label: 'Studio'),
                ...studioRows,
              ],
            ),
          ),
        ],
      ),
    );
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
