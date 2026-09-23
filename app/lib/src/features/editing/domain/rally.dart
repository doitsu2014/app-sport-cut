/// Which side of the court won a rally.
///
/// There is no "unknown" member on purpose: a rally whose winner the user has
/// not confirmed carries no side at all, which is what [Rally.winnerSide] being
/// null means. Nothing derives a winner from the video.
enum WinnerSide {
  /// The left-hand side of the court.
  left,

  /// The right-hand side of the court.
  right,

  ;

  /// The stored form of this side.
  String get wireName => name;

  /// Read a stored side, or `null` when nothing is recorded.
  static WinnerSide? fromWire(Object? value) => switch (value) {
        'left' => WinnerSide.left,
        'right' => WinnerSide.right,
        _ => null,
      };
}

/// Where a rally stands in the review.
enum RallyStatus {
  /// The user confirmed which side won.
  confirmed,

  /// The user marked the span but has not said who won it.
  unscored,

  ;

  /// The stored form of this status.
  String get wireName => name;

  /// Read a stored status, defaulting to [RallyStatus.unscored].
  static RallyStatus fromWire(Object? value) =>
      value == 'confirmed' ? RallyStatus.confirmed : RallyStatus.unscored;
}

/// One point, as the user marked it.
///
/// Fields follow the product data model (`docs/README.md` §11). `confidence` and
/// `highlightScore` belong to the automatic phases and stay null for a rally the
/// user marked by hand.
class Rally {
  /// Create a rally.
  const Rally({
    required this.id,
    required this.matchId,
    required this.startSeconds,
    required this.endSeconds,
    this.winnerSide,
    this.status = RallyStatus.unscored,
    this.confidence,
    this.highlightScore,
  });

  /// Stable identifier.
  final String id;

  /// Match this rally belongs to.
  final String matchId;

  /// Start of the rally in the recording, in seconds.
  final double startSeconds;

  /// End of the rally in the recording, in seconds.
  final double endSeconds;

  /// Confirmed winner, or `null` while the rally is unscored.
  final WinnerSide? winnerSide;

  /// Whether the user has confirmed a winner.
  final RallyStatus status;

  /// Confidence of an automatic suggestion; always null for a manual rally.
  final double? confidence;

  /// Ranking score from the highlight phase; always null for a manual rally.
  final double? highlightScore;

  /// Duration of the rally in seconds.
  double get durationSeconds => endSeconds - startSeconds;

  /// Whether this rally contributes to the score.
  bool get isScored => status == RallyStatus.confirmed && winnerSide != null;

  /// This rally with the given fields replaced.
  Rally copyWith({
    String? id,
    String? matchId,
    double? startSeconds,
    double? endSeconds,
    WinnerSide? winnerSide,
    bool clearWinner = false,
    RallyStatus? status,
    double? confidence,
    double? highlightScore,
  }) =>
      Rally(
        id: id ?? this.id,
        matchId: matchId ?? this.matchId,
        startSeconds: startSeconds ?? this.startSeconds,
        endSeconds: endSeconds ?? this.endSeconds,
        winnerSide: clearWinner ? null : (winnerSide ?? this.winnerSide),
        status: status ?? this.status,
        confidence: confidence ?? this.confidence,
        highlightScore: highlightScore ?? this.highlightScore,
      );
}
