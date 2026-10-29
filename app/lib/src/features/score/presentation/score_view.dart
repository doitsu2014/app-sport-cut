import 'package:flutter/material.dart';

import '../../../app/design/components/sc_transport.dart';
import '../../../app/design/sc_metrics.dart';
import '../../../app/design/sc_overlay_colors.dart';
import '../../../app/design/sc_tints.dart';
import '../../../app/design/sportcut_tokens.dart';
import '../../library/domain/match_record.dart';
import '../../library/presentation/playback_controller.dart';
import 'rally_panel.dart';

/// The legacy full-screen rally route.
///
/// The studio hosts [RallyPanel] in its inspector instead. This route keeps
/// working by composing the same panel beside the shared stage; the panel owns
/// both sessions here (`ownsSession: true`) exactly as the old `ScoreView`
/// `initState` did.
class ScoreView extends StatelessWidget {
  /// Build the score route over an already-managed controller.
  const ScoreView({super.key, required this.match, required this.controller});

  /// Match being reviewed.
  final MatchRecord match;

  /// Playback backend, loaded and owned by the caller.
  final PlaybackController controller;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final wide = constraints.maxWidth >= ScMetrics.collapseBreakpoint;
        final stage = _stage(context, tokens);
        final panel = _panel(palette, tokens, wide: wide);
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: stage),
              SizedBox(width: ScMetrics.inspectorWidth, child: panel),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(child: stage),
            SizedBox(height: ScMetrics.stackedPaneHeight, child: panel),
          ],
        );
      },
    );
  }

  /// The shared stage and its transport.
  Widget _stage(BuildContext context, SportcutTokens tokens) {
    return Column(
      children: <Widget>[
        Expanded(
          child: ColoredBox(
            color: ScOverlayColors.bed,
            child: Center(child: controller.buildSurface(context)),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(tokens.space3),
          child: ValueListenableBuilder<PlaybackState>(
            valueListenable: controller.state,
            builder: (BuildContext context, PlaybackState state, Widget? _) {
              return ScTransport(
                playing: state.isPlaying,
                enabled: state.isReady,
                position: state.position,
                duration: state.duration,
                onPlayPause: () {
                  if (state.isPlaying) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                },
                onSeekBackward: () {
                  final target = state.position - const Duration(seconds: 5);
                  controller.seek(
                    target < Duration.zero ? Duration.zero : target,
                  );
                },
                onSeekForward: () {
                  controller.seek(state.position + const Duration(seconds: 5));
                },
                onSeek: (Duration position) => controller.seek(position),
              );
            },
          ),
        ),
      ],
    );
  }

  /// The 320 px panel column.
  Widget _panel(
    SportcutPalette palette,
    SportcutTokens tokens, {
    required bool wide,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ScTints.railSurface(palette.surface, palette.bg),
        border: wide
            ? Border(left: BorderSide(color: palette.border))
            : Border(top: BorderSide(color: palette.border)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(tokens.space3),
        child: RallyPanel(
          match: match,
          controller: controller,
          ownsSession: true,
          onSelectRally: (rally) => controller.seek(
            Duration(milliseconds: (rally.startSeconds * 1000).round()),
          ),
        ),
      ),
    );
  }
}
