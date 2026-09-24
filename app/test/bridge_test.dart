/// Runtime verification of the generated bridge.
///
/// This test loads the real engine library through `flutter_rust_bridge` and
/// drives the facade the application uses, so it covers the native boundary
/// itself rather than a mock. It needs:
///
///   tools/generate-bridge.sh    (generated bindings)
///   tools/build-engine-lib.sh   (core/crates/api/target/release/libsportcut_api.*)
///   ffmpeg on PATH              (to generate a fixture recording)
///
/// Run with: cd app && flutter test
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sportcut/src/bridge/sportcut_engine.dart';
import 'package:sportcut/src/features/export/data/overlay_renderer.dart';

void main() {
  late Directory lab;
  late SportcutEngine engine;

  /// Follow a started job until it stops, the way the client polls.
  Future<JobStatusDto> awaitJob(String jobId) async {
    final deadline = DateTime.now().add(const Duration(seconds: 120));
    while (true) {
      final status = await engine.jobStatus(jobId);
      switch (status.state) {
        case JobStateDto.completed:
        case JobStateDto.cancelled:
        case JobStateDto.failed:
          return status;
        case JobStateDto.pending:
        case JobStateDto.running:
          if (DateTime.now().isAfter(deadline)) {
            fail('job $jobId never finished: $status');
          }
          await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
  }

  /// Start an import and wait for it to stop.
  Future<JobStatusDto> importMatch({
    required String matchId,
    required String originalPath,
    required String matchDir,
    double samplingRate = 2,
  }) async {
    final handle = await engine.startImport(
      matchId: matchId,
      originalPath: originalPath,
      matchDir: matchDir,
      samplingRate: samplingRate,
    );
    expect(handle.matchId, equals(matchId));
    return awaitJob(handle.jobId);
  }

  /// Import a match, waiting for the engine's admission slot to come free.
  ///
  /// A job reports its terminal state a moment before its worker releases the
  /// admission slot, so a client that starts the next job the instant the last
  /// one finished can be told that a heavy job is still running. The wait is
  /// bounded, so a slot that never came free would still fail the test.
  Future<JobStatusDto> importWhenAdmitted({
    required String matchId,
    required String originalPath,
    required String matchDir,
  }) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (true) {
      try {
        return await importMatch(
          matchId: matchId,
          originalPath: originalPath,
          matchDir: matchDir,
        );
      } on SportcutEngineException catch (error) {
        if (!error.message.contains('resource-intensive') ||
            DateTime.now().isAfter(deadline)) {
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
  }

  setUpAll(() async {
    // Rasterizing the scoreboard overlay goes through `dart:ui`, which needs a
    // binding even though this is not a widget test.
    TestWidgetsFlutterBinding.ensureInitialized();
    lab = await Directory.systemTemp.createTemp('sportcut-bridge-test');
    engine = await SportcutEngine.initialize();
  });

  tearDownAll(() async {
    await SportcutEngine.dispose();
    if (lab.existsSync()) {
      await lab.delete(recursive: true);
    }
  });

  test('the engine reports its import stages', () async {
    final stages = await engine.importStages();
    expect(stages, equals(<String>['probe', 'proxy', 'audio', 'frames']));
  });

  test('importing a recording through the bridge produces the expected artifacts',
      () async {
    final video = await _generateVideo(lab, 'match.mp4', withAudio: true);
    final originalBytes = await video.readAsBytes();

    final metadata = await engine.probe(video.path);
    expect(metadata.hasAudio, isTrue);
    expect(metadata.width, equals(320));
    expect(metadata.height, equals(240));
    expect(metadata.durationSeconds, closeTo(2.0, 0.5));

    final matchDir = Directory('${lab.path}/matches/match-1');
    final job = await importMatch(
      matchId: 'match-1',
      originalPath: video.path,
      matchDir: matchDir.path,
    );

    expect(job.state, equals(JobStateDto.completed));
    expect(job.completedStages.length, equals(4));

    final manifest = await engine.matchManifest(matchDir.path);
    expect(manifest.originalPresent, isTrue);
    expect(manifest.missingKinds, isEmpty);

    final kinds =
        manifest.artifacts.map((artifact) => artifact.kind).toList();
    expect(kinds, containsAll(<String>['proxy', 'analysis_audio', 'frames']));
    expect(File('${matchDir.path}/proxy/proxy.mp4').existsSync(), isTrue);
    expect(File('${matchDir.path}/audio/analysis.m4a').existsSync(), isTrue);
    expect(Directory('${matchDir.path}/frames').existsSync(), isTrue);
    expect(
      Directory('${matchDir.path}/frames').listSync().isNotEmpty,
      isTrue,
      reason: 'the import samples frames',
    );

    // The original recording is referenced in place and never modified.
    expect(await video.readAsBytes(), equals(originalBytes));

    // Importing again resumes from the checkpoints and redoes nothing.
    final second = await importMatch(
      matchId: 'match-1',
      originalPath: video.path,
      matchDir: matchDir.path,
    );
    expect(second.state, equals(JobStateDto.completed));
    expect(second.completedStages.length, equals(4));
  });

  test('a source without audio imports and reports no analysis audio', () async {
    final video = await _generateVideo(lab, 'silent.mp4', withAudio: false);
    final matchDir = Directory('${lab.path}/matches/silent-match');

    final job = await importMatch(
      matchId: 'silent-match',
      originalPath: video.path,
      matchDir: matchDir.path,
      samplingRate: 1,
    );

    final manifest = await engine.matchManifest(matchDir.path);
    final kinds =
        manifest.artifacts.map((artifact) => artifact.kind).toList();
    expect(job.state, equals(JobStateDto.completed));
    expect(kinds, isNot(contains('analysis_audio')));
    expect(kinds, contains('proxy'));
  });

  test('derived artifacts can be reported missing and regenerated', () async {
    final video = await _generateVideo(lab, 'repair.mp4', withAudio: true);
    final matchDir = Directory('${lab.path}/matches/repair-match');

    await importMatch(
      matchId: 'repair-match',
      originalPath: video.path,
      matchDir: matchDir.path,
    );

    // Move the derived artifacts aside, as a user clearing space would.
    for (final name in <String>['proxy', 'frames']) {
      await Directory('${matchDir.path}/$name')
          .rename('${matchDir.path}/$name.removed');
    }

    final damaged = await engine.matchManifest(matchDir.path);
    expect(damaged.missingKinds, containsAll(<String>['proxy', 'frames']));
    expect(damaged.originalPresent, isTrue);

    final repair = await engine.startRegenerate(matchDir.path, samplingRate: 2);
    expect((await awaitJob(repair.jobId)).state, equals(JobStateDto.completed));

    final repaired = await engine.matchManifest(matchDir.path);
    expect(repaired.missingKinds, isEmpty);
    expect(File('${matchDir.path}/proxy/proxy.mp4').existsSync(), isTrue);
    expect(Directory('${matchDir.path}/frames').existsSync(), isTrue);
  });

  test('a reel renders through the bridge and is recorded as an artifact',
      () async {
    final video = await _generateVideo(lab, 'reel.mp4', withAudio: true);
    final matchDir = Directory('${lab.path}/matches/reel-match');
    final first = await importMatch(
      matchId: 'reel-match',
      originalPath: video.path,
      matchDir: matchDir.path,
    );
    expect(first.state, equals(JobStateDto.completed));

    // The scoreboard is drawn by the application, not burned in by the engine.
    final overlay = await const OverlayRenderer().writeScoreboard(
      path: '${matchDir.path}/export/overlays/score-0.png',
      width: 320,
      height: 240,
      leftScore: 3,
      rightScore: 2,
    );
    expect(overlay.existsSync(), isTrue);

    final handle = await engine.startExport(
      ExportRequestDto(
        matchId: 'reel-match',
        matchDir: matchDir.path,
        sourcePath: video.path,
        clips: <EditClipDto>[
          EditClipDto(
            startSeconds: 0.5,
            endSeconds: 1.5,
            overlayPath: overlay.path,
          ),
        ],
        leadInSeconds: 0,
        leadOutSeconds: 0,
        title: null,
        musicPath: null,
        musicGain: 0.25,
      ),
    );
    expect((await awaitJob(handle.jobId)).state, equals(JobStateDto.completed));

    final manifest = await engine.matchManifest(matchDir.path);
    final exported =
        manifest.artifacts.where((artifact) => artifact.kind == 'export');
    expect(exported, hasLength(1));
    // The render did not displace what the import produced.
    expect(
      manifest.artifacts.map((artifact) => artifact.kind),
      containsAll(<String>['proxy', 'analysis_audio', 'frames', 'export']),
    );
    expect(
      File('${matchDir.path}/${exported.single.relativePath}').existsSync(),
      isTrue,
    );
    expect(exported.single.sizeBytes! > BigInt.zero, isTrue);
  });

  test('an unreadable source surfaces a typed engine error', () async {
    final missing = '${lab.path}/not-here.mp4';

    await expectLater(
      engine.probe(missing),
      throwsA(
        isA<SportcutEngineException>()
            .having((error) => error.message, 'message', contains('not-here.mp4')),
      ),
    );
  });

  test('a calibration crosses the bridge, is stored, and reads back', () async {
    final video = await _generateVideo(lab, 'calibrated.mp4', withAudio: true);
    final matchDir = Directory('${lab.path}/matches/calibrated-match');
    final imported = await importMatch(
      matchId: 'calibrated-match',
      originalPath: video.path,
      matchDir: matchDir.path,
    );
    expect(imported.state, equals(JobStateDto.completed));

    // A match nobody has marked claims no court, no net, and no sides.
    expect(await engine.matchCalibration(matchDir.path), isNull);

    const segment = CalibrationSegmentDto(
      fromMs: 0,
      corners: <CourtCornerDto>[
        CourtCornerDto(x: 0.10, y: 0.90),
        CourtCornerDto(x: 0.90, y: 0.90),
        CourtCornerDto(x: 0.70, y: 0.40),
        CourtCornerDto(x: 0.30, y: 0.40),
      ],
      orientation: CourtOrientationDto.away,
    );

    // While the user is still moving corners the engine is asked to project the
    // court and stores nothing.
    final geometry = await engine.courtGeometry(segment);
    expect(geometry.imageToCourt, hasLength(9));
    expect(geometry.courtToImage, hasLength(9));
    expect(geometry.corners, hasLength(4));
    expect(geometry.net, hasLength(2));
    expect(await engine.matchCalibration(matchDir.path), isNull);

    final saved = await engine.saveCalibration(
      matchDir: matchDir.path,
      calibration: const CourtCalibrationDto(
        schemaVersion: 1,
        segments: <CalibrationSegmentDto>[segment],
      ),
    );
    expect(saved.changed, isTrue);
    expect(saved.geometry, hasLength(1));
    expect(
      File('${matchDir.path}/calibration/calibration.json').existsSync(),
      isTrue,
    );

    // The manifest records the calibration like any other artifact.
    final manifest = await engine.matchManifest(matchDir.path);
    final recorded =
        manifest.artifacts.where((artifact) => artifact.kind == 'calibration');
    expect(recorded, hasLength(1));
    expect(recorded.single.state, equals(ArtifactStateDto.final_));
    expect(manifest.missingKinds, isEmpty);

    // And the corners and orientation survive the round trip.
    final stored = await engine.matchCalibration(matchDir.path);
    expect(stored, isNotNull);
    expect(stored!.segments, hasLength(1));
    expect(stored.segments.single.orientation, equals(CourtOrientationDto.away));
    expect(stored.segments.single.corners, hasLength(4));
    expect(stored.segments.single.corners.first.x, closeTo(0.10, 1e-9));
    expect(stored.segments.single.corners.last.y, closeTo(0.40, 1e-9));
  });

  test('an unknown job handle is reported through the binding', () async {
    await expectLater(
      engine.jobStatus('job-that-never-started'),
      throwsA(
        isA<SportcutEngineException>().having(
          (error) => error.message,
          'message',
          contains('no job job-that-never-started'),
        ),
      ),
    );
    await expectLater(
      engine.jobCancel('job-that-never-started'),
      throwsA(
        isA<SportcutEngineException>().having(
          (error) => error.message,
          'message',
          contains('job-that-never-started'),
        ),
      ),
    );
  });

  test('a running import can be cancelled from the client', () async {
    final video = await _generateVideo(
      lab,
      'cancelled.mp4',
      withAudio: true,
      seconds: 20,
    );
    final matchDir = Directory('${lab.path}/matches/cancelled-match');

    final handle = await engine.startImport(
      matchId: 'cancelled-match',
      originalPath: video.path,
      matchDir: matchDir.path,
      samplingRate: 2,
    );
    final asked = await engine.jobCancel(handle.jobId);
    expect(asked.state, equals(JobStateDto.cancelled));

    final finished = await awaitJob(handle.jobId);
    expect(finished.state, equals(JobStateDto.cancelled));

    // Nothing the cancelled run had recorded is presented as a result. A run
    // stopped before the first stage had a manifest at all, which is also fine.
    if (File('${matchDir.path}/manifest.json').existsSync()) {
      final manifest = await engine.matchManifest(matchDir.path);
      for (final artifact in manifest.artifacts) {
        expect(artifact.state, isNot(equals(ArtifactStateDto.final_)));
      }
    }

    // The admission slot comes free again: the engine admits the next job
    // rather than leaving the user with a machine that will not import.
    final next = await importWhenAdmitted(
      matchId: 'after-cancel',
      originalPath: video.path,
      matchDir: '${lab.path}/matches/after-cancel',
    );
    expect(next.state, equals(JobStateDto.completed));
  });
}

Future<File> _generateVideo(
  Directory lab,
  String name, {
  required bool withAudio,
  double seconds = 2,
}) async {
  final output = File('${lab.path}/$name');
  final arguments = <String>[
    '-hide_banner',
    '-nostdin',
    '-y',
    '-f',
    'lavfi',
    '-i',
    'testsrc2=size=320x240:rate=10:duration=$seconds',
  ];
  if (withAudio) {
    arguments.addAll(<String>[
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:duration=$seconds',
    ]);
  }
  arguments.addAll(<String>[
    '-c:v',
    'mpeg4',
    '-q:v',
    '5',
    '-pix_fmt',
    'yuv420p',
  ]);
  arguments.addAll(withAudio
      ? <String>['-c:a', 'aac', '-b:a', '64k', '-shortest']
      : <String>['-an']);
  arguments.add(output.path);

  final result = await Process.run('ffmpeg', arguments);
  if (result.exitCode != 0) {
    fail('ffmpeg failed to generate $name: ${result.stderr}');
  }
  return output;
}
