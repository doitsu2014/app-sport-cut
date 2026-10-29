import 'package:flutter/material.dart';

import '../../../../app/design/sc_metrics.dart';
import '../../../../app/design/sportcut_tokens.dart';
import '../../domain/pipeline_stage.dart';
import 'studio_chrome.dart';

/// The right rail listing the pipeline stages as selectable features.
class InspectorPane extends StatelessWidget {
  /// Build the inspector for the selected video's [states].
  const InspectorPane({
    super.key,
    required this.states,
    required this.selectedStage,
    required this.busyStages,
    required this.onSelectPlay,
    required this.onSelectStage,
  });

  /// The resolved state of every stage for the selected video.
  final Map<PipelineStage, StageState> states;

  /// The selected feature, where null means playback.
  final PipelineStage? selectedStage;

  /// Stages with a job running in the background for the selected video.
  final Set<PipelineStage> busyStages;

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
    final scheme = Theme.of(context).colorScheme;
    final tokens = SportcutTokens.of(context);
    final doneCount =
        states.values.where((state) => state == StageState.done).length;
    return Container(
      width: ScMetrics.inspectorWidth,
      color: scheme.surface,
      child: Column(
        children: <Widget>[
          RailHeader(
            label: 'Pipeline',
            trailing: '$doneCount / ${PipelineStage.values.length}',
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(tokens.space2),
              children: <Widget>[
                FeatureRow(
                  label: 'Play',
                  selected: selectedStage == null,
                  icon: Icons.play_circle_outline,
                  done: false,
                  ready: false,
                  onTap: onSelectPlay,
                ),
                const SectionHeader(label: 'Analysis'),
                for (final stage in _analysis) _item(stage),
                const SectionHeader(label: 'Studio'),
                for (final stage in _studio) _item(stage),
              ],
            ),
          ),
        ],
      ),
    );
  }

  FeatureRow _item(PipelineStage stage) => FeatureRow(
        label: stage.label,
        selected: selectedStage == stage,
        icon: _stageIcon(stage),
        done: states[stage] == StageState.done,
        ready: states[stage] == StageState.ready,
        busy: busyStages.contains(stage),
        onTap: () => onSelectStage(stage),
      );

  static IconData _stageIcon(PipelineStage stage) => switch (stage) {
        PipelineStage.import => Icons.download_done,
        PipelineStage.calibrate => Icons.grid_on,
        PipelineStage.analyze => Icons.settings_input_component,
        PipelineStage.track => Icons.person_search,
        PipelineStage.score => Icons.scoreboard,
        PipelineStage.highlight => Icons.star_outline,
        PipelineStage.export => Icons.ios_share,
      };
}

/// One selectable feature in the [InspectorPane].
class FeatureRow extends StatelessWidget {
  /// Build a feature row.
  const FeatureRow({
    super.key,
    required this.label,
    required this.selected,
    required this.icon,
    required this.done,
    required this.ready,
    this.busy = false,
    required this.onTap,
  });

  /// The feature's name.
  final String label;

  /// Whether this is the showing feature.
  final bool selected;

  /// The feature's icon.
  final IconData icon;

  /// Whether the feature's output exists.
  final bool done;

  /// Whether the feature can be done now.
  final bool ready;

  /// Whether this feature's job is running in the background.
  final bool busy;

  /// Open the feature.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = SportcutTokens.of(context);
    final palette = SportcutPalette.of(context);
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;

    return Material(
      color: selected ? scheme.surfaceContainerHighest : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        side: BorderSide(
          color: selected ? scheme.outlineVariant : Colors.transparent,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.space3,
            vertical: tokens.space2,
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: color),
              SizedBox(width: tokens.space2),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color:
                        selected ? scheme.onSurface : scheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (busy)
                const BusySpinner(tooltip: 'Running in the background')
              else if (done)
                Icon(Icons.check, size: 15, color: palette.success)
              else if (ready)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
