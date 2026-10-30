import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/components/sc_calibration_overlay.dart';
import '../../../bridge/models.dart';
import '../../library/domain/match_record.dart';
import 'calibration_controller.dart';

/// The calibration overlay drawn on the shared studio preview.
///
/// The host maps the controller's normalised corners into the box it is given
/// by [ScVideoStage], which is the same aspect-fit box the footage occupies.
/// That is what keeps a drag on the video and a normalised corner the same
/// point (ADR-0003 D15; PR 4c): a position divided by this box is the
/// coordinate the recording's frames use.
///
/// The host owns only the interaction state [ScCalibrationOverlay] needs — the
/// active handle and whether a drag is in progress — and asks the engine to
/// re-project once the pointer is released. Save, orientation, and the
/// validation message live in `CalibrationPanel`.
class CalibrationOverlayHost extends ConsumerStatefulWidget {
  /// Build the overlay for [match].
  const CalibrationOverlayHost({super.key, required this.match});

  /// Match whose corners are being marked.
  final MatchRecord match;

  @override
  ConsumerState<CalibrationOverlayHost> createState() =>
      _CalibrationOverlayHostState();
}

class _CalibrationOverlayHostState
    extends ConsumerState<CalibrationOverlayHost> {
  /// The handle the user pressed, or -1 when none is active.
  int _activeIndex = -1;

  /// Whether a handle drag is waiting for its release.
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(covariant CalibrationOverlayHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.id != widget.match.id) {
      _open();
    }
  }

  /// Load whatever this match already has marked, after the frame so the
  /// controller's first state has been delivered to the tree.
  void _open() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(calibrationControllerProvider.notifier).open(widget.match);
    });
  }

  /// Mark a handle active and leave dragging off until a pan actually moves.
  void _select(int index) {
    setState(() {
      _activeIndex = index;
      _dragging = false;
    });
  }

  /// Move the handle to the pointer's normalised position.
  ///
  /// The controller takes an offset rather than a position, so the pointer is
  /// compared with the corner as the controller currently holds it. Reading
  /// the state here rather than from the last build keeps the drag exact even
  /// when several pointer updates arrive between two frames.
  void _drag(int index, Offset position) {
    final corners = ref.read(calibrationControllerProvider).corners;
    if (index < 0 || index >= corners.length) {
      return;
    }
    final corner = corners[index];
    if (!_dragging) {
      setState(() => _dragging = true);
    }
    ref
        .read(calibrationControllerProvider.notifier)
        .nudgeCorner(index, position.dx - corner.x, position.dy - corner.y);
  }

  /// Clear the active handle and ask the engine to project the court.
  ///
  /// The [Listener] uses its default `deferToChild` behaviour, so it observes
  /// releases only where a handle is hit and leaves the preview's transport
  /// reachable everywhere else.
  void _release() {
    if (!_dragging && _activeIndex < 0) {
      return;
    }
    final wasDragging = _dragging;
    setState(() {
      _activeIndex = -1;
      _dragging = false;
    });
    if (wasDragging) {
      unawaited(ref.read(calibrationControllerProvider.notifier).project());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calibrationControllerProvider);
    final corners = <Offset>[
      for (final corner in state.corners) Offset(corner.x, corner.y),
    ];
    final geometry = _geometry(state.geometry);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final box = Size(constraints.maxWidth, constraints.maxHeight);
        if (box.isEmpty) {
          return const SizedBox.shrink();
        }
        return Listener(
          onPointerUp: (_) => _release(),
          onPointerCancel: (_) => _release(),
          child: ScCalibrationOverlay(
            box: box,
            corners: corners,
            geometry: geometry,
            activeIndex: _activeIndex,
            onSelect: _select,
            onDrag: _drag,
          ),
        );
      },
    );
  }

  /// The engine's projected outline and net, normalized to the displayed box.
  ///
  /// A payload with the wrong shape or a point outside the frame is treated as
  /// "nothing projected": the overlay then draws no court rather than a
  /// plausible but wrong one (security review S-1).
  ScCourtGeometry? _geometry(CourtGeometryDto? dto) {
    if (dto == null) {
      return null;
    }
    Offset clamp(CourtCornerDto point) => Offset(
          point.x.clamp(0.0, 1.0).toDouble(),
          point.y.clamp(0.0, 1.0).toDouble(),
        );
    final geometry = ScCourtGeometry(
      outline: <Offset>[for (final corner in dto.corners) clamp(corner)],
      net: <Offset>[for (final point in dto.net) clamp(point)],
    );
    return geometry.isValid ? geometry : null;
  }
}
