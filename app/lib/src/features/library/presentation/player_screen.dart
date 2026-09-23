import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/match_record.dart';
import 'formatters.dart';
import 'library_providers.dart';
import 'playback_controller.dart';

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
      body: ValueListenableBuilder<PlaybackState>(
        valueListenable: _controller.state,
        builder: (context, state, _) {
          return Column(
            children: <Widget>[
              Expanded(
                child: ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: state.error == null
                        ? _controller.buildSurface(context)
                        : _PlaybackProblem(message: state.error!),
                  ),
                ),
              ),
              _TransportControls(
                state: state,
                onPlayPause: () =>
                    state.isPlaying ? _controller.pause() : _controller.play(),
                onSeek: (progress) {
                  if (state.duration.inMilliseconds == 0) {
                    return;
                  }
                  _controller.seek(
                    Duration(
                      milliseconds:
                          (state.duration.inMilliseconds * progress).round(),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TransportControls extends StatelessWidget {
  const _TransportControls({
    required this.state,
    required this.onPlayPause,
    required this.onSeek,
  });

  final PlaybackState state;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: state.isReady && state.error == null ? onPlayPause : null,
            icon: Icon(
              state.isPlaying ? Icons.pause : Icons.play_arrow,
              semanticLabel: state.isPlaying ? 'Pause' : 'Play',
            ),
            tooltip: state.isPlaying ? 'Pause' : 'Play',
          ),
          Text(formatPosition(state.position)),
          Expanded(
            child: Slider(
              value: state.progress,
              onChanged: state.isReady && state.error == null ? onSeek : null,
            ),
          ),
          Text(formatPosition(state.duration)),
        ],
      ),
    );
  }
}

class _PlaybackProblem extends StatelessWidget {
  const _PlaybackProblem({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.videocam_off_outlined, color: Colors.white70, size: 40),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
