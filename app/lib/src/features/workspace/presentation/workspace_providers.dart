import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bridge/generated/dto.dart';
import '../../library/presentation/library_providers.dart';
import '../../library/presentation/match_list_entry.dart';
import '../domain/pipeline_stage.dart';
import '../domain/workspace.dart';

/// Every workspace, oldest first.
final workspaceListProvider = FutureProvider<List<Workspace>>((ref) async {
  final repository = await ref.watch(matchRepositoryProvider.future);
  return repository.listWorkspaces();
});

/// The videos in one workspace, with their availability and score.
final workspaceVideosProvider =
    FutureProvider.family<List<MatchListEntry>, String>(
        (ref, workspaceId) async {
  final repository = await ref.watch(matchRepositoryProvider.future);
  final matches = await repository.listMatches(workspaceId: workspaceId);
  final scores = await repository.scoreSummaries();
  return <MatchListEntry>[
    for (final match in matches)
      MatchListEntry(
        match: match,
        recordingAvailable: repository.isRecordingAvailable(match),
        score: scores[match.id],
      ),
  ];
});

/// Each video's pipeline progress in one workspace, gathered once per view.
///
/// Manifests are read once per video here — a bridge call each — and cached by
/// Riverpod until a stage finishes and invalidates the provider, rather than
/// being re-read on every rebuild.
final workspaceVideoFactsProvider =
    FutureProvider.family<Map<String, VideoStageFacts>, String>(
        (ref, workspaceId) async {
  final repository = await ref.watch(matchRepositoryProvider.future);
  final matches = await repository.listMatches(workspaceId: workspaceId);
  final scores = await repository.scoreSummaries();
  final clips = await repository.selectedClipCounts();

  final facts = <String, VideoStageFacts>{};
  for (final match in matches) {
    final manifest = await repository.manifest(match);
    facts[match.id] = VideoStageFacts(
      recordingAvailable: repository.isRecordingAvailable(match),
      calibrated: match.courtCalibration?.isComplete ?? false,
      analysisReady: _hasFinal(manifest.artifacts, 'frames'),
      tracksReady: _hasFinal(manifest.artifacts, 'tracks'),
      exportReady: _hasFinal(manifest.artifacts, 'export'),
      hasScore: scores.containsKey(match.id),
      hasSelectedClips: (clips[match.id] ?? 0) > 0,
    );
  }
  return facts;
});

bool _hasFinal(List<ArtifactDto> artifacts, String kind) =>
    artifacts.any((a) => a.kind == kind && a.state == ArtifactStateDto.final_);
