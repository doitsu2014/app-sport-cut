/// Screenshots of the real macOS app, captured through a [RepaintBoundary].
///
/// `IntegrationTestWidgetsFlutterBinding.takeScreenshot` is not implemented on
/// macOS (it throws `MissingPluginException`), so every image goes through the
/// shared [captureScreenshot] helper instead. The test pumps the real
/// [SportcutApp] with in-memory provider overrides, so no engine, service, or
/// catalog database is started, and drives the real route table end to end.
///
/// Run from `app/`:
///
/// ```
/// flutter test integration_test/app_screenshot_test.dart -d macos \
///   --reporter expanded
/// ```
///
/// PNGs land in `build/screenshots/` unless `SPORTCUT_SCREENSHOT_DIR` says
/// otherwise.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sportcut/src/app/app.dart';
import 'package:sportcut/src/app/di.dart';
import 'package:sportcut/src/app/router.dart';
import 'package:sportcut/src/bridge/sportcut_engine.dart';
import 'package:sportcut/src/features/analysis/presentation/analysis_panel.dart';
import 'package:sportcut/src/features/analysis/presentation/analysis_screen.dart';
import 'package:sportcut/src/features/calibration/presentation/calibration_panel.dart';
import 'package:sportcut/src/features/calibration/presentation/calibration_screen.dart';
import 'package:sportcut/src/features/editing/domain/highlight_clip.dart';
import 'package:sportcut/src/features/editing/domain/rally.dart';
import 'package:sportcut/src/features/editing/presentation/editing_providers.dart';
import 'package:sportcut/src/features/export/presentation/export_screen.dart';
import 'package:sportcut/src/features/export/presentation/export_sheet.dart';
import 'package:sportcut/src/features/highlights/presentation/highlight_ranking_providers.dart';
import 'package:sportcut/src/features/highlights/presentation/highlights_screen.dart';
import 'package:sportcut/src/features/highlights/presentation/reel_panel.dart';
import 'package:sportcut/src/features/library/domain/match_record.dart';
import 'package:sportcut/src/features/library/presentation/library_providers.dart';
import 'package:sportcut/src/features/library/presentation/player_screen.dart';
import 'package:sportcut/src/features/rally/presentation/rally_review_providers.dart';
import 'package:sportcut/src/features/score/presentation/rally_panel.dart';
import 'package:sportcut/src/features/score/presentation/score_screen.dart';
import 'package:sportcut/src/features/score/presentation/serving_sides_providers.dart';
import 'package:sportcut/src/features/tracking/presentation/player_tracking_screen.dart';
import 'package:sportcut/src/features/tracking/presentation/tracking_panel.dart';
import 'package:sportcut/src/features/workspace/presentation/home/workspace_row.dart';
import 'package:sportcut/src/features/workspace/presentation/studio/inspector_pane.dart';
import 'package:sportcut/src/features/workspace/presentation/studio/stage_strip.dart';
import 'package:sportcut/src/features/workspace/presentation/studio/studio_shell.dart';
import 'package:sportcut/src/features/workspace/presentation/studio/studio_status_bar.dart';
import 'package:sportcut/src/features/workspace/presentation/studio/timeline_dock.dart';
import 'package:sportcut/src/features/workspace/presentation/studio/video_rail.dart';
import 'package:sportcut/src/features/workspace/domain/workspace.dart';
import 'package:sportcut/src/features/workspace/presentation/workspace_screen.dart';
import 'package:sportcut/src/features/workspace/presentation/workspace_studio_screen.dart';

import '../test/support/fake_match_editing.dart';
import '../test/support/fake_match_library.dart';
import '../test/support/fakes.dart';
import '../test/support/screenshot_fixtures.dart';
import '../test/support/screenshot_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures the home and every studio stage', (tester) async {
    final fixture = _ScreenshotFixture.create();
    addTearDown(fixture.dispose);

    await _prepareSurface(tester);
    final key = GlobalKey();
    await _pumpApp(tester, key, fixture);
    await tester.pumpAndSettle();

    // Home: the workspace list with one night and two recordings.
    expect(find.byType(WorkspaceScreen), findsOneWidget);
    expect(find.byType(WorkspaceRow), findsOneWidget);
    expect(find.text('Thursday club night'), findsOneWidget);
    expect(find.textContaining('Last video'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
    await captureScreenshot(tester, key, 'macos_home');

    // Open the workspace. The first video is auto-selected post-frame.
    await tester.tap(find.text('Thursday club night'));
    await tester.pumpAndSettle();

    expect(find.byType(WorkspaceStudioScreen), findsOneWidget);
    expect(find.byType(StudioShell), findsOneWidget);
    expect(find.byType(StageStrip), findsOneWidget);
    expect(find.byType(VideoRail), findsOneWidget);
    expect(find.byType(InspectorPane), findsOneWidget);
    expect(find.byType(TimelineDock), findsOneWidget);
    expect(find.byType(StudioStatusBar), findsOneWidget);
    expect(find.text('Workspace / Thursday club night'), findsOneWidget);
    expect(find.byKey(const Key('fake-playback-surface')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captureScreenshot(tester, key, 'macos_studio_play');

    // Mark court: the stored court reopens on the projection.
    await _tapStage(tester, 'Mark court');
    expect(find.byType(CalibrationPanel), findsOneWidget);
    expect(find.text('MARK COURT'), findsOneWidget);
    expect(find.text('COURT'), findsOneWidget);
    expect(find.text('4 of 4'), findsOneWidget);
    expect(find.text('Which way does the court run?'), findsOneWidget);
    expect(find.text('Update court'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captureScreenshot(tester, key, 'macos_studio_mark_court');

    // Prepare analysis: the manifest reports the final frames.
    await _tapStage(tester, 'Prepare analysis');
    expect(find.byType(AnalysisPanel), findsOneWidget);
    expect(find.text('PREPARE ANALYSIS'), findsOneWidget);
    expect(find.text('ANALYSIS FILES'), findsOneWidget);
    expect(find.text('Nothing to rebuild'), findsOneWidget);
    expect(find.text('ARTIFACTS'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captureScreenshot(tester, key, 'macos_studio_analysis');

    // Player analysis: tracks load from the fake engine into the panel.
    await _tapStage(tester, 'Player analysis');
    expect(find.byType(TrackingPanel), findsOneWidget);
    expect(find.text('PLAYER ANALYSIS'), findsOneWidget);
    expect(find.text('QUALITY'), findsOneWidget);
    expect(find.text('Detections'), findsOneWidget);
    expect(find.text('Review rallies manually'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captureScreenshot(tester, key, 'macos_studio_tracking');

    // Review & score: the rally inspector with the confirmed first point.
    await _tapStage(tester, 'Review & score');
    expect(find.byType(RallyPanel), findsOneWidget);
    expect(find.text('REVIEW & SCORE'), findsOneWidget);
    expect(find.text('L · LEFT'), findsOneWidget);
    expect(find.text('R · RIGHT'), findsOneWidget);
    expect(find.text('MANUAL MARKING'), findsOneWidget);
    expect(find.textContaining('Point 1'), findsOneWidget);
    expect(find.text('Rally'), findsOneWidget);
    expect(find.text('Clip'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captureScreenshot(tester, key, 'macos_studio_score');

    // Highlights: the kept reel and the rally that was left out.
    await _tapStage(tester, 'Highlights');
    expect(find.byType(ReelPanel), findsOneWidget);
    expect(find.text('HIGHLIGHTS'), findsOneWidget);
    expect(find.text('LEFT OUT'), findsOneWidget);
    expect(find.text('Keep top 10'), findsOneWidget);
    expect(find.text('2 kept · 0 dismissed'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captureScreenshot(tester, key, 'macos_studio_highlights');

    // Export: the stage tab opens the export sheet over the studio. At the
    // 1180x760 reference window the sheet's scrolling body folds the primary
    // action below the visible area, so this capture records the real layout;
    // the assertions then prove the action is reachable by scrolling.
    await _tapStage(tester, 'Export');
    expect(find.byType(ExportSheet), findsOneWidget);
    expect(find.text('Export highlight reel'), findsOneWidget);
    expect(find.text('Export reel'), findsOneWidget);
    expect(find.text('Scoreboard through 1–1.'), findsOneWidget);
    expect(find.text('No music; match audio only.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captureScreenshot(tester, key, 'macos_studio_export');

    await tester.ensureVisible(find.text('Export reel'));
    await tester.pumpAndSettle();
    expect(find.text('Export reel').hitTestable(), findsOneWidget);
    await captureScreenshot(tester, key, 'macos_studio_export_scrolled');

    await tester.tap(
      find.descendant(
        of: find.byType(ExportSheet),
        matching: find.text('Cancel'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ExportSheet), findsNothing);
  });

  testWidgets('captures the legacy pipeline routes', (tester) async {
    final fixture = _ScreenshotFixture.create();
    addTearDown(fixture.dispose);

    await _prepareSurface(tester);
    final key = GlobalKey();
    await _pumpApp(tester, key, fixture);
    await tester.pumpAndSettle();

    expect(find.byType(WorkspaceScreen), findsOneWidget);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);

    // Player.
    unawaited(
      navigator.pushNamed(AppRoutes.player, arguments: fixture.routeMatch),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PlayerScreen), findsOneWidget);
    expect(find.text('Club final'), findsOneWidget);
    expect(find.byKey(const Key('fake-playback-surface')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captureScreenshot(tester, key, 'macos_player');
    navigator.pop();
    await tester.pumpAndSettle();

    // Court calibration.
    unawaited(
      navigator.pushNamed(
        AppRoutes.calibration,
        arguments: fixture.routeMatch,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CalibrationScreen), findsOneWidget);
    expect(find.text('Court calibration'), findsOneWidget);
    expect(find.text('COURT'), findsOneWidget);
    expect(find.text('4 of 4'), findsOneWidget);
    expect(find.text('Save court'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captureScreenshot(tester, key, 'macos_calibration');
    navigator.pop();
    await tester.pumpAndSettle();

    // Analysis.
    unawaited(
      navigator.pushNamed(AppRoutes.analysis, arguments: fixture.routeMatch),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AnalysisScreen), findsOneWidget);
    expect(find.text('Analysis'), findsOneWidget);
    expect(find.text('ANALYSIS FILES'), findsOneWidget);
    expect(find.text('Nothing to rebuild'), findsOneWidget);
    expect(find.text('Review player analysis'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captureScreenshot(tester, key, 'macos_analysis');
    navigator.pop();
    await tester.pumpAndSettle();

    // Player analysis.
    unawaited(
      navigator.pushNamed(
        AppRoutes.playerTracking,
        arguments: fixture.routeMatch,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PlayerTrackingScreen), findsOneWidget);
    expect(find.text('Player analysis'), findsOneWidget);
    expect(find.byType(TrackingPanel), findsOneWidget);
    expect(find.text('QUALITY'), findsOneWidget);
    expect(find.text('Detections'), findsOneWidget);
    expect(find.text('Review rallies manually'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captureScreenshot(tester, key, 'macos_player_tracking');
    navigator.pop();
    await tester.pumpAndSettle();

    // Score.
    unawaited(
      navigator.pushNamed(AppRoutes.score, arguments: fixture.routeMatch),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ScoreScreen), findsOneWidget);
    expect(find.byType(RallyPanel), findsOneWidget);
    expect(find.text('L · LEFT'), findsOneWidget);
    expect(find.text('MANUAL MARKING'), findsOneWidget);
    expect(find.textContaining('Point 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captureScreenshot(tester, key, 'macos_score');
    navigator.pop();
    await tester.pumpAndSettle();

    // Highlights.
    unawaited(
      navigator.pushNamed(
        AppRoutes.highlights,
        arguments: fixture.routeMatch,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HighlightsScreen), findsOneWidget);
    expect(find.byType(ReelPanel), findsOneWidget);
    expect(
      find.text('No clip selected. Choose a rally on the timeline.'),
      findsOneWidget,
    );
    expect(find.text('Keep top 10'), findsOneWidget);
    expect(find.text('2 kept · 0 dismissed'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captureScreenshot(tester, key, 'macos_highlights');
    navigator.pop();
    await tester.pumpAndSettle();

    // Export.
    unawaited(
      navigator.pushNamed(AppRoutes.export, arguments: fixture.routeMatch),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ExportScreen), findsOneWidget);
    expect(find.text('Export Club final'), findsOneWidget);
    expect(find.text('Export reel'), findsOneWidget);
    expect(find.text('Title card'), findsOneWidget);
    expect(find.text('Scoreboard through 1–1.'), findsOneWidget);
    expect(find.text('No music; match audio only.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captureScreenshot(tester, key, 'macos_export');
    navigator.pop();
    await tester.pumpAndSettle();
  });
}

/// Size the live macOS surface and force the light theme branch.
Future<void> _prepareSurface(WidgetTester tester) async {
  await useIntegrationScreenshotSurface(tester);
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

/// Pump the real app inside the capture boundary with the fake overrides.
Future<void> _pumpApp(
  WidgetTester tester,
  GlobalKey key,
  _ScreenshotFixture fixture,
) {
  return tester.pumpWidget(
    screenshotBoundary(
      key,
      ProviderScope(
        overrides: fixture.overrides,
        child: const SportcutApp(),
      ),
    ),
  );
}

/// Tap a stage tab, scoped to the strip so repeated labels cannot match.
Future<void> _tapStage(WidgetTester tester, String label) async {
  final tab = find.descendant(
    of: find.byType(StageStrip),
    matching: find.text(label),
  );
  expect(tab, findsOneWidget);
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

/// A review controller that reports an opened, loaded session.
///
/// `test/support/fakes.dart` has no rally-review double, and the real
/// controller calls the engine for suggestions. Overriding it here keeps the
/// Rally inspector free of an engine problem banner.
class _FakeRallyReviewController extends RallyReviewController {
  @override
  RallyReviewState build() => const RallyReviewState();

  @override
  Future<void> open(MatchRecord match) async {
    state = RallyReviewState(match: match, loaded: true);
  }
}

/// Everything the screenshots need: a temp recording store and the fakes.
class _ScreenshotFixture {
  _ScreenshotFixture({
    required this.directory,
    required this.match,
    required this.routeMatch,
    required this.library,
    required this.editing,
    required this.mediaEngine,
    required this.engine,
  });

  factory _ScreenshotFixture.create() {
    final directory =
        Directory.systemTemp.createTempSync('sportcut_screenshots_');
    final recording = writeRecordingPlaceholder(
      directory: directory,
      fileName: 'match-1.mp4',
    );
    final routeRecording = writeRecordingPlaceholder(
      directory: directory,
      fileName: 'match-route.mp4',
    );
    final match = screenshotMatch(
      id: 'match-1',
      title: 'Club final',
      workspaceId: 'ws-1',
      videoPath: recording.path,
      matchDir: p.join(directory.path, 'matches', 'match-1'),
      courtCalibration: screenshotCourtCalibration(),
    );
    final secondMatch = screenshotMatch(
      id: 'match-2',
      title: 'Semifinal',
      workspaceId: 'ws-1',
      videoPath: recording.path,
      durationSeconds: 62,
      matchDir: p.join(directory.path, 'matches', 'match-2'),
    );
    final routeMatch = screenshotMatch(
      id: 'match-route',
      title: 'Club final',
      workspaceId: 'ws-1',
      videoPath: routeRecording.path,
      matchDir: p.join(directory.path, 'matches', 'match-route'),
    );
    final library = screenshotLibrary(
      workspaces: <Workspace>[screenshotWorkspace()],
      matches: <MatchRecord>[match, secondMatch],
      manifestArtifacts: <String, List<ArtifactDto>>{
        'match-1': screenshotArtifacts(
          includeTracks: true,
          includeExport: true,
        ),
      },
      clipCounts: <String, int>{'match-1': 2},
      scores: <String, ({int left, int right})>{
        'match-1': (left: 1, right: 1),
      },
    );
    final editing = screenshotEditing(
      rallies: <Rally>[
        screenshotRally(
          id: 'rally-1',
          startSeconds: 8,
          endSeconds: 16,
          winnerSide: WinnerSide.left,
        ),
        screenshotRally(
          id: 'rally-2',
          startSeconds: 24,
          endSeconds: 33,
          winnerSide: WinnerSide.right,
        ),
        screenshotRally(
          id: 'rally-3',
          startSeconds: 40,
          endSeconds: 52,
        ),
      ],
      clips: <HighlightClip>[
        screenshotClip(
          id: 'clip-rally-1',
          rallyId: 'rally-1',
          startSeconds: 8,
          endSeconds: 16,
        ),
        screenshotClip(
          id: 'clip-rally-2',
          rallyId: 'rally-2',
          startSeconds: 24,
          endSeconds: 33,
          orderIndex: 1,
        ),
      ],
    );
    final mediaEngine = screenshotEngine(
      manifest: screenshotManifest(
        artifacts: screenshotArtifacts(
          includeTracks: true,
          includeExport: true,
        ),
      ),
      calibration: screenshotCalibrationDto(),
      durationSeconds: 90,
    );
    final engine = screenshotSportcutEngine();
    return _ScreenshotFixture(
      directory: directory,
      match: match,
      routeMatch: routeMatch,
      library: library,
      editing: editing,
      mediaEngine: mediaEngine,
      engine: engine,
    );
  }

  final Directory directory;
  final MatchRecord match;
  final MatchRecord routeMatch;
  final FakeMatchLibrary library;
  final FakeMatchEditing editing;
  final FakeMediaEngine mediaEngine;
  final ScreenshotSportcutEngine engine;

  /// Every provider the pumped screens read, replaced with a fake.
  List<Override> get overrides => <Override>[
        matchRepositoryProvider.overrideWith((ref) async => library),
        matchEditingProvider.overrideWith((ref) async => editing),
        playbackControllerFactoryProvider
            .overrideWithValue(FakePlaybackController.new),
        mediaEngineProvider.overrideWithValue(mediaEngine),
        sportcutEngineProvider.overrideWithValue(engine),
        rallyReviewControllerProvider.overrideWith(
          _FakeRallyReviewController.new,
        ),
        servingSidesProvider.overrideWith(
          (ref) async => const <String, RallySideDto>{},
        ),
        highlightRankingProvider.overrideWith(
          (ref) async => const <String, HighlightRankDto>{},
        ),
      ];

  void dispose() {
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  }
}
