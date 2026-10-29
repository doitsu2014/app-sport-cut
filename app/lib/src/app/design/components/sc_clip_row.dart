import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../sc_elevation.dart';
import '../sc_icons.dart';
import '../sc_metrics.dart';
import '../sc_typography.dart';
import '../sportcut_tokens.dart';

/// Opacity of a dismissed clip row's content. The keep toggle stays at full
/// opacity so the clip reads as still recoverable.
const double _dismissedOpacity = 0.55;

/// Hairline width for the clip row ring.
const double _hairline = 1;

/// The keyboard activations the row and its toggle accept.
const Map<ShortcutActivator, Intent> _activateShortcuts =
    <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
};

Map<Type, Action<Intent>> _activateActions(VoidCallback onActivate) {
  return <Type, Action<Intent>>{
    ActivateIntent: CallbackAction<ActivateIntent>(
      onInvoke: (ActivateIntent intent) {
        onActivate();
        return null;
      },
    ),
  };
}

/// A rally clip in a highlights list.
///
/// The row shows the in/out timecodes, the duration, and an optional score
/// context, with a single keep/dismiss toggle. A kept clip carries a check and
/// an accent ring; a dismissed clip lowers the opacity of its content but stays
/// tappable and recoverable until export (DESIGN.md §6). The row is data-in /
/// callback-out and never reads a provider or the engine bridge.
class ScClipRow extends StatefulWidget {
  /// Build a clip row.
  const ScClipRow({
    super.key,
    required this.title,
    required this.inOut,
    required this.duration,
    this.scoreContext,
    this.kept = true,
    this.dismissed = false,
    this.selected = false,
    this.onTap,
    this.onToggle,
    this.toggleLabel = 'Keep clip',
  });

  /// The clip title, such as "Rally 14". Shown on one line with an ellipsis.
  final String title;

  /// The in/out timecode range, such as `42:17 – 42:59`.
  final String inOut;

  /// The clip duration, such as `0:42`.
  final String duration;

  /// An optional score or rally context, such as `18–16`.
  final String? scoreContext;

  /// Whether the clip is part of the reel.
  final bool kept;

  /// Whether the clip has been dismissed. Dismissed clips remain recoverable.
  final bool dismissed;

  /// Whether this clip is the current selection.
  final bool selected;

  /// Called when the row is tapped or activated from the keyboard.
  final VoidCallback? onTap;

  /// Called when the keep toggle is used. The toggle is hidden when null.
  final VoidCallback? onToggle;

  /// The accessible label for the keep toggle.
  final String toggleLabel;

  @override
  State<ScClipRow> createState() => _ScClipRowState();
}

class _ScClipRowState extends State<ScClipRow> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final SportcutPalette palette = SportcutPalette.of(context);
    final SportcutTypography typography = SportcutTypography.of(context);
    final SportcutTokens tokens = SportcutTokens.of(context);
    final bool pressable = widget.onTap != null;
    final bool warm = widget.selected || (pressable && _hovered);
    final Color ring = widget.kept
        ? palette.accent
        : (widget.selected ? palette.border : palette.borderSoft);

    Widget details = Row(
      children: <Widget>[
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typography.xs12.copyWith(
                  color: palette.fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: tokens.space1 / 2),
              Row(
                children: <Widget>[
                  Text(
                    widget.inOut,
                    maxLines: 1,
                    style: typography.timecode11.copyWith(
                      color: palette.meta,
                    ),
                  ),
                  if (widget.scoreContext != null)
                    Flexible(
                      child: Text(
                        ' · ${widget.scoreContext}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.xs12.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(width: tokens.space3),
        Text(
          widget.duration,
          maxLines: 1,
          style: typography.timecode11.copyWith(color: palette.fg2),
        ),
      ],
    );

    if (widget.dismissed) {
      details = Opacity(opacity: _dismissedOpacity, child: details);
    }

    final Widget content = Row(
      children: <Widget>[
        Expanded(child: details),
        if (widget.onToggle != null) ...<Widget>[
          SizedBox(width: tokens.space2),
          _KeepToggle(
            label: widget.toggleLabel,
            kept: widget.kept,
            color: widget.kept ? palette.accent : palette.muted,
            onPressed: widget.onToggle!,
          ),
        ],
      ],
    );

    return ScFocusRing.overlay(
      palette: palette,
      focused: _focused,
      child: FocusableActionDetector(
        enabled: pressable,
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (bool value) {
          setState(() => _focused = value);
        },
        onShowHoverHighlight: (bool value) {
          setState(() => _hovered = value);
        },
        shortcuts: _activateShortcuts,
        actions: _activateActions(() => widget.onTap?.call()),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Semantics(
            button: pressable,
            selected: widget.selected,
            child: AnimatedContainer(
              duration: tokens.motionFast,
              constraints: const BoxConstraints(
                minHeight: ScMetrics.rowCompact,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: tokens.space2,
                vertical: tokens.space1,
              ),
              decoration: BoxDecoration(
                color: warm ? palette.surfaceWarm : palette.surface,
                borderRadius: BorderRadius.circular(tokens.radiusMd),
                border: Border.all(color: ring, width: _hairline),
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// The keep toggle: an icon-only control with a tooltip and button semantics.
class _KeepToggle extends StatefulWidget {
  const _KeepToggle({
    required this.label,
    required this.kept,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final bool kept;
  final Color color;
  final VoidCallback onPressed;

  @override
  State<_KeepToggle> createState() => _KeepToggleState();
}

class _KeepToggleState extends State<_KeepToggle> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final SportcutPalette palette = SportcutPalette.of(context);
    return Tooltip(
      message: widget.label,
      child: ScFocusRing.overlay(
        palette: palette,
        focused: _focused,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowFocusHighlight: (bool value) {
            setState(() => _focused = value);
          },
          shortcuts: _activateShortcuts,
          actions: _activateActions(widget.onPressed),
          child: Semantics(
            button: true,
            label: widget.label,
            toggled: widget.kept,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onPressed,
              child: SizedBox(
                width: ScMetrics.iconButton,
                height: ScMetrics.rowCompact,
                child: Center(
                  child: Icon(
                    widget.kept ? ScIcons.check : ScIcons.add,
                    size: ScIcons.toolbarSize,
                    color: widget.color,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
