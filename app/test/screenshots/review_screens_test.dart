/// Screenshots for the three review routes: score, highlights, and export.
///
/// Every test pumps the real [SportcutApp] at the studio reference size and
/// pushes the route through [AppRouter], so the chrome, theme, and navigation
/// are the ones the app ships. The overrides below keep the screens off the
/// SQLite catalog, the Unix-socket engine, and the platform plugins the widget
/// test cannot run.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:sportcut/src/app/app.dart';
import 'package:sportcut/src/app/design/components/sc_actions.dart';
import 'package:sportcut/src/app/design/components/sc_scoreboard.dart';
import 'package:sportcut/src/app/router.dart';
import 'package:sportcut/src/features/editing/domain/export_settings.dart';
import 'package:sportcut/src/features/editing/domain/highlight_clip.dart';
import 'package:sportcut/src/features/editing/domain/rally.dart';
import 'package:sportcut/src/features/editing/presentation/editing_providers.dart';
import 'package:sportcut/src/features/export/presentation/export_providers.dart';
import 'package:sportcut/src/features/highlights/presentation/highlight_ranking_providers.dart';
import 'package:sportcut/src/features/library/domain/match_record.dart';
import 'package:sportcut/src/features/library/presentation/library_providers.dart';
import 'package:sportcut/src/features/rally/presentation/rally_review_providers.dart';
import 'package:sportcut/src/features/score/presentation/serving_sides_providers.dart';

import '../support/fakes.dart';
import '../support/fake_match_editing.dart';
import '../support/fake_overlay_renderer.dart';
import '../support/screenshot_fixtures.dart';
import '../support/screenshot_harness.dart';

/// Review stub: the panel stays on manual marking, with no engine read.
class _StubRallyReview extends RallyReviewController {
  @override
  RallyReviewState build() => const RallyReviewState(loaded: true);

  @override
  Future<void> open(MatchRecord match) async {}

  @override
  Future<void> analyze() async {}

  @override
  Future<void> cancel() async {}
}

/// The match every route below reviews.
MatchRecord _match() => screenshotMatch(
      id: 'match-1',
      title: 'Club final',
      videoPath: '/tmp/club-final.mp4',
      matchDir: '/tmp/matches/match-1',
    );

/// Pump the real app, then push [route] with [match] as its argument.
Future<GlobalKey> _pumpRoute(
  WidgetTester tester, {
  required List<Override> overrides,
  required String route,
  required MatchRecord match,
}) async {
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

/// A library + editing pair so the home route behind the push never opens
/// SQLite and the pushed route reads the same in-memory records.
List<Override> _editingOverrides({
  required MatchRecord match,
  required FakeMatchEditing editing,
}) =>
    <Override>[
      matchRepositoryProvider.overrideWith(
        (ref) async => screenshotLibrary(matches: <MatchRecord>[match]),
      ),
      matchEditingProvider.overrideWith((ref) async => editing),
    ];

void main() {
  setUpAll(loadScreenshotFonts);

  testWidgets('score route with confirmed rallies', (WidgetTester tester) async {
    useWidgetScreenshotView(tester);
    final match = _match();
    final playback = FakePlaybackController();
    final editing = screenshotEditing(
      rallies: <Rally>[
        screenshotRally(
          id: 'rally-1',
          startSeconds: 10,
          endSeconds: 20,
          winnerSide: WinnerSide.left,
        ),
        screenshotRally(id: 'rally-2', startSeconds: 30, endSeconds: 44),
        screenshotRally(id: 'rally-3', startSeconds: 55, endSeconds: 70),
      ],
    );

    final key = await _pumpRoute(
      tester,
      route: AppRoutes.score,
      match: match,
      overrides: <Override>[
        ..._editingOverrides(match: match, editing: editing),
        playbackControllerFactoryProvider.overrideWithValue(() => playback),
        servingSidesProvider.overrideWith(
          (ref) async => screenshotServingSides(),
        ),
        rallyReviewControllerProvider.overrideWith(_StubRallyReview.new),
      ],
    );

    expect(find.text('Club final'), findsOneWidget);
    expect(find.byType(ScScoreboard), findsOneWidget);
    final scoreboard = tester.widget<ScScoreboard>(find.byType(ScScoreboard));
    expect(scoreboard.leftScore, 1);
    expect(scoreboard.rightScore, 0);
    expect(find.text('Confirmed · 1–0'), findsOneWidget);
    expect(find.text('Point 1 · 0:10–0:20'), findsOneWidget);
    expect(find.text('L won'), findsOneWidget);
    expect(find.text('R won'), findsOneWidget);
    expect(playback.loaded, <String>['/tmp/club-final.mp4']);

    await captureScreenshot(tester, key, 'score_populated');
  });

  testWidgets('highlights route with a populated reel', (WidgetTester tester) async {
    useWidgetScreenshotView(tester);
    final match = _match();
    final editing = screenshotEditing(
      rallies: <Rally>[
        screenshotRally(
          id: 'rally-1',
          startSeconds: 10,
          endSeconds: 20,
          winnerSide: WinnerSide.left,
        ),
        screenshotRally(
          id: 'rally-2',
          startSeconds: 30,
          endSeconds: 44,
          winnerSide: WinnerSide.right,
        ),
        screenshotRally(id: 'rally-3', startSeconds: 55, endSeconds: 70),
      ],
      clips: <HighlightClip>[
        screenshotClip(
          id: 'clip-rally-1',
          rallyId: 'rally-1',
          startSeconds: 10,
          endSeconds: 20,
        ),
        screenshotClip(
          id: 'clip-rally-2',
          rallyId: 'rally-2',
          startSeconds: 30,
          endSeconds: 44,
          orderIndex: 1,
          trimStartSeconds: 32,
        ),
      ],
    );

    final key = await _pumpRoute(
      tester,
      route: AppRoutes.highlights,
      match: match,
      overrides: <Override>[
        ..._editingOverrides(match: match, editing: editing),
        highlightRankingProvider.overrideWith(
          (ref) async => screenshotHighlightRanking(),
        ),
      ],
    );

    expect(find.text('Highlights'), findsOneWidget);
    expect(find.text('2 clips · 0:22'), findsOneWidget);
    expect(find.text('2 kept · 0 dismissed'), findsOneWidget);
    expect(find.text('Rally 1'), findsOneWidget);
    expect(find.text('Rally 2'), findsOneWidget);
    expect(find.text('0:10 – 0:20'), findsOneWidget);
    expect(find.text('0:32 – 0:44'), findsOneWidget);
    expect(find.text('LEFT OUT'), findsOneWidget);

    await captureScreenshot(tester, key, 'highlights_populated');
  });

  testWidgets('highlights route with a selected clip', (WidgetTester tester) async {
    useWidgetScreenshotView(tester);
    final match = _match();
    final editing = screenshotEditing(
      rallies: <Rally>[
        screenshotRally(
          id: 'rally-1',
          startSeconds: 10,
          endSeconds: 20,
          winnerSide: WinnerSide.left,
        ),
        screenshotRally(
          id: 'rally-2',
          startSeconds: 30,
          endSeconds: 44,
          winnerSide: WinnerSide.right,
        ),
        screenshotRally(id: 'rally-3', startSeconds: 55, endSeconds: 70),
      ],
      clips: <HighlightClip>[
        screenshotClip(
          id: 'clip-rally-1',
          rallyId: 'rally-1',
          startSeconds: 10,
          endSeconds: 20,
        ),
      ],
    );

    final key = await _pumpRoute(
      tester,
      route: AppRoutes.highlights,
      match: match,
      overrides: <Override>[
        ..._editingOverrides(match: match, editing: editing),
        highlightRankingProvider.overrideWith(
          (ref) async => screenshotHighlightRanking(),
        ),
      ],
    );

    await tester.ensureVisible(find.text('Rally 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rally 1'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Suggested rank'));
    await tester.pumpAndSettle();

    expect(find.text('Winner'), findsOneWidget);
    expect(find.text('Score after'), findsOneWidget);
    expect(find.text('Suggested rank'), findsOneWidget);
    expect(find.text('Full rally'), findsOneWidget);
    expect(find.text('Left won'), findsOneWidget);
    expect(find.text('Trim clip'), findsOneWidget);

    await captureScreenshot(tester, key, 'highlights_selected');
  });

  testWidgets('export route with a ready reel', (WidgetTester tester) async {
    useWidgetScreenshotView(tester);
    final match = _match();
    final editing = screenshotEditing(
      rallies: <Rally>[
        screenshotRally(
          id: 'rally-1',
          startSeconds: 10,
          endSeconds: 20,
          winnerSide: WinnerSide.left,
        ),
      ],
      clips: <HighlightClip>[
        screenshotClip(
          id: 'clip-rally-1',
          rallyId: 'rally-1',
          startSeconds: 10,
          endSeconds: 20,
        ),
      ],
      settings: const ExportSettings(matchId: 'match-1', title: 'Club final'),
    );

    final key = await _pumpRoute(
      tester,
      route: AppRoutes.export,
      match: match,
      overrides: <Override>[
        ..._editingOverrides(match: match, editing: editing),
        mediaEngineProvider.overrideWithValue(
          screenshotEngine(artifacts: screenshotArtifacts(includeExport: true)),
        ),
        audioFilePickerProvider.overrideWithValue(FakeAudioFilePicker()),
        overlayRendererProvider.overrideWithValue(FakeOverlayRenderer()),
      ],
    );

    expect(find.text('Export Club final'), findsOneWidget);
    expect(find.text('1 clips · 0:15 · —'), findsOneWidget);
    expect(find.text('Scoreboard through 1–0.'), findsOneWidget);
    expect(find.text('No music; match audio only.'), findsOneWidget);
    expect(find.text('Club final'), findsOneWidget);
    final render = tester.widget<ScButton>(
      find.widgetWithText(ScButton, 'Export reel'),
    );
    expect(render.enabled, isTrue);

    await captureScreenshot(tester, key, 'export_settings');
  });

  testWidgets('export route with score overlays turned off',
      (WidgetTester tester) async {
    useWidgetScreenshotView(tester);
    final match = _match();
    final editing = screenshotEditing(
      rallies: <Rally>[
        screenshotRally(
          id: 'rally-1',
          startSeconds: 10,
          endSeconds: 20,
          winnerSide: WinnerSide.left,
        ),
      ],
      clips: <HighlightClip>[
        screenshotClip(
          id: 'clip-rally-1',
          rallyId: 'rally-1',
          startSeconds: 10,
          endSeconds: 20,
        ),
      ],
      settings: const ExportSettings(matchId: 'match-1', title: 'Club final'),
    );

    final key = await _pumpRoute(
      tester,
      route: AppRoutes.export,
      match: match,
      overrides: <Override>[
        ..._editingOverrides(match: match, editing: editing),
        mediaEngineProvider.overrideWithValue(
          screenshotEngine(artifacts: screenshotArtifacts(includeExport: true)),
        ),
        audioFilePickerProvider.overrideWithValue(FakeAudioFilePicker()),
        overlayRendererProvider.overrideWithValue(FakeOverlayRenderer()),
      ],
    );

    await tester.ensureVisible(find.text('Include score overlays'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Include score overlays'));
    await tester.pumpAndSettle();

    expect(find.text('Score overlays are off for this export.'), findsOneWidget);
    expect(find.text('Export reel'), findsOneWidget);

    await captureScreenshot(tester, key, 'export_overlays_off');
  });
}
