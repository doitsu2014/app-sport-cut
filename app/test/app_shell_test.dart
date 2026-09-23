/// Shell-level tests: the route table, the theme, and the home screen.
///
/// The shell is pumped with an in-memory library, so these tests do not touch
/// SQLite, the file system, the platform video player, or the native engine.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sportcut/src/app/app.dart';
import 'package:sportcut/src/app/router.dart';
import 'package:sportcut/src/app/theme.dart';
import 'package:sportcut/src/features/library/domain/match_record.dart';
import 'package:sportcut/src/features/library/presentation/library_providers.dart';

import 'support/fake_match_library.dart';
import 'support/fakes.dart';

void main() {
  final match = MatchRecord(
    id: 'match-1',
    title: 'Test match',
    videoPath: '/tmp/match.mp4',
    durationSeconds: 60,
    createdAt: DateTime(2026, 1, 1),
    matchDir: '/tmp/matches/match-1',
  );

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchRepositoryProvider
              .overrideWith((ref) async => FakeMatchLibrary()),
          videoFilePickerProvider.overrideWithValue(FakeVideoFilePicker()),
          playbackControllerFactoryProvider
              .overrideWithValue(FakePlaybackController.new),
        ],
        child: const SportcutApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the shell opens on the library route', (tester) async {
    await pumpShell(tester);

    expect(find.text('Sportcut'), findsOneWidget);
    expect(find.text('No matches yet'), findsOneWidget);
  });

  testWidgets('every route in the table builds a screen', (tester) async {
    await pumpShell(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    for (final route in <String>[
      AppRoutes.player,
      AppRoutes.calibration,
      AppRoutes.analysis,
      AppRoutes.score,
      AppRoutes.highlights,
      AppRoutes.export,
    ]) {
      navigator.pushNamed(route, arguments: match);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'route $route threw');

      navigator.pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('an unknown route is reported as not found', (tester) async {
    expect(
      AppRouter.onGenerateRoute(const RouteSettings(name: '/nope')),
      isNull,
    );
  });

  test('routes that need a match reject a missing argument', () {
    expect(
      () => AppRouter.matchFrom(const RouteSettings(name: AppRoutes.player)),
      throwsArgumentError,
    );
  });

  testWidgets('the theme is Material 3 in both brightnesses', (tester) async {
    for (final brightness in Brightness.values) {
      final theme = buildSportcutTheme(brightness);
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.brightness, brightness);
    }
  });
}
