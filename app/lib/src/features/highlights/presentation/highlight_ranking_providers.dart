import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../bridge/sportcut_engine.dart';
import '../../editing/domain/match_edit.dart';
import '../../editing/domain/rally.dart';
import '../../editing/presentation/editing_providers.dart';

/// The engine's suggested highlight order for the open match, keyed by rally id.
///
/// Recomputed whenever the edit reloads, so it always reflects the current
/// rallies and score. Empty while there is nothing to rank or the call is in
/// flight.
final highlightRankingProvider =
    FutureProvider<Map<String, HighlightRankDto>>((ref) async {
  final edit = ref.watch(editingControllerProvider).edit;
  if (edit == null || edit.rallies.isEmpty) {
    return const <String, HighlightRankDto>{};
  }
  final engine = ref.read(sportcutEngineProvider);
  final ranks = await engine.rankHighlights(<HighlightRallyDto>[
    for (final rally in edit.rallies)
      HighlightRallyDto(
        rallyId: rally.id,
        startSeconds: rally.startSeconds,
        endSeconds: rally.endSeconds,
        motion: rally.confidence,
        scoreContext: scoreContextFor(rally, edit),
      ),
  ]);
  return <String, HighlightRankDto>{
    for (final rank in ranks) rank.rallyId: rank,
  };
});

/// How important a rally's point was: `1 / (1 + score gap)` for a confirmed
/// rally, `0` for one that has no confirmed winner.
double scoreContextFor(Rally rally, MatchEdit edit) {
  final event = edit.score.atRally(rally.id);
  if (event == null) {
    return 0.0;
  }
  final gap = (event.leftScore - event.rightScore).abs();
  return 1.0 / (1.0 + gap);
}
