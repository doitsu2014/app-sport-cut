/// Highlight reel screen tests: keeping a rally, taking it out, trimming it, and
/// putting the reel in the order the user wants.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sportcut/src/features/editing/domain/highlight_clip.dart';
import 'package:sportcut/src/features/editing/domain/rally.dart';
import 'package:sportcut/src/features/editing/presentation/editing_providers.dart';
import 'package:sportcut/src/features/highlights/presentation/highlights_screen.dart';
import 'package:sportcut/src/features/library/domain/match_record.dart';

import 'support/fake_match_editing.dart';

void main() {
  final match = MatchRecord(
    id: 'match-1',
    title: 'Club final',
    videoPath: '/tmp/club-final.mp4',
    durationSeconds: 90,
    createdAt: DateTime(2026, 3, 2),
    matchDir: '/tmp/matches/match-1',
  );

  const first = Rally(
    id: 'rally-1',
    matchId: 'match-1',
    startSeconds: 10,
    endSeconds: 20,
    winnerSide: WinnerSide.left,
    status: RallyStatus.confirmed,
  );
  const second = Rally(
    id: 'rally-2',
    matchId: 'match-1',
    startSeconds: 30,
    endSeconds: 44,
  );

  HighlightClip clipOf(Rally rally, {required int orderIndex}) => HighlightClip(
        id: 'clip-${rally.id}',
        matchId: 'match-1',
        rallyId: rally.id,
        startSeconds: rally.startSeconds,
        endSeconds: rally.endSeconds,
        orderIndex: orderIndex,
      );

  Future<void> pumpHighlights(
    WidgetTester tester,
    FakeMatchEditing editing,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchEditingProvider.overrideWith((ref) async => editing),
        ],
        // A touch platform, so the reel reorders with a long press the way it
        // does on a phone rather than the desktop's immediate drag.
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: HighlightsScreen(match: match),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a match with no clips shows the empty reel and what is left out',
      (tester) async {
    final editing = FakeMatchEditing(
      rallies: <Rally>[first, second],
    );
    await pumpHighlights(tester, editing);

    expect(find.textContaining('No clips in the reel yet'), findsOneWidget);
    expect(find.text('Left out (2)'), findsOneWidget);
    expect(find.text('0 clips · 0:00'), findsOneWidget);
  });

  testWidgets('keeping a rally puts a clip in the reel', (tester) async {
    final editing = FakeMatchEditing(rallies: <Rally>[first, second]);
    await pumpHighlights(tester, editing);

    await tester.tap(find.byType(ActionChip).first);
    await tester.pumpAndSettle();

    expect(editing.calls, contains('keepClip'));
    expect(editing.clips, hasLength(1));
    expect(editing.clips.single.rallyId, first.id);
    expect(find.text('Left out (1)'), findsOneWidget);
    expect(find.textContaining('1. 0:10–0:20'), findsOneWidget);
    expect(find.text('1 clips · 0:10'), findsOneWidget);
  });

  testWidgets('removing a clip takes it out of the reel and leaves the rally',
      (tester) async {
    final editing = FakeMatchEditing(
      rallies: <Rally>[first, second],
      clips: <HighlightClip>[clipOf(first, orderIndex: 0)],
    );
    await pumpHighlights(tester, editing);

    await tester.tap(find.byTooltip('Remove from the reel'));
    await tester.pumpAndSettle();

    expect(editing.clips, isEmpty);
    expect(editing.rallies, hasLength(2));
    expect(find.text('Left out (2)'), findsOneWidget);
  });

  testWidgets('trimming a clip moves its boundaries and not the rally',
      (tester) async {
    final editing = FakeMatchEditing(
      rallies: <Rally>[first],
      clips: <HighlightClip>[clipOf(first, orderIndex: 0)],
    );
    await pumpHighlights(tester, editing);

    await tester.tap(find.byTooltip('Trim'));
    await tester.pumpAndSettle();
    expect(find.text('Trim clip'), findsOneWidget);
    expect(find.textContaining('0:10–0:20'), findsWidgets);

    // Pull the start of the clip inward, then keep the trim.
    final slider = tester.getRect(find.byType(RangeSlider));
    await tester.dragFrom(
      Offset(slider.left + 24, slider.center.dy),
      const Offset(40, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Trim'));
    await tester.pumpAndSettle();

    expect(editing.calls, contains('trimClip'));
    expect(editing.clips.single.trimStartSeconds, greaterThan(10));
    expect(editing.clips.single.startSeconds, 10);
    expect(editing.rallies.single.startSeconds, 10);
    expect(find.textContaining('(trimmed)'), findsOneWidget);
  });

  testWidgets('cancelling a trim leaves the clip as it was', (tester) async {
    final editing = FakeMatchEditing(
      rallies: <Rally>[first],
      clips: <HighlightClip>[clipOf(first, orderIndex: 0)],
    );
    await pumpHighlights(tester, editing);

    await tester.tap(find.byTooltip('Trim'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(editing.calls, isNot(contains('trimClip')));
    expect(editing.clips.single.trimStartSeconds, isNull);
  });

  testWidgets('dragging a clip rewrites the reel order', (tester) async {
    final editing = FakeMatchEditing(
      rallies: <Rally>[first, second],
      clips: <HighlightClip>[
        clipOf(first, orderIndex: 0),
        clipOf(second, orderIndex: 1),
      ],
    );
    await pumpHighlights(tester, editing);
    expect(
      editing.clips.map((clip) => clip.rallyId),
      <String>[first.id, second.id],
    );

    // A long press starts the reorder, which is how the list behaves on a
    // touch device.
    final start = tester.getCenter(find.textContaining('1. 0:10–0:20'));
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(start + const Offset(0, 150));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(editing.calls, contains('reorderClips'));
    expect(
      editing.clips.map((clip) => clip.rallyId),
      <String>[second.id, first.id],
    );
  });
}
