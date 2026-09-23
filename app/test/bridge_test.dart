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

void main() {
  late Directory lab;
  late SportcutEngine engine;

  setUpAll(() async {
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
    final result = await engine.importMatch(
      matchId: 'match-1',
      originalPath: video.path,
      matchDir: matchDir.path,
      samplingRate: 2,
    );

    expect(result.job.state, equals(JobStateDto.completed));
    expect(result.job.completedStages.length, equals(4));
    expect(result.skippedStages, isEmpty);
    expect(result.framesSampled, greaterThan(0));
    expect(result.manifest.originalPresent, isTrue);
    expect(result.manifest.missingKinds, isEmpty);

    final kinds =
        result.manifest.artifacts.map((artifact) => artifact.kind).toList();
    expect(kinds, containsAll(<String>['proxy', 'analysis_audio', 'frames']));
    expect(File('${matchDir.path}/proxy/proxy.mp4').existsSync(), isTrue);
    expect(File('${matchDir.path}/audio/analysis.m4a').existsSync(), isTrue);
    expect(Directory('${matchDir.path}/frames').existsSync(), isTrue);

    // The original recording is referenced in place and never modified.
    expect(await video.readAsBytes(), equals(originalBytes));

    // Importing again resumes from the checkpoints and redoes nothing.
    final second = await engine.importMatch(
      matchId: 'match-1',
      originalPath: video.path,
      matchDir: matchDir.path,
      samplingRate: 2,
    );
    expect(second.job.state, equals(JobStateDto.completed));
    expect(second.skippedStages.length, equals(4));
  });

  test('a source without audio imports and reports no analysis audio', () async {
    final video = await _generateVideo(lab, 'silent.mp4', withAudio: false);
    final matchDir = Directory('${lab.path}/matches/silent-match');

    final result = await engine.importMatch(
      matchId: 'silent-match',
      originalPath: video.path,
      matchDir: matchDir.path,
      samplingRate: 1,
    );

    final kinds =
        result.manifest.artifacts.map((artifact) => artifact.kind).toList();
    expect(result.job.state, equals(JobStateDto.completed));
    expect(kinds, isNot(contains('analysis_audio')));
    expect(kinds, contains('proxy'));
  });

  test('derived artifacts can be reported missing and regenerated', () async {
    final video = await _generateVideo(lab, 'repair.mp4', withAudio: true);
    final matchDir = Directory('${lab.path}/matches/repair-match');

    await engine.importMatch(
      matchId: 'repair-match',
      originalPath: video.path,
      matchDir: matchDir.path,
      samplingRate: 2,
    );

    // Move the derived artifacts aside, as a user clearing space would.
    for (final name in <String>['proxy', 'frames']) {
      await Directory('${matchDir.path}/$name')
          .rename('${matchDir.path}/$name.removed');
    }

    final damaged = await engine.matchManifest(matchDir.path);
    expect(damaged.missingKinds, containsAll(<String>['proxy', 'frames']));
    expect(damaged.originalPresent, isTrue);

    final repaired =
        await engine.regenerateMatch(matchDir.path, samplingRate: 2);
    expect(repaired.missingKinds, isEmpty);
    expect(File('${matchDir.path}/proxy/proxy.mp4').existsSync(), isTrue);
    expect(Directory('${matchDir.path}/frames').existsSync(), isTrue);
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
}

Future<File> _generateVideo(
  Directory lab,
  String name, {
  required bool withAudio,
}) async {
  final output = File('${lab.path}/$name');
  final arguments = <String>[
    '-hide_banner',
    '-nostdin',
    '-y',
    '-f',
    'lavfi',
    '-i',
    'testsrc2=size=320x240:rate=10:duration=2',
  ];
  if (withAudio) {
    arguments.addAll(<String>[
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:duration=2',
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
