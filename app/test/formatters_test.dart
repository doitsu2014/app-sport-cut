/// Formatting helpers used by the library and player screens.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sportcut/src/features/library/presentation/formatters.dart';

void main() {
  test('durations read as m:ss below an hour and h:mm:ss above it', () {
    expect(formatDuration(0), '0:00');
    expect(formatDuration(9.4), '0:09');
    expect(formatDuration(65), '1:05');
    expect(formatDuration(1830.5), '30:31');
    expect(formatDuration(3725), '1:02:05');
    expect(formatDuration(-5), '0:00');
  });

  test('creation dates read as yyyy-mm-dd', () {
    expect(formatMatchDate(DateTime(2026, 5, 4, 19, 30)), '2026-05-04');
  });

  test('playback positions read as m:ss', () {
    expect(formatPosition(Duration.zero), '0:00');
    expect(formatPosition(const Duration(seconds: 72)), '1:12');
  });

  test('recording sizes read in decimal units', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(999), '999 B');
    expect(formatBytes(1024), '1.0 KB');
    expect(formatBytes(734003200), '734 MB');
    expect(formatBytes(1500000000), '1.5 GB');
  });

  test('media summaries name what is known and skip what is not', () {
    expect(
      formatMediaSummary(
        width: 1920,
        height: 1080,
        frameRate: 30,
        hasAudio: true,
        bytes: 734003200,
      ),
      '1920×1080 · 30 fps · audio · 734 MB',
    );
    expect(
      formatMediaSummary(width: 1280, height: 720, frameRate: 29.97),
      '1280×720 · 29.97 fps',
    );
    expect(formatMediaSummary(), '');
    // A recording with no audio track says nothing about audio.
    expect(formatMediaSummary(hasAudio: false, bytes: 1024), '1.0 KB');
  });
}
