/// In-memory [MatchLibrary] for widget tests.
///
/// The screen tests exercise the UI contract with this double. The real
/// SQLite-backed repository is covered separately in match_repository_test.dart,
/// which runs outside the widget test's fake-async zone.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sportcut/src/bridge/sportcut_engine.dart';
import 'package:sportcut/src/features/calibration/domain/court_calibration.dart';
import 'package:sportcut/src/features/library/data/video_file_picker.dart';
import 'package:sportcut/src/features/library/domain/import_cancel_token.dart';
import 'package:sportcut/src/features/library/domain/match_library.dart';
import 'package:sportcut/src/features/library/domain/match_record.dart';
import 'package:sportcut/src/features/workspace/domain/workspace.dart';

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

  /// Value passed to the last [deleteMatch] call.
  bool? lastDeleteRecording;

  /// Match removed by the last [deleteMatch] call.
  MatchRecord? lastDeleted;

  /// Calibration passed to the last [saveCalibration] call.
  CourtCalibration? lastSavedCalibration;

  /// Score reported for each match by [scoreSummaries].
  Map<String, ({int left, int right})> scores =
      <String, ({int left, int right})>{};

  @override
  Future<List<MatchRecord>> listMatches({String? workspaceId}) async {
    if (workspaceId == null) {
      return List<MatchRecord>.unmodifiable(matches);
    }
    return List<MatchRecord>.unmodifiable(
      matches.where((match) => match.workspaceId == workspaceId),
    );
  }

  @override
  Future<List<Workspace>> listWorkspaces() async => const <Workspace>[];

  @override
  Future<Workspace> createWorkspace({String? title}) async => Workspace(
        id: 'workspace-1',
        title: title ?? 'Untitled workspace',
        createdAt: DateTime(2026, 3, 2),
      );

  @override
  Future<void> deleteWorkspace(
    Workspace workspace, {
    bool deleteArtifacts = false,
    bool deleteRecording = false,
  }) async {}

  @override
  Future<ArtifactManifestDto> manifest(MatchRecord match) async =>
      ArtifactManifestDto(
        matchId: match.id,
        originalPath: match.videoPath,
        artifacts: const <ArtifactDto>[],
        missingKinds: const <String>[],
        notRebuildableKinds: const <String>[],
        originalPresent: true,
      );

  @override
  Future<Map<String, int>> selectedClipCounts() async => const <String, int>{};

  @override
  Future<Map<String, ({int left, int right})>> scoreSummaries() async => scores;

  @override
  Future<MatchRecord> importVideo(
    PickedVideo video, {
    String? title,
    String? workspaceId,
    ImportCancelToken? cancelToken,
  }) async {
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
      workspaceId: workspaceId,
      videoWidth: 1920,
      videoHeight: 1080,
      frameRate: 30,
      hasAudio: true,
      originalPath: video.path,
      sourceBytes: 512,
    );
    matches.insert(0, match);
    return match;
  }

  @override
  bool isRecordingAvailable(MatchRecord match) => File(match.videoPath).existsSync();

  @override
  Future<ArtifactManifestDto> generateArtifacts(
    MatchRecord match, {
    double samplingRate = 1,
  }) async {
    generateCalls += 1;
    final error = failure;
    if (error != null) {
      throw error;
    }
    return ArtifactManifestDto(
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
      notRebuildableKinds: const <String>[],
      originalPresent: true,
    );
  }

  @override
  Future<MatchRecord> saveCalibration(
    MatchRecord match,
    CourtCalibration calibration,
  ) async {
    final error = failure;
    if (error != null) {
      throw error;
    }
    lastSavedCalibration = calibration;
    final updated = match.copyWith(courtCalibration: calibration);
    final index = matches.indexWhere((stored) => stored.id == match.id);
    if (index >= 0) {
      matches[index] = updated;
    }
    return updated;
  }

  @override
  Future<void> deleteMatch(
    MatchRecord match, {
    bool deleteArtifacts = false,
    bool deleteRecording = false,
  }) async {
    lastDeleteArtifacts = deleteArtifacts;
    lastDeleteRecording = deleteRecording;
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
