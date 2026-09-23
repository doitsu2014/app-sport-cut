import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Draws the images the exporter composites over the video.
///
/// The engine composites what it is given rather than drawing text, because
/// burning text needs a font-capable media toolchain and those are not
/// universal. Drawing here has the better half of the trade: the scoreboard uses
/// the application's own typography, at the same proportions the user sees while
/// reviewing, and the engine needs no font at all.
class OverlayRenderer {
  /// Create a renderer.
  const OverlayRenderer();

  /// Height the layout is designed against; everything scales from it.
  static const double _designHeight = 720;

  /// Write a transparent scoreboard sized to the recording.
  Future<File> writeScoreboard({
    required String path,
    required int width,
    required int height,
    required int leftScore,
    required int rightScore,
    String? leftName,
    String? rightName,
  }) async {
    final scale = _scale(height);
    final margin = 40 * scale;
    final fontSize = 44 * scale;

    return _write(
      path: path,
      width: width,
      height: height,
      draw: (canvas) {
        final left = _label(leftScore, leftName);
        final right = _label(rightScore, rightName);

        _drawChip(
          canvas,
          text: left,
          fontSize: fontSize,
          origin: Offset(margin, margin),
          scale: scale,
        );
        _drawChip(
          canvas,
          text: right,
          fontSize: fontSize,
          origin: Offset(margin, margin),
          scale: scale,
          alignRightAt: width - margin,
        );
      },
    );
  }

  /// Write a full-frame title card.
  Future<File> writeTitleCard({
    required String path,
    required int width,
    required int height,
    required String title,
  }) =>
      _write(
        path: path,
        width: width,
        height: height,
        draw: (canvas) {
          final scale = _scale(height);
          canvas.drawRect(
            Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
            Paint()..color = const Color(0xFF101010),
          );
          _drawChip(
            canvas,
            text: title,
            fontSize: 56 * scale,
            origin: Offset(width / 2, height / 2),
            scale: scale,
            centred: true,
          );
        },
      );

  /// The wording of one side's scoreboard entry.
  ///
  /// A name the user never gave is left out rather than invented, so the
  /// scoreboard shows the score alone.
  String _label(int score, String? name) {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return '$score';
    }
    return '$trimmed  $score';
  }

  static double _scale(int height) {
    final value = height / _designHeight;
    return value.clamp(0.15, 8.0);
  }

  static void _drawChip(
    ui.Canvas canvas, {
    required String text,
    required double fontSize,
    required Offset origin,
    required double scale,
    double alignRightAt = 0,
    bool centred = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFFFFFFFF),
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final padding = 16 * scale;
    final border = 12 * scale;
    final width = painter.width + padding * 2;
    final height = painter.height + border * 2;

    final double left;
    if (centred) {
      left = origin.dx - width / 2;
    } else if (alignRightAt > 0) {
      left = alignRightAt - width;
    } else {
      left = origin.dx;
    }
    final top = centred ? origin.dy - height / 2 : origin.dy;
    final rect = Rect.fromLTWH(left, top, width, height);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(12 * scale)),
      Paint()..color = const Color(0x8C000000),
    );
    painter.paint(canvas, Offset(left + padding, top + border));
  }

  static Future<File> _write({
    required String path,
    required int width,
    required int height,
    required void Function(ui.Canvas canvas) draw,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );
    draw(canvas);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        throw StateError('the overlay image could not be encoded');
      }
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      return file;
    } finally {
      image.dispose();
    }
  }
}
