import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/domain/match_record.dart';
import '../../library/presentation/library_providers.dart';
import '../../library/presentation/playback_controller.dart';
import 'calibration_view.dart';

/// Full-screen route wrapper for court calibration.
///
/// The screen owns its playback controller for the route's lifetime and hosts
/// [CalibrationView], which the studio also hosts with a shared controller.
class CalibrationScreen extends ConsumerStatefulWidget {
  /// Build the calibration screen.
  ///
  /// [controller] is injected by tests; the app uses the platform player.
  const CalibrationScreen({
    required this.match,
    this.controller,
    super.key,
  });

  /// Match being calibrated.
  final MatchRecord match;

  /// Playback backend, when supplied by a test.
  final PlaybackController? controller;

  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends ConsumerState<CalibrationScreen> {
  late final PlaybackController _playback;
  late final bool _ownsPlayback;

  @override
  void initState() {
    super.initState();
    _playback =
        widget.controller ?? ref.read(playbackControllerFactoryProvider)();
    _ownsPlayback = widget.controller == null;
    unawaited(_playback.load(widget.match.videoPath));
  }

  @override
  void dispose() {
    if (_ownsPlayback) {
      unawaited(_playback.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Court calibration')),
      body: CalibrationView(
        match: widget.match,
        controller: _playback,
        onSaved: (updated) => Navigator.of(context).pop(updated),
      ),
    );
  }
}
