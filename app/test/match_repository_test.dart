/// Repository tests: custody of the picked recording, metadata population,
/// failure handling, artifact generation, availability, and deletion. The
/// engine is faked, so these run without the native library; the bridge itself
/// is covered by test/bridge_test.dart.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sportcut/src/bridge/sportcut_engine.dart';
import 'package:sportcut/src/features/library/data/match_catalog.dart';
import 'package:sportcut/src/features/library/data/match_paths.dart';
import 'package:sportcut/src/features/library/data/match_repository.dart';
import 'package:sportcut/src/features/library/data/recording_store.dart';
import 'package:sportcut/src/features/library/data/video_file_picker.dart';
import 'package:sportcut/src/features/library/domain/import_cancel_token.dart';
import 'package:sportcut/src/features/library/domain/match_import_exception.dart';

import 'support/fakes.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory tempDir;
  late String artifactRoot;
  late String recordingsRoot;
  late MatchCatalog catalog;
  late MatchRepository repository;
  late FakeMediaEngine engine;
  late File recording;
  var sequence = 0;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sportcut-repository-test');
    recording = File(p.join(tempDir.path, 'thursday-night.mp4'));
    await recording.writeAsBytes(List<int>.filled(4096, 7));

    artifactRoot = p.join(tempDir.path, 'artifacts');
    recordingsRoot = p.join(tempDir.path, 'recordings');
    catalog = await MatchCatalog.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    engine = FakeMediaEngine();
    repository = MatchRepository(
      catalog: catalog,
      engine: engine,
      paths: MatchPaths(
        artifactRoot: artifactRoot,
        recordingsRoot: recordingsRoot,
      ),
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

  /// Everything the application stored under its recordings root.
  List<FileSystemEntity> storedRecordings() => Directory(recordingsRoot).existsSync()
      ? Directory(recordingsRoot).listSync()
      : const <FileSystemEntity>[];

  test('import takes custody of the picked recording', () async {
    final match = await repository.importVideo(
      PickedVideo(path: recording.path, displayName: 'thursday-night.mp4'),
    );

    expect(match.title, 'thursday-night');
    expect(match.durationSeconds, closeTo(90.5, 0.001));
    expect(match.videoWidth, 1920);
    expect(match.videoHeight, 1080);
    expect(match.frameRate, 30);
    expect(match.hasAudio, isTrue);
    expect(match.createdAt, DateTime(2026, 7, 1, 12));
    expect(match.matchDir, p.join(artifactRoot, match.id));

    // The match records the app-owned copy, which is where the picked bytes
    // ended up — not the path the platform handed back.
    expect(match.videoPath, p.join(recordingsRoot, match.id, 'thursday-night.mp4'));
    expect(match.videoPath, isNot(recording.path));
    expect(match.originalPath, recording.path);
    expect(File(match.videoPath).readAsBytesSync(), recording.readAsBytesSync());
    expect(match.sourceBytes, recording.lengthSync());

    // The user's file is untouched, and the engine's artifact directory has
    // not been created by an import.
    expect(recording.existsSync(), isTrue);
    expect(Directory(match.matchDir).existsSync(), isFalse);

    final stored = await repository.listMatches();
    expect(stored, hasLength(1));
    expect(stored.single.id, match.id);
    expect(engine.probeCalls, 1);
  });

  test('the app-owned copy outlives the file the picker returned', () async {
    final match = await repository.importVideo(
      PickedVideo(path: recording.path, displayName: 'thursday-night.mp4'),
    );

    // The platform emptied the directory it handed us, which is exactly what
    // happens to iOS temporary files and the Android picker cache.
    await recording.delete();

    expect(File(match.videoPath).existsSync(), isTrue);
    expect(repository.isRecordingAvailable(match), isTrue);
  });

  test('a match whose recording has gone is reported unavailable', () async {
    final match = await repository.importVideo(
      PickedVideo(path: recording.path, displayName: 'thursday-night.mp4'),
    );
    await File(match.videoPath).delete();

    expect(repository.isRecordingAvailable(match), isFalse);
    expect(
      await repository.listMatches(),
      hasLength(1),
      reason: 'a missing recording must not remove the match',
    );
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
            .having((error) => error.kind, 'kind', MatchImportKind.unreadable)
            .having((error) => error.message, 'message', contains('gone.mp4')),
      ),
    );

    expect(await repository.listMatches(), isEmpty);
    expect(engine.probeCalls, 0);
    expect(storedRecordings(), isEmpty);
  });

  test('an unreadable codec is reported and leaves no copy behind', () async {
    engine = FakeMediaEngine(
      failure: SportcutEngineException('unsupported codec: hevc-in-avi'),
    );
    repository = MatchRepository(
      catalog: catalog,
      engine: engine,
      paths: MatchPaths(
        artifactRoot: artifactRoot,
        recordingsRoot: recordingsRoot,
      ),
      idGenerator: () => 'match-broken',
    );

    await expectLater(
      repository.importVideo(PickedVideo(path: recording.path)),
      throwsA(
        isA<MatchImportException>()
            .having((error) => error.kind, 'kind', MatchImportKind.unsupported)
            .having((error) => error.message, 'message', contains('could not be read')),
      ),
    );

    expect(await repository.listMatches(), isEmpty);
    expect(engine.probeCalls, 1);
    expect(
      storedRecordings(),
      isEmpty,
      reason: 'an unsupported recording must be rejected before it is copied',
    );
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
        isA<MatchImportException>()
            .having((error) => error.kind, 'kind', MatchImportKind.unreadable)
            .having(
              (error) => error.message,
              'message',
              contains('could not be opened'),
            ),
      ),
    );

    expect(await repository.listMatches(), isEmpty);
    expect(engine.probeCalls, 0);
  });

  test('a cancelled import leaves neither a match nor a partial copy', () async {
    final large = File(p.join(tempDir.path, 'large.mp4'));
    await large.writeAsBytes(List<int>.filled(4 * 1024 * 1024, 3));

    final token = ImportCancelToken();
    scheduleMicrotask(token.cancel);

    await expectLater(
      repository.importVideo(
        PickedVideo(path: large.path, displayName: 'large.mp4'),
        cancelToken: token,
      ),
      throwsA(
        isA<MatchImportException>()
            .having((error) => error.kind, 'kind', MatchImportKind.cancelled),
      ),
    );

    expect(await repository.listMatches(), isEmpty);
    expect(
      storedRecordings(),
      isEmpty,
      reason: 'the partial copy must not survive a cancellation',
    );
  });

  test('a copy that cannot be written is reported and leaves nothing behind',
      () async {
    // Something already occupies the path the recording directory needs, so the
    // copy fails the way a full or unwritable volume would.
    final blocked = File(p.join(tempDir.path, 'blocked-root'));
    await blocked.writeAsBytes(<int>[0]);
    final blockedRepository = MatchRepository(
      catalog: catalog,
      engine: engine,
      paths: MatchPaths(
        artifactRoot: artifactRoot,
        recordingsRoot: blocked.path,
      ),
      idGenerator: () => 'match-blocked',
    );

    await expectLater(
      blockedRepository.importVideo(PickedVideo(path: recording.path)),
      throwsA(
        isA<MatchImportException>()
            .having((error) => error.kind, 'kind', MatchImportKind.storage)
            .having(
              (error) => error.message,
              'message',
              contains('could not be stored'),
            ),
      ),
    );

    expect(await blockedRepository.listMatches(), isEmpty);
    expect(blocked.existsSync(), isTrue);
  });

  test('a write that fails on a full device is classified as out of space', () {
    const full = FileSystemException(
      'No space left on device',
      '/recordings',
      OSError('No space left on device', 28),
    );
    const denied = FileSystemException(
      'Permission denied',
      '/recordings',
      OSError('Permission denied', 13),
    );

    expect(RecordingStore.isOutOfSpace(full), isTrue);
    expect(RecordingStore.isOutOfSpace(denied), isFalse);
  });

  test('generating artifacts uses the match directory and reports failures',
      () async {
    final match = await repository.importVideo(PickedVideo(path: recording.path));

    final manifest = await repository.generateArtifacts(match, samplingRate: 2);
    expect(manifest.artifacts.single.kind, 'proxy');
    expect(engine.lastMatchDir, match.matchDir);
    expect(engine.startedJobs, hasLength(1));
    expect(engine.jobStatusCalls, greaterThan(0));

    engine = FakeMediaEngine(
      failure: SportcutEngineException('ffmpeg failed: disk full'),
    );
    repository = MatchRepository(
      catalog: catalog,
      engine: engine,
      paths: MatchPaths(
        artifactRoot: artifactRoot,
        recordingsRoot: recordingsRoot,
      ),
    );
    await expectLater(
      repository.generateArtifacts(match),
      throwsA(
        isA<MatchImportException>()
            .having((error) => error.message, 'message', contains('disk full')),
      ),
    );
  });

  test('deleting a match keeps what it owns unless asked to remove it',
      () async {
    final match = await repository.importVideo(PickedVideo(path: recording.path));
    final matchDir = Directory(match.matchDir);
    await matchDir.create(recursive: true);
    final recordingCopy = File(match.videoPath);

    await repository.deleteMatch(match);
    expect(await repository.listMatches(), isEmpty);
    expect(matchDir.existsSync(), isTrue,
        reason: 'derived artifacts should survive a plain delete');
    expect(recordingCopy.existsSync(), isTrue,
        reason: 'the app-owned copy should survive a plain delete');
    expect(recording.existsSync(), isTrue,
        reason: 'the original recording is never deleted');

    final second = await repository.importVideo(PickedVideo(path: recording.path));
    final secondDir = Directory(second.matchDir);
    await secondDir.create(recursive: true);

    await repository.deleteMatch(
      second,
      deleteArtifacts: true,
      deleteRecording: true,
    );
    expect(await repository.listMatches(), isEmpty);
    expect(secondDir.existsSync(), isFalse);
    expect(File(second.videoPath).existsSync(), isFalse);
    expect(recording.existsSync(), isTrue,
        reason: 'the original recording is never deleted');
  });
}
