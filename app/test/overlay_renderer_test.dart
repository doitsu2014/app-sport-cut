/// The images the application hands the engine to composite.
///
/// The engine burns in what it is given rather than drawing text, so the
/// scoreboard and the title card are the application's own pictures. Drawing
/// them uses `dart:ui`, which needs a real engine rather than a widget test's
/// fake-async zone, so this is a plain test and the export screen's own test
/// uses a double for the renderer.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sportcut/src/features/export/data/overlay_renderer.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sportcut-overlay-test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('a scoreboard is written at the recording size', () async {
    final file = await const OverlayRenderer().writeScoreboard(
      path: p.join(tempDir.path, 'overlays', 'score-0.png'),
      width: 1920,
      height: 1080,
      leftScore: 3,
      rightScore: 2,
    );

    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(0));
    // The directory the file names did not exist yet is created for it.
    expect(file.parent.path, p.join(tempDir.path, 'overlays'));
  });

  test('a title card is written at the recording size', () async {
    final file = await const OverlayRenderer().writeTitleCard(
      path: p.join(tempDir.path, 'overlays', 'title.png'),
      width: 1920,
      height: 1080,
      title: 'Club final',
    );

    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(0));
  });
}
