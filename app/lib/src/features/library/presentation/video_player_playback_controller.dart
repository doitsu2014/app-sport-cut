import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import 'playback_controller.dart';

/// [PlaybackController] backed by the platform video player.
class VideoPlayerPlaybackController implements PlaybackController {
  final ValueNotifier<PlaybackState> _state =
      ValueNotifier<PlaybackState>(const PlaybackState());

  VideoPlayerController? _controller;

  @override
  ValueListenable<PlaybackState> get state => _state;

  @override
  Future<void> load(String path) async {
    try {
      final controller = VideoPlayerController.file(File(path));
      _controller = controller;
      await controller.initialize();
      controller.addListener(_publish);
      _state.value = PlaybackState(
        isReady: true,
        isPlaying: controller.value.isPlaying,
        position: controller.value.position,
        duration: controller.value.duration,
        aspectRatio: controller.value.aspectRatio,
      );
    } on Exception catch (error) {
      // An unsupported container or codec lands here; the screen shows the
      // message and keeps the match listed.
      _state.value = PlaybackState(
        error: 'This recording cannot be played on this device: $error',
      );
    }
  }

  @override
  Widget buildSurface(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return AspectRatio(
      aspectRatio: controller.value.aspectRatio,
      child: VideoPlayer(controller),
    );
  }

  @override
  Future<void> play() async {
    await _controller?.play();
  }

  @override
  Future<void> pause() async {
    await _controller?.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    await _controller?.seekTo(position);
  }

  @override
  Future<void> dispose() async {
    _controller?.removeListener(_publish);
    await _controller?.dispose();
    _state.dispose();
  }

  void _publish() {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final value = controller.value;
    _state.value = PlaybackState(
      isReady: value.isInitialized,
      isPlaying: value.isPlaying,
      position: value.position,
      duration: value.duration,
      aspectRatio: value.aspectRatio,
      error: value.hasError ? value.errorDescription : null,
    );
  }
}
