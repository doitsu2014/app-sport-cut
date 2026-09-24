/// Score timeline tests: the running score is derived from the confirmed
/// winners, never stored as a value of its own.
///
/// These run without a screen and without a database, because the derivation is
/// a function of the rallies.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sportcut/src/features/editing/domain/rally.dart';
import 'package:sportcut/src/features/editing/domain/score_timeline.dart';

void main() {
  var sequence = 0;

  Rally rally({
    required double start,
    required double end,
    WinnerSide? winner,
  }) {
    sequence += 1;
    return Rally(
      id: 'rally-$sequence',
      matchId: 'match-1',
      startSeconds: start,
      endSeconds: end,
      winnerSide: winner,
      status: winner == null ? RallyStatus.unscored : RallyStatus.confirmed,
    );
  }

  test('the score advances one point per confirmed rally in rally order', () {
    final timeline = ScoreTimeline.fromRallies('match-1', <Rally>[
      rally(start: 30, end: 40, winner: WinnerSide.left),
      rally(start: 10, end: 20, winner: WinnerSide.right),
      rally(start: 50, end: 60, winner: WinnerSide.left),
    ]);

    // The order is the recording's, not the order the rallies were handed over.
    expect(
      timeline.events.map((event) => (event.leftScore, event.rightScore)),
      <(int, int)>[(0, 1), (1, 1), (2, 1)],
    );
    expect(timeline.left, 2);
    expect(timeline.right, 1);
  });

  test('a rally with no confirmed winner contributes nothing', () {
    final unscored = rally(start: 10, end: 20);
    final timeline = ScoreTimeline.fromRallies('match-1', <Rally>[
      unscored,
      rally(start: 30, end: 40, winner: WinnerSide.left),
    ]);

    expect(timeline.events, hasLength(1));
    expect(timeline.atRally(unscored.id), isNull);
    expect(timeline.left, 1);
    expect(timeline.right, 0);
  });

  test('correcting an early winner rewrites every later score', () {
    final first = rally(start: 10, end: 20, winner: WinnerSide.left);
    final second = rally(start: 30, end: 40, winner: WinnerSide.left);
    final third = rally(start: 50, end: 60, winner: WinnerSide.right);

    final before = ScoreTimeline.fromRallies('match-1', <Rally>[
      first,
      second,
      third,
    ]);
    expect(before.left, 2);
    expect(before.right, 1);
    expect(before.atRally(third.id)!.leftScore, 2);

    // The user says the first point was the other side's after all.
    final corrected = ScoreTimeline.fromRallies('match-1', <Rally>[
      first.copyWith(
        winnerSide: WinnerSide.right,
        status: RallyStatus.confirmed,
      ),
      second,
      third,
    ]);

    expect(corrected.left, 1);
    expect(corrected.right, 2);
    expect(
      corrected.events.map((event) => (event.leftScore, event.rightScore)),
      <(int, int)>[(0, 1), (1, 1), (1, 2)],
    );
  });

  test('clearing a winner takes its point back off the timeline', () {
    final first = rally(start: 10, end: 20, winner: WinnerSide.left);
    final second = rally(start: 30, end: 40, winner: WinnerSide.left);

    final cleared = ScoreTimeline.fromRallies('match-1', <Rally>[
      first.copyWith(clearWinner: true, status: RallyStatus.unscored),
      second,
    ]);

    expect(cleared.left, 1);
    expect(cleared.right, 0);
    expect(cleared.atRally(first.id), isNull);
  });

  test('the same rallies always derive the same timeline', () {
    final rallies = <Rally>[
      rally(start: 10, end: 20, winner: WinnerSide.right),
      rally(start: 30, end: 40, winner: WinnerSide.left),
    ];

    final first = ScoreTimeline.fromRallies('match-1', rallies);
    final again = ScoreTimeline.fromRallies('match-1', rallies.reversed.toList());

    expect(
      again.events.map((event) => event.id).toList(),
      first.events.map((event) => event.id).toList(),
    );
    expect(
      again.events.map((event) => event.timestampSeconds).toList(),
      first.events.map((event) => event.timestampSeconds).toList(),
    );
    expect(again.left, first.left);
    expect(again.right, first.right);
  });

  test('the score at a moment is the score as it stood then', () {
    final timeline = ScoreTimeline.fromRallies('match-1', <Rally>[
      rally(start: 10, end: 20, winner: WinnerSide.left),
      rally(start: 30, end: 40, winner: WinnerSide.left),
      rally(start: 50, end: 60, winner: WinnerSide.right),
    ]);

    // Before the first point, during the second, and after the last: this is
    // what the scoreboard on a clip shows, which is the score at the clip's own
    // position in the match rather than the final one.
    expect(timeline.atSeconds(5), (left: 0, right: 0));
    expect(timeline.atSeconds(25), (left: 1, right: 0));
    expect(timeline.atSeconds(45), (left: 2, right: 0));
    expect(timeline.atSeconds(55), (left: 2, right: 1));
  });

  test('a match with no confirmed rally has an empty timeline', () {
    final timeline = ScoreTimeline.fromRallies('match-1', <Rally>[
      rally(start: 10, end: 20),
    ]);

    expect(timeline.isEmpty, isTrue);
    expect(timeline.left, 0);
    expect(timeline.right, 0);
    expect(timeline.atSeconds(15), (left: 0, right: 0));
  });
}
