/// Library screen tests.
///
/// The screen is driven with an in-memory library double, because widget tests
/// run in a fake-async zone where real database I/O does not progress. The
/// SQLite-backed repository has its own tests in match_repository_test.dart.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sportcut/src/app/app.dart';
import 'package:sportcut/src/features/library/data/video_file_picker.dart';
import 'package:sportcut/src/features/library/domain/match_import_exception.dart';
import 'package:sportcut/src/features/library/domain/match_record.dart';
import 'package:sportcut/src/features/library/presentation/library_providers.dart';

import 'support/fake_match_library.dart';
import 'support/fakes.dart';

void main() {
  late Directory tempDir;
  late FakeMatchLibrary library;
  late FakeVideoFilePicker picker;
  late File recording;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sportcut-library-ui-test');
    recording = File(p.join(tempDir.path, 'club-final.mp4'));
    await recording.writeAsBytes(List<int>.filled(512, 1));
    library = FakeMatchLibrary();
    picker = FakeVideoFilePicker();
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> pumpLibrary(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchRepositoryProvider.overrideWith((ref) async => library),
          videoFilePickerProvider.overrideWithValue(picker),
          playbackControllerFactoryProvider
              .overrideWithValue(FakePlaybackController.new),
        ],
        child: const SportcutApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  MatchRecord sampleMatch({String id = 'match-1', String title = 'club-final'}) =>
      MatchRecord(
        id: id,
        title: title,
        videoPath: recording.path,
        durationSeconds: 90,
        createdAt: DateTime(2026, 3, 2),
        matchDir: p.join(tempDir.path, 'matches', id),
      );

  testWidgets('an empty library offers to import a recording', (tester) async {
    await pumpLibrary(tester);

    expect(find.text('No matches yet'), findsOneWidget);
    expect(find.text('Import video'), findsOneWidget);
  });

  testWidgets('matches are listed with title, duration, and creation date',
      (tester) async {
    library.matches.add(sampleMatch());
    await pumpLibrary(tester);

    expect(find.text('club-final'), findsOneWidget);
    expect(find.textContaining('1:30'), findsOneWidget);
    expect(find.textContaining('2026-03-02'), findsOneWidget);
  });

  testWidgets('importing adds the chosen recording to the library',
      (tester) async {
    picker.result = PickedVideo(
      path: recording.path,
      displayName: 'club-final.mp4',
    );
    await pumpLibrary(tester);

    await tester.tap(find.text('Import video'));
    await tester.pumpAndSettle();

    expect(picker.calls, 1);
    expect(library.importCalls, 1);
    expect(find.text('club-final'), findsOneWidget);
    expect(find.text('Imported club-final'), findsOneWidget);
  });

  testWidgets('a cancelled picker changes nothing', (tester) async {
    picker.result = null;
    await pumpLibrary(tester);

    await tester.tap(find.text('Import video'));
    await tester.pumpAndSettle();

    expect(picker.calls, 1);
    expect(library.importCalls, 0);
    expect(find.text('No matches yet'), findsOneWidget);
  });

  testWidgets('an unreadable recording is reported and nothing is stored',
      (tester) async {
    picker.result = PickedVideo(path: p.join(tempDir.path, 'gone.mp4'));
    library.failure = MatchImportException(
      'That file is no longer available: ${p.join(tempDir.path, 'gone.mp4')}',
    );
    await pumpLibrary(tester);

    await tester.tap(find.text('Import video'));
    await tester.pumpAndSettle();

    expect(find.textContaining('no longer available'), findsOneWidget);
    expect(library.matches, isEmpty);
    expect(find.text('No matches yet'), findsOneWidget);
  });

  testWidgets('preparing analysis files reports the result', (tester) async {
    library.matches.add(sampleMatch());
    await pumpLibrary(tester);

    await tester.tap(find.byTooltip('Match actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prepare analysis files'));
    await tester.pumpAndSettle();

    expect(library.generateCalls, 1);
    expect(find.textContaining('Analysis files ready'), findsOneWidget);
  });

  testWidgets('deleting a match asks about the derived artifacts',
      (tester) async {
    final match = sampleMatch();
    library.matches.add(match);
    final matchDir = Directory(match.matchDir);
    // Synchronous on purpose: real asynchronous filesystem work does not
    // progress inside a widget test's fake-async zone.
    matchDir.createSync(recursive: true);
    await pumpLibrary(tester);

    await tester.tap(find.byTooltip('Match actions'));
    await _settle(tester, 'opening the menu');
    await tester.tap(find.text('Delete'));
    await _settle(tester, 'opening the dialog');

    expect(find.text('Delete match?'), findsOneWidget);
    expect(find.text('Also delete analysis files'), findsOneWidget);
    expect(find.textContaining('original recording is never deleted'),
        findsOneWidget);

    await tester.tap(find.byType(CheckboxListTile));
    await _settle(tester, 'toggling the checkbox');
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await _settle(tester, 'confirming the delete');

    expect(library.lastDeleteArtifacts, isTrue);
    expect(library.matches, isEmpty);
    expect(matchDir.existsSync(), isFalse);
    expect(recording.existsSync(), isTrue);
    expect(find.text('No matches yet'), findsOneWidget);
  });

  testWidgets('cancelling the delete dialog keeps the match', (tester) async {
    library.matches.add(sampleMatch());
    await pumpLibrary(tester);

    await tester.tap(find.byTooltip('Match actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(library.matches, hasLength(1));
    expect(find.text('club-final'), findsOneWidget);
  });

  testWidgets('opening a match navigates to playback', (tester) async {
    library.matches.add(sampleMatch());
    await pumpLibrary(tester);

    await tester.tap(find.text('club-final'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fake-playback-surface')), findsOneWidget);
    expect(find.byTooltip('Play'), findsOneWidget);
  });
}

/// Settle with a short timeout so a stuck screen fails the test instead of
/// hanging the suite.
Future<void> _settle(WidgetTester tester, String step) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
  } on FlutterError catch (error) {
    fail('pumpAndSettle timed out while $step: ${error.message}');
  }
}
