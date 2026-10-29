import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../app/design/components/sc_overlay.dart';
import '../../../../app/design/components/sc_score_bug.dart';
import '../../../../app/design/components/sc_transport.dart';
import '../../../../app/design/sc_icons.dart';
import '../../../../app/design/sc_metrics.dart';
import '../../../../app/design/sc_overlay_colors.dart';
import '../../../../app/design/sc_typography.dart';
import '../../../../app/design/sportcut_tokens.dart';
import '../../../../bridge/sportcut_engine.dart';
import '../../../editing/domain/match_edit.dart';
import '../../../editing/domain/rally.dart';
import '../../../editing/presentation/editing_providers.dart';
import '../../../library/presentation/formatters.dart';
import '../../../library/presentation/match_list_entry.dart';
import '../../../library/presentation/playback_controller.dart';
import '../../../score/presentation/serving_sides_providers.dart';

/// The ratio used until a player reports a finite one.
const double _fallbackAspectRatio = 16 / 9;

/// The floating transport's maximum width.
///
/// This mirrors `studio.html`'s `min(680px, …)` at the Flutter scale. It is a
/// stage layout value that `ScMetrics` does not own yet; it stays here, named,
/// so a later design-layer change can move it without touching the logic.
const double _transportMaxWidth = 640;

/// The side labels the score bug shows.
const String _leftLabel = 'L · Left side';
const String _rightLabel = 'R · Right side';

/// The shared stage for the selected recording.
///
/// The stage is the one video surface every studio stage draws: the footage
/// sits on the fixed stage bed, the transport floats inside the video box, and
/// the score bug can be drawn over the top-left when a score-aware stage asks
/// for it (ADR-0003 D13 and D16; FR-SHL-10, FR-SHL-29, FR-SHL-45).
///
/// A missing recording gets [ScMissingRecording], which follows D8: it names
/// the fact, offers no fake relocate action, and says that importing a
/// replacement creates a new match. While missing, the transport is absent and
/// therefore cannot play, seek, or score.
class VideoPreview extends StatelessWidget {
  /// Build the stage for [entry].
  const VideoPreview({
    super.key,
    required this.entry,
    required this.controller,
    this.showScoreBug = false,
  });

  /// The selected video and whether its recording can still be read.
  final MatchListEntry entry;

  /// The shared player, or null before one has been created.
  final PlaybackController? controller;

  /// Whether the score bug is drawn over the frame.
  final bool showScoreBug;

  @override
  Widget build(BuildContext context) {
    final fileName = p.basename(entry.match.videoPath);
    if (!entry.recordingAvailable) {
      return ScVideoStage(
        videoChild: null,
        aspectRatio: _fallbackAspectRatio,
        showMissing: true,
        missingFileName: fileName,
      );
    }
    final player = controller;
    if (player == null) {
      return const ScVideoStage(
        videoChild: _StageLoading(),
        aspectRatio: _fallbackAspectRatio,
      );
    }
    return _StageFrame(
      controller: player,
      showScoreBug: showScoreBug,
      fileName: fileName,
    );
  }
}

/// The loading state drawn on the stage bed.
class _StageLoading extends StatelessWidget {
  const _StageLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: ScOverlayColors.signal),
    );
  }
}

/// One loaded controller rendered into the stage.
///
/// The frame listens to the player once and rebuilds only when the layout it
/// depends on changes: readiness, aspect ratio, or the playback error. Position
/// updates never rebuild the surface; the transport and the score bug listen
/// for themselves.
class _StageFrame extends StatefulWidget {
  const _StageFrame({
    required this.controller,
    required this.showScoreBug,
    required this.fileName,
  });

  /// The shared player, owned by the studio screen.
  final PlaybackController controller;

  /// Whether the score bug is drawn over the frame.
  final bool showScoreBug;

  /// The recording's file name, named by the error state.
  final String fileName;

  @override
  State<_StageFrame> createState() => _StageFrameState();
}

class _StageFrameState extends State<_StageFrame> {
  late bool _ready;
  late double _aspectRatio;
  String? _error;

  PlaybackController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _read(_controller.state.value);
    _controller.state.addListener(_onPlayback);
  }

  @override
  void didUpdateWidget(covariant _StageFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.state.removeListener(_onPlayback);
      _read(widget.controller.state.value);
      widget.controller.state.addListener(_onPlayback);
    }
  }

  @override
  void dispose() {
    _controller.state.removeListener(_onPlayback);
    super.dispose();
  }

  void _read(PlaybackState state) {
    _ready = state.isReady;
    _aspectRatio = state.aspectRatio;
    _error = state.error;
  }

  void _onPlayback() {
    final state = _controller.state.value;
    final changed = state.isReady != _ready ||
        state.aspectRatio != _aspectRatio ||
        state.error != _error;
    if (!changed) {
      return;
    }
    setState(() => _read(state));
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final loading = !_ready && error == null;
    return ScVideoStage(
      videoChild: loading
          ? const _StageLoading()
          : (error == null ? _controller.buildSurface(context) : null),
      aspectRatio: _aspectRatio,
      errorSlot: error == null
          ? null
          : _PlaybackProblem(message: error, fileName: widget.fileName),
      overlay: error == null
          ? _StageOverlay(
              controller: _controller,
              showScoreBug: widget.showScoreBug,
            )
          : null,
    );
  }
}

/// The controls and overlays drawn inside the video box.
class _StageOverlay extends StatelessWidget {
  const _StageOverlay({required this.controller, required this.showScoreBug});

  /// The shared player.
  final PlaybackController controller;

  /// Whether the score bug is drawn over the frame.
  final bool showScoreBug;

  @override
  Widget build(BuildContext context) {
    final tokens = SportcutTokens.of(context);
    // 14 px from the bottom edge, composed from the design tokens.
    final inset = tokens.space3 + tokens.space1 / 2;
    return Stack(
      children: <Widget>[
        if (showScoreBug)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _ScoreBugOverlay(controller: controller),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: inset,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _transportMaxWidth),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: tokens.space5),
                child: _StageTransport(controller: controller),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The floating transport, wired to the shared player.
class _StageTransport extends StatelessWidget {
  const _StageTransport({required this.controller});

  /// The shared player.
  final PlaybackController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlaybackState>(
      valueListenable: controller.state,
      builder: (context, state, _) {
        final enabled = state.isReady && state.error == null;
        return ScTransport(
          playing: state.isPlaying,
          enabled: enabled,
          position: state.position,
          duration: state.duration,
          onPlayPause: () =>
              state.isPlaying ? controller.pause() : controller.play(),
          onSeekBackward: () => _seekBy(state, const Duration(seconds: -5)),
          onSeekForward: () => _seekBy(state, const Duration(seconds: 5)),
          onSeek: (Duration position) {
            if (enabled) {
              controller.seek(position);
            }
          },
        );
      },
    );
  }

  /// Seek by [delta], kept inside the recording.
  void _seekBy(PlaybackState state, Duration delta) {
    if (!state.isReady || state.error != null) {
      return;
    }
    final target = state.position + delta;
    final duration = state.duration;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (duration > Duration.zero && target > duration ? duration : target);
    controller.seek(clamped);
  }
}

/// The score bug derived from the editing session at the play position.
///
/// The bug listens to the player but rebuilds only when the values it shows
/// change: the rally index, the score, the serving side, or the whole-second
/// timecode. A per-frame position change never rebuilds it. Scores are read
/// from [ScoreTimeline.atSeconds] and never animated (FR-SHL-29).
class _ScoreBugOverlay extends ConsumerStatefulWidget {
  const _ScoreBugOverlay({required this.controller});

  /// The shared player.
  final PlaybackController controller;

  @override
  ConsumerState<_ScoreBugOverlay> createState() => _ScoreBugOverlayState();
}

class _ScoreBugOverlayState extends ConsumerState<_ScoreBugOverlay> {
  MatchEdit? _edit;
  Map<String, RallySideDto> _sides = const <String, RallySideDto>{};
  String? _signature;

  /// The last side the provider or a confirmed rally established.
  ///
  /// `ScScoreBug` always draws its serving pill, so an unknown server falls
  /// back to the previous known side rather than flickering the pill away.
  bool _lastServingLeft = true;

  @override
  void initState() {
    super.initState();
    widget.controller.state.addListener(_onPosition);
  }

  @override
  void didUpdateWidget(covariant _ScoreBugOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.state.removeListener(_onPosition);
      widget.controller.state.addListener(_onPosition);
    }
  }

  @override
  void dispose() {
    widget.controller.state.removeListener(_onPosition);
    super.dispose();
  }

  void _onPosition() {
    final facts = _factsFor(
      _edit,
      _sides,
      widget.controller.state.value.position,
    );
    if (facts == null || facts.signature == _signature) {
      return;
    }
    setState(() => _signature = facts.signature);
  }

  @override
  Widget build(BuildContext context) {
    final edit = ref.watch(editingControllerProvider).edit;
    final sides =
        ref.watch(servingSidesProvider).value ?? const <String, RallySideDto>{};
    _edit = edit;
    _sides = sides;

    final facts =
        _factsFor(edit, sides, widget.controller.state.value.position);
    if (facts == null) {
      _signature = null;
      return const SizedBox.shrink();
    }
    _signature = facts.signature;

    final servingLeft = facts.servingLeft ?? _lastServingLeft;
    _lastServingLeft = servingLeft;
    return ScScoreBug(
      rallyIndex: facts.index,
      rallyTotal: facts.total,
      leftScore: facts.left,
      rightScore: facts.right,
      leftLabel: _leftLabel,
      rightLabel: _rightLabel,
      servingLeft: servingLeft,
      timecode: facts.timecode,
    );
  }
}

/// The score-bug values for one play position.
class _ScoreFacts {
  const _ScoreFacts({
    required this.index,
    required this.total,
    required this.left,
    required this.right,
    required this.servingLeft,
    required this.timecode,
  });

  /// One-based rally index, or 0 outside every rally.
  final int index;

  /// Marked rallies in the match.
  final int total;

  /// Left side's score at the position.
  final int left;

  /// Right side's score at the position.
  final int right;

  /// Serving side, or null when nothing derives it.
  final bool? servingLeft;

  /// The position as `HH:MM:SS`.
  final String timecode;

  /// The values the bug draws; a change means the bug must rebuild.
  String get signature =>
      '$index/$total/$left/$right/${servingLeft ?? '?'}/$timecode';
}

/// Derive the bug's values from the edit and the play position.
_ScoreFacts? _factsFor(
  MatchEdit? edit,
  Map<String, RallySideDto> sides,
  Duration position,
) {
  if (edit == null) {
    return null;
  }
  final seconds = position.inMilliseconds / 1000;
  final rallies = edit.rallies;

  var index = 0;
  var previous = -1;
  for (var i = 0; i < rallies.length; i++) {
    final rally = rallies[i];
    if (seconds >= rally.startSeconds && seconds <= rally.endSeconds) {
      index = i + 1;
      previous = i;
      break;
    }
  }
  // Outside a rally, the last rally to start is still the serving context.
  if (previous < 0) {
    for (var i = rallies.length - 1; i >= 0; i--) {
      if (rallies[i].startSeconds <= seconds) {
        previous = i;
        break;
      }
    }
  }

  final score = edit.score.atSeconds(seconds);
  return _ScoreFacts(
    index: index,
    total: rallies.length,
    left: score.left,
    right: score.right,
    servingLeft: _servingLeft(rallies, sides, previous),
    timecode: formatClock(position),
  );
}

/// The serving side for the rally at [from], falling back to earlier rallies.
bool? _servingLeft(
  List<Rally> rallies,
  Map<String, RallySideDto> sides,
  int from,
) {
  for (var i = from; i >= 0 && i < rallies.length; i--) {
    final side = sides[rallies[i].id];
    if (side != null) {
      return side == RallySideDto.left;
    }
  }
  // The winner of a rally serves the next one, which is what the engine's
  // derivation follows; use the last confirmed winner when the map is empty.
  for (var i = from; i >= 0 && i < rallies.length; i--) {
    final side = rallies[i].winnerSide;
    if (side != null) {
      return side == WinnerSide.left;
    }
  }
  return null;
}

/// The stage's error slot: the reason and the file it belongs to.
class _PlaybackProblem extends StatelessWidget {
  const _PlaybackProblem({required this.message, required this.fileName});

  /// Why playback could not start.
  final String message;

  /// The recording's file name.
  final String fileName;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final typography = SportcutTypography.of(context);
    final tokens = SportcutTokens.of(context);
    return Padding(
      padding: EdgeInsets.all(tokens.space6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            ScIcons.error,
            size: ScMetrics.iconButtonVisual,
            color: palette.danger,
          ),
          SizedBox(height: tokens.space3),
          Text(
            message,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: typography.sm14.copyWith(color: ScOverlayColors.ink),
          ),
          SizedBox(height: tokens.space1),
          Text(
            fileName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: typography.timecode11.copyWith(color: ScOverlayColors.ink),
          ),
        ],
      ),
    );
  }
}
