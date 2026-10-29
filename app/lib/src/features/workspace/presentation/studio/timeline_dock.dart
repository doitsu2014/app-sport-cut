import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/design/components/sc_timeline.dart';
import '../../../../app/design/sc_metrics.dart';
import '../../../../app/design/sc_typography.dart';
import '../../../../app/design/sportcut_tokens.dart';
import '../../../editing/domain/match_edit.dart';
import '../../../editing/domain/rally.dart';
import '../../../editing/domain/score_event.dart';
import '../../../library/presentation/formatters.dart';
import 'studio_chrome.dart';

/// The number of labels drawn across the ruler.
const int _rulerTicks = 5;

/// The 176 px shared timeline dock.
///
/// The dock is data-in / callback-out: it reads no provider and owns no state.
/// A 34 px header names the visible window and its rally count; a 112 px gutter
/// labels the 24/44/32 px ruler, rally, and score tracks; the tracks themselves
/// draw one [ScRallySegment] per rally overlapping the window, one
/// [ScScoreChip] per score event in it, and an accent [ScPlayhead] at the
/// playback position while that position is inside the window. Clicking the
/// ruler or an empty part of a track seeks, and clicking a rally selects it.
/// Double-click is deliberately unused: PR 6b gives it the trim dialogue.
///
/// The visible window is [ScMetrics.timelineWindowSeconds] long and starts at
/// [windowStart]; the caller derives that start with `windowStartFor` so the
/// dock never moves the scale on its own. A missing recording disables seeking
/// and states the fact without promising a locate action (ADR-0003 D8).
class TimelineDock extends StatelessWidget {
  /// Build the dock for one visible window.
  const TimelineDock({
    super.key,
    required this.edit,
    required this.duration,
    required this.position,
    required this.windowStart,
    this.windowLength,
    this.selectedRallyId,
    this.recordingAvailable = false,
    this.loading = false,
    this.onSeek,
    this.onSelectRally,
  });

  /// The match's review, or null while the session opens.
  final MatchEdit? edit;

  /// The recording's duration, or null while it is unknown.
  final Duration? duration;

  /// The playback position.
  final Duration position;

  /// The left edge of the visible window, already recentred by the caller.
  final Duration windowStart;

  /// The visible window length, or null for the design ceiling.
  final Duration? windowLength;

  /// The selected rally, or null when none is selected.
  final String? selectedRallyId;

  /// Whether the recording can still be read.
  final bool recordingAvailable;

  /// Whether the review session has not loaded yet.
  final bool loading;

  /// Seeks to a time chosen on the ruler or an empty part of a track.
  final ValueChanged<Duration>? onSeek;

  /// Selects a rally, which the caller also seeks to and inspects.
  final ValueChanged<Rally>? onSelectRally;

  /// The visible window length, derived from the design metric.
  static final Duration _window = Duration(
    milliseconds: (ScMetrics.timelineWindowSeconds * 1000).round(),
  );

  /// The window this dock is drawing.
  Duration get _span => windowLength ?? _window;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);

    final start = _effectiveStart;
    final startSeconds = _seconds(start);
    final endSeconds = startSeconds + _span.inSeconds;
    final visible = _visibleRallies(startSeconds, endSeconds);
    final events = _visibleEvents(startSeconds, endSeconds);
    // A selected recording that is missing outranks loading: the absence of
    // the file is the fact worth stating, not that a session has not opened.
    final missing = !loading && !recordingAvailable;

    return SizedBox(
      height: ScMetrics.timelineHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(top: BorderSide(color: palette.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _header(
              start: start,
              visibleCount: visible.length,
              missing: missing,
              loading: loading,
              typography: typography,
              palette: palette,
              tokens: tokens,
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _labels(
                    palette: palette,
                    tokens: tokens,
                    typography: typography,
                  ),
                  Expanded(
                    child: _trackArea(
                      start: start,
                      startSeconds: startSeconds,
                      endSeconds: endSeconds,
                      visible: visible,
                      events: events,
                      missing: missing,
                      loading: loading,
                      palette: palette,
                      typography: typography,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The 34 px title, window range, window length, count, and legend.
  Widget _header({
    required Duration start,
    required int visibleCount,
    required bool missing,
    required bool loading,
    required SportcutTypography typography,
    required SportcutPalette palette,
    required SportcutTokens tokens,
  }) {
    final meta = SportcutTypography.withTabular(
      typography.chrome9.copyWith(color: palette.muted),
    );
    final String range;
    final String count;
    if (missing) {
      range = 'No recording';
      count = '—';
    } else if (loading) {
      range = '—';
      count = '—';
    } else {
      range = '${formatPosition(start)} – '
          '${formatPosition(start + _window)}';
      count = visibleCount == 1 ? '1 rally' : '$visibleCount rallies';
    }

    return Container(
      height: ScMetrics.timelineHeaderHeight,
      padding: EdgeInsets.symmetric(horizontal: tokens.space3),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.borderSoft)),
      ),
      child: Row(
        children: <Widget>[
          Text(
            'Timeline',
            style: typography.xs12.copyWith(
              color: palette.fg2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(range, style: meta),
          SizedBox(width: tokens.space2),
          StudioChip(label: '${_window.inMinutes} min view'),
          SizedBox(width: tokens.space2),
          Text(count, style: meta),
          if (!missing && !loading) ...<Widget>[
            SizedBox(width: tokens.space4),
            const Flexible(
              child: ScTimelineLegend(
                showRest: false,
                showPlayhead: true,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The 112 px gutter naming the three tracks.
  Widget _labels({
    required SportcutPalette palette,
    required SportcutTokens tokens,
    required SportcutTypography typography,
  }) {
    const heights = <double>[
      ScMetrics.timelineRuler,
      ScMetrics.timelineRally,
      ScMetrics.timelineScore,
    ];
    const labels = <String>['Time', 'Rallies', 'Score'];
    final padding = EdgeInsets.symmetric(
      horizontal: tokens.space2 + tokens.space1 / 2,
    );

    return Container(
      width: ScMetrics.timelineGutter,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(right: BorderSide(color: palette.borderSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var index = 0; index < labels.length; index++)
            Container(
              height: heights[index],
              alignment: Alignment.centerLeft,
              padding: padding,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: palette.borderSoft)),
              ),
              child: Text(
                labels[index].toUpperCase(),
                style: typography.chrome9.copyWith(
                  color: index == 0 ? palette.fg2 : palette.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The ruler, rally, and score tracks, or the state standing in for them.
  Widget _trackArea({
    required Duration start,
    required double startSeconds,
    required double endSeconds,
    required List<(int, Rally)> visible,
    required List<ScoreEvent> events,
    required bool missing,
    required bool loading,
    required SportcutPalette palette,
    required SportcutTypography typography,
  }) {
    if (missing) {
      return _message(
        'No recording. Import the video again to review it.',
        palette: palette,
        typography: typography,
      );
    }
    if (loading) {
      return _message(
        'Loading timeline…',
        palette: palette,
        typography: typography,
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final width =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;

        void seekAt(double x) {
          final callback = onSeek;
          if (callback == null || width <= 0) {
            return;
          }
          final ratio = (x / width).clamp(0.0, 1.0);
          callback(start + _window * ratio);
        }

        final playhead = _clampedPosition;
        final showPlayhead = playhead >= start && playhead <= start + _window;

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: <Widget>[
            // The background handles taps that miss a control. The ruler and
            // each track repeat it so their own opaque pixels seek too; the
            // segments and chips sit above those surfaces as siblings, so a
            // click on one never reaches a seek surface.
            Positioned.fill(
              child: _SeekSurface(
                onSeekAt: seekAt,
                color: palette.bg,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  height: ScMetrics.timelineRuler,
                  child: _SeekSurface(
                    onSeekAt: seekAt,
                    child: ColoredBox(
                      color: palette.surface,
                      child: ScRuler(
                        windowStart: start,
                        windowLength: _window,
                        ticks: _rulerTicks,
                        style: typography.chrome9,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: ScMetrics.timelineRally,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: <Widget>[
                      Positioned.fill(
                        child: _SeekSurface(
                          onSeekAt: seekAt,
                          color: palette.surfaceWarm,
                        ),
                      ),
                      for (final (index, rally) in visible)
                        _segment(rally, index, startSeconds, width),
                    ],
                  ),
                ),
                SizedBox(
                  height: ScMetrics.timelineScore,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: <Widget>[
                      Positioned.fill(
                        child: _SeekSurface(
                          onSeekAt: seekAt,
                          color: palette.bg,
                        ),
                      ),
                      for (final event in events)
                        _scoreChip(event, startSeconds, width),
                    ],
                  ),
                ),
              ],
            ),
            if (visible.isEmpty)
              Positioned.fill(
                top: ScMetrics.timelineRuler,
                child: IgnorePointer(
                  child: Center(
                    child: Text(
                      'No rallies in this window.',
                      style: typography.xs12.copyWith(color: palette.muted),
                    ),
                  ),
                ),
              ),
            if (showPlayhead)
              ScPlayhead(
                x: _xFor(_seconds(playhead), startSeconds, width),
              ),
          ],
        );
      },
    );
  }

  /// One rally segment, clipped to the visible window.
  Widget _segment(
    Rally rally,
    int index,
    double startSeconds,
    double width,
  ) {
    final start = math.max(rally.startSeconds, startSeconds);
    final end = math.min(
      rally.endSeconds,
      startSeconds + _span.inSeconds,
    );
    final left = _xFor(start, startSeconds, width);
    final segmentWidth = math.max(_xFor(end, startSeconds, width) - left, 0.0);
    final callback = onSelectRally;
    final review = edit;

    return ScRallySegment(
      key: ValueKey<String>(rally.id),
      index: index,
      left: left,
      width: segmentWidth,
      state: _stateFor(review, rally),
      selected: rally.id == selectedRallyId,
      onTap: callback == null ? null : () => callback(rally),
    );
  }

  /// One score event marker, centred on its timestamp.
  Widget _scoreChip(ScoreEvent event, double startSeconds, double width) {
    return Positioned(
      left: _xFor(event.timestampSeconds, startSeconds, width),
      top: (ScMetrics.timelineScore - ScMetrics.chip) / 2,
      child: FractionalTranslation(
        translation: const Offset(-0.5, 0),
        child: ScScoreChip(
          key: ValueKey<String>(event.id),
          label: '${event.leftScore}–${event.rightScore}',
          selected: event.winnerSide == WinnerSide.left,
        ),
      ),
    );
  }

  /// A centred factual sentence over the track bed.
  Widget _message(
    String message, {
    required SportcutPalette palette,
    required SportcutTypography typography,
  }) {
    return ColoredBox(
      color: palette.bg,
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: typography.xs12.copyWith(color: palette.muted),
        ),
      ),
    );
  }

  /// The window start, clamped to `0..max(0, duration - window)`.
  Duration get _effectiveStart {
    var start = windowStart;
    if (start < Duration.zero) {
      start = Duration.zero;
    }
    final recording = duration;
    if (recording != null && recording > Duration.zero) {
      final maxStart = recording - _window;
      if (maxStart < Duration.zero) {
        return Duration.zero;
      }
      if (start > maxStart) {
        start = maxStart;
      }
    }
    return start;
  }

  /// The playhead, clamped to the recording.
  Duration get _clampedPosition {
    var value = position;
    if (value < Duration.zero) {
      value = Duration.zero;
    }
    final recording = duration;
    if (recording != null && recording > Duration.zero && value > recording) {
      value = recording;
    }
    return value;
  }

  /// Rallies overlapping the window, paired with their one-based index.
  List<(int, Rally)> _visibleRallies(double startSeconds, double endSeconds) {
    final review = edit;
    if (review == null) {
      return const <(int, Rally)>[];
    }
    final result = <(int, Rally)>[];
    for (var index = 0; index < review.rallies.length; index++) {
      final rally = review.rallies[index];
      if (rally.startSeconds < endSeconds && rally.endSeconds > startSeconds) {
        result.add((index, rally));
      }
    }
    return result;
  }

  /// Score events inside the window.
  List<ScoreEvent> _visibleEvents(double startSeconds, double endSeconds) {
    final review = edit;
    if (review == null) {
      return const <ScoreEvent>[];
    }
    return review.score.events
        .where(
          (event) =>
              event.timestampSeconds >= startSeconds &&
              event.timestampSeconds <= endSeconds,
        )
        .toList();
  }

  /// How a rally draws on the track.
  ///
  /// Kept wins over scored: the accent is the reel signal. A confirmed rally
  /// that is not in the reel shows the success tint instead, and an unscored
  /// one keeps the rally tint.
  ScRallySegmentState _stateFor(MatchEdit? review, Rally rally) {
    if (review != null && review.isKept(rally)) {
      return ScRallySegmentState.kept;
    }
    if (rally.isScored) {
      return ScRallySegmentState.scored;
    }
    return ScRallySegmentState.unkept;
  }

  /// The x offset of [seconds] inside the window.
  double _xFor(double seconds, double startSeconds, double width) {
    if (width <= 0) {
      return 0;
    }
    final ratio = (seconds - startSeconds) / _span.inSeconds;
    return ratio * width;
  }

  /// Seconds as a double.
  double _seconds(Duration value) => value.inMilliseconds / 1000;
}

/// An opaque surface that seeks to the clicked offset.
///
/// It is a sibling underneath the controls it must not swallow, so a rally
/// segment or score chip above it keeps its own click.
class _SeekSurface extends StatelessWidget {
  const _SeekSurface({required this.onSeekAt, this.color, this.child});

  /// Reports the local x offset of a click.
  final ValueChanged<double> onSeekAt;

  /// The fill for a bare track surface.
  final Color? color;

  /// The content drawn on the surface, when there is one.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final fill = color;
    return MouseRegion(
      cursor: SystemMouseCursors.precise,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (TapDownDetails details) =>
            onSeekAt(details.localPosition.dx),
        child: child ??
            (fill == null ? const SizedBox.expand() : ColoredBox(color: fill)),
      ),
    );
  }
}
