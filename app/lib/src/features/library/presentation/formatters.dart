/// Formats a duration in seconds as `m:ss`, or `h:mm:ss` past an hour.
String formatDuration(double seconds) {
  final total = seconds.isFinite && seconds > 0 ? seconds.round() : 0;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final remainder = total % 60;
  final paddedSeconds = remainder.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$paddedSeconds';
  }
  return '$minutes:$paddedSeconds';
}

/// Formats a creation date as `yyyy-mm-dd`.
String formatMatchDate(DateTime createdAt) {
  final year = createdAt.year.toString().padLeft(4, '0');
  final month = createdAt.month.toString().padLeft(2, '0');
  final day = createdAt.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// Formats a playback position as `m:ss`.
String formatPosition(Duration position) {
  final seconds = position.inSeconds < 0 ? 0 : position.inSeconds;
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '$minutes:${remainder.toString().padLeft(2, '0')}';
}

/// Formats a byte count as `1.4 GB`, `820 MB`, or `17 KB`.
///
/// Sizes are reported in decimal units, which is what device storage settings
/// and file managers show.
String formatBytes(int bytes) {
  if (bytes <= 0) {
    return '0 B';
  }
  const units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit += 1;
  }
  final rounded = value >= 100 || unit == 0
      ? value.round().toString()
      : value.toStringAsFixed(1);
  return '$rounded ${units[unit]}';
}

/// Summarizes what the engine reported about a recording.
///
/// Unknown fields are left out rather than shown as placeholders, so a record
/// written before a field existed still reads sensibly. Returns an empty string
/// when nothing is known.
String formatMediaSummary({
  int? width,
  int? height,
  double? frameRate,
  bool hasAudio = false,
  int? bytes,
}) {
  final parts = <String>[];
  if (width != null && height != null && width > 0 && height > 0) {
    parts.add('$width×$height');
  }
  if (frameRate != null && frameRate > 0) {
    final rounded = frameRate.roundToDouble() == frameRate
        ? frameRate.round().toString()
        : frameRate.toStringAsFixed(2);
    parts.add('$rounded fps');
  }
  if (hasAudio) {
    parts.add('audio');
  }
  if (bytes != null && bytes > 0) {
    parts.add(formatBytes(bytes));
  }
  return parts.join(' · ');
}
