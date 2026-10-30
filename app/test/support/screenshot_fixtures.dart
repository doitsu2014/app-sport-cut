/// Deterministic fixtures for the screenshot suites.
///
/// Every builder is single-purpose and returns a fresh object, so a suite can
/// compose the set it needs and change one value without affecting another
/// screen. Dates are stable: the default is 2 March of the current year, which
/// keeps the home row's `Last video 2 Mar` label year-stable while still
/// omitting the year the way the real list does.
///
/// Nothing here reads the machine's filesystem. Call
/// [writeRecordingPlaceholder] with an explicit temporary directory when a
/// screen checks `isRecordingAvailable`.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sportcut/src/bridge/sportcut_engine.dart';
import 'package:sportcut/src/features/calibration/domain/court_calibration.dart';
import 'package:sportcut/src/features/editing/domain/export_settings.dart';
import 'package:sportcut/src/features/editing/domain/highlight_clip.dart';
import 'package:sportcut/src/features/editing/domain/rally.dart';
import 'package:sportcut/src/features/library/domain/match_record.dart';
import 'package:sportcut/src/features/workspace/domain/workspace.dart';

import 'fake_match_editing.dart';
import 'fake_match_library.dart';
import 'fakes.dart';

/// 2 March of the current year, the date every default fixture carries.
///
/// Using the current year keeps the home row's date label as `2 Mar` rather
/// than `2 Mar 2026`, no matter when the suite runs.
DateTime screenshotDate() => DateTime(DateTime.now().year, 3, 2);

/// A workspace for the home and studio screens.
Workspace screenshotWorkspace({
  String id = 'ws-1',
  String title = 'Thursday club night',
  DateTime? createdAt,
}) =>
    Workspace(
      id: id,
      title: title,
      createdAt: createdAt ?? screenshotDate(),
    );

/// A match record with the fields the studio fixtures need.
///
/// Paths are relative placeholders, not machine paths: a suite that needs
/// [MatchLibrary.isRecordingAvailable] to answer `true` writes a real file with
/// [writeRecordingPlaceholder] and passes its path as [videoPath].
MatchRecord screenshotMatch({
  String id = 'match-1',
  String title = 'Club final',
  String? workspaceId,
  String? videoPath,
  double durationSeconds = 90,
  CourtCalibration? courtCalibration,
  DateTime? createdAt,
  String? matchDir,
  int? videoWidth = 1920,
  int? videoHeight = 1080,
  double? frameRate = 30,
  bool hasAudio = true,
  String? originalPath,
  int? sourceBytes,
}) {
  final path = videoPath ?? p.join('recordings', '$id.mp4');
  return MatchRecord(
    id: id,
    title: title,
    videoPath: path,
    durationSeconds: durationSeconds,
    createdAt: createdAt ?? screenshotDate(),
    matchDir: matchDir ?? p.join('matches', id),
    workspaceId: workspaceId,
    videoWidth: videoWidth,
    videoHeight: videoHeight,
    frameRate: frameRate,
    hasAudio: hasAudio,
    originalPath: originalPath ?? path,
    sourceBytes: sourceBytes,
    courtCalibration: courtCalibration,
  );
}

/// A scored or unscored rally.
Rally screenshotRally({
  String id = 'rally-1',
  String matchId = 'match-1',
  double startSeconds = 10,
  double endSeconds = 20,
  WinnerSide? winnerSide,
  RallyStatus? status,
}) =>
    Rally(
      id: id,
      matchId: matchId,
      startSeconds: startSeconds,
      endSeconds: endSeconds,
      winnerSide: winnerSide,
      status: status ??
          (winnerSide == null ? RallyStatus.unscored : RallyStatus.confirmed),
    );

/// One clip in the reels the review and export screens read.
HighlightClip screenshotClip({
  String id = 'clip-rally-1',
  String matchId = 'match-1',
  String? rallyId = 'rally-1',
  double startSeconds = 10,
  double endSeconds = 20,
  int orderIndex = 0,
  int? rank,
  double? trimStartSeconds,
  double? trimEndSeconds,
}) =>
    HighlightClip(
      id: id,
      matchId: matchId,
      rallyId: rallyId,
      startSeconds: startSeconds,
      endSeconds: endSeconds,
      orderIndex: orderIndex,
      rank: rank,
      trimStartSeconds: trimStartSeconds,
      trimEndSeconds: trimEndSeconds,
    );

/// The complete court marking, using the calibration controller's defaults.
CourtCalibration screenshotCourtCalibration({
  CourtOrientation orientation = CourtOrientation.away,
}) =>
    CourtCalibration.fromCorners(
      corners: const <CourtCorner>[
        CourtCorner(x: 0.10, y: 0.88),
        CourtCorner(x: 0.90, y: 0.88),
        CourtCorner(x: 0.72, y: 0.28),
        CourtCorner(x: 0.28, y: 0.28),
      ],
      orientation: orientation,
    );

/// The same court marking on the wire, for engine-facing fakes.
CourtCalibrationDto screenshotCalibrationDto({
  CourtOrientationDto orientation = CourtOrientationDto.away,
}) =>
    CourtCalibrationDto(
      schemaVersion: 1,
      segments: <CalibrationSegmentDto>[
        CalibrationSegmentDto(
          fromMs: 0,
          corners: const <CourtCornerDto>[
            CourtCornerDto(x: 0.10, y: 0.88),
            CourtCornerDto(x: 0.90, y: 0.88),
            CourtCornerDto(x: 0.72, y: 0.28),
            CourtCornerDto(x: 0.28, y: 0.28),
          ],
          orientation: orientation,
        ),
      ],
    );

/// A deterministic artifact list for the analysis and export screens.
///
/// The default is the proxy and frames the analysis panel shows as `READY`.
/// [missing] reports them as `MISSING` instead, and [includeTracks] and
/// [includeExport] add the kinds the tracking and export fixtures need.
List<ArtifactDto> screenshotArtifacts({
  bool includeTracks = false,
  bool includeExport = false,
  bool missing = false,
}) {
  final state = missing ? ArtifactStateDto.missing : ArtifactStateDto.final_;
  return <ArtifactDto>[
    ArtifactDto(
      kind: 'proxy',
      relativePath: 'proxy/proxy.mp4',
      state: state,
      sizeBytes: 2048,
    ),
    ArtifactDto(
      kind: 'frames',
      relativePath: 'frames',
      state: state,
      sizeBytes: 1024,
    ),
    if (includeTracks)
      ArtifactDto(
        kind: 'tracks',
        relativePath: 'tracks/tracks.json',
        state: state,
        sizeBytes: 3072,
      ),
    if (includeExport)
      ArtifactDto(
        kind: 'export',
        relativePath: 'export/highlight.mp4',
        state: state,
        sizeBytes: 4096,
      ),
  ];
}

/// A manifest with the standard artifact set.
ArtifactManifestDto screenshotManifest({
  String matchId = 'match-1',
  String originalPath = 'recordings/match-1.mp4',
  List<ArtifactDto>? artifacts,
  List<String> missingKinds = const <String>[],
  List<String> notRebuildableKinds = const <String>[],
  bool originalPresent = true,
}) =>
    ArtifactManifestDto(
      matchId: matchId,
      originalPath: originalPath,
      artifacts: artifacts ?? screenshotArtifacts(),
      missingKinds: missingKinds,
      notRebuildableKinds: notRebuildableKinds,
      originalPresent: originalPresent,
    );

/// An in-memory library populated with the given workspaces and matches.
///
/// [manifestArtifacts], [clipCounts], and [scores] seed the per-match facts the
/// studio stage strip and score rows read; leave them out for the empty states.
FakeMatchLibrary screenshotLibrary({
  List<Workspace>? workspaces,
  List<MatchRecord>? matches,
  Map<String, List<ArtifactDto>>? manifestArtifacts,
  Map<String, int>? clipCounts,
  Map<String, ({int left, int right})>? scores,
}) {
  final library = FakeMatchLibrary(
    workspaces: workspaces,
    matches: matches,
    manifestArtifacts: manifestArtifacts,
    clipCounts: clipCounts,
  );
  if (scores != null) {
    library.scores.addAll(scores);
  }
  return library;
}

/// An in-memory editing session with the given rallies, clips, and settings.
FakeMatchEditing screenshotEditing({
  List<Rally>? rallies,
  List<HighlightClip>? clips,
  ExportSettings? settings,
}) =>
    FakeMatchEditing(
      rallies: rallies,
      clips: clips,
      settings: settings,
    );

/// A media engine configured so the analysis, calibration, and export screens
/// settle with meaningful data.
///
/// [manifest] supplies the artifacts the analysis panel lists; [artifacts]
/// overrides just the list when a suite does not need the full manifest.
/// [calibration] is what `matchCalibration` reports. [jobState], [jobStage],
/// and [jobError] shape the progress and failure cards a suite wants to drive.
FakeMediaEngine screenshotEngine({
  ArtifactManifestDto? manifest,
  CourtCalibrationDto? calibration,
  List<ArtifactDto>? artifacts,
  double durationSeconds = 90,
  JobStateDto jobState = JobStateDto.completed,
  String? jobStage = 'frames',
  String? jobError,
  Object? failure,
}) {
  final engine = FakeMediaEngine(
    durationSeconds: durationSeconds,
    failure: failure,
  );
  engine.jobState = jobState;
  engine.jobStage = jobStage;
  engine.jobError = jobError;
  engine.manifestArtifacts = artifacts ?? manifest?.artifacts;
  engine.storedCalibration = calibration;
  return engine;
}

/// Two observed players, a coverage interval, and one short track gap.
///
/// The observation boxes sit inside a 16:9 stage and are timestamped at zero,
/// which is where the tracking overlay looks for the play position it paints.
PlayerTracksDto screenshotPlayerTracks({
  ObservedPlayerCountDto count = ObservedPlayerCountDto.two,
  double countQuality = 0.92,
}) =>
    PlayerTracksDto(
      schemaVersion: 1,
      modelId: 'person-detector@2026.1',
      count: count,
      countQuality: countQuality,
      countEvidence: const TrackIntervalDto(
        startSeconds: 0,
        endSeconds: 5,
      ),
      coverage: const <TrackIntervalDto>[
        TrackIntervalDto(startSeconds: 0, endSeconds: 5),
      ],
      usableCoverage: const <TrackIntervalDto>[
        TrackIntervalDto(startSeconds: 0, endSeconds: 5),
      ],
      gaps: const <PlayerGapDto>[
        PlayerGapDto(
          trackId: 1,
          time: TrackIntervalDto(startSeconds: 1.2, endSeconds: 1.8),
        ),
      ],
      frames: const <PlayerTrackFrameDto>[
        PlayerTrackFrameDto(
          timestampSeconds: 0,
          people: <PlayerObservationDto>[
            PlayerObservationDto(
              confidence: 0.9,
              boxX: 0.28,
              boxY: 0.45,
              boxWidth: 0.10,
              boxHeight: 0.30,
              side: PlayerCourtSideDto.first,
              selection: PersonSelectionDto.onCourt,
              associationAmbiguous: false,
              trackId: 1,
            ),
            PlayerObservationDto(
              confidence: 0.88,
              boxX: 0.62,
              boxY: 0.42,
              boxWidth: 0.11,
              boxHeight: 0.31,
              side: PlayerCourtSideDto.second,
              selection: PersonSelectionDto.onCourt,
              associationAmbiguous: false,
              trackId: 2,
            ),
          ],
        ),
      ],
    );

/// The serving-side suggestions the score screen can show.
Map<String, RallySideDto> screenshotServingSides({
  Map<String, RallySideDto> sides = const <String, RallySideDto>{
    'rally-2': RallySideDto.left,
    'rally-3': RallySideDto.right,
  },
}) =>
    Map<String, RallySideDto>.of(sides);

/// The highlight ranks the review screen can show.
Map<String, HighlightRankDto> screenshotHighlightRanking({
  Map<String, HighlightRankDto> ranks = const <String, HighlightRankDto>{
    'rally-1': HighlightRankDto(rallyId: 'rally-1', score: 0.82, rank: 2),
    'rally-2': HighlightRankDto(rallyId: 'rally-2', score: 0.95, rank: 1),
    'rally-3': HighlightRankDto(rallyId: 'rally-3', score: 0.40, rank: 3),
  },
}) =>
    Map<String, HighlightRankDto>.of(ranks);

/// An engine double for the route-level player-tracking screen.
///
/// [tracks] is what `matchPlayerTracks` returns. The builder defaults it to
/// [screenshotPlayerTracks] so the screen settles with boxes and a loaded panel;
/// pass [tracksMissing] to model a match with no track artifact yet. The job
/// fields let a suite capture the analyzing and failed states.
ScreenshotSportcutEngine screenshotSportcutEngine({
  PlayerTracksDto? tracks,
  bool tracksMissing = false,
  JobStateDto jobState = JobStateDto.completed,
  String? jobStage = 'person_detection',
  String? jobError,
}) =>
    ScreenshotSportcutEngine(
      tracks: tracksMissing ? null : (tracks ?? screenshotPlayerTracks()),
      jobState: jobState,
      jobStage: jobStage,
      jobError: jobError,
    );

/// A [SportcutEngine] double serving player tracks and tracking job status.
///
/// Only the tracking route needs an engine: the studio supplies a fake tracking
/// controller instead. The remaining methods are unreachable through the
/// screenshots and forward to [noSuchMethod].
class ScreenshotSportcutEngine implements SportcutEngine {
  /// Build the double over the given track result.
  ScreenshotSportcutEngine({
    this.tracks,
    this.jobState = JobStateDto.completed,
    this.jobStage = 'person_detection',
    this.jobError,
  });

  /// Result [matchPlayerTracks] returns, or `null` for no track artifact.
  PlayerTracksDto? tracks;

  /// State [jobStatus] and [jobCancel] report.
  JobStateDto jobState;

  /// Stage [jobStatus] reports.
  String? jobStage;

  /// Failure reason [jobStatus] reports when [jobState] is failed.
  String? jobError;

  /// Error thrown by [matchPlayerTracks] instead of returning [tracks].
  Object? tracksFailure;

  /// Windows requested through [matchPlayerTracks], in order.
  final List<PlayerTrackWindowRequestDto> windows =
      <PlayerTrackWindowRequestDto>[];

  /// Number of tracking jobs started by [startPlayerTracking].
  int trackingStartCalls = 0;

  /// Number of [jobStatus] and [jobCancel] calls.
  int jobStatusCalls = 0;
  int jobCancelCalls = 0;

  @override
  Future<PlayerTracksDto?> matchPlayerTracks({
    required String matchDir,
    required double startSeconds,
    required double endSeconds,
  }) async {
    windows.add(
      PlayerTrackWindowRequestDto(
        matchDir: matchDir,
        startSeconds: startSeconds,
        endSeconds: endSeconds,
      ),
    );
    final error = tracksFailure;
    if (error != null) {
      throw error;
    }
    return tracks;
  }

  @override
  Future<JobHandleDto> startPlayerTracking({
    required String matchDir,
    required PlayerTrackingConfigDto config,
    String? runtimePath,
    String? modelPath,
  }) async {
    trackingStartCalls += 1;
    return const JobHandleDto(jobId: 'tracking-job-1', matchId: 'match-1');
  }

  @override
  Future<JobStatusDto> jobStatus(String jobId) async {
    jobStatusCalls += 1;
    return JobStatusDto(
      jobId: jobId,
      matchId: 'match-1',
      state: jobState,
      stage: jobStage,
      error: jobError,
      completedStages: const <String>['person_detection'],
    );
  }

  @override
  Future<JobStatusDto> jobCancel(String jobId) async {
    jobCancelCalls += 1;
    return jobStatus(jobId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Write a small placeholder recording into [directory] and return it.
///
/// Synchronous on purpose: a widget test runs in a fake-async zone where real
/// asynchronous file work never completes, so suites usually call this from
/// `setUp` before pumping. The bytes are zeros; no screen decodes them.
File writeRecordingPlaceholder({
  required Directory directory,
  String fileName = 'recording.mp4',
  int bytes = 1024,
}) =>
    _writePlaceholder(
      path: p.join(directory.path, fileName),
      bytes: bytes,
    );

/// Write the exported reel placeholder the export success state looks for.
///
/// The file lands at `<matchDirectory>/export/<fileName>`, which is where the
/// export screen reads the rendered artifact from.
File writeExportPlaceholder({
  required Directory matchDirectory,
  String fileName = 'highlight.mp4',
  int bytes = 4096,
}) =>
    _writePlaceholder(
      path: p.join(matchDirectory.path, 'export', fileName),
      bytes: bytes,
    );

/// Write [bytes] zero bytes at [path], creating parent directories.
File _writePlaceholder({required String path, required int bytes}) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(List<int>.filled(bytes, 0), flush: true);
  return file;
}
