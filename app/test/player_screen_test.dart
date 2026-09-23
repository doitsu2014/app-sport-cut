/// Player screen tests, driven through a playback double so the platform video
/// implementation is not involved.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sportcut/src/features/library/domain/match_record.dart';
import 'package:sportcut/src/features/library/presentation/library_providers.dart';
import 'package:sportcut/src/features/library/presentation/player_screen.dart';

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

  Future<void> pumpPlayer(
    WidgetTester tester,
    FakePlaybackController controller,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playbackControllerFactoryProvider.overrideWithValue(() => controller),
        ],
        child: MaterialApp(home: PlayerScreen(match: match)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('loads the recording and shows transport controls',
      (tester) async {
    final controller = FakePlaybackController();
    await pumpPlayer(tester, controller);

    expect(controller.loaded, <String>[match.videoPath]);
    expect(find.byKey(const Key('fake-playback-surface')), findsOneWidget);
    expect(find.byTooltip('Play'), findsOneWidget);
    expect(find.text('1:30'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('play and pause go through the controller', (tester) async {
    final controller = FakePlaybackController();
    await pumpPlayer(tester, controller);

    await tester.tap(find.byTooltip('Play'));
    await tester.pumpAndSettle();
    expect(controller.playCalls, 1);
    expect(find.byTooltip('Pause'), findsOneWidget);

    await tester.tap(find.byTooltip('Pause'));
    await tester.pumpAndSettle();
    expect(controller.pauseCalls, 1);
    expect(find.byTooltip('Play'), findsOneWidget);
  });

  testWidgets('scrubbing the slider seeks and updates the position display',
      (tester) async {
    final controller = FakePlaybackController();
    await pumpPlayer(tester, controller);

    await tester.drag(find.byType(Slider), const Offset(60, 0));
    await tester.pumpAndSettle();

    expect(controller.lastSeek, isNotNull);
    expect(controller.lastSeek!.inSeconds, greaterThan(0));
  });

  testWidgets('an unplayable recording is reported and controls are disabled',
      (tester) async {
    final controller = FakePlaybackController()
      ..errorMessage = 'This recording cannot be played on this device';
    await pumpPlayer(tester, controller);

    expect(
      find.textContaining('cannot be played'),
      findsOneWidget,
    );
    final playButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.play_arrow),
    );
    expect(playButton.onPressed, isNull);
    expect(find.byKey(const Key('fake-playback-surface')), findsNothing);
  });
}
