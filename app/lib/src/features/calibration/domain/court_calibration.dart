/// The court calibration a user marks on a recording.
///
/// The application owns this value: it is the user's own input, it is stored in
/// the catalog as the source of truth, and the engine is handed a copy so it can
/// project the same calibration into the match directory. Corners are in
/// normalized displayed frame coordinates, so one calibration is valid for the
/// preview, the proxy, and the sampled frames alike.
library;

/// One court corner, in normalized displayed frame coordinates.
///
/// `(0, 0)` is the top-left of the frame as the user sees it and `(1, 1)` the
/// bottom-right, whatever the recording's stored pixel dimensions or rotation.
class CourtCorner {
  /// Build a corner.
  const CourtCorner({required this.x, required this.y});

  /// Horizontal position, `0.0` at the left edge.
  final double x;

  /// Vertical position, `0.0` at the top edge.
  final double y;

  /// Whether this corner is a finite position inside the frame.
  bool get isInsideFrame =>
      x.isFinite && y.isFinite && x >= 0 && x <= 1 && y >= 0 && y <= 1;

  /// This corner as JSON.
  Map<String, Object?> toJson() => <String, Object?>{'x': x, 'y': y};

  /// Read a corner from JSON, or `null` when the value is not a position.
  static CourtCorner? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final x = json['x'];
    final y = json['y'];
    if (x is! num || y is! num) {
      return null;
    }
    return CourtCorner(x: x.toDouble(), y: y.toDouble());
  }

  @override
  bool operator ==(Object other) =>
      other is CourtCorner && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'CourtCorner($x, $y)';
}

/// Which way the court runs relative to where the camera was standing.
///
/// The four corners are read in image order, so on their own they cannot say
/// whether the edge nearest the camera is a baseline or a sideline. This is that
/// answer, and it is what places the net.
enum CourtOrientation {
  /// The court stretches away from the camera, so the nearest edge is a
  /// baseline and the net cuts across the court's depth.
  away,

  /// The court stretches across the view, so the nearest edge is a sideline and
  /// the net runs from one side of the view to the other.
  across;

  /// The name this orientation is stored under.
  String get wireName => name;

  /// Read an orientation from its stored name, or `null` when it is unknown.
  static CourtOrientation? fromWireName(Object? name) {
    for (final orientation in CourtOrientation.values) {
      if (orientation.wireName == name) {
        return orientation;
      }
    }
    return null;
  }
}

/// One calibrated span of a recording.
///
/// A recording holds a list of these so a camera that gets moved part-way
/// through can be re-marked without discarding the earlier calibration. A
/// segment runs until the next one begins, or to the end of the recording.
class CalibrationSegment {
  /// Build a segment.
  const CalibrationSegment({
    required this.fromMs,
    required this.corners,
    required this.orientation,
  });

  /// Timestamp on the recording timeline where this segment begins, in
  /// milliseconds.
  final int fromMs;

  /// The four court corners, in the order the user marked them: nearest the
  /// camera on the left, nearest on the right, farthest on the right, then
  /// farthest on the left.
  final List<CourtCorner> corners;

  /// Which way the court runs relative to the camera.
  final CourtOrientation orientation;

  /// Whether this segment has four corners, all of them inside the frame.
  bool get isComplete =>
      corners.length == 4 && corners.every((corner) => corner.isInsideFrame);

  /// This segment as JSON.
  Map<String, Object?> toJson() => <String, Object?>{
        'from_ms': fromMs,
        'corners': corners.map((corner) => corner.toJson()).toList(),
        'orientation': orientation.wireName,
      };

  /// Read a segment from JSON, or `null` when the value is not a segment.
  static CalibrationSegment? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final fromMs = json['from_ms'];
    final corners = json['corners'];
    final orientation = CourtOrientation.fromWireName(json['orientation']);
    if (fromMs is! num || corners is! List || orientation == null) {
      return null;
    }
    final parsed = <CourtCorner>[];
    for (final corner in corners) {
      final point = CourtCorner.fromJson(corner);
      if (point == null) {
        return null;
      }
      parsed.add(point);
    }
    return CalibrationSegment(
      fromMs: fromMs.toInt(),
      corners: parsed,
      orientation: orientation,
    );
  }
}

/// A match's court calibration.
class CourtCalibration {
  /// Build a calibration.
  const CourtCalibration({required this.segments, this.schemaVersion = 1});

  /// A calibration from one set of corners covering the whole recording.
  CourtCalibration.fromCorners({
    required List<CourtCorner> corners,
    CourtOrientation orientation = CourtOrientation.away,
  }) : this(
          segments: <CalibrationSegment>[
            CalibrationSegment(
              fromMs: 0,
              corners: corners,
              orientation: orientation,
            ),
          ],
        );

  /// Schema version of the stored record.
  final int schemaVersion;

  /// Calibrated spans, in recording order.
  final List<CalibrationSegment> segments;

  /// Whether there is at least one complete segment.
  bool get isComplete =>
      segments.isNotEmpty && segments.every((segment) => segment.isComplete);

  /// The first calibrated span, when there is one.
  ///
  /// A recording the user has calibrated in one go — which is every recording
  /// the application currently produces — has exactly this one segment.
  CalibrationSegment? get firstSegment =>
      segments.isEmpty ? null : segments.first;

  /// This calibration as JSON, for the catalog column.
  Map<String, Object?> toJson() => <String, Object?>{
        'schema_version': schemaVersion,
        'segments': segments.map((segment) => segment.toJson()).toList(),
      };

  /// Read a calibration from JSON, or `null` when the value is not one.
  static CourtCalibration? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final version = json['schema_version'];
    final segments = json['segments'];
    if (version is! num || segments is! List) {
      return null;
    }
    final parsed = <CalibrationSegment>[];
    for (final segment in segments) {
      final value = CalibrationSegment.fromJson(segment);
      if (value == null) {
        return null;
      }
      parsed.add(value);
    }
    return CourtCalibration(
      schemaVersion: version.toInt(),
      segments: parsed,
    );
  }
}
