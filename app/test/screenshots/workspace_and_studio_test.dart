/// Screenshots for the workspace home and the workspace studio.
///
/// Every test pumps the real [SportcutApp] at the studio reference window.
/// The export sheet is captured twice: once at that reference window, where its
/// scrolling body folds the primary action below the visible area, and once on
/// a taller window so the whole settings form is visible without scrolling.
/// Each test wraps the app in the shared screenshot boundary, seeds the studio
/// through the in-memory library/editing doubles, and drives the real route
/// table by tapping the home row. Nothing reads SQLite, the Unix-socket engine,
/// or a platform plugin.
///
/// The studio's Rally and Player-analysis stages normally read
/// `sportcutEngineProvider` directly through their controllers. The local
/// controller doubles below keep those sessions in memory, which is the same
/// shape the studio route already uses in production (the shell owns the
/// session and opens it once per selected video).
///
/// Capture names are intentionally flat snake_case for the whole suite.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sportcut/src/app/app.dart';
import 'package:sportcut/src/app/design/components/sc_dialog.dart';
import 'package:sportcut/src/app/design/components/sc_empty_state.dart';
import 'package:sportcut/src/app/design/components/sc_score_bug.dart';
import 'package:sportcut/src/bridge/sportcut_engine.dart';
import 'package:sportcut/src/features/analysis/presentation/analysis_panel.dart';
import 'package:sportcut/src/features/calibration/presentation/calibration_panel.dart';
import 'package:sportcut/src/features/editing/domain/highlight_clip.dart';
import 'package:sportcut/src/features/editing/domain/rally.dart';
import 'package:sportcut/src/features/editing/presentation/editing_providers.dart';
import 'package:sportcut/src/features/export/presentation/export_sheet.dart';
import 'package:sportcut/src/features/highlights/presentation/clip_inspector_panel.dart';
import 'package:sportcut/src/features/highlights/presentation/highlight_ranking_providers.dart';
import 'package:sportcut/src/features/highlights/presentation/reel_panel.dart';
import 'package:sportcut/src/features/library/domain/match_record.dart';
import 'package:sportcut/src/features/library/presentation/library_providers.dart';
import 'package:sportcut/src/features/rally/presentation/rally_review_providers.dart';
import 'package:sportcut/src/features/score/presentation/rally_panel.dart';
import 'package:sportcut/src/features/score/presentation/serving_sides_providers.dart';
import 'package:sportcut/src/features/tracking/presentation/player_tracking_providers.dart';
import 'package:sportcut/src/features/tracking/presentation/tracking_panel.dart';
import 'package:sportcut/src/features/workspace/domain/workspace.dart';
import 'package:sportcut/src/features/workspace/presentation/home/workspace_row.dart';
import 'package:sportcut/src/features/workspace/presentation/studio/inspector_pane.dart';
import 'package:sportcut/src/features/workspace/presentation/studio/stage_strip.dart';
import 'package:sportcut/src/features/workspace/presentation/studio/studio_shell.dart';
import 'package:sportcut/src/features/workspace/presentation/studio/studio_status_bar.dart';
import 'package:sportcut/src/features/workspace/presentation/studio/studio_toolbar.dart';
import 'package:sportcut/src/features/workspace/presentation/studio/timeline_dock.dart';
import 'package:sportcut/src/features/workspace/presentation/studio/video_rail.dart';
import 'package:sportcut/src/features/workspace/presentation/workspace_screen.dart';
import 'package:sportcut/src/features/workspace/presentation/workspace_studio_screen.dart';

import '../support/fake_match_editing.dart';
import '../support/fake_match_library.dart';
import '../support/fakes.dart';
import '../support/screenshot_fixtures.dart';
import '../support/screenshot_harness.dart';

/// Rally review stub: loaded, with no engine-backed suggestions.
class _LocalRallyReviewController extends RallyReviewController {
  @override
  RallyReviewState build() => const RallyReviewState(loaded: true);

  @override
  Future<void> open(MatchRecord match) async {
    state = RallyReviewState(match: match, loaded: true);
  }
}

/// Tracking stub: loaded with no tracks and no engine read.
class _LocalPlayerTrackingController extends PlayerTrackingController {
  @override
  PlayerTrackingState build() => const PlayerTrackingState(loaded: true);

  @override
  Future<void> open(MatchRecord match) async {
    state = const PlayerTrackingState(loaded: true);
  }

  @override
  Future<void> loadWindow(MatchRecord match, double positionSeconds) async {}
}

/// One seeded studio: a real temp directory plus the doubles it reads.
typedef _StudioFixture = ({
  Directory directory,
  FakeMatchLibrary library,
  FakeMatchEditing editing,
  FakeMediaEngine engine,
});

/// The empty workspace fixture: one workspace, no videos.
({Directory directory, FakeMatchLibrary library}) _emptyWorkspaceFixture() {
  final directory = Directory.systemTemp.createTempSync('sportcut-studio-');
  final library = screenshotLibrary(
    workspaces: <Workspace>[
      screenshotWorkspace(id: 'ws-empty', title: 'Empty studio'),
    ],
  );
  return (directory: directory, library: library);
}

/// The fresh fixture: recordings exist, every pipeline output is absent.
_StudioFixture _freshFixture() {
  final directory = Directory.systemTemp.createTempSync('sportcut-studio-');
  final first = writeRecordingPlaceholder(
    directory: directory,
    fileName: 'match-1.mp4',
  );
  final second = writeRecordingPlaceholder(
    directory: directory,
    fileName: 'match-2.mp4',
    bytes: 2048,
  );
  final library = screenshotLibrary(
    workspaces: <Workspace>[screenshotWorkspace()],
    matches: <MatchRecord>[
      screenshotMatch(
        id: 'match-1',
        title: 'Club final',
        workspaceId: 'ws-1',
        videoPath: first.path,
        durationSeconds: 90,
        matchDir: p.join(directory.path, 'matches', 'match-1'),
      ),
      screenshotMatch(
        id: 'match-2',
        title: 'Semifinal',
        workspaceId: 'ws-1',
        videoPath: second.path,
        durationSeconds: 62,
        matchDir: p.join(directory.path, 'matches', 'match-2'),
      ),
    ],
  );
  return (
    directory: directory,
    library: library,
    editing: screenshotEditing(),
    engine: screenshotEngine(durationSeconds: 90),
  );
}

/// The complete fixture: a calibrated match with tracks, a score, and clips.
_StudioFixture _completeFixture() {
  final directory = Directory.systemTemp.createTempSync('sportcut-studio-');
  final first = writeRecordingPlaceholder(
    directory: directory,
    fileName: 'match-1.mp4',
  );
  final second = writeRecordingPlaceholder(
    directory: directory,
    fileName: 'match-2.mp4',
    bytes: 2048,
  );
  final artifacts = screenshotArtifacts(includeTracks: true, includeExport: true);
  final library = screenshotLibrary(
    workspaces: <Workspace>[screenshotWorkspace()],
    matches: <MatchRecord>[
      screenshotMatch(
        id: 'match-1',
        title: 'Club final',
        workspaceId: 'ws-1',
        videoPath: first.path,
        durationSeconds: 90,
        matchDir: p.join(directory.path, 'matches', 'match-1'),
        courtCalibration: screenshotCourtCalibration(),
      ),
      screenshotMatch(
        id: 'match-2',
        title: 'Semifinal',
        workspaceId: 'ws-1',
        videoPath: second.path,
        durationSeconds: 62,
        matchDir: p.join(directory.path, 'matches', 'match-2'),
      ),
    ],
    manifestArtifacts: <String, List<ArtifactDto>>{'match-1': artifacts},
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
      screenshotRally(id: 'rally-3', startSeconds: 40, endSeconds: 52),
    ],
    clips: <HighlightClip>[
      screenshotClip(
        id: 'clip-rally-1',
        rallyId: 'rally-1',
        startSeconds: 8,
        endSeconds: 16,
        orderIndex: 0,
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
  return (
    directory: directory,
    library: library,
    editing: editing,
    engine: screenshotEngine(artifacts: artifacts, durationSeconds: 90),
  );
}

/// Remove a fixture's temporary recordings after the test.
void _disposeFixture(Directory directory) {
  addTearDown(() {
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });
}

/// The overrides every video-bearing studio needs.
List<Override> _studioOverrides(_StudioFixture fixture) => <Override>[
      matchRepositoryProvider.overrideWith((ref) async => fixture.library),
      matchEditingProvider.overrideWith((ref) async => fixture.editing),
      playbackControllerFactoryProvider
          .overrideWithValue(FakePlaybackController.new),
      mediaEngineProvider.overrideWithValue(fixture.engine),
      rallyReviewControllerProvider
          .overrideWith(_LocalRallyReviewController.new),
      playerTrackingControllerProvider
          .overrideWith(_LocalPlayerTrackingController.new),
      servingSidesProvider.overrideWith(
        (ref) async => const <String, RallySideDto>{},
      ),
      highlightRankingProvider.overrideWith(
        (ref) async => const <String, HighlightRankDto>{},
      ),
      videoFilePickerProvider.overrideWithValue(FakeVideoFilePicker()),
    ];

/// Pump the real app on its initial workspace route.
Future<GlobalKey> _pumpHome(
  WidgetTester tester,
  List<Override> overrides,
) async {
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
  return key;
}

/// Open a workspace through the home row, the same path a user takes.
Future<void> _openWorkspace(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

/// Tap a stage tab, scoped to the strip because labels repeat elsewhere.
Future<void> _tapStage(WidgetTester tester, String label) async {
  final Finder tab = find.descendant(
    of: find.byType(StageStrip),
    matching: find.text(label),
  );
  expect(tab, findsOneWidget);
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

/// Capture [name] and prove the PNG reached the output directory.
Future<void> _capture(
  WidgetTester tester,
  GlobalKey key,
  String name,
) async {
  final File file = await captureScreenshot(tester, key, name);
  expect(file.existsSync(), isTrue, reason: 'missing $name.png');
  expect(file.lengthSync(), greaterThan(0), reason: 'empty $name.png');
}

void main() {
  setUpAll(loadScreenshotFonts);

  testWidgets('workspace_home_empty shows the first-run home', (tester) async {
    useWidgetScreenshotView(tester);
    final FakeMatchLibrary library = FakeMatchLibrary();
    final GlobalKey key = await _pumpHome(
      tester,
      <Override>[
        matchRepositoryProvider.overrideWith((ref) async => library),
      ],
    );

    expect(find.byType(WorkspaceScreen), findsOneWidget);
    expect(find.byType(ScEmptyState), findsOneWidget);
    expect(find.byType(WorkspaceRow), findsNothing);
    expect(find.text('No workspaces yet.'), findsOneWidget);
    expect(find.text('New workspace'), findsNWidgets(2));
    expect(find.text('0 workspaces · 0 videos'), findsOneWidget);
    expect(find.text('On-device · No cloud'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);

    await _capture(tester, key, 'workspace_home_empty');
  });

  testWidgets('workspace_home_populated shows the workspace row and counts',
      (tester) async {
    useWidgetScreenshotView(tester);
    final _StudioFixture fixture = _freshFixture();
    _disposeFixture(fixture.directory);
    final GlobalKey key = await _pumpHome(
      tester,
      <Override>[
        matchRepositoryProvider.overrideWith((ref) async => fixture.library),
      ],
    );

    expect(find.byType(WorkspaceScreen), findsOneWidget);
    expect(find.byType(WorkspaceRow), findsOneWidget);
    expect(find.text('WORKSPACES'), findsOneWidget);
    expect(find.text('Thursday club night'), findsOneWidget);
    expect(find.textContaining('2 videos'), findsWidgets);
    expect(find.text('1 workspace · 2 videos'), findsOneWidget);
    expect(find.text('New workspace'), findsOneWidget);
    expect(find.text('Import video'), findsOneWidget);
    expect(find.text('On-device · No cloud'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _capture(tester, key, 'workspace_home_populated');
  });

  testWidgets('studio_empty shows the empty preview and rail', (tester) async {
    useWidgetScreenshotView(tester);
    final ({Directory directory, FakeMatchLibrary library}) fixture =
        _emptyWorkspaceFixture();
    _disposeFixture(fixture.directory);
    final GlobalKey key = await _pumpHome(
      tester,
      <Override>[
        matchRepositoryProvider.overrideWith((ref) async => fixture.library),
      ],
    );
    await _openWorkspace(tester, 'Empty studio');

    expect(find.byType(WorkspaceStudioScreen), findsOneWidget);
    expect(find.text('Select a video to preview.'), findsOneWidget);
    expect(find.text('No videos in this workspace.'), findsOneWidget);
    expect(find.text('Import video'), findsNWidgets(2));
    expect(find.text('Loading timeline…'), findsOneWidget);
    expect(find.textContaining('0 videos'), findsWidgets);
    expect(find.text('0 missing'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(StageStrip), matching: find.text('READY')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(StageStrip),
        matching: find.text('BLOCKED'),
      ),
      findsNothing,
    );
    expect(find.byKey(const Key('fake-playback-surface')), findsNothing);
    expect(tester.takeException(), isNull);

    await _capture(tester, key, 'studio_empty');
  });

  testWidgets('studio_play shows the shared preview and blocked pipeline',
      (tester) async {
    useWidgetScreenshotView(tester);
    final _StudioFixture fixture = _freshFixture();
    _disposeFixture(fixture.directory);
    final GlobalKey key = await _pumpHome(tester, _studioOverrides(fixture));
    await _openWorkspace(tester, 'Thursday club night');

    expect(find.byType(StudioShell), findsOneWidget);
    expect(find.byType(StudioToolbar), findsOneWidget);
    expect(find.byType(StageStrip), findsOneWidget);
    expect(find.byType(VideoRail), findsOneWidget);
    expect(find.byType(InspectorPane), findsOneWidget);
    expect(find.byType(TimelineDock), findsOneWidget);
    expect(find.byType(StudioStatusBar), findsOneWidget);
    expect(find.byKey(const Key('fake-playback-surface')), findsOneWidget);
    expect(find.text('Workspace / Thursday club night'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(StageStrip), matching: find.text('READY')),
      findsNWidgets(2),
    );
    expect(
      find.descendant(
        of: find.byType(StageStrip),
        matching: find.text('BLOCKED'),
      ),
      findsNWidgets(5),
    );
    expect(find.text('No rallies in this window.'), findsOneWidget);
    expect(find.text('Needs a clip'), findsOneWidget);
    expect(find.text('· Play'), findsOneWidget);
    expect(find.text('PLAYBACK'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _capture(tester, key, 'studio_play');
  });

  testWidgets('studio_calibration shows the marked court panel', (tester) async {
    useWidgetScreenshotView(tester);
    final _StudioFixture fixture = _freshFixture();
    _disposeFixture(fixture.directory);
    final GlobalKey key = await _pumpHome(tester, _studioOverrides(fixture));
    await _openWorkspace(tester, 'Thursday club night');
    await _tapStage(tester, 'Mark court');

    expect(find.byType(CalibrationPanel), findsOneWidget);
    expect(find.text('MARK COURT'), findsOneWidget);
    expect(find.text('COURT'), findsOneWidget);
    expect(find.text('Which way does the court run?'), findsOneWidget);
    expect(find.text('4 of 4'), findsOneWidget);
    expect(find.text('Save court'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('· Court'), findsOneWidget);
    expect(find.text('Clip'), findsNothing);
    expect(tester.takeException(), isNull);

    await _capture(tester, key, 'studio_calibration');
  });

  testWidgets('studio_analysis shows the ready artifact panel', (tester) async {
    useWidgetScreenshotView(tester);
    final _StudioFixture fixture = _freshFixture();
    _disposeFixture(fixture.directory);
    final GlobalKey key = await _pumpHome(tester, _studioOverrides(fixture));
    await _openWorkspace(tester, 'Thursday club night');
    await _tapStage(tester, 'Prepare analysis');

    expect(find.byType(AnalysisPanel), findsOneWidget);
    expect(find.text('ANALYSIS FILES'), findsOneWidget);
    expect(find.text('ARTIFACTS'), findsOneWidget);
    expect(find.text('Nothing to rebuild'), findsOneWidget);
    expect(find.text('Review player analysis'), findsOneWidget);
    expect(find.text('PREPARE ANALYSIS'), findsOneWidget);
    expect(find.text('· Analysis'), findsOneWidget);
    expect(
      find.textContaining('Preparing makes a smaller proxy video'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await _capture(tester, key, 'studio_analysis');
  });

  testWidgets('studio_tracking shows the player-analysis prerequisite',
      (tester) async {
    useWidgetScreenshotView(tester);
    final _StudioFixture fixture = _freshFixture();
    _disposeFixture(fixture.directory);
    final GlobalKey key = await _pumpHome(tester, _studioOverrides(fixture));
    await _openWorkspace(tester, 'Thursday club night');
    await _tapStage(tester, 'Player analysis');

    expect(find.byType(TrackingPanel), findsOneWidget);
    expect(
      find.text('Player analysis needs the court marked first.'),
      findsOneWidget,
    );
    expect(find.text('Mark court'), findsWidgets);
    expect(find.text('Analyze players'), findsOneWidget);
    expect(find.text('Review rallies manually'), findsOneWidget);
    expect(
      find.textContaining('No player tracks detected'),
      findsOneWidget,
    );
    expect(find.text('PLAYER ANALYSIS'), findsOneWidget);
    expect(find.text('· Tracking'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _capture(tester, key, 'studio_tracking');
  });

  testWidgets('studio_score shows the scored rally panel', (tester) async {
    useWidgetScreenshotView(tester);
    final _StudioFixture fixture = _completeFixture();
    _disposeFixture(fixture.directory);
    final GlobalKey key = await _pumpHome(tester, _studioOverrides(fixture));
    await _openWorkspace(tester, 'Thursday club night');
    await _tapStage(tester, 'Review & score');

    expect(find.byType(RallyPanel), findsOneWidget);
    expect(find.byType(ScScoreBug), findsOneWidget);
    expect(find.text('Rally'), findsOneWidget);
    expect(find.text('Clip'), findsOneWidget);
    expect(find.text('L · LEFT'), findsOneWidget);
    expect(find.text('R · RIGHT'), findsOneWidget);
    expect(find.text('MANUAL MARKING'), findsOneWidget);
    expect(find.text('LAST RALLIES'), findsOneWidget);
    expect(find.text('RALLY SUGGESTIONS'), findsOneWidget);
    expect(find.text('Manual marking is available.'), findsOneWidget);
    expect(find.text('Analyze rallies'), findsOneWidget);
    expect(find.textContaining('Point 1'), findsOneWidget);
    expect(find.text('· Score'), findsOneWidget);
    expect(find.text('REVIEW & SCORE'), findsOneWidget);
    // The reel is reachable below the Rally tab and keeps both clips.
    expect(find.byType(ReelPanel), findsOneWidget);
    expect(find.text('2 kept · 0 dismissed'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _capture(tester, key, 'studio_score');
  });

  testWidgets('studio_score_clip shows the clip inspector for a kept rally',
      (tester) async {
    useWidgetScreenshotView(tester);
    final _StudioFixture fixture = _completeFixture();
    _disposeFixture(fixture.directory);
    final GlobalKey key = await _pumpHome(tester, _studioOverrides(fixture));
    await _openWorkspace(tester, 'Thursday club night');
    await _tapStage(tester, 'Review & score');

    // The reel row selects the rally and switches the inspector to Clip.
    await tester.ensureVisible(find.text('Rally 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rally 1'));
    await tester.pumpAndSettle();

    expect(find.byType(ClipInspectorPanel), findsOneWidget);
    expect(find.text('Clip'), findsOneWidget);
    expect(find.text('Rally 1'), findsWidgets);
    expect(find.text('Winner'), findsOneWidget);
    expect(find.text('Score after'), findsOneWidget);
    expect(find.text('Type'), findsOneWidget);
    expect(find.text('Suggested rank'), findsOneWidget);
    expect(find.text('Not ranked'), findsOneWidget);
    expect(find.text('Keep as highlight'), findsOneWidget);
    expect(find.text('Trim clip'), findsOneWidget);
    expect(find.text('2 kept · 0 dismissed'), findsOneWidget);
    expect(find.textContaining('2 clips'), findsWidgets);
    expect(tester.takeException(), isNull);

    await _capture(tester, key, 'studio_score_clip');
  });

  testWidgets('studio_highlights shows the reel and left-out rail',
      (tester) async {
    useWidgetScreenshotView(tester);
    final _StudioFixture fixture = _completeFixture();
    _disposeFixture(fixture.directory);
    final GlobalKey key = await _pumpHome(tester, _studioOverrides(fixture));
    await _openWorkspace(tester, 'Thursday club night');
    await _tapStage(tester, 'Highlights');

    expect(find.byType(ReelPanel), findsOneWidget);
    expect(find.text('HIGHLIGHTS'), findsOneWidget);
    expect(find.text('Highlights'), findsOneWidget);
    expect(find.text('Rally 1'), findsWidgets);
    expect(find.text('Rally 2'), findsWidgets);
    expect(find.text('LEFT OUT'), findsOneWidget);
    expect(find.text('Keep top 10'), findsOneWidget);
    expect(find.text('2 kept · 0 dismissed'), findsOneWidget);
    expect(find.textContaining('2 clips'), findsWidgets);
    expect(find.text('· Clips'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _capture(tester, key, 'studio_highlights');
  });

  testWidgets('studio_export captures the sheet at the reference window',
      (tester) async {
    useWidgetScreenshotView(tester);
    final _StudioFixture fixture = _completeFixture();
    _disposeFixture(fixture.directory);
    final GlobalKey key = await _pumpHome(tester, _studioOverrides(fixture));
    await _openWorkspace(tester, 'Thursday club night');
    await _tapStage(tester, 'Export');

    expect(find.byType(ExportSheet), findsOneWidget);
    expect(find.byType(ScDialog), findsOneWidget);
    expect(find.text('Export highlight reel'), findsOneWidget);
    expect(find.text('Export reel'), findsOneWidget);
    expect(find.text('Title card'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Choose music'), findsOneWidget);
    expect(find.text('Music volume'), findsOneWidget);
    expect(find.text('Lead-in'), findsOneWidget);
    expect(find.text('Lead-out'), findsOneWidget);
    expect(find.text('Include score overlays'), findsOneWidget);
    expect(find.text('Remove rest periods'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.textContaining('2 clips'), findsWidgets);
    expect(find.text('Scoreboard through 1–1.'), findsOneWidget);
    expect(find.text('No music; match audio only.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // The settings form is taller than the sheet's scrolling body at the
    // 1180x760 reference window, so this capture records the real layout with
    // the primary action below the fold.
    await _capture(tester, key, 'studio_export');

    // Scrolling the sheet reaches the action: it is folded, not lost.
    await tester.ensureVisible(find.text('Export reel'));
    await tester.pumpAndSettle();
    expect(find.text('Export reel').hitTestable(), findsOneWidget);
    await _capture(tester, key, 'studio_export_scrolled');
  });

  testWidgets('studio_export_full shows the whole export form', (tester) async {
    // A taller window lets the sheet size its own body to the form, so the
    // full settings form and the primary action fit in one capture.
    useWidgetScreenshotView(
      tester,
      logicalSize: Size(kScreenshotLogicalSize.width, 1000),
    );
    final _StudioFixture fixture = _completeFixture();
    _disposeFixture(fixture.directory);
    final GlobalKey key = await _pumpHome(tester, _studioOverrides(fixture));
    await _openWorkspace(tester, 'Thursday club night');
    await _tapStage(tester, 'Export');

    expect(find.byType(ExportSheet), findsOneWidget);
    expect(find.byType(ScDialog), findsOneWidget);
    expect(find.text('Export highlight reel'), findsOneWidget);
    expect(find.text('Export reel'), findsOneWidget);
    expect(find.text('Title card'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Choose music'), findsOneWidget);
    expect(find.text('Music volume'), findsOneWidget);
    expect(find.text('Lead-in'), findsOneWidget);
    expect(find.text('Lead-out'), findsOneWidget);
    expect(find.text('Include score overlays'), findsOneWidget);
    expect(find.text('Remove rest periods'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.textContaining('2 clips'), findsWidgets);
    expect(find.text('Scoreboard through 1–1.'), findsOneWidget);
    expect(find.text('No music; match audio only.'), findsOneWidget);
    // The primary action must be visible, not merely present in the tree.
    expect(find.text('Export reel').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _capture(tester, key, 'studio_export_full');
  });
}
