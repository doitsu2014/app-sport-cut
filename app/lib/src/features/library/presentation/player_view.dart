import 'package:flutter/material.dart';

import '../../../app/design/sc_elevation.dart';
import '../../../app/design/sc_metrics.dart';
import '../../../app/design/sc_overlay_colors.dart';
import '../../../app/design/sc_typography.dart';
import '../../../app/design/sportcut_tokens.dart';
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
                color: ScOverlayColors.bed,
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

class _TransportControls extends StatefulWidget {
  const _TransportControls({
    required this.state,
    required this.onPlayPause,
    required this.onSeek,
  });

  final PlaybackState state;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onSeek;

  @override
  State<_TransportControls> createState() => _TransportControlsState();
}

class _TransportControlsState extends State<_TransportControls> {
  final FocusNode _seekFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _seekFocus.addListener(_onSeekFocus);
  }

  void _onSeekFocus() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _seekFocus.removeListener(_onSeekFocus);
    _seekFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = SportcutTokens.of(context);
    final palette = SportcutPalette.of(context);
    final PlaybackState state = widget.state;
    final VoidCallback onPlayPause = widget.onPlayPause;
    final ValueChanged<double> onSeek = widget.onSeek;
    final typography = SportcutTypography.of(context);
    final ready = state.isReady && state.error == null;
    final baseTimecode = SportcutTypography.withTabular(
      typography.timecode11,
    ).copyWith(color: scheme.onSurface);
    final timecodeStyle = ready
        ? baseTimecode
        : baseTimecode.copyWith(color: scheme.onSurfaceVariant);
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space3,
        vertical: tokens.space1 + tokens.space1 / 2,
      ),
      child: Row(
        children: <Widget>[
          IconButton.filled(
            onPressed: ready ? onPlayPause : null,
            icon: Icon(
              state.isPlaying ? Icons.pause : Icons.play_arrow,
              semanticLabel: state.isPlaying ? 'Pause' : 'Play',
            ),
            tooltip: state.isPlaying ? 'Pause' : 'Play',
          ),
          SizedBox(width: tokens.space2),
          Text(formatPosition(state.position), style: timecodeStyle),
          Expanded(
            child: Semantics(
              label: 'Seek through the recording',
              value: formatPosition(state.position),
              child: ScFocusRing.overlay(
                palette: palette,
                focused: _seekFocus.hasFocus,
                child: Slider(
                  focusNode: _seekFocus,
                  value: state.progress,
                  onChanged: ready ? onSeek : null,
                  semanticFormatterCallback: (double value) =>
                      '${(value * 100).round()} percent',
                ),
              ),
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
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    return Padding(
      padding: EdgeInsets.all(tokens.space6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.videocam_off_outlined,
            color: ScOverlayColors.ink.withValues(alpha: 0.72),
            size: ScMetrics.iconButtonVisual,
          ),
          SizedBox(height: tokens.space3),
          Text(
            message,
            style: typography.sm14.copyWith(color: ScOverlayColors.ink),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
