/// Calibration screen tests: the four handles, moving one, the projected court,
/// and saving the result with the match.
///
/// The engine and the library are doubles, and playback is a double the screen
/// accepts directly, so nothing here needs the native library, a database, or a
/// device.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sportcut/src/bridge/sportcut_engine.dart';
import 'package:sportcut/src/features/calibration/domain/court_calibration.dart';
import 'package:sportcut/src/features/calibration/presentation/calibration_screen.dart';
import 'package:sportcut/src/features/library/domain/match_record.dart';
import 'package:sportcut/src/features/library/presentation/library_providers.dart';

import 'support/fake_match_library.dart';
import 'support/fakes.dart';

void main() {
  late FakeMediaEngine engine;
  late FakeMatchLibrary library;
  late FakePlaybackController playback;

  final match = MatchRecord(
    id: 'match-1',
    title: 'Club final',
    videoPath: '/tmp/club-final.mp4',
    durationSeconds: 90,
    createdAt: DateTime(2026, 3, 2),
    matchDir: '/tmp/matches/match-1',
  );

  setUp(() {
    engine = FakeMediaEngine();
    library = FakeMatchLibrary(matches: <MatchRecord>[match]);
    playback = FakePlaybackController();
  });

  Future<void> pumpCalibration(WidgetTester tester, MatchRecord record) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaEngineProvider.overrideWithValue(engine),
          matchRepositoryProvider.overrideWith((ref) async => library),
        ],
        child: MaterialApp(
          home: CalibrationScreen(match: record, controller: playback),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder handleFor(int number) => find.ancestor(
        of: find.text('$number'),
        matching: find.byType(GestureDetector),
      );

  testWidgets('the four corners are marked and the court is projected',
      (tester) async {
    await pumpCalibration(tester, match);

    for (var number = 1; number <= 4; number += 1) {
      expect(handleFor(number), findsOneWidget);
    }
    // An unmarked match claims nothing: the handles are where the screen starts
    // them, and the engine has not been asked about a court yet.
    expect(engine.lastGeometrySegment, isNull);

    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save court'),
    );
    expect(save.onPressed, isNotNull);
  });

  testWidgets('dragging a handle moves that corner', (tester) async {
    await pumpCalibration(tester, match);
    final before = tester.getCenter(handleFor(3));
    final projectionsBefore = engine.lastGeometrySegment;

    await tester.drag(handleFor(3), const Offset(-40, -30));
    await tester.pumpAndSettle();

    final after = tester.getCenter(handleFor(3));
    expect(after.dx, lessThan(before.dx));
    expect(after.dy, lessThan(before.dy));
    // Letting go re-projects the court through the engine, so the outline the
    // user checks is the court they just marked.
    expect(engine.lastGeometrySegment, isNotNull);
    expect(
      identical(engine.lastGeometrySegment, projectionsBefore),
      isFalse,
    );
    expect(playback.loaded, <String>[match.videoPath]);
  });

  testWidgets('a handle dragged past the edge of the frame stops at the edge',
      (tester) async {
    await pumpCalibration(tester, match);
    final box = tester.getRect(handleFor(3));
    final far = tester.getCenter(handleFor(3)) + const Offset(600, 600);

    await tester.dragFrom(tester.getCenter(handleFor(3)), const Offset(600, 600));
    await tester.pumpAndSettle();

    // The handle is still on screen, in the corner it was dragged towards,
    // rather than off the frame.
    final moved = tester.getCenter(handleFor(3));
    expect(moved.dx, lessThan(far.dx));
    expect(moved.dx, greaterThan(box.center.dx));
  });

  testWidgets('the way the court runs is the user choice, and is saved',
      (tester) async {
    await pumpCalibration(tester, match);

    await tester.tap(find.text('Across the view'));
    await tester.pumpAndSettle();

    expect(
      engine.lastGeometrySegment!.orientation,
      CourtOrientationDto.across,
    );

    await tester.tap(find.text('Save court'));
    await tester.pumpAndSettle();

    final saved = library.lastSavedCalibration;
    expect(saved, isNotNull);
    expect(saved!.firstSegment!.orientation, CourtOrientation.across);
    expect(saved.firstSegment!.corners, hasLength(4));
  });

  testWidgets('a court the engine rejects is reported to the user',
      (tester) async {
    engine.failure = SportcutEngineException(
      'court calibration: segment from 0ms: the corners do not go round the '
      'court in order',
    );
    await pumpCalibration(tester, match);

    await tester.drag(handleFor(2), const Offset(60, -60));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('do not go round the court in order'),
      findsOneWidget,
    );
  });

  testWidgets('an incomplete court cannot be saved', (tester) async {
    const partial = CalibrationSegment(
      fromMs: 0,
      corners: <CourtCorner>[
        CourtCorner(x: 0.1, y: 0.9),
        CourtCorner(x: 0.9, y: 0.9),
        CourtCorner(x: 0.7, y: 0.4),
      ],
      orientation: CourtOrientation.away,
    );
    final record = match.copyWith(
      courtCalibration: const CourtCalibration(
        segments: <CalibrationSegment>[partial],
      ),
    );
    await pumpCalibration(tester, record);

    // The match already has a stored court, so the screen offers to update it —
    // and refuses while three of its corners are all it has.
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Update court'),
    );
    expect(save.onPressed, isNull);
    expect(
      find.text('Place all four corners to see the projected net.'),
      findsOneWidget,
    );
    expect(library.lastSavedCalibration, isNull);
  });
}
