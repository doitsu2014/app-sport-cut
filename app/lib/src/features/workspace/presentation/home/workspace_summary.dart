import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../library/presentation/library_providers.dart';
import '../../domain/workspace.dart';
import '../workspace_providers.dart';

/// A workspace with the counts the home list shows.
///
/// The catalog stores only the workspace's title and creation date, so the
/// counts and the newest video's date are derived from its matches here. The
/// result is presentation data: nothing is written and nothing is cached
/// beyond the provider's own lifetime.
class WorkspaceSummary {
  /// Pair a workspace with what the home row shows.
  const WorkspaceSummary({
    required this.workspace,
    required this.videoCount,
    required this.missingCount,
    this.lastVideoAt,
  });

  /// The workspace itself.
  final Workspace workspace;

  /// How many videos belong to the workspace.
  final int videoCount;

  /// How many of those videos have no readable recording.
  final int missingCount;

  /// When the newest video was added, or null when the workspace is empty.
  final DateTime? lastVideoAt;
}

/// Every workspace with its counts, in the catalog's oldest-first order.
///
/// The matches are read once per workspace per build of this provider, which
/// is one local SQLite query each — the same shape as the studio's video list.
/// Invalidating [workspaceListProvider] (after a create, delete, or import)
/// recomputes this provider too.
final workspaceSummariesProvider =
    FutureProvider<List<WorkspaceSummary>>((ref) async {
  final workspaces = await ref.watch(workspaceListProvider.future);
  final repository = await ref.watch(matchRepositoryProvider.future);

  final summaries = <WorkspaceSummary>[];
  for (final workspace in workspaces) {
    final matches = await repository.listMatches(workspaceId: workspace.id);
    var missing = 0;
    DateTime? lastVideoAt;
    for (final match in matches) {
      if (!repository.isRecordingAvailable(match)) {
        missing += 1;
      }
      final created = match.createdAt;
      if (lastVideoAt == null || created.isAfter(lastVideoAt)) {
        lastVideoAt = created;
      }
    }
    summaries.add(
      WorkspaceSummary(
        workspace: workspace,
        videoCount: matches.length,
        missingCount: missing,
        lastVideoAt: lastVideoAt,
      ),
    );
  }
  return List<WorkspaceSummary>.unmodifiable(summaries);
});
