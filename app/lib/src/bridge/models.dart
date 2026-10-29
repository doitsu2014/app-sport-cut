/// The protocol's model types, hand-written.
///
/// These classes mirror the DTOs in `core/adapters/api/src/dto.rs`. They used
/// to be produced by a code generator from the Rust types; that generated code
/// is gone with the FFI path, so the models are hand-written here.
///
/// Dart field names mirror the Rust field names (`durationSeconds`,
/// `matchId`), while the JSON keys on the wire are the same names — the Rust
/// side serializes with `serde_json` and then converts every object key from
/// snake_case to camelCase. Enum wire values follow the Rust `serde` shape.
library;

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// Which side of the court a result refers to.
enum RallySideDto {
  /// The left-hand side of the court.
  left,

  /// The right-hand side of the court.
  right;

  /// Read the wire form, e.g. `left`.
  static RallySideDto fromWire(String value) => switch (value) {
        'left' => RallySideDto.left,
        'right' => RallySideDto.right,
        _ => throw ArgumentError.value(value, 'value', 'Unknown RallySideDto'),
      };

  /// The wire form this variant serializes to.
  String toWire() => switch (this) {
        RallySideDto.left => 'left',
        RallySideDto.right => 'right',
      };
}

/// Sustained number of on-court players supported by the sampled evidence.
enum ObservedPlayerCountDto {
  /// One observed player on each side.
  two,

  /// Two observed players on each side.
  four,

  /// The evidence does not support either count.
  unknown;

  /// Read the wire form, e.g. `two`.
  static ObservedPlayerCountDto fromWire(String value) => switch (value) {
        'two' => ObservedPlayerCountDto.two,
        'four' => ObservedPlayerCountDto.four,
        'unknown' => ObservedPlayerCountDto.unknown,
        _ => throw ArgumentError.value(
            value, 'value', 'Unknown ObservedPlayerCountDto'),
      };

  /// The wire form this variant serializes to.
  String toWire() => switch (this) {
        ObservedPlayerCountDto.two => 'two',
        ObservedPlayerCountDto.four => 'four',
        ObservedPlayerCountDto.unknown => 'unknown',
      };
}

/// Geometric half of the calibrated net, or an uncertain side.
enum PlayerCourtSideDto {
  /// Half containing the calibration's first corner.
  first,

  /// Half containing the calibration's third corner.
  second,

  /// No reliable assignment.
  unknown;

  /// Read the wire form, e.g. `first`.
  static PlayerCourtSideDto fromWire(String value) => switch (value) {
        'first' => PlayerCourtSideDto.first,
        'second' => PlayerCourtSideDto.second,
        'unknown' => PlayerCourtSideDto.unknown,
        _ => throw ArgumentError.value(
            value, 'value', 'Unknown PlayerCourtSideDto'),
      };

  /// The wire form this variant serializes to.
  String toWire() => switch (this) {
        PlayerCourtSideDto.first => 'first',
        PlayerCourtSideDto.second => 'second',
        PlayerCourtSideDto.unknown => 'unknown',
      };
}

/// Why a detected person was or was not selected for tracking.
enum PersonSelectionDto {
  /// Ground point falls within the calibrated court.
  onCourt,

  /// Detector confidence is too low.
  lowConfidence,

  /// Bounding box cannot locate a person in the frame.
  invalidBox,

  /// No calibration covers the frame.
  missingCalibration,

  /// Image-to-court projection is undefined.
  projectionFailed,

  /// Ground point lies within the margin just outside the court.
  borderline,

  /// Ground point lies beyond the court margin.
  offCourt;

  /// Read the wire form, e.g. `on_court`.
  static PersonSelectionDto fromWire(String value) => switch (value) {
        'on_court' => PersonSelectionDto.onCourt,
        'low_confidence' => PersonSelectionDto.lowConfidence,
        'invalid_box' => PersonSelectionDto.invalidBox,
        'missing_calibration' => PersonSelectionDto.missingCalibration,
        'projection_failed' => PersonSelectionDto.projectionFailed,
        'borderline' => PersonSelectionDto.borderline,
        'off_court' => PersonSelectionDto.offCourt,
        _ => throw ArgumentError.value(
            value, 'value', 'Unknown PersonSelectionDto'),
      };

  /// The wire form this variant serializes to.
  String toWire() => switch (this) {
        PersonSelectionDto.onCourt => 'on_court',
        PersonSelectionDto.lowConfidence => 'low_confidence',
        PersonSelectionDto.invalidBox => 'invalid_box',
        PersonSelectionDto.missingCalibration => 'missing_calibration',
        PersonSelectionDto.projectionFailed => 'projection_failed',
        PersonSelectionDto.borderline => 'borderline',
        PersonSelectionDto.offCourt => 'off_court',
      };
}

/// Lifecycle state of a job, mirrored for the client.
enum JobStateDto {
  /// Accepted but not started.
  pending,

  /// Currently executing a stage.
  running,

  /// Finished successfully.
  completed,

  /// Stopped by an explicit cancel request.
  cancelled,

  /// Stopped because a stage failed.
  failed;

  /// Read the wire form, e.g. `completed`.
  static JobStateDto fromWire(String value) => switch (value) {
        'pending' => JobStateDto.pending,
        'running' => JobStateDto.running,
        'completed' => JobStateDto.completed,
        'cancelled' => JobStateDto.cancelled,
        'failed' => JobStateDto.failed,
        _ => throw ArgumentError.value(value, 'value', 'Unknown JobStateDto'),
      };

  /// The wire form this variant serializes to.
  String toWire() => switch (this) {
        JobStateDto.pending => 'pending',
        JobStateDto.running => 'running',
        JobStateDto.completed => 'completed',
        JobStateDto.cancelled => 'cancelled',
        JobStateDto.failed => 'failed',
      };
}

/// How the camera was rotated relative to the stored pixels.
enum OrientationDto {
  /// No rotation metadata; pixels are upright.
  landscape,

  /// Rotated 90 degrees clockwise on playback.
  portrait,

  /// Rotated 180 degrees.
  upsideDown,

  /// Rotated 270 degrees clockwise (90 counter-clockwise).
  portraitReversed,

  /// Rotation metadata was present but not a right angle.
  unknown;

  /// Read the wire form, e.g. `upside_down`.
  static OrientationDto fromWire(String value) => switch (value) {
        'landscape' => OrientationDto.landscape,
        'portrait' => OrientationDto.portrait,
        'upside_down' => OrientationDto.upsideDown,
        'portrait_reversed' => OrientationDto.portraitReversed,
        'unknown' => OrientationDto.unknown,
        _ => throw ArgumentError.value(value, 'value', 'Unknown OrientationDto'),
      };

  /// The wire form this variant serializes to.
  String toWire() => switch (this) {
        OrientationDto.landscape => 'landscape',
        OrientationDto.portrait => 'portrait',
        OrientationDto.upsideDown => 'upside_down',
        OrientationDto.portraitReversed => 'portrait_reversed',
        OrientationDto.unknown => 'unknown',
      };
}

/// Whether a recorded artifact is a result or partial output.
enum ArtifactStateDto {
  /// Produced by a completed stage.
  final_,

  /// Produced by a stage that was cancelled or interrupted.
  nonFinal,

  /// Recorded but the file is gone.
  missing;

  /// Read the wire form, e.g. `non_final`.
  static ArtifactStateDto fromWire(String value) => switch (value) {
        'final' => ArtifactStateDto.final_,
        'non_final' => ArtifactStateDto.nonFinal,
        'missing' => ArtifactStateDto.missing,
        _ => throw ArgumentError.value(
            value, 'value', 'Unknown ArtifactStateDto'),
      };

  /// The wire form this variant serializes to.
  String toWire() => switch (this) {
        ArtifactStateDto.final_ => 'final',
        ArtifactStateDto.nonFinal => 'non_final',
        ArtifactStateDto.missing => 'missing',
      };
}

/// Which way the court runs relative to where the camera was standing.
enum CourtOrientationDto {
  /// The court stretches away from the camera, so the nearest edge is a
  /// baseline and the net cuts across the court's depth.
  away,

  /// The court stretches across the view, so the nearest edge is a sideline
  /// and the net cuts across the view from side to side.
  across;

  /// Read the wire form, e.g. `away`.
  static CourtOrientationDto fromWire(String value) => switch (value) {
        'away' => CourtOrientationDto.away,
        'across' => CourtOrientationDto.across,
        _ => throw ArgumentError.value(
            value, 'value', 'Unknown CourtOrientationDto'),
      };

  /// The wire form this variant serializes to.
  String toWire() => switch (this) {
        CourtOrientationDto.away => 'away',
        CourtOrientationDto.across => 'across',
      };
}

// ---------------------------------------------------------------------------
// Structs
// ---------------------------------------------------------------------------

/// Explicit thresholds for motion-first rally analysis.
class RallySegmentationConfigDto {
  /// Creates a rally segmentation config.
  const RallySegmentationConfigDto({
    required this.binMs,
    required this.maxTrackGapMs,
    required this.enterMotionPerSecond,
    required this.exitMotionPerSecond,
    required this.audioIntensityThreshold,
    required this.minRallyMs,
    required this.minRestMs,
    required this.minUsableCoverage,
  });

  /// Reads a config from its camelCase wire shape.
  factory RallySegmentationConfigDto.fromJson(Map<String, dynamic> json) {
    return RallySegmentationConfigDto(
      binMs: (json['binMs'] as num).toInt(),
      maxTrackGapMs: (json['maxTrackGapMs'] as num).toInt(),
      enterMotionPerSecond: (json['enterMotionPerSecond'] as num).toDouble(),
      exitMotionPerSecond: (json['exitMotionPerSecond'] as num).toDouble(),
      audioIntensityThreshold:
          (json['audioIntensityThreshold'] as num).toDouble(),
      minRallyMs: (json['minRallyMs'] as num).toInt(),
      minRestMs: (json['minRestMs'] as num).toInt(),
      minUsableCoverage: (json['minUsableCoverage'] as num).toDouble(),
    );
  }

  /// Width of one activity bin in milliseconds.
  final int binMs;

  /// Largest track gap from which motion can be measured.
  final int maxTrackGapMs;

  /// Motion required to start a proposed rally.
  final double enterMotionPerSecond;

  /// Motion required to continue a proposed rally.
  final double exitMotionPerSecond;

  /// Audio intensity that may support weak motion.
  final double audioIntensityThreshold;

  /// Minimum accepted rally duration.
  final int minRallyMs;

  /// Rest shorter than this is joined between rallies.
  final int minRestMs;

  /// Minimum fraction of the recording with usable tracks.
  final double minUsableCoverage;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'binMs': binMs,
        'maxTrackGapMs': maxTrackGapMs,
        'enterMotionPerSecond': enterMotionPerSecond,
        'exitMotionPerSecond': exitMotionPerSecond,
        'audioIntensityThreshold': audioIntensityThreshold,
        'minRallyMs': minRallyMs,
        'minRestMs': minRestMs,
        'minUsableCoverage': minUsableCoverage,
      };
}

/// Start a local rally-analysis job for a match with a completed track
/// artifact.
class RallySegmentationRequestDto {
  /// Creates a rally segmentation request.
  const RallySegmentationRequestDto({
    required this.matchDir,
    required this.config,
  });

  /// Reads a request from its camelCase wire shape.
  factory RallySegmentationRequestDto.fromJson(Map<String, dynamic> json) {
    return RallySegmentationRequestDto(
      matchDir: json['matchDir'] as String,
      config: RallySegmentationConfigDto.fromJson(
        json['config'] as Map<String, dynamic>,
      ),
    );
  }

  /// Match artifact directory.
  final String matchDir;

  /// Explicit, footage-tuned thresholds.
  final RallySegmentationConfigDto config;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'matchDir': matchDir,
        'config': config.toJson(),
      };
}

/// One proposed rally, never an accepted or scored point by itself.
class RallySuggestionDto {
  /// Creates a rally suggestion.
  const RallySuggestionDto({
    required this.id,
    required this.startSeconds,
    required this.endSeconds,
    required this.quality,
    required this.audioAvailable,
  });

  /// Reads a suggestion from its camelCase wire shape.
  factory RallySuggestionDto.fromJson(Map<String, dynamic> json) {
    return RallySuggestionDto(
      id: json['id'] as String,
      startSeconds: (json['startSeconds'] as num).toDouble(),
      endSeconds: (json['endSeconds'] as num).toDouble(),
      quality: (json['quality'] as num).toDouble(),
      audioAvailable: json['audioAvailable'] as bool,
    );
  }

  /// Stable identity within the analysis generation.
  final String id;

  /// Start on the original recording timeline, in seconds.
  final double startSeconds;

  /// End on the original recording timeline, in seconds.
  final double endSeconds;

  /// Heuristic quality from zero to one; not winner confidence.
  final double quality;

  /// Whether supporting audio evidence was supplied.
  final bool audioAvailable;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'startSeconds': startSeconds,
        'endSeconds': endSeconds,
        'quality': quality,
        'audioAvailable': audioAvailable,
      };
}

/// One classified span of the recording.
class RallyActivitySpanDto {
  /// Creates an activity span.
  const RallyActivitySpanDto({
    required this.startSeconds,
    required this.endSeconds,
    required this.kind,
  });

  /// Reads an activity span from its camelCase wire shape.
  factory RallyActivitySpanDto.fromJson(Map<String, dynamic> json) {
    return RallyActivitySpanDto(
      startSeconds: (json['startSeconds'] as num).toDouble(),
      endSeconds: (json['endSeconds'] as num).toDouble(),
      kind: json['kind'] as String,
    );
  }

  /// Start on the original recording timeline, in seconds.
  final double startSeconds;

  /// End on the original recording timeline, in seconds.
  final double endSeconds;

  /// `rally`, `rest`, or `unknown`.
  final String kind;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'startSeconds': startSeconds,
        'endSeconds': endSeconds,
        'kind': kind,
      };
}

/// Current completed suggestion set for a match.
class RallySuggestionsDto {
  /// Creates a suggestion set.
  const RallySuggestionsDto({
    required this.schemaVersion,
    required this.algorithmVersion,
    required this.generationId,
    required this.candidates,
    required this.timeline,
    required this.usableCoverage,
    required this.audioAvailable,
  });

  /// Reads a suggestion set from its camelCase wire shape.
  factory RallySuggestionsDto.fromJson(Map<String, dynamic> json) {
    return RallySuggestionsDto(
      schemaVersion: (json['schemaVersion'] as num).toInt(),
      algorithmVersion: (json['algorithmVersion'] as num).toInt(),
      generationId: json['generationId'] as String,
      candidates: (json['candidates'] as List<dynamic>? ?? const [])
          .map((e) => RallySuggestionDto.fromJson(
                e as Map<String, dynamic>,
              ))
          .toList(),
      timeline: (json['timeline'] as List<dynamic>? ?? const [])
          .map((e) => RallyActivitySpanDto.fromJson(
                e as Map<String, dynamic>,
              ))
          .toList(),
      usableCoverage: (json['usableCoverage'] as num).toDouble(),
      audioAvailable: json['audioAvailable'] as bool,
    );
  }

  /// File format version.
  final int schemaVersion;

  /// Segmenter version.
  final int algorithmVersion;

  /// Stable identity of the exact input generation.
  final String generationId;

  /// Rally proposals in recording order.
  final List<RallySuggestionDto> candidates;

  /// Rally, rest, and unknown partition.
  final List<RallyActivitySpanDto> timeline;

  /// Fraction supported by usable tracks.
  final double usableCoverage;

  /// Whether audio evidence was supplied.
  final bool audioAvailable;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'algorithmVersion': algorithmVersion,
        'generationId': generationId,
        'candidates': candidates.map((e) => e.toJson()).toList(),
        'timeline': timeline.map((e) => e.toJson()).toList(),
        'usableCoverage': usableCoverage,
        'audioAvailable': audioAvailable,
      };
}

/// One rally's known signals for highlight ranking.
class HighlightRallyDto {
  /// Creates a highlight rally.
  const HighlightRallyDto({
    required this.rallyId,
    required this.startSeconds,
    required this.endSeconds,
    required this.scoreContext,
    this.motion,
  });

  /// Reads a highlight rally from its camelCase wire shape.
  factory HighlightRallyDto.fromJson(Map<String, dynamic> json) {
    return HighlightRallyDto(
      rallyId: json['rallyId'] as String,
      startSeconds: (json['startSeconds'] as num).toDouble(),
      endSeconds: (json['endSeconds'] as num).toDouble(),
      motion: json['motion'] == null
          ? null
          : (json['motion'] as num).toDouble(),
      scoreContext: (json['scoreContext'] as num).toDouble(),
    );
  }

  /// Stable identity in the application's editing records.
  final String rallyId;

  /// Start on the original recording timeline, in seconds.
  final double startSeconds;

  /// End on the original recording timeline, in seconds.
  final double endSeconds;

  /// Motion quality from analysis, `0.0..=1.0`, when the rally came from a
  /// suggestion; absent for a hand-marked rally.
  final double? motion;

  /// Score context from `0.0..=1.0`: importance of the point, `0` when the
  /// rally is unscored.
  final double scoreContext;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'rallyId': rallyId,
        'startSeconds': startSeconds,
        'endSeconds': endSeconds,
        'motion': motion,
        'scoreContext': scoreContext,
      };
}

/// Ask the engine to rank rallies into a suggested highlight order.
class HighlightRankingRequestDto {
  /// Creates a highlight ranking request.
  const HighlightRankingRequestDto({required this.rallies});

  /// Reads a ranking request from its camelCase wire shape.
  factory HighlightRankingRequestDto.fromJson(Map<String, dynamic> json) {
    return HighlightRankingRequestDto(
      rallies: (json['rallies'] as List<dynamic>? ?? const [])
          .map((e) => HighlightRallyDto.fromJson(
                e as Map<String, dynamic>,
              ))
          .toList(),
    );
  }

  /// Rallies to rank, in any order.
  final List<HighlightRallyDto> rallies;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'rallies': rallies.map((e) => e.toJson()).toList(),
      };
}

/// One rally's computed place in the suggested highlight order.
class HighlightRankDto {
  /// Creates a highlight rank.
  const HighlightRankDto({
    required this.rallyId,
    required this.score,
    required this.rank,
  });

  /// Reads a highlight rank from its camelCase wire shape.
  factory HighlightRankDto.fromJson(Map<String, dynamic> json) {
    return HighlightRankDto(
      rallyId: json['rallyId'] as String,
      score: (json['score'] as num).toDouble(),
      rank: (json['rank'] as num).toInt(),
    );
  }

  /// Stable identity in the application's editing records.
  final String rallyId;

  /// Highlight score from `0.0..=1.0`, higher is better.
  final double score;

  /// `1`-based rank, best first.
  final int rank;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'rallyId': rallyId,
        'score': score,
        'rank': rank,
      };
}

/// One rally's known outcome, in recording order.
class RallyOutcomeDto {
  /// Creates a rally outcome.
  const RallyOutcomeDto({required this.rallyId, this.winner});

  /// Reads a rally outcome from its camelCase wire shape.
  factory RallyOutcomeDto.fromJson(Map<String, dynamic> json) {
    return RallyOutcomeDto(
      rallyId: json['rallyId'] as String,
      winner: json['winner'] == null
          ? null
          : RallySideDto.fromWire(json['winner'] as String),
    );
  }

  /// Stable identity in the application's editing records.
  final String rallyId;

  /// Confirmed winner, or `null` while the rally is unscored.
  final RallySideDto? winner;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'rallyId': rallyId,
        'winner': winner?.toWire(),
      };
}

/// Ask the engine to derive who served each rally.
class ServingSideRequestDto {
  /// Creates a serving side request.
  const ServingSideRequestDto({required this.rallies});

  /// Reads a serving side request from its camelCase wire shape.
  factory ServingSideRequestDto.fromJson(Map<String, dynamic> json) {
    return ServingSideRequestDto(
      rallies: (json['rallies'] as List<dynamic>? ?? const [])
          .map((e) => RallyOutcomeDto.fromJson(
                e as Map<String, dynamic>,
              ))
          .toList(),
    );
  }

  /// Rallies in recording order.
  final List<RallyOutcomeDto> rallies;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'rallies': rallies.map((e) => e.toJson()).toList(),
      };
}

/// Who served one rally.
class ServingSideDto {
  /// Creates a serving side result.
  const ServingSideDto({required this.rallyId, this.side});

  /// Reads a serving side result from its camelCase wire shape.
  factory ServingSideDto.fromJson(Map<String, dynamic> json) {
    return ServingSideDto(
      rallyId: json['rallyId'] as String,
      side: json['side'] == null
          ? null
          : RallySideDto.fromWire(json['side'] as String),
    );
  }

  /// Stable identity in the application's editing records.
  final String rallyId;

  /// The side that served this rally, or `null` when it cannot be derived.
  final RallySideDto? side;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'rallyId': rallyId,
        'side': side?.toWire(),
      };
}

/// Read only the sampled observations needed for a playback window.
class PlayerTrackWindowRequestDto {
  /// Creates a player track window request.
  const PlayerTrackWindowRequestDto({
    required this.matchDir,
    required this.startSeconds,
    required this.endSeconds,
  });

  /// Reads a track window request from its camelCase wire shape.
  factory PlayerTrackWindowRequestDto.fromJson(Map<String, dynamic> json) {
    return PlayerTrackWindowRequestDto(
      matchDir: json['matchDir'] as String,
      startSeconds: (json['startSeconds'] as num).toDouble(),
      endSeconds: (json['endSeconds'] as num).toDouble(),
    );
  }

  /// Match artifact directory.
  final String matchDir;

  /// Inclusive start on the original recording timeline, in seconds.
  final double startSeconds;

  /// Exclusive end on the original recording timeline, in seconds.
  final double endSeconds;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'matchDir': matchDir,
        'startSeconds': startSeconds,
        'endSeconds': endSeconds,
      };
}

/// Explicit, provisional thresholds for macOS player tracking.
class PlayerTrackingConfigDto {
  /// Creates a player tracking config.
  const PlayerTrackingConfigDto({
    required this.samplingRate,
    required this.minConfidence,
    required this.courtMargin,
    required this.netMargin,
    required this.maxTrackGapMs,
    required this.maxFrameGapMs,
    required this.maxGroundSpeedPerSecond,
    required this.ambiguityMargin,
    required this.minTrackObservations,
    required this.minCountFrames,
    required this.minCountFraction,
  });

  /// Reads a tracking config from its camelCase wire shape.
  factory PlayerTrackingConfigDto.fromJson(Map<String, dynamic> json) {
    return PlayerTrackingConfigDto(
      samplingRate: (json['samplingRate'] as num).toDouble(),
      minConfidence: (json['minConfidence'] as num).toDouble(),
      courtMargin: (json['courtMargin'] as num).toDouble(),
      netMargin: (json['netMargin'] as num).toDouble(),
      maxTrackGapMs: (json['maxTrackGapMs'] as num).toInt(),
      maxFrameGapMs: (json['maxFrameGapMs'] as num).toInt(),
      maxGroundSpeedPerSecond:
          (json['maxGroundSpeedPerSecond'] as num).toDouble(),
      ambiguityMargin: (json['ambiguityMargin'] as num).toDouble(),
      minTrackObservations: (json['minTrackObservations'] as num).toInt(),
      minCountFrames: (json['minCountFrames'] as num).toInt(),
      minCountFraction: (json['minCountFraction'] as num).toDouble(),
    );
  }

  /// Frame sampling rate in frames per second.
  final double samplingRate;

  /// Minimum confidence for a person box to enter tracking.
  final double minConfidence;

  /// Margin outside the marked court used to label borderline boxes.
  final double courtMargin;

  /// Court distance from the net where side is unknown.
  final double netMargin;

  /// Longest gap over which an old player ID may be reused.
  final int maxTrackGapMs;

  /// Longest interval between frames counted as continuous coverage.
  final int maxFrameGapMs;

  /// Maximum normalized image-plane ground-point travel per second.
  final double maxGroundSpeedPerSecond;

  /// Association cost difference below which identity stays ambiguous.
  final double ambiguityMargin;

  /// Minimum observations on a track before it supports count.
  final int minTrackObservations;

  /// Minimum adequately observed frames supporting a count.
  final int minCountFrames;

  /// Fraction of sampled frames required for a count assessment.
  final double minCountFraction;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'samplingRate': samplingRate,
        'minConfidence': minConfidence,
        'courtMargin': courtMargin,
        'netMargin': netMargin,
        'maxTrackGapMs': maxTrackGapMs,
        'maxFrameGapMs': maxFrameGapMs,
        'maxGroundSpeedPerSecond': maxGroundSpeedPerSecond,
        'ambiguityMargin': ambiguityMargin,
        'minTrackObservations': minTrackObservations,
        'minCountFrames': minCountFrames,
        'minCountFraction': minCountFraction,
      };
}

/// Start a local player-analysis job for an already imported match.
class PlayerTrackingRequestDto {
  /// Creates a player tracking request.
  const PlayerTrackingRequestDto({
    required this.matchDir,
    required this.config,
    this.runtimePath,
    this.modelPath,
  });

  /// Reads a tracking request from its camelCase wire shape.
  factory PlayerTrackingRequestDto.fromJson(Map<String, dynamic> json) {
    return PlayerTrackingRequestDto(
      matchDir: json['matchDir'] as String,
      config: PlayerTrackingConfigDto.fromJson(
        json['config'] as Map<String, dynamic>,
      ),
      runtimePath: json['runtimePath'] as String?,
      modelPath: json['modelPath'] as String?,
    );
  }

  /// Match artifact directory.
  final String matchDir;

  /// Explicit trial parameters, to be tuned on representative footage.
  final PlayerTrackingConfigDto config;

  /// Absolute path to the bundled TFLite runtime, when supplied by the client.
  final String? runtimePath;

  /// Absolute path to the bundled model weights, when supplied by the client.
  final String? modelPath;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'matchDir': matchDir,
        'config': config.toJson(),
        'runtimePath': runtimePath,
        'modelPath': modelPath,
      };
}

/// One interval of attempted or usable tracking, in seconds.
class TrackIntervalDto {
  /// Creates a track interval.
  const TrackIntervalDto({
    required this.startSeconds,
    required this.endSeconds,
  });

  /// Reads a track interval from its camelCase wire shape.
  factory TrackIntervalDto.fromJson(Map<String, dynamic> json) {
    return TrackIntervalDto(
      startSeconds: (json['startSeconds'] as num).toDouble(),
      endSeconds: (json['endSeconds'] as num).toDouble(),
    );
  }

  /// Inclusive start.
  final double startSeconds;

  /// Exclusive end.
  final double endSeconds;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'startSeconds': startSeconds,
        'endSeconds': endSeconds,
      };
}

/// One interrupted player track.
class PlayerGapDto {
  /// Creates a player gap.
  const PlayerGapDto({required this.trackId, required this.time});

  /// Reads a player gap from its camelCase wire shape.
  factory PlayerGapDto.fromJson(Map<String, dynamic> json) {
    return PlayerGapDto(
      trackId: (json['trackId'] as num).toInt(),
      time: TrackIntervalDto.fromJson(json['time'] as Map<String, dynamic>),
    );
  }

  /// Identity within this track generation.
  final int trackId;

  /// Interval without a reliable observation.
  final TrackIntervalDto time;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'trackId': trackId,
        'time': time.toJson(),
      };
}

/// A detected person in one upright sampled frame.
class PlayerObservationDto {
  /// Creates a player observation.
  const PlayerObservationDto({
    required this.confidence,
    required this.boxX,
    required this.boxY,
    required this.boxWidth,
    required this.boxHeight,
    required this.side,
    required this.selection,
    required this.associationAmbiguous,
    this.trackId,
    this.groundX,
    this.groundY,
    this.courtU,
    this.courtV,
  });

  /// Reads a player observation from its camelCase wire shape.
  factory PlayerObservationDto.fromJson(Map<String, dynamic> json) {
    return PlayerObservationDto(
      trackId: json['trackId'] == null
          ? null
          : (json['trackId'] as num).toInt(),
      confidence: (json['confidence'] as num).toDouble(),
      boxX: (json['boxX'] as num).toDouble(),
      boxY: (json['boxY'] as num).toDouble(),
      boxWidth: (json['boxWidth'] as num).toDouble(),
      boxHeight: (json['boxHeight'] as num).toDouble(),
      groundX: json['groundX'] == null
          ? null
          : (json['groundX'] as num).toDouble(),
      groundY: json['groundY'] == null
          ? null
          : (json['groundY'] as num).toDouble(),
      courtU:
          json['courtU'] == null ? null : (json['courtU'] as num).toDouble(),
      courtV:
          json['courtV'] == null ? null : (json['courtV'] as num).toDouble(),
      side: PlayerCourtSideDto.fromWire(json['side'] as String),
      selection: PersonSelectionDto.fromWire(json['selection'] as String),
      associationAmbiguous: json['associationAmbiguous'] as bool,
    );
  }

  /// Identity within this track generation, if association was reliable.
  final int? trackId;

  /// Detector confidence from zero to one.
  final double confidence;

  /// Box origin and size normalized to the upright displayed frame.
  final double boxX;
  final double boxY;
  final double boxWidth;
  final double boxHeight;

  /// Estimated ground contact, when the box is valid.
  final double? groundX;
  final double? groundY;

  /// Projected court position, when available.
  final double? courtU;
  final double? courtV;

  /// Side remains unknown when projection or net proximity is ambiguous.
  final PlayerCourtSideDto side;

  /// Selection decision for the box.
  final PersonSelectionDto selection;

  /// Whether multiple existing tracks could match this person.
  final bool associationAmbiguous;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'trackId': trackId,
        'confidence': confidence,
        'boxX': boxX,
        'boxY': boxY,
        'boxWidth': boxWidth,
        'boxHeight': boxHeight,
        'groundX': groundX,
        'groundY': groundY,
        'courtU': courtU,
        'courtV': courtV,
        'side': side.toWire(),
        'selection': selection.toWire(),
        'associationAmbiguous': associationAmbiguous,
      };
}

/// Detected people and track assignments in one sampled frame.
class PlayerTrackFrameDto {
  /// Creates a sampled track frame.
  const PlayerTrackFrameDto({
    required this.timestampSeconds,
    required this.people,
  });

  /// Reads a sampled track frame from its camelCase wire shape.
  factory PlayerTrackFrameDto.fromJson(Map<String, dynamic> json) {
    return PlayerTrackFrameDto(
      timestampSeconds: (json['timestampSeconds'] as num).toDouble(),
      people: (json['people'] as List<dynamic>? ?? const [])
          .map((e) => PlayerObservationDto.fromJson(
                e as Map<String, dynamic>,
              ))
          .toList(),
    );
  }

  /// Position on the original recording timeline, in seconds.
  final double timestampSeconds;

  /// All detected people, including rejected off-court candidates.
  final List<PlayerObservationDto> people;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'timestampSeconds': timestampSeconds,
        'people': people.map((e) => e.toJson()).toList(),
      };
}

/// Read-only review evidence for one completed track generation.
class PlayerTracksDto {
  /// Creates a player tracks result.
  const PlayerTracksDto({
    required this.schemaVersion,
    required this.modelId,
    required this.count,
    required this.countQuality,
    required this.countEvidence,
    required this.coverage,
    required this.usableCoverage,
    required this.gaps,
    required this.frames,
  });

  /// Reads a player tracks result from its camelCase wire shape.
  factory PlayerTracksDto.fromJson(Map<String, dynamic> json) {
    return PlayerTracksDto(
      schemaVersion: (json['schemaVersion'] as num).toInt(),
      modelId: json['modelId'] as String,
      count: ObservedPlayerCountDto.fromWire(json['count'] as String),
      countQuality: (json['countQuality'] as num).toDouble(),
      countEvidence: TrackIntervalDto.fromJson(
        json['countEvidence'] as Map<String, dynamic>,
      ),
      coverage: (json['coverage'] as List<dynamic>? ?? const [])
          .map((e) => TrackIntervalDto.fromJson(
                e as Map<String, dynamic>,
              ))
          .toList(),
      usableCoverage: (json['usableCoverage'] as List<dynamic>? ?? const [])
          .map((e) => TrackIntervalDto.fromJson(
                e as Map<String, dynamic>,
              ))
          .toList(),
      gaps: (json['gaps'] as List<dynamic>? ?? const [])
          .map((e) => PlayerGapDto.fromJson(
                e as Map<String, dynamic>,
              ))
          .toList(),
      frames: (json['frames'] as List<dynamic>? ?? const [])
          .map((e) => PlayerTrackFrameDto.fromJson(
                e as Map<String, dynamic>,
              ))
          .toList(),
    );
  }

  /// Version of the track artifact.
  final int schemaVersion;

  /// Exact detector name and version recorded by the producer.
  final String modelId;

  /// Sustained count or unknown.
  final ObservedPlayerCountDto count;

  /// Fraction of sampled frames supporting the count.
  final double countQuality;

  /// Interval evaluated for the count.
  final TrackIntervalDto countEvidence;

  /// Intervals where calibrated frames attempted to observe the court.
  final List<TrackIntervalDto> coverage;

  /// Intervals with observed players on both sides.
  final List<TrackIntervalDto> usableCoverage;

  /// Player-specific observation gaps.
  final List<PlayerGapDto> gaps;

  /// Sampled observations within the requested playback window.
  final List<PlayerTrackFrameDto> frames;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'modelId': modelId,
        'count': count.toWire(),
        'countQuality': countQuality,
        'countEvidence': countEvidence.toJson(),
        'coverage': coverage.map((e) => e.toJson()).toList(),
        'usableCoverage':
            usableCoverage.map((e) => e.toJson()).toList(),
        'gaps': gaps.map((e) => e.toJson()).toList(),
        'frames': frames.map((e) => e.toJson()).toList(),
      };
}

/// Media metadata the client shows and stores in its catalog.
class MediaMetadataDto {
  /// Creates media metadata.
  const MediaMetadataDto({
    required this.path,
    required this.durationSeconds,
    required this.frameRate,
    required this.width,
    required this.height,
    required this.rotationDegrees,
    required this.orientation,
    required this.hasAudio,
    required this.sizeBytes,
  });

  /// Reads media metadata from its camelCase wire shape.
  factory MediaMetadataDto.fromJson(Map<String, dynamic> json) {
    return MediaMetadataDto(
      path: json['path'] as String,
      durationSeconds: (json['durationSeconds'] as num).toDouble(),
      frameRate: (json['frameRate'] as num).toDouble(),
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
      rotationDegrees: (json['rotationDegrees'] as num).toInt(),
      orientation: OrientationDto.fromWire(json['orientation'] as String),
      hasAudio: json['hasAudio'] as bool,
      sizeBytes: (json['sizeBytes'] as num).toInt(),
    );
  }

  /// Path of the original recording, referenced in place.
  final String path;

  /// Duration in seconds.
  final double durationSeconds;

  /// Frame rate in frames per second.
  final double frameRate;

  /// Stored frame width in pixels, before rotation.
  final int width;

  /// Stored frame height in pixels, before rotation.
  final int height;

  /// Rotation implied by the container metadata.
  final int rotationDegrees;

  /// Display orientation derived from the rotation.
  final OrientationDto orientation;

  /// Whether the source contains an audio track.
  final bool hasAudio;

  /// Size of the original file in bytes.
  final int sizeBytes;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'path': path,
        'durationSeconds': durationSeconds,
        'frameRate': frameRate,
        'width': width,
        'height': height,
        'rotationDegrees': rotationDegrees,
        'orientation': orientation.toWire(),
        'hasAudio': hasAudio,
        'sizeBytes': sizeBytes,
      };
}

/// Progress within a stage.
class JobProgressDto {
  /// Creates job progress.
  const JobProgressDto({required this.stage, required this.value, this.message});

  /// Reads job progress from its camelCase wire shape.
  factory JobProgressDto.fromJson(Map<String, dynamic> json) {
    return JobProgressDto(
      stage: json['stage'] as String,
      value: (json['value'] as num).toDouble(),
      message: json['message'] as String?,
    );
  }

  /// Stage label, for example `proxy`.
  final String stage;

  /// Progress within the stage, in the range `0.0..=1.0`.
  final double value;

  /// Optional human-readable detail.
  final String? message;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'stage': stage,
        'value': value,
        'message': message,
      };
}

/// Current state of a job.
class JobStatusDto {
  /// Creates a job status.
  const JobStatusDto({
    required this.jobId,
    required this.matchId,
    required this.state,
    required this.completedStages,
    this.stage,
    this.progress,
    this.error,
  });

  /// Reads a job status from its camelCase wire shape.
  factory JobStatusDto.fromJson(Map<String, dynamic> json) {
    return JobStatusDto(
      jobId: json['jobId'] as String,
      matchId: json['matchId'] as String,
      state: JobStateDto.fromWire(json['state'] as String),
      stage: json['stage'] as String?,
      progress: json['progress'] == null
          ? null
          : JobProgressDto.fromJson(json['progress'] as Map<String, dynamic>),
      error: json['error'] as String?,
      completedStages:
          List<String>.from(json['completedStages'] as List<dynamic>? ?? const []),
    );
  }

  /// Stable job identifier.
  final String jobId;

  /// Match the job belongs to.
  final String matchId;

  /// Lifecycle state.
  final JobStateDto state;

  /// Stage currently executing, or the last stage reached.
  final String? stage;

  /// Latest progress within `stage`.
  final JobProgressDto? progress;

  /// Human-readable failure reason when `state` is `failed`.
  final String? error;

  /// Stages that have been checkpointed as complete.
  final List<String> completedStages;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'jobId': jobId,
        'matchId': matchId,
        'state': state.toWire(),
        'stage': stage,
        'progress': progress?.toJson(),
        'error': error,
        'completedStages': completedStages,
      };
}

/// Handle for a job the client started and can now follow.
class JobHandleDto {
  /// Creates a job handle.
  const JobHandleDto({required this.jobId, required this.matchId});

  /// Reads a job handle from its camelCase wire shape.
  factory JobHandleDto.fromJson(Map<String, dynamic> json) {
    return JobHandleDto(
      jobId: json['jobId'] as String,
      matchId: json['matchId'] as String,
    );
  }

  /// Stable job identifier.
  final String jobId;

  /// Match the job works on.
  final String matchId;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'jobId': jobId,
        'matchId': matchId,
      };
}

/// One derived artifact in the match directory.
class ArtifactDto {
  /// Creates an artifact record.
  const ArtifactDto({
    required this.kind,
    required this.relativePath,
    required this.state,
    this.sizeBytes,
  });

  /// Reads an artifact record from its camelCase wire shape.
  factory ArtifactDto.fromJson(Map<String, dynamic> json) {
    return ArtifactDto(
      kind: json['kind'] as String,
      relativePath: json['relativePath'] as String,
      state: ArtifactStateDto.fromWire(json['state'] as String),
      sizeBytes: json['sizeBytes'] == null
          ? null
          : (json['sizeBytes'] as num).toInt(),
    );
  }

  /// Artifact kind, for example `proxy` or `analysis_audio`.
  final String kind;

  /// Path relative to the match directory.
  final String relativePath;

  /// Whether the artifact is final, partial, or missing.
  final ArtifactStateDto state;

  /// Size in bytes, when known.
  final int? sizeBytes;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind,
        'relativePath': relativePath,
        'state': state.toWire(),
        'sizeBytes': sizeBytes,
      };
}

/// The artifact manifest as the client sees it.
class ArtifactManifestDto {
  /// Creates an artifact manifest.
  const ArtifactManifestDto({
    required this.matchId,
    required this.originalPath,
    required this.artifacts,
    required this.missingKinds,
    required this.notRebuildableKinds,
    required this.originalPresent,
  });

  /// Reads an artifact manifest from its camelCase wire shape.
  factory ArtifactManifestDto.fromJson(Map<String, dynamic> json) {
    return ArtifactManifestDto(
      matchId: json['matchId'] as String,
      originalPath: json['originalPath'] as String,
      artifacts: (json['artifacts'] as List<dynamic>? ?? const [])
          .map((e) => ArtifactDto.fromJson(
                e as Map<String, dynamic>,
              ))
          .toList(),
      missingKinds:
          List<String>.from(json['missingKinds'] as List<dynamic>? ?? const []),
      notRebuildableKinds: List<String>.from(
        json['notRebuildableKinds'] as List<dynamic>? ?? const [],
      ),
      originalPresent: json['originalPresent'] as bool,
    );
  }

  /// Match identifier.
  final String matchId;

  /// Path of the original recording, referenced in place.
  final String originalPath;

  /// Artifacts recorded for this match.
  final List<ArtifactDto> artifacts;

  /// Artifact kinds recorded but missing from disk.
  final List<String> missingKinds;

  /// Missing artifact kinds the engine cannot rebuild on its own, because they
  /// are the user's own input or need a request the caller supplies.
  final List<String> notRebuildableKinds;

  /// Whether the original recording is still where the manifest says it is.
  final bool originalPresent;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'matchId': matchId,
        'originalPath': originalPath,
        'artifacts': artifacts.map((e) => e.toJson()).toList(),
        'missingKinds': missingKinds,
        'notRebuildableKinds': notRebuildableKinds,
        'originalPresent': originalPresent,
      };
}

/// One court corner, in normalized displayed frame coordinates.
class CourtCornerDto {
  /// Creates a court corner.
  const CourtCornerDto({required this.x, required this.y});

  /// Reads a court corner from its camelCase wire shape.
  factory CourtCornerDto.fromJson(Map<String, dynamic> json) {
    return CourtCornerDto(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  /// Horizontal position, `0.0` at the left edge.
  final double x;

  /// Vertical position, `0.0` at the top edge.
  final double y;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'x': x,
        'y': y,
      };
}

/// One calibrated span of a recording.
class CalibrationSegmentDto {
  /// Creates a calibration segment.
  const CalibrationSegmentDto({
    required this.fromMs,
    required this.corners,
    required this.orientation,
  });

  /// Reads a calibration segment from its camelCase wire shape.
  factory CalibrationSegmentDto.fromJson(Map<String, dynamic> json) {
    return CalibrationSegmentDto(
      fromMs: (json['fromMs'] as num).toInt(),
      corners: (json['corners'] as List<dynamic>? ?? const [])
          .map((e) => CourtCornerDto.fromJson(
                e as Map<String, dynamic>,
              ))
          .toList(),
      orientation: CourtOrientationDto.fromWire(
        json['orientation'] as String,
      ),
    );
  }

  /// Timestamp on the recording timeline where this segment begins, in
  /// milliseconds.
  final int fromMs;

  /// The four court corners, in the order the user marked them.
  final List<CourtCornerDto> corners;

  /// Which way the court runs relative to the camera.
  final CourtOrientationDto orientation;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'fromMs': fromMs,
        'corners': corners.map((e) => e.toJson()).toList(),
        'orientation': orientation.toWire(),
      };
}

/// A match's court calibration.
class CourtCalibrationDto {
  /// Creates a court calibration.
  const CourtCalibrationDto({
    required this.schemaVersion,
    required this.segments,
  });

  /// Reads a court calibration from its camelCase wire shape.
  factory CourtCalibrationDto.fromJson(Map<String, dynamic> json) {
    return CourtCalibrationDto(
      schemaVersion: (json['schemaVersion'] as num).toInt(),
      segments: (json['segments'] as List<dynamic>? ?? const [])
          .map((e) => CalibrationSegmentDto.fromJson(
                e as Map<String, dynamic>,
              ))
          .toList(),
    );
  }

  /// Schema version of the record.
  final int schemaVersion;

  /// Calibrated spans, in recording order.
  final List<CalibrationSegmentDto> segments;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'segments':
            segments.map((e) => e.toJson()).toList(),
      };
}

/// The geometry one calibrated segment defines.
class CourtGeometryDto {
  /// Creates court geometry.
  const CourtGeometryDto({
    required this.imageToCourt,
    required this.courtToImage,
    required this.corners,
    required this.net,
  });

  /// Reads court geometry from its camelCase wire shape.
  factory CourtGeometryDto.fromJson(Map<String, dynamic> json) {
    return CourtGeometryDto(
      imageToCourt: (json['imageToCourt'] as List<dynamic>? ?? const [])
          .map((e) => (e as num).toDouble())
          .toList(),
      courtToImage: (json['courtToImage'] as List<dynamic>? ?? const [])
          .map((e) => (e as num).toDouble())
          .toList(),
      corners: (json['corners'] as List<dynamic>? ?? const [])
          .map((e) => CourtCornerDto.fromJson(
                e as Map<String, dynamic>,
              ))
          .toList(),
      net: (json['net'] as List<dynamic>? ?? const [])
          .map((e) => CourtCornerDto.fromJson(
                e as Map<String, dynamic>,
              ))
          .toList(),
    );
  }

  /// Row-major 3x3 mapping from normalized image coordinates to court
  /// coordinates, as nine values.
  final List<double> imageToCourt;

  /// Row-major 3x3 mapping from court coordinates back to normalized image
  /// coordinates, as nine values.
  final List<double> courtToImage;

  /// The four court corners, in the order they were marked.
  final List<CourtCornerDto> corners;

  /// The two ends of the net line, in normalized image coordinates.
  final List<CourtCornerDto> net;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'imageToCourt': imageToCourt,
        'courtToImage': courtToImage,
        'corners': corners.map((e) => e.toJson()).toList(),
        'net': net.map((e) => e.toJson()).toList(),
      };
}

/// Request to store a match's court calibration.
class CalibrationSaveRequestDto {
  /// Creates a calibration save request.
  const CalibrationSaveRequestDto({
    required this.matchDir,
    required this.calibration,
  });

  /// Reads a calibration save request from its camelCase wire shape.
  factory CalibrationSaveRequestDto.fromJson(Map<String, dynamic> json) {
    return CalibrationSaveRequestDto(
      matchDir: json['matchDir'] as String,
      calibration: CourtCalibrationDto.fromJson(
        json['calibration'] as Map<String, dynamic>,
      ),
    );
  }

  /// Directory holding the match's artifacts.
  final String matchDir;

  /// The calibration to store, replacing any already recorded.
  final CourtCalibrationDto calibration;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'matchDir': matchDir,
        'calibration': calibration.toJson(),
      };
}

/// What storing a calibration did.
class CalibrationSaveDto {
  /// Creates a calibration save result.
  const CalibrationSaveDto({
    required this.changed,
    required this.invalidatedKinds,
    required this.geometry,
  });

  /// Reads a calibration save result from its camelCase wire shape.
  factory CalibrationSaveDto.fromJson(Map<String, dynamic> json) {
    return CalibrationSaveDto(
      changed: json['changed'] as bool,
      invalidatedKinds: List<String>.from(
        json['invalidatedKinds'] as List<dynamic>? ?? const [],
      ),
      geometry: (json['geometry'] as List<dynamic>? ?? const [])
          .map((e) => CourtGeometryDto.fromJson(
                e as Map<String, dynamic>,
              ))
          .toList(),
    );
  }

  /// Whether the stored calibration differs from the one it replaced.
  final bool changed;

  /// Artifact kinds invalidated because they were derived from the previous
  /// calibration rather than the new one.
  final List<String> invalidatedKinds;

  /// The geometry of each stored segment, in the same order.
  final List<CourtGeometryDto> geometry;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'changed': changed,
        'invalidatedKinds': invalidatedKinds,
        'geometry': geometry.map((e) => e.toJson()).toList(),
      };
}

/// Request to import a recording into a match directory.
class MediaImportRequestDto {
  /// Creates a media import request.
  const MediaImportRequestDto({
    required this.matchId,
    required this.originalPath,
    required this.matchDir,
    required this.samplingRate,
  });

  /// Reads a media import request from its camelCase wire shape.
  factory MediaImportRequestDto.fromJson(Map<String, dynamic> json) {
    return MediaImportRequestDto(
      matchId: json['matchId'] as String,
      originalPath: json['originalPath'] as String,
      matchDir: json['matchDir'] as String,
      samplingRate: (json['samplingRate'] as num).toDouble(),
    );
  }

  /// Match identifier; also the match directory name.
  final String matchId;

  /// Original recording. Referenced in place, never copied or modified.
  final String originalPath;

  /// Directory that holds this match's derived artifacts.
  final String matchDir;

  /// Frame sampling rate, in frames per second.
  final double samplingRate;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'matchId': matchId,
        'originalPath': originalPath,
        'matchDir': matchDir,
        'samplingRate': samplingRate,
      };
}

/// One clip in an export request.
class EditClipDto {
  /// Creates an edit clip.
  const EditClipDto({
    required this.startSeconds,
    required this.endSeconds,
    this.overlayPath,
  });

  /// Reads an edit clip from its camelCase wire shape.
  factory EditClipDto.fromJson(Map<String, dynamic> json) {
    return EditClipDto(
      startSeconds: (json['startSeconds'] as num).toDouble(),
      endSeconds: (json['endSeconds'] as num).toDouble(),
      overlayPath: json['overlayPath'] as String?,
    );
  }

  /// Start of the clip in the source recording, in seconds.
  final double startSeconds;

  /// End of the clip in the source recording, in seconds.
  final double endSeconds;

  /// Image the application rendered of the score at this clip, composited
  /// over it for its whole duration.
  final String? overlayPath;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'startSeconds': startSeconds,
        'endSeconds': endSeconds,
        'overlayPath': overlayPath,
      };
}

/// The card shown before the first clip.
class EditTitleDto {
  /// Creates an edit title card.
  const EditTitleDto({required this.imagePath, required this.seconds});

  /// Reads an edit title card from its camelCase wire shape.
  factory EditTitleDto.fromJson(Map<String, dynamic> json) {
    return EditTitleDto(
      imagePath: json['imagePath'] as String,
      seconds: (json['seconds'] as num).toDouble(),
    );
  }

  /// Image the application rendered for the title card.
  final String imagePath;

  /// How long the card is shown, in seconds.
  final double seconds;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'imagePath': imagePath,
        'seconds': seconds,
      };
}

/// Everything needed to render one highlight video.
class ExportRequestDto {
  /// Creates an export request.
  const ExportRequestDto({
    required this.matchId,
    required this.matchDir,
    required this.sourcePath,
    required this.clips,
    required this.leadInSeconds,
    required this.leadOutSeconds,
    required this.musicGain,
    this.title,
    this.musicPath,
  });

  /// Reads an export request from its camelCase wire shape.
  factory ExportRequestDto.fromJson(Map<String, dynamic> json) {
    return ExportRequestDto(
      matchId: json['matchId'] as String,
      matchDir: json['matchDir'] as String,
      sourcePath: json['sourcePath'] as String,
      clips: (json['clips'] as List<dynamic>? ?? const [])
          .map((e) => EditClipDto.fromJson(
                e as Map<String, dynamic>,
              ))
          .toList(),
      leadInSeconds: (json['leadInSeconds'] as num).toDouble(),
      leadOutSeconds: (json['leadOutSeconds'] as num).toDouble(),
      title: json['title'] == null
          ? null
          : EditTitleDto.fromJson(json['title'] as Map<String, dynamic>),
      musicPath: json['musicPath'] as String?,
      musicGain: (json['musicGain'] as num).toDouble(),
    );
  }

  /// Match the export belongs to.
  final String matchId;

  /// Directory holding this match's artifacts; the reel is written inside it.
  final String matchDir;

  /// Recording to read. Referenced in place, never modified.
  final String sourcePath;

  /// Clips, in the order they must appear in the reel.
  final List<EditClipDto> clips;

  /// Material added before each clip, in seconds.
  final double leadInSeconds;

  /// Material added after each clip, in seconds.
  final double leadOutSeconds;

  /// Title card, when the user asked for one.
  final EditTitleDto? title;

  /// Music mixed under the match audio.
  final String? musicPath;

  /// Music volume relative to the match audio, in the range `0.0..=1.0`.
  final double musicGain;

  /// Writes the camelCase wire shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'matchId': matchId,
        'matchDir': matchDir,
        'sourcePath': sourcePath,
        'clips': clips.map((e) => e.toJson()).toList(),
        'leadInSeconds': leadInSeconds,
        'leadOutSeconds': leadOutSeconds,
        'title': title?.toJson(),
        'musicPath': musicPath,
        'musicGain': musicGain,
      };
}
