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
}
