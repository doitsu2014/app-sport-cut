/// Overlay renderer double: records what it was asked to draw and writes a
/// placeholder file where the real one would write a PNG.
///
/// The real renderer rasterises with `dart:ui`, which does not complete inside a
/// widget test's fake-async zone. Recording the arguments is also what lets a
/// test assert the rule that matters here: the overlay carries the score and no
/// label the user never gave.
library;

import 'dart:io';

import 'package:sportcut/src/features/export/data/overlay_renderer.dart';

/// One scoreboard the screen asked for.
class ScoreboardRequest {
  /// Describe a scoreboard request.
  const ScoreboardRequest({
    required this.path,
    required this.width,
    required this.height,
    required this.leftScore,
    required this.rightScore,
    this.leftName,
    this.rightName,
  });

  /// Where the drawing was written.
  final String path;

  /// Recording size the drawing is for.
  final int width;
  final int height;

  /// The score shown.
  final int leftScore;
  final int rightScore;

  /// Team names, when the caller supplied any.
  final String? leftName;
  final String? rightName;
}

class FakeOverlayRenderer extends OverlayRenderer {
  /// Every scoreboard the screen asked for, in order.
  final List<ScoreboardRequest> scoreboards = <ScoreboardRequest>[];

  /// Every title card the screen asked for, in order.
  final List<({String title, int width, int height})> titles =
      <({String title, int width, int height})>[];

  @override
  Future<File> writeScoreboard({
    required String path,
    required int width,
    required int height,
    required int leftScore,
    required int rightScore,
    String? leftName,
    String? rightName,
  }) async {
    scoreboards.add(
      ScoreboardRequest(
        path: path,
        width: width,
        height: height,
        leftScore: leftScore,
        rightScore: rightScore,
        leftName: leftName,
        rightName: rightName,
      ),
    );
    return _placeholder(path);
  }

  @override
  Future<File> writeTitleCard({
    required String path,
    required int width,
    required int height,
    required String title,
  }) async {
    titles.add((title: title, width: width, height: height));
    return _placeholder(path);
  }

  Future<File> _placeholder(String path) async {
    final file = File(path);
    // Written synchronously on purpose: a widget test runs in a fake-async
    // zone where real, asynchronous file work never completes, so the double
    // must not await the filesystem.
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(<int>[0x89, 0x50, 0x4e, 0x47], flush: true);
    return file;
  }
}
