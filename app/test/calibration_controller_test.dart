/// Calibration controller tests: what the screen holds while the user marks the
/// court, and what it asks the engine and the library to do.
///
/// The engine is a double, so these run without the native library; the screen
/// that drives this controller is covered by `calibration_screen_test.dart`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sportcut/src/bridge/sportcut_engine.dart';
import 'package:sportcut/src/features/calibration/domain/court_calibration.dart';
import 'package:sportcut/src/features/calibration/presentation/calibration_controller.dart';
import 'package:sportcut/src/features/library/domain/match_record.dart';
import 'package:sportcut/src/features/library/presentation/library_providers.dart';

import 'support/fake_match_library.dart';
import 'support/fakes.dart';

void main() {
  final match = MatchRecord(
    id: 'match-1',
    title: 'Club final',
    videoPath: '/tmp/club-final.mp4',
    durationSeconds: 90,
    createdAt: DateTime(2026, 3, 2),
    matchDir: '/tmp/matches/match-1',
  );

  late FakeMediaEngine engine;
  late FakeMatchLibrary library;
  late ProviderContainer container;

  setUp(() {
    engine = FakeMediaEngine();
    library = FakeMatchLibrary(matches: <MatchRecord>[match]);
    container = ProviderContainer(
      overrides: [
        mediaEngineProvider.overrideWithValue(engine),
        matchRepositoryProvider.overrideWith((ref) async => library),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  CalibrationController controller() =>
      container.read(calibrationControllerProvider.notifier);

  CalibrationState state() => container.read(calibrationControllerProvider);

  CourtCorner cornerOf(int index) => state().corners[index];

  test('a corner dragged past the edge stops at the edge', () {
    final before = List<CourtCorner>.of(state().corners);

    // Far past the bottom-right of the frame, and far past the top-left.
    controller().nudgeCorner(0, 5, 5);
    expect(cornerOf(0), const CourtCorner(x: 1, y: 1));
    controller().nudgeCorner(0, -5, -5);
    expect(cornerOf(0), const CourtCorner(x: 0, y: 0));

    // Only the corner the user moved has moved.
    expect(cornerOf(1), before[1]);
    expect(cornerOf(2), before[2]);
    expect(cornerOf(3), before[3]);
  });

  test('a drag moves one corner by the offset it was given', () {
    final before = cornerOf(1);

    controller().nudgeCorner(1, 0.05, -0.1);

    expect(cornerOf(1).x, closeTo(before.x + 0.05, 1e-9));
    expect(cornerOf(1).y, closeTo(before.y - 0.1, 1e-9));
  });

  test('a corner index that does not exist is ignored', () {
    final before = state().corners;

    controller().nudgeCorner(9, 0.1, 0.1);

    expect(state().corners, before);
  });

  test('an incomplete calibration is never projected', () async {
    // A stored segment with only three corners: the user has not finished.
    const partial = CalibrationSegment(
      fromMs: 0,
      corners: <CourtCorner>[
        CourtCorner(x: 0.1, y: 0.9),
        CourtCorner(x: 0.9, y: 0.9),
        CourtCorner(x: 0.7, y: 0.4),
      ],
      orientation: CourtOrientation.away,
    );
    controller().open(
      match.copyWith(
        courtCalibration: const CourtCalibration(
          segments: <CalibrationSegment>[partial],
        ),
      ),
    );

    expect(state().isComplete, isFalse);
    expect(state().isProjected, isFalse);
    await controller().project();
    expect(engine.lastGeometrySegment, isNull);
    expect(state().isProjected, isFalse);
  });

  test('a complete calibration is projected through the engine', () async {
    controller().open(match);
    await controller().project();

    expect(state().isComplete, isTrue);
    expect(engine.lastGeometrySegment, isNotNull);
    expect(engine.lastGeometrySegment!.corners, hasLength(4));
    expect(engine.lastGeometrySegment!.orientation, CourtOrientationDto.away);
    expect(state().isProjected, isTrue);
    expect(state().problem, isNull);
  });

  test('a court the engine rejects is reported and nothing is drawn', () async {
    controller().open(match);
    engine.failure = SportcutEngineException(
      'court calibration: segment from 0ms: the corners do not go round the '
      'court in order',
    );

    await controller().project();

    expect(state().isProjected, isFalse);
    expect(state().problem, contains('do not go round the court in order'));
  });

  test('opening a calibrated match loads the court the user marked', () async {
    final calibration = CourtCalibration.fromCorners(
      corners: const <CourtCorner>[
        CourtCorner(x: 0.2, y: 0.8),
        CourtCorner(x: 0.8, y: 0.8),
        CourtCorner(x: 0.65, y: 0.3),
        CourtCorner(x: 0.35, y: 0.3),
      ],
      orientation: CourtOrientation.across,
    );
    controller().open(match.copyWith(courtCalibration: calibration));
    await Future<void>.delayed(Duration.zero);

    expect(state().loaded, isTrue);
    expect(state().stored, isTrue);
    expect(state().orientation, CourtOrientation.across);
    expect(state().corners.first.x, 0.2);
    // The stored court is re-projected, so the screen draws it again.
    expect(engine.lastGeometrySegment, isNotNull);
  });

  test('an uncalibrated match opens with the starting court and claims '
      'nothing', () async {
    controller().open(match);
    await Future<void>.delayed(Duration.zero);

    expect(state().loaded, isTrue);
    expect(state().stored, isFalse);
    expect(state().corners, hasLength(4));
    expect(engine.lastGeometrySegment, isNull);
  });

  test('changing the orientation re-projects against the new one', () async {
    controller().open(match);
    await controller().project();
    expect(
      engine.lastGeometrySegment!.orientation,
      CourtOrientationDto.away,
    );

    await controller().setOrientation(CourtOrientation.across);

    expect(state().orientation, CourtOrientation.across);
    expect(
      engine.lastGeometrySegment!.orientation,
      CourtOrientationDto.across,
    );

    // Asking for the orientation it already has changes nothing.
    final before = engine.lastGeometrySegment;
    await controller().setOrientation(CourtOrientation.across);
    expect(engine.lastGeometrySegment, same(before));
  });

  test('saving stores the corners and orientation the user set', () async {
    controller().open(match);
    controller().nudgeCorner(2, -0.05, 0.05);
    await controller().setOrientation(CourtOrientation.across);

    final saved = await controller().save(match);

    expect(saved, isNotNull);
    final stored = library.lastSavedCalibration;
    expect(stored, isNotNull);
    final segment = stored!.firstSegment!;
    expect(segment.orientation, CourtOrientation.across);
    expect(segment.corners, hasLength(4));
    expect(segment.corners[2].x, closeTo(state().corners[2].x, 1e-9));
    expect(state().stored, isTrue);
    expect(state().saving, isFalse);
  });

  test('an incomplete calibration is not saved', () async {
    const partial = CalibrationSegment(
      fromMs: 0,
      corners: <CourtCorner>[
        CourtCorner(x: 0.1, y: 0.9),
        CourtCorner(x: 0.9, y: 0.9),
        CourtCorner(x: 0.7, y: 0.4),
      ],
      orientation: CourtOrientation.away,
    );
    controller().open(
      match.copyWith(
        courtCalibration: const CourtCalibration(
          segments: <CalibrationSegment>[partial],
        ),
      ),
    );

    final saved = await controller().save(match);

    expect(saved, isNull);
    expect(library.lastSavedCalibration, isNull);
  });

  test('a save that fails is reported rather than silently dropped', () async {
    controller().open(match);
    library.failure = StateError('the catalog is not writable');

    final saved = await controller().save(match);

    expect(saved, isNull);
    expect(state().saving, isFalse);
    expect(state().problem, contains('could not be saved'));
  });
}
