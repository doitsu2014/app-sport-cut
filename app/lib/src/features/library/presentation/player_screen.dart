import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/match_record.dart';
import 'library_providers.dart';
import 'playback_controller.dart';
import 'player_view.dart';

/// Local playback of one match, with the standard transport controls.
///
/// Playback is offline by construction: the file lives on the device and the
/// engine's probe already established that it is readable.
class PlayerScreen extends ConsumerStatefulWidget {
  /// Build the player screen.
  ///
  /// [controller] is injected by tests; the app uses the platform player.
  const PlayerScreen({required this.match, this.controller, super.key});

  /// Match being played.
  final MatchRecord match;

  /// Playback backend, when supplied by a test.
  final PlaybackController? controller;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final PlaybackController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    // Resolved once: a screen owns its playback backend for its whole life.
    _controller =
        widget.controller ?? ref.read(playbackControllerFactoryProvider)();
    _ownsController = widget.controller == null;
    unawaited(_controller.load(widget.match.videoPath));
  }

  @override
  void dispose() {
    if (_ownsController) {
      unawaited(_controller.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.match.title)),
      body: PlayerView(controller: _controller),
    );
  }
}
