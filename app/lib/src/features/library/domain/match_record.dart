/// A match, as the application knows it.
///
/// The original recording is referenced in place: [videoPath] points at the
/// user's file and is never copied. [matchDir] holds the engine's derived
/// artifacts for this match.
class MatchRecord {
  /// Create a match record.
  const MatchRecord({
    required this.id,
    required this.title,
    required this.videoPath,
    required this.durationSeconds,
    required this.createdAt,
    required this.matchDir,
    this.videoWidth,
    this.videoHeight,
    this.frameRate,
    this.hasAudio = false,
  });

  /// Stable identifier, also the match directory name.
  final String id;

  /// Title shown in the library.
  final String title;

  /// Original recording, referenced in place.
  final String videoPath;

  /// Duration in seconds, read from the recording on import.
  final double durationSeconds;

  /// When the match was created.
  final DateTime createdAt;

  /// Directory holding this match's derived artifacts.
  final String matchDir;

  /// Stored frame width, when known.
  final int? videoWidth;

  /// Stored frame height, when known.
  final int? videoHeight;

  /// Frame rate, when known.
  final double? frameRate;

  /// Whether the recording has an audio track.
  final bool hasAudio;

  /// This record with the given fields replaced.
  MatchRecord copyWith({
    String? id,
    String? title,
    String? videoPath,
    double? durationSeconds,
    DateTime? createdAt,
    String? matchDir,
    int? videoWidth,
    int? videoHeight,
    double? frameRate,
    bool? hasAudio,
  }) =>
      MatchRecord(
        id: id ?? this.id,
        title: title ?? this.title,
        videoPath: videoPath ?? this.videoPath,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        createdAt: createdAt ?? this.createdAt,
        matchDir: matchDir ?? this.matchDir,
        videoWidth: videoWidth ?? this.videoWidth,
        videoHeight: videoHeight ?? this.videoHeight,
        frameRate: frameRate ?? this.frameRate,
        hasAudio: hasAudio ?? this.hasAudio,
      );
}
