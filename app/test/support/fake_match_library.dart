/// In-memory [MatchLibrary] for widget tests.
///
/// The screen tests exercise the UI contract with this double. The real
/// SQLite-backed repository is covered separately in match_repository_test.dart,
/// which runs outside the widget test's fake-async zone.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sportcut/src/bridge/sportcut_engine.dart';
import 'package:sportcut/src/features/library/data/video_file_picker.dart';
import 'package:sportcut/src/features/library/domain/match_library.dart';
import 'package:sportcut/src/features/library/domain/match_record.dart';

class FakeMatchLibrary implements MatchLibrary {
  FakeMatchLibrary({List<MatchRecord>? matches})
      : matches = List<MatchRecord>.from(matches ?? const <MatchRecord>[]);

  /// Stored matches, newest first.
  final List<MatchRecord> matches;

  /// Error thrown by [importVideo] and [generateArtifacts], when set.
  Object? failure;

  /// Number of import calls.
  int importCalls = 0;

  /// Number of artifact-generation calls.
  int generateCalls = 0;

  /// Value passed to the last [deleteMatch] call.
  bool? lastDeleteArtifacts;

  /// Match removed by the last [deleteMatch] call.
  MatchRecord? lastDeleted;

  @override
  Future<List<MatchRecord>> listMatches() async =>
      List<MatchRecord>.unmodifiable(matches);

  @override
  Future<MatchRecord> importVideo(PickedVideo video, {String? title}) async {
    importCalls += 1;
    final error = failure;
    if (error != null) {
      throw error;
    }
    final name = video.displayName ?? p.basename(video.path);
    final id = 'match-${matches.length + 1}';
    final match = MatchRecord(
      id: id,
      title: title ?? (name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name),
      videoPath: video.path,
      durationSeconds: 90.5,
      createdAt: DateTime(2026, 3, 2),
      matchDir: p.join(p.dirname(video.path), 'matches', id),
      videoWidth: 1920,
      videoHeight: 1080,
      frameRate: 30,
      hasAudio: true,
    );
    matches.insert(0, match);
    return match;
  }

  @override
  Future<MediaImportResultDto> generateArtifacts(
    MatchRecord match, {
    double samplingRate = 1,
  }) async {
    generateCalls += 1;
    final error = failure;
    if (error != null) {
      throw error;
    }
    return MediaImportResultDto(
      metadata: MediaMetadataDto(
        path: match.videoPath,
        durationSeconds: match.durationSeconds,
        frameRate: match.frameRate ?? 30,
        width: match.videoWidth ?? 1920,
        height: match.videoHeight ?? 1080,
        rotationDegrees: 0,
        orientation: OrientationDto.landscape,
        hasAudio: match.hasAudio,
        sizeBytes: BigInt.from(1024),
      ),
      manifest: ArtifactManifestDto(
        matchId: match.id,
        originalPath: match.videoPath,
        artifacts: <ArtifactDto>[
          ArtifactDto(
            kind: 'proxy',
            relativePath: 'proxy/proxy.mp4',
            state: ArtifactStateDto.final_,
            sizeBytes: BigInt.from(1024),
          ),
          ArtifactDto(
            kind: 'frames',
            relativePath: 'frames',
            state: ArtifactStateDto.final_,
            sizeBytes: BigInt.from(1024),
          ),
        ],
        missingKinds: const <String>[],
        originalPresent: true,
      ),
      job: JobStatusDto(
        jobId: 'job-1',
        matchId: match.id,
        state: JobStateDto.completed,
        stage: 'frames',
        progress: null,
        error: null,
        completedStages: const <String>['probe', 'proxy', 'audio', 'frames'],
      ),
      framesSampled: 45,
      skippedStages: const <String>[],
    );
  }

  @override
  Future<void> deleteMatch(
    MatchRecord match, {
    bool deleteArtifacts = false,
  }) async {
    lastDeleteArtifacts = deleteArtifacts;
    lastDeleted = match;
    matches.removeWhere((stored) => stored.id == match.id);
    if (deleteArtifacts) {
      final directory = Directory(match.matchDir);
      if (directory.existsSync()) {
        // Synchronous on purpose: widget tests run in a fake-async zone where a
        // real asynchronous filesystem call would never complete.
        directory.deleteSync(recursive: true);
      }
    }
  }
}
