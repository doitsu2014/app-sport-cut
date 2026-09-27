import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bridge/sportcut_engine.dart';
import '../../library/domain/match_record.dart';
import '../../library/presentation/formatters.dart';
import 'analysis_providers.dart';

/// What the engine produced for a match, and how to rebuild what is gone.
///
/// A form-style panel with no playback of its own, so the studio hosts it
/// directly in the center pane.
class AnalysisView extends ConsumerStatefulWidget {
  /// Build the analysis view.
  const AnalysisView({super.key, required this.match, this.onOpenTracking});

  /// Match being inspected.
  final MatchRecord match;

  /// Called when the user wants to review player analysis; the studio switches
  /// to the tracking feature and the route wrapper pushes the tracking screen.
  final VoidCallback? onOpenTracking;

  @override
  ConsumerState<AnalysisView> createState() => _AnalysisViewState();
}

class _AnalysisViewState extends ConsumerState<AnalysisView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref.read(analysisControllerProvider.notifier).open(widget.match),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analysisControllerProvider);
    final controller = ref.read(analysisControllerProvider.notifier);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        if (state.problem != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              state.problem!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.movie_outlined),
            title: Text(widget.match.title),
            subtitle: Text(
              _summary(widget.match),
              style: theme.textTheme.bodySmall,
            ),
            isThreeLine: true,
          ),
        ),
        const SizedBox(height: 8),
        if (state.running) ...<Widget>[
          LinearProgressIndicator(value: state.progress),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(child: Text(_stageLabel(state.stage))),
              TextButton(
                onPressed: controller.cancel,
                child: const Text('Cancel'),
              ),
            ],
          ),
        ] else
          FilledButton.tonalIcon(
            onPressed: state.missing.isEmpty
                ? null
                : () => controller.repair(widget.match),
            icon: const Icon(Icons.healing_outlined),
            label: Text(
              state.missing.isEmpty
                  ? 'Nothing to rebuild'
                  : 'Rebuild ${state.missing.length} missing '
                      '${state.missing.length == 1 ? 'file' : 'files'}',
            ),
          ),
        if (widget.onOpenTracking != null) ...<Widget>[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: widget.onOpenTracking,
            icon: const Icon(Icons.person_search_outlined),
            label: const Text('Review player analysis'),
          ),
        ],
        const SizedBox(height: 16),
        Text('Artifacts', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        if (!state.loaded)
          const Center(child: CircularProgressIndicator())
        else if ((state.manifest?.artifacts ?? const <ArtifactDto>[]).isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'This match has no analysis files yet. Prepare them from the '
              'studio.',
            ),
          )
        else
          DataTable(
            columns: const <DataColumn>[
              DataColumn(label: Text('Kind')),
              DataColumn(label: Text('Path')),
              DataColumn(label: Text('State')),
              DataColumn(label: Text('Size'), numeric: true),
            ],
            rows: <DataRow>[
              for (final artifact in state.manifest!.artifacts)
                DataRow(
                  cells: <DataCell>[
                    DataCell(
                      Row(
                        children: <Widget>[
                          Icon(
                            _artifactIcon(artifact.kind),
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(artifact.kind),
                        ],
                      ),
                    ),
                    DataCell(Text(artifact.relativePath)),
                    DataCell(_StateChip(state: artifact.state)),
                    DataCell(
                      Text(
                        artifact.sizeBytes != null
                            ? formatBytes(artifact.sizeBytes!.toInt())
                            : '—',
                      ),
                    ),
                  ],
                ),
            ],
          ),
      ],
    );
  }

  static String _summary(MatchRecord match) {
    final parts = <String>[
      formatDuration(match.durationSeconds),
      if (match.videoWidth != null && match.videoHeight != null)
        '${match.videoWidth}×${match.videoHeight}',
      if (match.frameRate != null) '${match.frameRate!.toStringAsFixed(2)} fps',
      if (match.hasAudio) 'audio',
    ];
    return parts.join('  ·  ');
  }

  static String _stageLabel(String? stage) => switch (stage) {
        'probe' => 'Reading the recording…',
        'proxy' => 'Rebuilding the proxy…',
        'audio' => 'Rebuilding the analysis audio…',
        'frames' => 'Sampling frames…',
        'regenerate' => 'Working out what to rebuild…',
        _ => 'Working…',
      };
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.state});

  final ArtifactStateDto state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, border, color) = switch (state) {
      ArtifactStateDto.final_ => ('ready', scheme.primary, scheme.primary),
      ArtifactStateDto.nonFinal => (
          'partial',
          scheme.outline,
          scheme.onSurfaceVariant,
        ),
      ArtifactStateDto.missing => ('missing', scheme.error, scheme.error),
    };
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: color,
        ),
      ),
    );
  }
}

IconData _artifactIcon(String kind) => switch (kind) {
      'proxy' => Icons.slow_motion_video_outlined,
      'analysis_audio' => Icons.graphic_eq,
      'frames' => Icons.photo_library_outlined,
      'export' => Icons.movie_filter_outlined,
      _ => Icons.folder_outlined,
    };
