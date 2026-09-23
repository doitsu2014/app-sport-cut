/// Choices that shape a match's highlight video.
///
/// One row per match: the settings are what the user last chose, not a record of
/// what was rendered. A rendered file is a derived artifact and belongs in the
/// match manifest, which is where the engine records what exists on disk.
class ExportSettings {
  /// Create settings.
  const ExportSettings({
    required this.matchId,
    this.title,
    this.musicPath,
    this.musicGain = defaultMusicGain,
    this.leadInSeconds = defaultLeadInSeconds,
    this.leadOutSeconds = defaultLeadOutSeconds,
  });

  /// Volume the music is mixed at under the match audio.
  static const double defaultMusicGain = 0.25;

  /// Padding added before each clip.
  static const double defaultLeadInSeconds = 1;

  /// Padding added after each clip.
  static const double defaultLeadOutSeconds = 1;

  /// Match these settings belong to.
  final String matchId;

  /// Title card text, when the user wants one.
  final String? title;

  /// Path of the user's chosen music, or `null` for match audio only.
  final String? musicPath;

  /// Music volume relative to the match audio, in the range `0..1`.
  final double musicGain;

  /// Padding added before each clip, in seconds.
  final double leadInSeconds;

  /// Padding added after each clip, in seconds.
  final double leadOutSeconds;

  /// Whether the user asked for music.
  bool get hasMusic => musicPath != null && musicPath!.isNotEmpty;

  /// These settings with the given fields replaced.
  ExportSettings copyWith({
    String? matchId,
    String? title,
    bool clearTitle = false,
    String? musicPath,
    bool clearMusic = false,
    double? musicGain,
    double? leadInSeconds,
    double? leadOutSeconds,
  }) =>
      ExportSettings(
        matchId: matchId ?? this.matchId,
        title: clearTitle ? null : (title ?? this.title),
        musicPath: clearMusic ? null : (musicPath ?? this.musicPath),
        musicGain: musicGain ?? this.musicGain,
        leadInSeconds: leadInSeconds ?? this.leadInSeconds,
        leadOutSeconds: leadOutSeconds ?? this.leadOutSeconds,
      );
}
