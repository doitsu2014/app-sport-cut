import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../sc_elevation.dart';
import '../sc_metrics.dart';
import '../sc_typography.dart';
import '../sportcut_tokens.dart';

/// A labelled on/off switch.
///
/// The whole label row is the pointer target. The track is 36 x 20 with a
/// 16 px thumb, takes the accent when checked, and draws the studio focus
/// ring. The accessible name and state come from [label] and [value].
class ScSwitch extends StatefulWidget {
  /// Build a switch row.
  const ScSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.enabled = true,
  });

  /// Whether the switch is on.
  final bool value;

  /// Called with the next value when the row is tapped or activated.
  final ValueChanged<bool> onChanged;

  /// The label shown beside the track and announced as the accessible name.
  final String label;

  /// Whether the switch accepts pointer and keyboard input.
  final bool enabled;

  @override
  State<ScSwitch> createState() => _ScSwitchState();
}

class _ScSwitchState extends State<ScSwitch> {
  bool _focused = false;

  void _toggle() {
    if (widget.enabled) {
      widget.onChanged(!widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final thumbSize = ScMetrics.chip - tokens.space1;

    Widget track = AnimatedContainer(
      duration: tokens.motionFast,
      curve: Curves.easeOut,
      width: ScMetrics.iconButtonVisual,
      height: ScMetrics.chip,
      padding: EdgeInsets.all(tokens.space1 / 2),
      decoration: BoxDecoration(
        color: widget.value ? palette.accent : palette.border,
        borderRadius: BorderRadius.circular(tokens.radiusPill),
      ),
      child: AnimatedAlign(
        duration: tokens.motionFast,
        curve: Curves.easeOut,
        alignment: widget.value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: thumbSize,
          height: thumbSize,
          decoration: BoxDecoration(
            color: palette.surface,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );

    track = ScFocusRing.overlay(
      palette: palette,
      focused: _focused && widget.enabled,
      child: track,
    );

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: ScMetrics.field),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.sm14.copyWith(color: palette.fg2),
            ),
          ),
          SizedBox(width: tokens.space3),
          track,
        ],
      ),
    );

    Widget content = FocusableActionDetector(
      enabled: widget.enabled,
      onShowFocusHighlight: (value) {
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
            _toggle();
            return null;
          },
        ),
      },
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? _toggle : null,
          child: row,
        ),
      ),
    );

    content = Semantics(
      container: true,
      toggled: widget.value,
      enabled: widget.enabled,
      label: widget.label,
      onTap: widget.enabled ? _toggle : null,
      excludeSemantics: true,
      child: content,
    );

    return Opacity(
      opacity: widget.enabled ? 1 : 0.45,
      child: content,
    );
  }
}
