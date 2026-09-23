/// One clip in the highlight reel.
///
/// A clip usually comes from a rally the user kept, which is what [rallyId]
/// records; the reel is the user's selection, not a copy of the rally list, so a
/// scored rally the user left out simply has no clip.
class HighlightClip {
  /// Create a clip.
  const HighlightClip({
    required this.id,
    required this.matchId,
    this.rallyId,
    required this.startSeconds,
    required this.endSeconds,
    this.rank,
    this.selected = true,
    this.trimStartSeconds,
    this.trimEndSeconds,
    this.orderIndex = 0,
  });

  /// Stable identifier.
  final String id;

  /// Match this clip belongs to.
  final String matchId;

  /// Rally the clip was made from, or `null` for a span kept without one.
  final String? rallyId;

  /// Start of the clip in the recording, in seconds.
  final double startSeconds;

  /// End of the clip in the recording, in seconds.
  final double endSeconds;

  /// How good a suggestion this clip was, in the automatic phases. Never the
  /// user's order, which is [orderIndex].
  final int? rank;

  /// Whether the clip is in the reel.
  final bool selected;

  /// Trimmed start, when the user pulled the clip inward.
  final double? trimStartSeconds;

  /// Trimmed end, when the user pulled the clip inward.
  final double? trimEndSeconds;

  /// Position in the reel, lowest first.
  final int orderIndex;

  /// Where the clip actually starts once its trim is applied.
  double get effectiveStartSeconds => trimStartSeconds ?? startSeconds;

  /// Where the clip actually ends once its trim is applied.
  double get effectiveEndSeconds => trimEndSeconds ?? endSeconds;

  /// Rendered duration in seconds.
  double get durationSeconds => effectiveEndSeconds - effectiveStartSeconds;

  /// This clip with the given fields replaced.
  HighlightClip copyWith({
    String? id,
    String? matchId,
    String? rallyId,
    bool clearRally = false,
    double? startSeconds,
    double? endSeconds,
    int? rank,
    bool? selected,
    double? trimStartSeconds,
    double? trimEndSeconds,
    int? orderIndex,
  }) =>
      HighlightClip(
        id: id ?? this.id,
        matchId: matchId ?? this.matchId,
        rallyId: clearRally ? null : (rallyId ?? this.rallyId),
        startSeconds: startSeconds ?? this.startSeconds,
        endSeconds: endSeconds ?? this.endSeconds,
        rank: rank ?? this.rank,
        selected: selected ?? this.selected,
        trimStartSeconds: trimStartSeconds ?? this.trimStartSeconds,
        trimEndSeconds: trimEndSeconds ?? this.trimEndSeconds,
        orderIndex: orderIndex ?? this.orderIndex,
      );
}
