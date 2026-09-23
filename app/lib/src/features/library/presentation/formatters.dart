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
