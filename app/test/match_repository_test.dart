/// Repository tests: import, metadata population, failure handling, artifact
/// generation, and deletion. The engine is faked, so these run without the
/// native library; the bridge itself is covered by test/bridge_test.dart.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sportcut/src/bridge/sportcut_engine.dart';
import 'package:sportcut/src/features/library/data/match_catalog.dart';
import 'package:sportcut/src/features/library/data/match_paths.dart';
import 'package:sportcut/src/features/library/data/match_repository.dart';
import 'package:sportcut/src/features/library/data/video_file_picker.dart';
import 'package:sportcut/src/features/library/domain/match_import_exception.dart';

import 'support/fakes.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory tempDir;
  late MatchCatalog catalog;
  late MatchRepository repository;
  late FakeMediaEngine engine;
  late File recording;
  var sequence = 0;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sportcut-repository-test');
    recording = File(p.join(tempDir.path, 'thursday-night.mp4'));
    await recording.writeAsBytes(List<int>.filled(4096, 7));

    catalog = await MatchCatalog.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    engine = FakeMediaEngine();
    repository = MatchRepository(
      catalog: catalog,
      engine: engine,
      paths: MatchPaths(p.join(tempDir.path, 'matches')),
      clock: () => DateTime(2026, 7, 1, 12),
      idGenerator: () => 'match-${++sequence}',
    );
  });

  tearDown(() async {
    await catalog.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('import creates a record that references the recording in place',
      () async {
    final match = await repository.importVideo(
      PickedVideo(path: recording.path, displayName: 'thursday-night.mp4'),
    );

    expect(match.title, 'thursday-night');
    expect(match.videoPath, recording.path);
    expect(match.durationSeconds, closeTo(90.5, 0.001));
    expect(match.videoWidth, 1920);
    expect(match.videoHeight, 1080);
    expect(match.frameRate, 30);
    expect(match.hasAudio, isTrue);
    expect(match.createdAt, DateTime(2026, 7, 1, 12));
    expect(match.matchDir, p.join(tempDir.path, 'matches', match.id));

    // No duplicate copy of the recording, and no artifact directory yet.
    expect(Directory(match.matchDir).existsSync(), isFalse);
    expect(
      tempDir.listSync().whereType<File>().map((file) => file.path),
      <String>[recording.path],
    );

    final stored = await repository.listMatches();
    expect(stored, hasLength(1));
    expect(stored.single.id, match.id);
    expect(engine.probeCalls, 1);
  });

  test('an explicit title overrides the file name', () async {
    final match = await repository.importVideo(
      PickedVideo(path: recording.path, displayName: 'thursday-night.mp4'),
      title: '  Club final  ',
    );
    expect(match.title, 'Club final');
  });

  test('a missing file is reported and leaves no catalog record', () async {
    final missing = p.join(tempDir.path, 'gone.mp4');

    await expectLater(
      repository.importVideo(PickedVideo(path: missing)),
      throwsA(
        isA<MatchImportException>()
            .having((error) => error.message, 'message', contains('gone.mp4')),
      ),
    );

    expect(await repository.listMatches(), isEmpty);
    expect(engine.probeCalls, 0);
  });

  test('an unreadable codec is reported and leaves no catalog record',
      () async {
    engine = FakeMediaEngine(
      failure: SportcutEngineException('unsupported codec: hevc-in-avi'),
    );
    repository = MatchRepository(
      catalog: catalog,
      engine: engine,
      paths: MatchPaths(p.join(tempDir.path, 'matches')),
      idGenerator: () => 'match-broken',
    );

    await expectLater(
      repository.importVideo(PickedVideo(path: recording.path)),
      throwsA(
        isA<MatchImportException>()
            .having((error) => error.message, 'message', contains('could not be read')),
      ),
    );

    expect(await repository.listMatches(), isEmpty);
    expect(engine.probeCalls, 1);
  });

  test('a file that cannot be opened is reported as an access problem',
      () async {
    final locked = File(p.join(tempDir.path, 'locked.mp4'));
    await locked.writeAsBytes(<int>[1, 2, 3]);
    await Process.run('chmod', <String>['000', locked.path]);
    addTearDown(() => Process.run('chmod', <String>['600', locked.path]));

    // A privileged process can read through mode 000, which would make this
    // test pass for the wrong reason; skip it there instead.
    var stillReadable = true;
    try {
      final handle = await locked.open();
      await handle.close();
    } on FileSystemException {
      stillReadable = false;
    }
    if (stillReadable) {
      return;
    }

    await expectLater(
      repository.importVideo(PickedVideo(path: locked.path)),
      throwsA(
        isA<MatchImportException>().having(
          (error) => error.message,
          'message',
          contains('could not be opened'),
        ),
      ),
    );

    expect(await repository.listMatches(), isEmpty);
    expect(engine.probeCalls, 0);
  });

  test('generating artifacts uses the match directory and reports failures',
      () async {
    final match = await repository.importVideo(PickedVideo(path: recording.path));

    final result = await repository.generateArtifacts(match, samplingRate: 2);
    expect(result.job.state, JobStateDto.completed);
    expect(result.framesSampled, 45);
    expect(engine.lastMatchDir, match.matchDir);

    engine = FakeMediaEngine(
      failure: SportcutEngineException('ffmpeg failed: disk full'),
    );
    repository = MatchRepository(
      catalog: catalog,
      engine: engine,
      paths: MatchPaths(p.join(tempDir.path, 'matches')),
    );
    await expectLater(
      repository.generateArtifacts(match),
      throwsA(
        isA<MatchImportException>()
            .having((error) => error.message, 'message', contains('disk full')),
      ),
    );
  });

  test('deleting a match keeps derived artifacts unless asked to remove them',
      () async {
    final match = await repository.importVideo(PickedVideo(path: recording.path));
    final matchDir = Directory(match.matchDir);
    await matchDir.create(recursive: true);

    await repository.deleteMatch(match);
    expect(await repository.listMatches(), isEmpty);
    expect(matchDir.existsSync(), isTrue,
        reason: 'derived artifacts should survive a plain delete');

    final second = await repository.importVideo(PickedVideo(path: recording.path));
    final secondDir = Directory(second.matchDir);
    await secondDir.create(recursive: true);

    await repository.deleteMatch(second, deleteArtifacts: true);
    expect(await repository.listMatches(), isEmpty);
    expect(secondDir.existsSync(), isFalse);
    expect(recording.existsSync(), isTrue,
        reason: 'the original recording is never deleted');
  });
}
