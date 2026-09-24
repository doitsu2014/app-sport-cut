import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bridge/sportcut_engine.dart';
import '../../library/domain/match_record.dart';
import '../../library/presentation/library_providers.dart';
import '../data/calibration_bridge.dart';
import '../domain/court_calibration.dart';

/// Where the four handles start before the user moves them.
///
/// A court seen from behind a baseline: the near edge is wider than the far one,
/// and both sit inside the frame so every handle is reachable.
const List<CourtCorner> _defaultCorners = <CourtCorner>[
  CourtCorner(x: 0.10, y: 0.88),
  CourtCorner(x: 0.90, y: 0.88),
  CourtCorner(x: 0.72, y: 0.28),
  CourtCorner(x: 0.28, y: 0.28),
];

/// What the calibration screen is showing.
class CalibrationState {
  /// Describe a calibration in progress.
  const CalibrationState({
    this.corners = _defaultCorners,
    this.orientation = CourtOrientation.away,
    this.geometry,
    this.problem,
    this.saving = false,
    this.loaded = false,
    this.stored = false,
  });

  /// The four court corners, in the order the user marks them.
  final List<CourtCorner> corners;

  /// Which way the court runs relative to the camera.
  final CourtOrientation orientation;

  /// The projected court, once the engine has been asked for it.
  final CourtGeometryDto? geometry;

  /// Why the calibration cannot be used, or why saving failed.
  final String? problem;

  /// Whether a save is in flight.
  final bool saving;

  /// Whether the match's stored calibration has been read.
  final bool loaded;

  /// Whether this match already had a calibration when the screen opened.
  final bool stored;

  /// Whether four corners are marked and inside the frame.
  bool get isComplete =>
      corners.length == 4 && corners.every((corner) => corner.isInsideFrame);

  /// Whether the projected court can be drawn.
  bool get isProjected => geometry != null;

  /// This state with the given fields replaced.
  CalibrationState copyWith({
    List<CourtCorner>? corners,
    CourtOrientation? orientation,
    CourtGeometryDto? geometry,
    String? problem,
    bool? saving,
    bool? loaded,
    bool? stored,
    bool clearGeometry = false,
    bool clearProblem = false,
  }) =>
      CalibrationState(
        corners: corners ?? this.corners,
        orientation: orientation ?? this.orientation,
        geometry: clearGeometry ? null : (geometry ?? this.geometry),
        problem: clearProblem ? null : (problem ?? this.problem),
        saving: saving ?? this.saving,
        loaded: loaded ?? this.loaded,
        stored: stored ?? this.stored,
      );
}

/// Holds the court the user is marking, and asks the engine to project it.
///
/// The engine owns the homography, so this controller never computes geometry:
/// during a drag it holds the corners, and it asks for the projection when the
/// user lets go.
class CalibrationController extends Notifier<CalibrationState> {
  @override
  CalibrationState build() => const CalibrationState();

  /// Load whatever this match already has marked.
  void open(MatchRecord match) {
    final calibration = match.courtCalibration;
    final segment = calibration?.firstSegment;
    if (segment == null) {
      state = const CalibrationState(loaded: true);
      return;
    }
    state = CalibrationState(
      corners: List<CourtCorner>.of(segment.corners),
      orientation: segment.orientation,
      loaded: true,
      stored: true,
    );
    unawaited(project());
  }

  /// Move one corner by a normalized offset.
  ///
  /// An offset rather than a position: a drag can deliver several updates
  /// between two rebuilds, and each one has to move the corner as this
  /// controller currently holds it rather than as the last frame drew it.
  /// Geometry is left stale until [project] is called, because a drag draws the
  /// quadrilateral from the corners alone.
  void nudgeCorner(int index, double dx, double dy) {
    if (index < 0 || index >= state.corners.length) {
      return;
    }
    final current = state.corners[index];
    final moved = List<CourtCorner>.of(state.corners);
    // Clamped rather than rejected: a handle dragged past the edge of the frame
    // stops there, which is what a user dragging it expects.
    moved[index] = CourtCorner(
      x: (current.x + dx).clamp(0.0, 1.0),
      y: (current.y + dy).clamp(0.0, 1.0),
    );
    state = state.copyWith(corners: moved, clearProblem: true);
  }

  /// Record which way the court runs and re-project against it.
  Future<void> setOrientation(CourtOrientation orientation) async {
    if (orientation == state.orientation) {
      return;
    }
    state = state.copyWith(orientation: orientation, clearProblem: true);
    await project();
  }

  /// Ask the engine to project the court these corners define.
  Future<void> project() async {
    state = state.copyWith(clearProblem: true);
    if (!state.isComplete) {
      state = state.copyWith(clearGeometry: true);
      return;
    }
    try {
      final geometry = await ref.read(mediaEngineProvider).courtGeometry(
            toSegmentDto(_segmentInProgress()),
          );
      state = state.copyWith(geometry: geometry, clearProblem: true);
    } on SportcutEngineException catch (error) {
      state = state.copyWith(clearGeometry: true, problem: error.message);
    } on Object catch (error) {
      state = state.copyWith(
        clearGeometry: true,
        problem: 'The court could not be projected: $error',
      );
    }
  }

  /// Store the marked court with the match.
  ///
  /// Returns the updated match when it was saved, so the caller can refresh the
  /// library, and `null` when it was rejected or failed.
  Future<MatchRecord?> save(MatchRecord match) async {
    if (!state.isComplete || state.saving) {
      return null;
    }
    state = state.copyWith(saving: true, clearProblem: true);
    try {
      final repository = await ref.read(matchRepositoryProvider.future);
      final updated = await repository.saveCalibration(
        match,
        CourtCalibration.fromCorners(
          corners: state.corners,
          orientation: state.orientation,
        ),
      );
      state = state.copyWith(saving: false, stored: true, clearProblem: true);
      return updated;
    } on Object catch (error) {
      state = state.copyWith(
        saving: false,
        problem: 'The court could not be saved: $error',
      );
      return null;
    }
  }

  /// The segment the user is marking.
  CalibrationSegment _segmentInProgress() => CalibrationSegment(
        fromMs: 0,
        corners: state.corners,
        orientation: state.orientation,
      );
}

/// The court being marked on the calibration screen.
final calibrationControllerProvider =
    NotifierProvider<CalibrationController, CalibrationState>(
  CalibrationController.new,
);
