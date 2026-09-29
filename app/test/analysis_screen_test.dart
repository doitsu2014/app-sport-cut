/// Analysis screen tests: what the match's artifacts are, rebuilding the ones
/// that are gone, watching that run, and stopping it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sportcut/src/bridge/sportcut_engine.dart';
import 'package:sportcut/src/features/analysis/presentation/analysis_screen.dart';
import 'package:sportcut/src/features/library/domain/match_record.dart';
import 'package:sportcut/src/features/library/presentation/library_providers.dart';

import 'support/fakes.dart';

void main() {
  late FakeMediaEngine engine;

  final match = MatchRecord(
    id: 'match-1',
    title: 'Club final',
    videoPath: '/tmp/club-final.mp4',
    durationSeconds: 90,
    createdAt: DateTime(2026, 3, 2),
    matchDir: '/tmp/matches/match-1',
    videoWidth: 1920,
    videoHeight: 1080,
    frameRate: 30,
    hasAudio: true,
  );

  ArtifactDto artifact(String kind, ArtifactStateDto state) => ArtifactDto(
        kind: kind,
        relativePath: '$kind/$kind',
        state: state,
        sizeBytes: BigInt.from(1024),
      );

  setUp(() {
    engine = FakeMediaEngine();
  });

  Future<void> pumpAnalysis(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaEngineProvider.overrideWithValue(engine),
        ],
        child: MaterialApp(home: AnalysisScreen(match: match)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the match and its artifacts are listed', (tester) async {
    engine.manifestArtifacts = <ArtifactDto>[
      artifact('proxy', ArtifactStateDto.final_),
      artifact('frames', ArtifactStateDto.final_),
    ];
    await pumpAnalysis(tester);

    expect(find.text('Club final'), findsOneWidget);
    expect(find.text('Artifacts'), findsOneWidget);
    expect(find.text('proxy'), findsOneWidget);
    expect(find.text('frames'), findsOneWidget);
  });

  testWidgets('nothing missing means nothing to rebuild', (tester) async {
    engine.manifestArtifacts = <ArtifactDto>[
      artifact('proxy', ArtifactStateDto.final_),
    ];
    await pumpAnalysis(tester);

    expect(find.text('Nothing to rebuild'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Nothing to rebuild'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('a match with no analysis files says so', (tester) async {
    engine.manifestArtifacts = <ArtifactDto>[];
    await pumpAnalysis(tester);

    expect(
      find.textContaining('no analysis files yet'),
      findsOneWidget,
    );
  });

  testWidgets('a manifest that cannot be read is reported', (tester) async {
    engine.failure = StateError('the manifest is unreadable');
    await pumpAnalysis(tester);

    expect(
      find.textContaining('analysis files could not be read'),
      findsOneWidget,
    );
  });

  testWidgets('rebuilding the missing artifacts goes through the engine',
      (tester) async {
    engine.manifestArtifacts = <ArtifactDto>[
      artifact('proxy', ArtifactStateDto.missing),
      artifact('frames', ArtifactStateDto.missing),
    ];
    await pumpAnalysis(tester);
    expect(find.text('Rebuild 2 missing files'), findsOneWidget);

    await tester.tap(find.text('Rebuild 2 missing files'));
    await tester.pumpAndSettle();

    expect(engine.startedJobs, hasLength(1));
    expect(engine.lastMatchDir, match.matchDir);
    // The repair finished, so the screen stops showing progress and reads the
    // manifest again.
    expect(find.text('Rebuild 2 missing files'), findsOneWidget);
    expect(find.text('Nothing to rebuild'), findsNothing);
  });

  testWidgets('a running rebuild can be cancelled', (tester) async {
    engine.manifestArtifacts = <ArtifactDto>[
      artifact('proxy', ArtifactStateDto.missing),
    ];
    engine.jobState = JobStateDto.running;
    engine.jobStage = 'proxy';
    await pumpAnalysis(tester);

    await tester.tap(find.text('Rebuild 1 missing file'));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Rebuilding the proxy…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    // The engine reports the cancellation, which is what ends the screen's
    // watch of the job.
    engine.jobState = JobStateDto.cancelled;
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(engine.jobCancelCalls, 1);
    expect(find.text('Rebuild 1 missing file'), findsOneWidget);
  });

  testWidgets('a rebuild that fails reports the engine reason', (tester) async {
    engine.manifestArtifacts = <ArtifactDto>[
      artifact('proxy', ArtifactStateDto.missing),
    ];
    engine.jobState = JobStateDto.failed;
    engine.jobError = 'the proxy could not be written';
    await pumpAnalysis(tester);

    await tester.tap(find.text('Rebuild 1 missing file'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('the proxy could not be written'),
      findsOneWidget,
    );
  });

  testWidgets('a match with no files offers to start preparing', (tester) async {
    engine.manifestArtifacts = <ArtifactDto>[];
    await pumpAnalysis(tester);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start preparing analysis'),
    );
    expect(button.onPressed, isNotNull);
    // Opening the screen reads the manifest; it does not start the job.
    expect(engine.artifactCalls, 0);
  });

  testWidgets('starting preparation runs the job and lists the new files',
      (tester) async {
    engine.manifestArtifacts = <ArtifactDto>[];
    await pumpAnalysis(tester);

    // The job completes at once; afterwards the manifest has the files.
    engine.manifestArtifacts = <ArtifactDto>[
      artifact('proxy', ArtifactStateDto.final_),
      artifact('frames', ArtifactStateDto.final_),
    ];
    await tester.tap(find.text('Start preparing analysis'));
    await tester.pumpAndSettle();

    expect(engine.artifactCalls, 1);
    expect(engine.lastMatchId, match.id);
    expect(engine.lastMatchDir, match.matchDir);
    expect(find.text('Start preparing analysis'), findsNothing);
    expect(find.text('frames'), findsOneWidget);
  });

  testWidgets('a running preparation shows its step and can be cancelled',
      (tester) async {
    engine.manifestArtifacts = <ArtifactDto>[];
    engine.jobState = JobStateDto.running;
    engine.jobStage = 'proxy';
    await pumpAnalysis(tester);

    await tester.tap(find.text('Start preparing analysis'));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Making the proxy…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('Running in the background'), findsOneWidget);

    engine.jobState = JobStateDto.cancelled;
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(engine.jobCancelCalls, 1);
    expect(find.text('Start preparing analysis'), findsOneWidget);
  });

  testWidgets('another video waits while one is being prepared',
      (tester) async {
    final other = MatchRecord(
      id: 'match-2',
      title: 'Club semi',
      videoPath: '/tmp/club-semi.mp4',
      durationSeconds: 60,
      createdAt: DateTime(2026, 3, 1),
      matchDir: '/tmp/matches/match-2',
    );
    final container = ProviderContainer(
      overrides: [mediaEngineProvider.overrideWithValue(engine)],
    );
    addTearDown(container.dispose);
    Future<void> show(MatchRecord shown) => tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(home: AnalysisScreen(match: shown)),
          ),
        );

    engine.manifestArtifacts = <ArtifactDto>[];
    engine.jobState = JobStateDto.running;
    await show(match);
    await tester.pump();
    await tester.tap(find.text('Start preparing analysis'));
    await tester.pump(const Duration(milliseconds: 50));

    // The job keeps running while another video is opened.
    await show(other);
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.textContaining('Another video is being prepared (Club final)'),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start preparing analysis'),
    );
    expect(button.onPressed, isNull);

    // Going back shows the same job, still running.
    await show(match);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Cancel'), findsOneWidget);
    expect(engine.artifactCalls, 1);

    engine.jobState = JobStateDto.completed;
    await tester.pumpAndSettle();
  });
}
