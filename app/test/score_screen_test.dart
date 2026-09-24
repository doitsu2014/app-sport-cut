/// Score timeline screen tests: marking a point, saying who won it, and the
/// score following.
///
/// The screen is driven with in-memory doubles — an editing session that keeps
/// its rallies in a list, and a playback controller that reports a position —
/// so nothing here needs the database, the platform player, or a device.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sportcut/src/features/editing/domain/rally.dart';
import 'package:sportcut/src/features/editing/presentation/editing_providers.dart';
import 'package:sportcut/src/features/library/domain/match_record.dart';
import 'package:sportcut/src/features/score/presentation/score_screen.dart';

import 'support/fake_match_editing.dart';
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

  Future<void> pumpScore(
    WidgetTester tester, {
    required FakeMatchEditing editing,
    FakePlaybackController? playback,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchEditingProvider.overrideWith((ref) async => editing),
        ],
        child: MaterialApp(
          home: ScoreScreen(
            match: match,
            controller: playback ?? FakePlaybackController(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a span the user marks becomes a rally on the timeline',
      (tester) async {
    final editing = FakeMatchEditing();
    final playback = FakePlaybackController();
    await pumpScore(tester, editing: editing, playback: playback);
    expect(find.textContaining('No rallies yet'), findsOneWidget);

    await tester.tap(find.text('Mark start'));
    await tester.pumpAndSettle();
    expect(find.text('Start at 0:00'), findsOneWidget);

    // Move the playhead to where the point ended, then close the span.
    await playback.seek(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark end'));
    await tester.pumpAndSettle();

    expect(editing.calls, contains('addRally'));
    expect(editing.rallies, hasLength(1));
    expect(editing.rallies.single.startSeconds, 0);
    expect(editing.rallies.single.endSeconds, 30);
    expect(find.textContaining('Point 1 · 0:00–0:30'), findsOneWidget);
  });

  testWidgets('a span that does not end after it starts is refused',
      (tester) async {
    final editing = FakeMatchEditing();
    await pumpScore(tester, editing: editing);

    // Mark both ends at the same position, which is not a point.
    await tester.tap(find.text('Mark start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark end'));
    await tester.pumpAndSettle();

    expect(editing.rallies, isEmpty);
    expect(
      find.textContaining('A rally has to end after it starts'),
      findsOneWidget,
    );
  });

  testWidgets('one tap on a side records that side as the winner',
      (tester) async {
    final editing = FakeMatchEditing(
      rallies: <Rally>[
        const Rally(
          id: 'rally-1',
          matchId: 'match-1',
          startSeconds: 10,
          endSeconds: 20,
        ),
      ],
    );
    await pumpScore(tester, editing: editing);

    // Nothing is claimed about a point the user has not decided.
    expect(find.text('Tap the side that won it'), findsOneWidget);

    await tester.tap(find.text('L'));
    await tester.pumpAndSettle();

    expect(editing.calls, contains('setWinner'));
    expect(editing.rallies.single.winnerSide, WinnerSide.left);
    expect(editing.rallies.single.status, RallyStatus.confirmed);
    // The scoreboard and the rally's own line both follow the confirmation.
    expect(find.text('Confirmed · 1–0'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('correcting the winner moves the point to the other side',
      (tester) async {
    final editing = FakeMatchEditing(
      rallies: <Rally>[
        const Rally(
          id: 'rally-1',
          matchId: 'match-1',
          startSeconds: 10,
          endSeconds: 20,
          winnerSide: WinnerSide.left,
          status: RallyStatus.confirmed,
        ),
      ],
    );
    await pumpScore(tester, editing: editing);
    expect(find.text('Confirmed · 1–0'), findsOneWidget);

    await tester.tap(find.text('R'));
    await tester.pumpAndSettle();

    expect(editing.rallies.single.winnerSide, WinnerSide.right);
    expect(find.text('Confirmed · 0–1'), findsOneWidget);
  });

  testWidgets('an unscored rally shows no score for itself', (tester) async {
    final editing = FakeMatchEditing(
      rallies: <Rally>[
        const Rally(
          id: 'rally-1',
          matchId: 'match-1',
          startSeconds: 10,
          endSeconds: 20,
        ),
      ],
    );
    await pumpScore(tester, editing: editing);

    expect(find.textContaining('Confirmed'), findsNothing);
    expect(find.text('Tap the side that won it'), findsOneWidget);
  });
}
