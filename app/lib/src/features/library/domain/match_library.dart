import '../../../bridge/sportcut_engine.dart';
import '../../calibration/domain/court_calibration.dart';
import '../data/video_file_picker.dart';
import 'import_cancel_token.dart';
import 'match_record.dart';

/// The library operations the presentation layer needs.
///
/// The screens depend on this rather than on the concrete repository, so widget
/// tests can run without a database or the native engine, and a different
/// storage backend can be substituted without touching the UI.
abstract interface class MatchLibrary {
  /// Every stored match, newest first.
  Future<List<MatchRecord>> listMatches();

  /// The score each match has reached, keyed by match identifier.
  ///
  /// The library shows a score on every row, so this is one query for the whole
  /// list rather than one per match; a match with no confirmed rally is absent.
  Future<Map<String, ({int left, int right})>> scoreSummaries();

  /// Create a match from a chosen recording, taking custody of it.
  ///
  /// The picked file is copied into app-owned storage and it is that copy the
  /// match records; the file the user selected is never modified.
  Future<MatchRecord> importVideo(
    PickedVideo video, {
    String? title,
    ImportCancelToken? cancelToken,
  });

  /// Whether this match's stored recording can still be read.
  bool isRecordingAvailable(MatchRecord match);

  /// Produce this match's derived artifacts, returning what the match has once
  /// the engine reports the job finished.
  Future<ArtifactManifestDto> generateArtifacts(
    MatchRecord match, {
    double samplingRate,
  });

  /// Record the court the user marked on this match.
  ///
  /// The engine writes the calibration into the match directory and only then is
  /// the catalog updated, so a calibration the catalog holds always has a
  /// matching artifact behind it, and a failure leaves the previous calibration
  /// intact rather than half of a new one.
  Future<MatchRecord> saveCalibration(
    MatchRecord match,
    CourtCalibration calibration,
  );

  /// Delete a match, optionally removing its derived artifacts and the
  /// app-owned copy of its recording. The file the user selected is never
  /// deleted.
  Future<void> deleteMatch(
    MatchRecord match, {
    bool deleteArtifacts,
    bool deleteRecording,
  });
}
