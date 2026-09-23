/// A match, as the application knows it.
///
/// [videoPath] is the app-owned copy of the recording, taken into custody when
/// the match was imported: the platform picker hands back a file the operating
/// system may purge, so the bytes the user picked are copied once and it is that
/// copy the application plays and analyzes. The file the user selected is left
/// exactly where it was, and [originalPath] is only a record of where it came
/// from. [matchDir] holds the engine's derived artifacts for this match.
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
    this.originalPath,
    this.sourceBytes,
  });

  /// Stable identifier, also the match and recording directory name.
  final String id;

  /// Title shown in the library.
  final String title;

  /// The app-owned copy of the recording.
  ///
  /// The platform pickers hand back a temporary copy the operating system may
  /// purge, so the bytes the user picked are copied into app-owned storage at
  /// import and it is that copy, not the picked path, that the application
  /// plays and analyzes.
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

  /// Where the recording came from, for support and diagnostics.
  ///
  /// Never read from to play or analyze a match: the file the user selected is
  /// left entirely under the user's control and may already be gone.
  final String? originalPath;

  /// Size of the app-owned copy in bytes, when known.
  final int? sourceBytes;

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
    String? originalPath,
    int? sourceBytes,
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
        originalPath: originalPath ?? this.originalPath,
        sourceBytes: sourceBytes ?? this.sourceBytes,
      );
}
