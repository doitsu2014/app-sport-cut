import '../../../bridge/sportcut_engine.dart';
import '../data/video_file_picker.dart';
import 'match_record.dart';

/// The library operations the presentation layer needs.
///
/// The screens depend on this rather than on the concrete repository, so widget
/// tests can run without a database or the native engine, and a different
/// storage backend can be substituted without touching the UI.
abstract interface class MatchLibrary {
  /// Every stored match, newest first.
  Future<List<MatchRecord>> listMatches();

  /// Create a match from a chosen recording, referencing it in place.
  Future<MatchRecord> importVideo(PickedVideo video, {String? title});

  /// Produce this match's derived artifacts.
  Future<MediaImportResultDto> generateArtifacts(
    MatchRecord match, {
    double samplingRate,
  });

  /// Delete a match, optionally removing its derived artifacts.
  Future<void> deleteMatch(
    MatchRecord match, {
    bool deleteArtifacts,
  });
}
