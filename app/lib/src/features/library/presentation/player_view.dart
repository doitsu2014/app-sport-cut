import 'package:flutter/material.dart';

import 'formatters.dart';
import 'playback_controller.dart';

/// The playback surface and transport controls for one recording, without any
/// screen chrome.
///
/// The caller owns the [controller]'s lifecycle (loading and disposal); this
/// view only renders it. That split lets the studio host the same player the
/// full-screen route uses, sharing one controller across features.
class PlayerView extends StatelessWidget {
  /// Build a playback view over an already-managed controller.
  const PlayerView({super.key, required this.controller});

  /// The playback backend, loaded and owned by the caller.
  final PlaybackController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlaybackState>(
      valueListenable: controller.state,
      builder: (context, state, _) {
        return Column(
          children: <Widget>[
            Expanded(
              child: ColoredBox(
                color: Colors.black,
                child: Center(
                  child: state.error == null
                      ? controller.buildSurface(context)
                      : _PlaybackProblem(message: state.error!),
                ),
              ),
            ),
            _TransportControls(
              state: state,
              onPlayPause: () =>
                  state.isPlaying ? controller.pause() : controller.play(),
              onSeek: (progress) {
                if (state.duration.inMilliseconds == 0) {
                  return;
                }
                controller.seek(
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
    final scheme = Theme.of(context).colorScheme;
    final ready = state.isReady && state.error == null;
    final timecodeStyle = ready
        ? const TextStyle(fontFeatures: tabularFigures)
        : TextStyle(
            color: scheme.onSurfaceVariant,
            fontFeatures: tabularFigures,
          );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: ready ? onPlayPause : null,
            icon: Icon(
              state.isPlaying ? Icons.pause : Icons.play_arrow,
              semanticLabel: state.isPlaying ? 'Pause' : 'Play',
            ),
            tooltip: state.isPlaying ? 'Pause' : 'Play',
          ),
          Text(formatPosition(state.position), style: timecodeStyle),
          Expanded(
            child: Slider(
              value: state.progress,
              onChanged: ready ? onSeek : null,
            ),
          ),
          Text(formatPosition(state.duration), style: timecodeStyle),
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
          const Icon(
            Icons.videocam_off_outlined,
            color: Colors.white70,
            size: 40,
          ),
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
