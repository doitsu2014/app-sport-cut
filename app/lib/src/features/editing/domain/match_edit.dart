import 'export_settings.dart';
import 'highlight_clip.dart';
import 'rally.dart';
import 'score_timeline.dart';

/// Everything a review session shows at once.
///
/// Loaded together because the parts are one thing: a clip comes from a rally,
/// the scoreboard on that clip comes from the score at its position, and the
/// settings shape how the reel is rendered.
class MatchEdit {
  /// Describe a match's editing state.
  const MatchEdit({
    required this.rallies,
    required this.clips,
    required this.score,
    required this.exportSettings,
  });

  /// Marked rallies, in recording order.
  final List<Rally> rallies;

  /// Clips in the reel, in the order the user set.
  final List<HighlightClip> clips;

  /// Score derived from the confirmed rallies.
  final ScoreTimeline score;

  /// Choices that shape the export.
  final ExportSettings exportSettings;

  /// Rallies that have a clip in the reel.
  Set<String> get clippedRallyIds => clips
      .map((clip) => clip.rallyId)
      .whereType<String>()
      .toSet();

  /// Whether a rally is in the reel.
  bool isKept(Rally rally) => clippedRallyIds.contains(rally.id);

  /// The clip made from a rally, or `null` when it is not in the reel.
  HighlightClip? clipForRally(String rallyId) {
    for (final clip in clips) {
      if (clip.rallyId == rallyId) {
        return clip;
      }
    }
    return null;
  }

  /// The reel's duration, in seconds.
  double get reelSeconds =>
      clips.fold(0, (total, clip) => total + clip.durationSeconds);
}
