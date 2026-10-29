import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../sc_elevation.dart';
import '../sc_tints.dart';
import '../sportcut_tokens.dart';

/// A bare pressable surface with hover, press, selection, and focus states.
///
/// Use it for rows, tiles, and tags that need the studio's interaction
/// language without Material's ink splash. It is data-in / callback-out: it
/// reads only the theme extensions and never a provider or the engine bridge.
class ScPressable extends StatefulWidget {
  /// Build a pressable surface.
  const ScPressable({
    super.key,
    this.onTap,
    this.semanticsLabel,
    this.selected = false,
    this.enabled = true,
    this.borderRadius,
    this.padding,
    required this.child,
  });

  /// Called when the surface is tapped or activated from the keyboard.
  final VoidCallback? onTap;

  /// The accessible name. Required when [child] is icon-only; optional
  /// otherwise, because the child's text supplies the name.
  final String? semanticsLabel;

  /// Whether the surface represents the selected row or tile.
  final bool selected;

  /// Whether the surface accepts pointer and keyboard input.
  final bool enabled;

  /// The corner radius. Defaults to [SportcutTokens.radiusSm].
  final BorderRadius? borderRadius;

  /// Inner padding. Defaults to none.
  final EdgeInsetsGeometry? padding;

  /// The content shown inside the surface.
  final Widget child;

  @override
  State<ScPressable> createState() => _ScPressableState();
}

class _ScPressableState extends State<ScPressable> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _interactive => widget.enabled && widget.onTap != null;

  void _setHovered(bool value) {
    if (!_interactive || _hovered == value) {
      return;
    }
    setState(() => _hovered = value);
  }

  void _setPressed(bool value) {
    if (!_interactive || _pressed == value) {
      return;
    }
    setState(() => _pressed = value);
  }

  Color _background(SportcutPalette palette) {
    final base = widget.selected
        ? palette.surfaceWarm
        : palette.surface.withValues(alpha: 0);
    if (!_interactive) {
      return base;
    }
    final bed = widget.selected ? palette.surfaceWarm : palette.surface;
    if (_pressed) {
      return Color.alphaBlend(ScTints.pressedTool(palette.fg), bed);
    }
    if (_hovered) {
      return Color.alphaBlend(palette.fg.withValues(alpha: 0.06), bed);
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final radius =
        widget.borderRadius ?? BorderRadius.circular(tokens.radiusSm);

    Widget surface = Stack(
      children: <Widget>[
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: tokens.motionFast,
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: _background(palette),
                borderRadius: radius,
                border: Border.all(
                  color: widget.selected
                      ? palette.border
                      : palette.border.withValues(alpha: 0),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: widget.padding ?? EdgeInsets.zero,
          child: widget.child,
        ),
      ],
    );

    surface = ScFocusRing.overlay(
      palette: palette,
      focused: _focused && widget.enabled,
      child: surface,
    );

    surface = MouseRegion(
      cursor:
          _interactive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: surface,
    );

    surface = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _interactive ? widget.onTap : null,
      onTapDown: _interactive ? (_) => _setPressed(true) : null,
      onTapUp: _interactive ? (_) => _setPressed(false) : null,
      onTapCancel: _interactive ? () => _setPressed(false) : null,
      child: surface,
    );

    surface = FocusableActionDetector(
      enabled: _interactive,
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
            widget.onTap?.call();
            return null;
          },
        ),
      },
      child: surface,
    );

    surface = Semantics(
      container: true,
      button: true,
      enabled: widget.enabled,
      selected: widget.selected,
      label: widget.semanticsLabel,
      child: surface,
    );

    return Opacity(
      opacity: widget.enabled ? 1 : 0.45,
      child: surface,
    );
  }
}
