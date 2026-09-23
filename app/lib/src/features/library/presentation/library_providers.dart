import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../app/di.dart';
import '../data/match_catalog.dart';
import '../data/match_paths.dart';
import '../data/match_repository.dart';
import '../data/media_engine.dart';
import '../data/video_file_picker.dart';
import '../domain/match_library.dart';
import 'match_list_entry.dart';
import 'playback_controller.dart';
import 'video_player_playback_controller.dart';

/// Source of recordings to import.
final videoFilePickerProvider = Provider<VideoFilePicker>(
  (ref) => SystemVideoFilePicker(),
);

/// Creates the playback backend for a player screen.
///
/// Overridden in tests so the player can be driven without a platform video
/// implementation.
final playbackControllerFactoryProvider = Provider<PlaybackController Function()>(
  (ref) => VideoPlayerPlaybackController.new,
);

/// The application's catalog database.
final matchCatalogProvider = FutureProvider<MatchCatalog>((ref) async {
  final path = '${await getDatabasesPath()}/sportcut.db';
  return MatchCatalog.open(factory: databaseFactory, path: path);
});

/// Read and write matches.
final matchRepositoryProvider = FutureProvider<MatchLibrary>((ref) async {
  final catalog = await ref.watch(matchCatalogProvider.future);
  final engine = BridgeMediaEngine(ref.watch(sportcutEngineProvider));
  return MatchRepository(
    catalog: catalog,
    engine: engine,
    paths: await MatchPathsHolder.paths,
  );
});

/// Every stored match, newest first, with its recording's availability.
///
/// Availability is resolved here, once per list, rather than inside each row:
/// a match whose recording has gone missing should be visible and explicable,
/// not silently missing or failing later.
final matchListProvider = FutureProvider<List<MatchListEntry>>((ref) async {
  final repository = await ref.watch(matchRepositoryProvider.future);
  final matches = await repository.listMatches();
  return <MatchListEntry>[
    for (final match in matches)
      MatchListEntry(
        match: match,
        recordingAvailable: repository.isRecordingAvailable(match),
      ),
  ];
});

/// Documents directory path, resolved once per process.
class MatchPathsHolder {
  MatchPathsHolder._();

  /// The resolved paths.
  static Future<MatchPaths> get paths async {
    _cached ??= await MatchPaths.forDocuments();
    return _cached!;
  }

  static MatchPaths? _cached;
}
