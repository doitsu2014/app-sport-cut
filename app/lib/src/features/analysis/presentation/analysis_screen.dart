import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bridge/sportcut_engine.dart';
import '../../../app/router.dart';
import '../../library/domain/match_record.dart';
import '../../library/presentation/formatters.dart';
import 'analysis_providers.dart';

/// What the engine produced for a match, and how to rebuild what is gone.
class AnalysisScreen extends ConsumerStatefulWidget {
  /// Build the screen.
  const AnalysisScreen({required this.match, super.key});

  /// Match being inspected.
  final MatchRecord match;

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
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

    return Scaffold(
      appBar: AppBar(title: const Text('Analysis')),
      body: ListView(
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
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pushNamed(
              AppRoutes.playerTracking,
              arguments: widget.match,
            ),
            icon: const Icon(Icons.person_search_outlined),
            label: const Text('Review player analysis'),
          ),
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
                'library.',
              ),
            )
          else
            for (final artifact in state.manifest!.artifacts)
              _ArtifactTile(artifact: artifact),
        ],
      ),
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

class _ArtifactTile extends StatelessWidget {
  const _ArtifactTile({required this.artifact});

  final ArtifactDto artifact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      leading: Icon(_icon(artifact.kind)),
      title: Text(artifact.kind),
      subtitle: Text(
        artifact.relativePath,
        style: theme.textTheme.bodySmall,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(_stateLabel(artifact.state), style: theme.textTheme.labelSmall),
          if (artifact.sizeBytes != null)
            Text(
              formatBytes(artifact.sizeBytes!.toInt()),
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  /// A cancelled or interrupted artifact is shown as partial, never as a
  /// result: it is on disk for diagnosis, not for use.
  static String _stateLabel(ArtifactStateDto state) => switch (state) {
        ArtifactStateDto.final_ => 'ready',
        ArtifactStateDto.nonFinal => 'partial',
        ArtifactStateDto.missing => 'missing',
      };

  static IconData _icon(String kind) => switch (kind) {
        'proxy' => Icons.slow_motion_video_outlined,
        'analysis_audio' => Icons.graphic_eq,
        'frames' => Icons.photo_library_outlined,
        'export' => Icons.movie_filter_outlined,
        _ => Icons.folder_outlined,
      };
}
