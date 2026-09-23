import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The two app-owned filesystem roots a match uses.
///
/// They are deliberately separate directories. [artifactRoot] belongs to the
/// engine, which writes a fixed layout inside each match directory; deleting a
/// match's analysis files removes that directory recursively, so the recording
/// must not live in it. [recordingsRoot] holds the copy of the recording the
/// application took custody of at import and keeps for the life of the match.
class MatchPaths {
  /// Use explicit roots.
  const MatchPaths({required this.artifactRoot, required this.recordingsRoot});

  /// Root holding every match's engine artifact directory.
  final String artifactRoot;

  /// Root holding every match's app-owned copy of its recording.
  final String recordingsRoot;

  /// Engine artifact directory for one match.
  String matchDir(String matchId) => p.join(artifactRoot, matchId);

  /// App-owned recording directory for one match.
  String recordingDir(String matchId) => p.join(recordingsRoot, matchId);

  /// The default roots inside the application documents directory:
  /// `SportcutMatches` for the engine's artifacts and `SportcutRecordings` for
  /// the recordings the application owns.
  static Future<MatchPaths> forDocuments() async {
    final documents = await getApplicationDocumentsDirectory();
    return MatchPaths(
      artifactRoot: p.join(documents.path, 'SportcutMatches'),
      recordingsRoot: p.join(documents.path, 'SportcutRecordings'),
    );
  }
}
