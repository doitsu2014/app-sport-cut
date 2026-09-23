import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where a match's derived artifacts live.
///
/// Artifacts are deliberately outside the original recording's folder: the
/// recording is referenced in place and never moved or copied, and the derived
/// files stay separable so a user can delete them to reclaim space.
class MatchPaths {
  /// Use an explicit root directory.
  const MatchPaths(this.root);

  /// Root directory holding every match directory.
  final String root;

  /// Directory for one match.
  String matchDir(String matchId) => p.join(root, matchId);

  /// The default root: `SportcutMatches` inside the application documents
  /// directory.
  static Future<MatchPaths> forDocuments() async {
    final documents = await getApplicationDocumentsDirectory();
    return MatchPaths(p.join(documents.path, 'SportcutMatches'));
  }
}
