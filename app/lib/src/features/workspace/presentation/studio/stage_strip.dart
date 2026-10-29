import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/design/sc_elevation.dart';
import '../../../../app/design/sc_icons.dart';
import '../../../../app/design/sc_metrics.dart';
import '../../../../app/design/sc_status.dart';
import '../../../../app/design/sc_tints.dart';
import '../../../../app/design/sc_typography.dart';
import '../../../../app/design/sportcut_tokens.dart';
import '../../domain/pipeline_stage.dart';

/// The stages the strip shows, in pipeline order.
///
/// `null` is Play: the shared preview rather than a pipeline output. Import is
/// deliberately absent because taking custody of a recording is a one-time
/// action, not a screen (ADR-0003 D2).
const List<PipelineStage?> stageStripOrder = <PipelineStage?>[
  null,
  PipelineStage.calibrate,
  PipelineStage.analyze,
  PipelineStage.track,
  PipelineStage.score,
  PipelineStage.highlight,
  PipelineStage.export,
];

/// The 40 px stage navigation that replaces the old pipeline rail.
///
/// Each tab carries its label and a state marker: a done check, an accent dot
/// plus READY, a danger icon plus BLOCKED, or a running percentage. The
/// selected stage gets a 2 px accent underline. Export is the exception: its
/// tab opens the export sheet through [onExport] instead of selecting a centre
/// takeover, because the sheet is the only editor. The widget is data-in /
/// callback-out and reads no provider.
class StageStrip extends StatelessWidget {
  /// Build the strip for the selected video's [states].
  const StageStrip({
    super.key,
    required this.states,
    required this.selectedStage,
    required this.runningStage,
    required this.runningFraction,
    required this.onSelectStage,
    this.onExport,
  });

  /// The resolved state of every stage for the selected video.
  final Map<PipelineStage, StageState> states;

  /// The stage currently showing, where null means Play.
  final PipelineStage? selectedStage;

  /// The stage with a job running, if any.
  final PipelineStage? runningStage;

  /// Progress of the running stage in the range 0 to 1, when known.
  final double? runningFraction;

  /// Select a stage, where null selects Play.
  final void Function(PipelineStage?) onSelectStage;

  /// Open the export sheet. When null, Export selects its stage as usual.
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    return Container(
      height: ScMetrics.stageStripHeight,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: FocusTraversalGroup(
        child: Row(
          children: <Widget>[
            for (final stage in stageStripOrder)
              Expanded(
                child: _StageTab(
                  label: stage?.label ?? 'Play',
                  status: _statusFor(stage),
                  detail: stage != null && stage == runningStage
                      ? _runningPercent
                      : null,
                  selected: selectedStage == stage,
                  onTap: stage == PipelineStage.export && onExport != null
                      ? onExport!
                      : () => onSelectStage(stage),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The state marker for [stage], or null when there is nothing to report.
  ScStatus? _statusFor(PipelineStage? stage) {
    if (stage == null) {
      // Play is always available with a video in view.
      return states.isEmpty ? null : ScStatus.ready;
    }
    if (stage == runningStage) {
      return ScStatus.running;
    }
    return switch (states[stage]) {
      StageState.done => ScStatus.done,
      StageState.ready => ScStatus.ready,
      StageState.idle => ScStatus.blocked,
      null => null,
    };
  }

  String get _runningPercent {
    final value = (runningFraction ?? 0).clamp(0.0, 1.0);
    return '${(value * 100).round()}%';
  }
}

/// One purpose-built stage tab.
class _StageTab extends StatefulWidget {
  const _StageTab({
    required this.label,
    required this.status,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final ScStatus? status;
  final String? detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_StageTab> createState() => _StageTabState();
}

class _StageTabState extends State<_StageTab> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final background = widget.selected
        ? palette.surfaceWarm
        : _pressed
            ? Color.alphaBlend(ScTints.pressedTool(palette.fg), palette.surface)
            : _hovered
                ? palette.surfaceWarm
                : palette.surface.withValues(alpha: 0);
    final status = widget.status;

    Widget body = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: tokens.motionFast,
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(ScMetrics.radiusTabTrack),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedContainer(
            duration: tokens.motionFast,
            curve: Curves.easeOut,
            height: tokens.space1 / 2,
            color: widget.selected
                ? palette.accent
                : palette.accent.withValues(alpha: 0),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.space2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.sm14.copyWith(
                    color: widget.selected ? palette.fg : palette.fg2,
                    fontWeight:
                        widget.selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (status != null) ...<Widget>[
                SizedBox(width: tokens.space1 + tokens.space1 / 2),
                _StageMarker(
                  status: status,
                  detail: widget.detail,
                  palette: palette,
                ),
              ],
            ],
          ),
        ),
      ],
    );

    body = ScFocusRing.overlay(
      palette: palette,
      focused: _focused,
      borderRadius: BorderRadius.circular(ScMetrics.radiusTabTrack),
      child: body,
    );

    body = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: body,
    );

    body = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: body,
    );

    body = FocusableActionDetector(
      onShowFocusHighlight: (bool value) {
        if (_focused != value) {
          setState(() => _focused = value);
        }
      },
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (ActivateIntent intent) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: body,
    );

    final stateLabel = status == null
        ? null
        : status == ScStatus.running
            ? widget.detail
            : status.label;
    return Semantics(
      container: true,
      button: true,
      selected: widget.selected,
      label: stateLabel == null ? widget.label : '${widget.label}, $stateLabel',
      excludeSemantics: true,
      child: body,
    );
  }
}

/// The word, dot, icon, or percentage that reinforces a stage's state.
class _StageMarker extends StatelessWidget {
  const _StageMarker({
    required this.status,
    required this.detail,
    required this.palette,
  });

  final ScStatus status;
  final String? detail;
  final SportcutPalette palette;

  @override
  Widget build(BuildContext context) {
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final style = status.resolve(palette);
    // Ready is the action state, so it takes the accent dot from the design
    // brief rather than the success tint that [ScStatus] carries for chips.
    final color = status == ScStatus.ready ? palette.accent : style.color;
    final dot = tokens.space1 + tokens.space1 / 2;

    switch (status) {
      case ScStatus.done:
        return Icon(
          ScIcons.check,
          size: tokens.space3,
          color: color,
        );
      case ScStatus.ready:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: tokens.space1),
            Text(
              'READY',
              style: typography.timecode11.copyWith(color: color),
            ),
          ],
        );
      case ScStatus.blocked:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              ScIcons.blocked,
              size: tokens.space3,
              color: style.color,
            ),
            SizedBox(width: tokens.space1),
            Text(
              'BLOCKED',
              style: typography.timecode11.copyWith(color: style.color),
            ),
          ],
        );
      case ScStatus.running:
        return Text(
          detail ?? '',
          style: typography.timecode11.copyWith(color: style.color),
        );
      case ScStatus.needsReview:
      case ScStatus.idle:
        return Text(
          status.label.toUpperCase(),
          style: typography.timecode11.copyWith(color: style.color),
        );
    }
  }
}
