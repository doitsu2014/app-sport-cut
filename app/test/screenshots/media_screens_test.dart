/// Screenshots for the media routes: player, calibration, analysis, tracking.
///
/// Each test pumps the real [SportcutApp] at the studio's reference window,
/// overrides every provider the route reads, pushes the named route with a
/// [MatchRecord], asserts the rendered screen, and captures the boundary.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:sportcut/src/app/app.dart';
import 'package:sportcut/src/app/di.dart';
import 'package:sportcut/src/app/router.dart';
import 'package:sportcut/src/features/library/domain/match_record.dart';
import 'package:sportcut/src/features/library/presentation/library_providers.dart';

import '../support/fakes.dart';
import '../support/screenshot_fixtures.dart';
import '../support/screenshot_harness.dart';

void main() {
  setUpAll(loadScreenshotFonts);

  /// Pump the real app shell and push [route] with [match] on top of it.
  ///
  /// The home route is reached first, so it needs the repository and picker
  /// overrides in [overrides]; every route-specific provider is listed by the
  /// caller.
  Future<GlobalKey> pumpRoute(
    WidgetTester tester, {
    required String route,
    required MatchRecord match,
    required List<Override> overrides,
  }) async {
    useWidgetScreenshotView(tester);
    final key = GlobalKey();
    await tester.pumpWidget(
      screenshotBoundary(
        key,
        ProviderScope(
          overrides: overrides,
          child: const SportcutApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .pushNamed(route, arguments: match);
    await tester.pumpAndSettle();
    return key;
  }

  /// The home route's dependencies, which every test needs.
  ///
  /// The catalog is seeded with [matches] so a route that saves (calibration)
  /// can replace the record it was given.
  List<Override> baseOverrides({
    List<MatchRecord> matches = const <MatchRecord>[],
  }) =>
      <Override>[
        matchRepositoryProvider.overrideWith(
          (ref) async => screenshotLibrary(matches: matches),
        ),
        videoFilePickerProvider.overrideWithValue(FakeVideoFilePicker()),
      ];

  MatchRecord mediaMatch() => screenshotMatch(
        id: 'match-1',
        title: 'Club final',
        videoPath: '/tmp/club-final.mp4',
        matchDir: '/tmp/matches/match-1',
        durationSeconds: 90,
      );

  testWidgets('captures the player route with its transport', (tester) async {
    final MatchRecord match = mediaMatch();
    final FakePlaybackController playback = FakePlaybackController();
    final GlobalKey key = await pumpRoute(
      tester,
      route: AppRoutes.player,
      match: match,
      overrides: <Override>[
        ...baseOverrides(),
        playbackControllerFactoryProvider.overrideWithValue(() => playback),
      ],
    );

    expect(find.text('Club final'), findsOneWidget);
    expect(playback.loaded, <String>[match.videoPath]);
    expect(find.byKey(const Key('fake-playback-surface')), findsOneWidget);
    expect(find.byTooltip('Play'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('0:00'), findsWidgets);
    expect(find.text('1:30'), findsOneWidget);

    await captureScreenshot(tester, key, 'player');

    await tester.tap(find.byTooltip('Play'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Pause'), findsOneWidget);
    expect(find.byTooltip('Play'), findsNothing);

    await captureScreenshot(tester, key, 'player_playing');
  });

  testWidgets('captures the calibration route before and after projecting',
      (tester) async {
    final MatchRecord match = mediaMatch();
    final FakeMediaEngine engine = screenshotEngine();
    final FakePlaybackController playback = FakePlaybackController();
    final GlobalKey key = await pumpRoute(
      tester,
      route: AppRoutes.calibration,
      match: match,
      overrides: <Override>[
        ...baseOverrides(matches: <MatchRecord>[match]),
        mediaEngineProvider.overrideWithValue(engine),
        playbackControllerFactoryProvider.overrideWithValue(() => playback),
      ],
    );

    expect(find.text('Court calibration'), findsOneWidget);
    expect(playback.loaded, <String>[match.videoPath]);
    for (final String handle in <String>['1', '2', '3', '4']) {
      expect(find.text(handle), findsOneWidget);
    }
    expect(find.text('COURT'), findsOneWidget);
    expect(find.text('Court runs'), findsOneWidget);
    expect(find.text('Away from you'), findsWidgets);
    expect(find.text('Corners'), findsOneWidget);
    expect(find.text('4 of 4'), findsOneWidget);
    expect(find.text('Marking the court…'), findsOneWidget);
    expect(find.text('Which way does the court run?'), findsOneWidget);
    expect(find.text('Across the view'), findsOneWidget);
    expect(find.text('Save court'), findsOneWidget);

    await captureScreenshot(tester, key, 'calibration_default');

    // Dragging handle 3 asks the engine to project, so the net is drawn.
    final Finder handle3 = find
        .ancestor(of: find.text('3'), matching: find.byType(GestureDetector))
        .first;
    await tester.drag(handle3, const Offset(-40, -30));
    await tester.pumpAndSettle();

    expect(engine.lastGeometrySegment, isNotNull);
    expect(
      find.textContaining('The dashed line is the net'),
      findsOneWidget,
    );

    await captureScreenshot(tester, key, 'calibration_projected');
  });

  testWidgets('captures the analysis route with ready artifacts',
      (tester) async {
    final MatchRecord match = mediaMatch();
    final FakeMediaEngine engine = screenshotEngine(
      artifacts: screenshotArtifacts(),
    );
    final GlobalKey key = await pumpRoute(
      tester,
      route: AppRoutes.analysis,
      match: match,
      overrides: <Override>[
        ...baseOverrides(),
        mediaEngineProvider.overrideWithValue(engine),
      ],
    );

    expect(find.text('Analysis'), findsOneWidget);
    expect(find.text('Club final'), findsOneWidget);
    expect(
      find.text('1:30  ·  1920×1080  ·  30.00 fps  ·  audio'),
      findsOneWidget,
    );
    expect(find.text('ANALYSIS FILES'), findsOneWidget);
    expect(find.text('ARTIFACTS'), findsOneWidget);
    expect(find.text('proxy'), findsOneWidget);
    // The frames artifact's kind and relative path are both "frames".
    expect(find.text('frames'), findsWidgets);
    expect(find.text('READY'), findsNWidgets(2));
    expect(find.text('2.0 KB'), findsOneWidget);
    expect(find.text('1.0 KB'), findsOneWidget);
    expect(find.text('proxy/proxy.mp4'), findsOneWidget);
    expect(find.text('Nothing to rebuild'), findsOneWidget);
    expect(find.text('Review player analysis'), findsOneWidget);
    expect(find.textContaining('no analysis files yet'), findsNothing);

    await captureScreenshot(tester, key, 'analysis_ready');
  });

  testWidgets('captures the player tracking route with loaded tracks',
      (tester) async {
    final MatchRecord match = mediaMatch();
    final ScreenshotSportcutEngine engine = screenshotSportcutEngine();
    final FakePlaybackController playback = FakePlaybackController();
    final GlobalKey key = await pumpRoute(
      tester,
      route: AppRoutes.playerTracking,
      match: match,
      overrides: <Override>[
        ...baseOverrides(),
        sportcutEngineProvider.overrideWithValue(engine),
        playbackControllerFactoryProvider.overrideWithValue(() => playback),
      ],
    );

    expect(find.text('Player analysis'), findsOneWidget);
    expect(find.text('Rebuild tracks'), findsOneWidget);
    expect(find.text('Review rallies manually'), findsOneWidget);
    expect(find.text('QUALITY'), findsOneWidget);
    expect(find.text('Detections'), findsOneWidget);
    expect(find.text('Two players observed'), findsOneWidget);
    expect(find.text('Coverage'), findsOneWidget);
    expect(find.text('92%'), findsOneWidget);
    expect(find.text('Gaps'), findsOneWidget);
    expect(find.text('Window'), findsOneWidget);
    expect(find.text('0:00 – 0:05'), findsWidgets);
    expect(find.text('Previous'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('L Left'), findsNWidgets(2));
    expect(find.text('R Right'), findsNWidgets(2));
    expect(find.text('? Unknown'), findsNWidgets(2));
    expect(
      find.text('Track #1 unseen from 0:01 to 0:02'),
      findsOneWidget,
    );
    expect(find.textContaining('No player tracks detected'), findsNothing);
    expect(find.text('Reading player tracks…'), findsNothing);

    await captureScreenshot(tester, key, 'player_tracking_tracks');
  });
}
