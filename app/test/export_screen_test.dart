/// Export screen tests: what the reel is rendered from, what happens while it
/// runs, and what the user is offered when it finishes.
///
/// The engine is a double, so the requests the screen builds can be inspected
/// and the job can be put into any state; the real renderer is used, because
/// the overlay image it draws is part of what the engine is given.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sportcut/src/bridge/sportcut_engine.dart';
import 'package:sportcut/src/features/editing/domain/export_settings.dart';
import 'package:sportcut/src/features/editing/domain/highlight_clip.dart';
import 'package:sportcut/src/features/editing/domain/rally.dart';
import 'package:sportcut/src/features/editing/presentation/editing_providers.dart';
import 'package:sportcut/src/features/export/data/audio_file_picker.dart';
import 'package:sportcut/src/features/export/presentation/export_providers.dart';
import 'package:sportcut/src/features/export/presentation/export_screen.dart';
import 'package:sportcut/src/features/library/domain/match_record.dart';
import 'package:sportcut/src/features/library/presentation/library_providers.dart';

import 'support/fake_match_editing.dart';
import 'support/fake_overlay_renderer.dart';
import 'support/fakes.dart';

void main() {
  late Directory tempDir;
  late MatchRecord match;
  late FakeMediaEngine engine;
  late FakeAudioFilePicker picker;
  late FakeOverlayRenderer renderer;

  const rally = Rally(
    id: 'rally-1',
    matchId: 'match-1',
    startSeconds: 10,
    endSeconds: 20,
    winnerSide: WinnerSide.left,
    status: RallyStatus.confirmed,
  );
  const clip = HighlightClip(
    id: 'clip-rally-1',
    matchId: 'match-1',
    rallyId: 'rally-1',
    startSeconds: 10,
    endSeconds: 20,
  );

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sportcut-export-test');
    match = MatchRecord(
      id: 'match-1',
      title: 'Club final',
      videoPath: p.join(tempDir.path, 'club-final.mp4'),
      durationSeconds: 90,
      createdAt: DateTime(2026, 3, 2),
      matchDir: p.join(tempDir.path, 'match-1'),
    );
    engine = FakeMediaEngine();
    picker = FakeAudioFilePicker();
    renderer = FakeOverlayRenderer();
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  FakeMatchEditing session({bool withClip = true, ExportSettings? settings}) =>
      FakeMatchEditing(
        rallies: <Rally>[rally],
        clips: withClip ? <HighlightClip>[clip] : <HighlightClip>[],
        settings: settings,
      );

  Future<void> pumpExport(
    WidgetTester tester,
    FakeMatchEditing editing,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchEditingProvider.overrideWith((ref) async => editing),
          mediaEngineProvider.overrideWithValue(engine),
          audioFilePickerProvider.overrideWithValue(picker),
          overlayRendererProvider.overrideWithValue(renderer),
        ],
        child: MaterialApp(home: ExportScreen(match: match)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an empty reel cannot be rendered', (tester) async {
    await pumpExport(tester, session(withClip: false));

    expect(find.text('0 clips · 0:00'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Render reel'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('rendering asks the engine for the reel the user built',
      (tester) async {
    final editing = session();
    await pumpExport(tester, editing);

    await tester.ensureVisible(find.text('Render reel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Render reel'));
    await tester.pumpAndSettle();

    expect(engine.exportRequests, hasLength(1));
    final request = engine.exportRequests.single;
    expect(request.matchId, match.id);
    expect(request.matchDir, match.matchDir);
    expect(request.sourcePath, match.videoPath);
    expect(request.clips, hasLength(1));
    expect(request.clips.single.startSeconds, clip.startSeconds);
    expect(request.clips.single.endSeconds, clip.endSeconds);
    // The scoreboard is an image the application drew, at the recording's size.
    final overlay = request.clips.single.overlayPath;
    expect(overlay, isNotNull);
    expect(File(overlay!).existsSync(), isTrue);
    // The scoreboard is drawn from the score at the clip's own position, and
    // the application supplies no team names, so none can be invented.
    final scoreboard = renderer.scoreboards.single;
    expect(scoreboard.path, overlay);
    expect(scoreboard.leftScore, 1);
    expect(scoreboard.rightScore, 0);
    expect(scoreboard.leftName, isNull);
    expect(scoreboard.rightName, isNull);
    expect(scoreboard.width, 1920);
    expect(scoreboard.height, 1080);
    // No title and no music unless the user asked for them.
    expect(request.title, isNull);
    expect(request.musicPath, isNull);
    expect(request.leadInSeconds, ExportSettings.defaultLeadInSeconds);
    expect(request.leadOutSeconds, ExportSettings.defaultLeadOutSeconds);
  });

  testWidgets('a title the user typed becomes a title card', (tester) async {
    final editing = session(
      settings: const ExportSettings(matchId: 'match-1', title: 'Club final'),
    );
    await pumpExport(tester, editing);

    await tester.ensureVisible(find.text('Render reel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Render reel'));
    await tester.pumpAndSettle();

    expect(renderer.titles.single.title, 'Club final');
    expect(engine.exportRequests.single.title, isNotNull);
    expect(engine.exportRequests.single.title!.seconds, greaterThan(0));
    expect(
      File(engine.exportRequests.single.title!.imagePath).existsSync(),
      isTrue,
    );
  });

  testWidgets('a finished reel is offered to the user', (tester) async {
    engine.manifestArtifacts = <ArtifactDto>[
      ArtifactDto(
        kind: 'export',
        relativePath: 'export/highlight.mp4',
        state: ArtifactStateDto.final_,
        sizeBytes: BigInt.from(4096),
      ),
    ];
    await pumpExport(tester, session());

    await tester.tap(find.text('Render reel'));
    await tester.pumpAndSettle();

    expect(find.text('Reel ready · highlight.mp4'), findsOneWidget);
    expect(find.text('Play the reel'), findsOneWidget);
    expect(find.text('Save or share'), findsOneWidget);
    expect(find.text('Render again'), findsOneWidget);
  });

  testWidgets('a failure is reported instead of being swallowed',
      (tester) async {
    engine.jobState = JobStateDto.failed;
    engine.jobError = 'the render failed: no space left on device';
    await pumpExport(tester, session());

    await tester.tap(find.text('Render reel'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('no space left on device'),
      findsOneWidget,
    );
    expect(find.text('Render reel'), findsOneWidget);
  });

  testWidgets('an export that finishes without a reel recorded is reported',
      (tester) async {
    await pumpExport(tester, session());

    await tester.tap(find.text('Render reel'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('no exported video recorded'),
      findsOneWidget,
    );
  });

  testWidgets('a running render shows its stage and can be cancelled',
      (tester) async {
    engine.jobState = JobStateDto.running;
    engine.jobStage = 'render';
    await pumpExport(tester, session());

    await tester.tap(find.text('Render reel'));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Rendering the reel…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // The engine reports the cancellation, which is what ends the screen's
    // watch of the job.
    engine.jobState = JobStateDto.cancelled;
    await tester.ensureVisible(find.text('Cancel'));
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(engine.jobCancelCalls, 1);
    expect(find.text('Render reel'), findsOneWidget);
  });

  testWidgets('music is chosen from device storage and stored with the match',
      (tester) async {
    final editing = session();
    final music = File(p.join(tempDir.path, 'warm-up.m4a'))
      ..writeAsBytesSync(<int>[1, 2, 3]);
    picker.result = PickedAudio(path: music.path, displayName: 'warm-up.m4a');
    await pumpExport(tester, editing);

    expect(find.text('No music'), findsOneWidget);
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();

    expect(picker.calls, 1);
    expect(editing.settings!.musicPath, music.path);
    expect(find.text('warm-up.m4a'), findsOneWidget);
  });

  testWidgets('music that is no longer on the device is reported before '
      'rendering', (tester) async {
    final editing = session(
      settings: ExportSettings(
        matchId: match.id,
        musicPath: p.join(tempDir.path, 'gone.m4a'),
      ),
    );
    await pumpExport(tester, editing);

    await tester.tap(find.text('Render reel'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('no longer on this device'),
      findsOneWidget,
    );
    expect(engine.exportRequests, isEmpty);
  });
}
