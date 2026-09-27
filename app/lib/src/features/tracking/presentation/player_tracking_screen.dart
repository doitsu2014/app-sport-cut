import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../library/domain/match_record.dart';
import '../../library/presentation/library_providers.dart';
import '../../library/presentation/playback_controller.dart';
import 'player_tracking_view.dart';

/// Full-screen route wrapper for player analysis.
///
/// The screen owns its playback controller for the route's lifetime and hosts
/// [PlayerTrackingView], which the studio also hosts with a shared controller.
class PlayerTrackingScreen extends ConsumerStatefulWidget {
  const PlayerTrackingScreen({
    required this.match,
    this.controller,
    super.key,
  });

  final MatchRecord match;

  /// Playback backend, when supplied by a test or the studio.
  final PlaybackController? controller;

  @override
  ConsumerState<PlayerTrackingScreen> createState() =>
      _PlayerTrackingScreenState();
}

class _PlayerTrackingScreenState extends ConsumerState<PlayerTrackingScreen> {
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
      appBar: AppBar(title: const Text('Player analysis')),
      body: PlayerTrackingView(
        match: widget.match,
        controller: _playback,
        onOpenScore: () => Navigator.of(context).pushNamed(
          AppRoutes.score,
          arguments: widget.match,
        ),
      ),
    );
  }
}
