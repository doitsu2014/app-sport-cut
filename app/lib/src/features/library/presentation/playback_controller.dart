import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// What the player screen needs to know about playback.
class PlaybackState {
  /// Build a playback state.
  const PlaybackState({
    this.isReady = false,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.error,
  });

  /// Whether the recording is loaded and can be played.
  final bool isReady;

  /// Whether playback is running.
  final bool isPlaying;

  /// Current position.
  final Duration position;

  /// Total duration, once known.
  final Duration duration;

  /// Explicit message when playback cannot start.
  final String? error;

  /// Progress in the range `0..1`, or `0` when the duration is unknown.
  double get progress {
    if (duration.inMilliseconds <= 0) {
      return 0;
    }
    final value = position.inMilliseconds / duration.inMilliseconds;
    return value.clamp(0.0, 1.0);
  }
}

/// Playback of one local recording.
///
/// Abstracted from `video_player` so the player screen can be tested without a
/// platform video implementation, and so a different playback backend can be
/// swapped in without rewriting the screen.
abstract interface class PlaybackController {
  /// Load the recording at [path].
  Future<void> load(String path);

  /// Current state, updated over time.
  ValueListenable<PlaybackState> get state;

  /// The view that renders video frames.
  Widget buildSurface(BuildContext context);

  /// Start or resume playback.
  Future<void> play();

  /// Pause playback.
  Future<void> pause();

  /// Move to a position.
  Future<void> seek(Duration position);

  /// Release resources.
  Future<void> dispose();
}
