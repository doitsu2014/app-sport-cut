import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../sc_elevation.dart';
import '../sc_metrics.dart';
import '../sc_typography.dart';
import '../sportcut_tokens.dart';

/// The studio button hierarchy.
enum ScButtonVariant {
  /// The single action that moves the work forward.
  primary,

  /// A supporting action on a raised surface.
  secondary,

  /// A quiet action with no surface.
  ghost,

  /// An action that removes or discards.
  destructive,
}

/// A labelled studio button.
///
/// The default height is [ScMetrics.button]; [ScButton.compact] uses
/// [ScMetrics.buttonCompact] for dense rows. Pressing is callback-only: the
/// widget never reads a provider or the engine bridge.
class ScButton extends StatelessWidget {
  /// Build a full-height button.
  const ScButton({
    super.key,
    required this.label,
    this.icon,
    this.variant = ScButtonVariant.primary,
    this.loading = false,
    this.enabled = true,
    this.onPressed,
    this.expanded = false,
  }) : _height = ScMetrics.button;

  /// Build a compact-height button for dense rows and toolbars.
  const ScButton.compact({
    super.key,
    required this.label,
    this.icon,
    this.variant = ScButtonVariant.primary,
    this.loading = false,
    this.enabled = true,
    this.onPressed,
    this.expanded = false,
  }) : _height = ScMetrics.buttonCompact;

  /// The button text. Verb-first, sentence case.
  final String label;

  /// An optional leading icon.
  final IconData? icon;

  /// The visual hierarchy for this button.
  final ScButtonVariant variant;

  /// Whether the action is in flight.
  ///
  /// The spinner replaces the leading icon when there is one. Without an icon
  /// it overlays the label instead, so enabling [loading] never widens the
  /// button or shifts its neighbours.
  final bool loading;

  /// Whether the button is enabled when [onPressed] is set.
  final bool enabled;

  /// Called when the button is tapped or activated from the keyboard.
  final VoidCallback? onPressed;

  /// Whether the button fills the available width.
  final bool expanded;

  final double _height;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);

    final transparent = palette.surface.withValues(alpha: 0);
    final (
      Color background,
      Color hover,
      Color pressed,
      Color foreground,
      Color border
    ) = switch (variant) {
      ScButtonVariant.primary => (
          palette.accent,
          palette.accentHover,
          palette.accentActive,
          palette.accentOn,
          transparent,
        ),
      ScButtonVariant.secondary => (
          palette.surface,
          palette.surfaceWarm,
          Color.alphaBlend(
            palette.fg.withValues(alpha: 0.08),
            palette.surfaceWarm,
          ),
          palette.fg,
          palette.border,
        ),
      ScButtonVariant.ghost => (
          transparent,
          palette.surfaceWarm,
          Color.alphaBlend(
            palette.fg.withValues(alpha: 0.08),
            palette.surfaceWarm,
          ),
          palette.fg2,
          transparent,
        ),
      ScButtonVariant.destructive => (
          palette.danger,
          Color.alphaBlend(palette.fg.withValues(alpha: 0.08), palette.danger),
          Color.alphaBlend(palette.fg.withValues(alpha: 0.16), palette.danger),
          palette.accentOn,
          transparent,
        ),
    };

    final canPress = enabled && onPressed != null;

    final Widget? progress = loading
        ? SizedBox(
            width: tokens.space4,
            height: tokens.space4,
            child: CircularProgressIndicator(
              strokeWidth: tokens.space1 / 2,
              color: foreground,
            ),
          )
        : null;

    final Widget row = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          if (progress != null)
            progress
          else
            Icon(icon, size: tokens.space4, color: foreground),
          SizedBox(width: tokens.space2),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typography.xs12.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );

    final Widget content = loading && icon == null
        ? Stack(
            alignment: Alignment.center,
            children: <Widget>[
              row,
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(child: progress),
                ),
              ),
            ],
          )
        : row;

    return _Pressable(
      background: background,
      hoverBackground: hover,
      pressedBackground: pressed,
      borderColor: border,
      borderRadius: BorderRadius.circular(tokens.radiusMd),
      width: expanded ? double.infinity : null,
      height: _height,
      padding: EdgeInsets.symmetric(
        horizontal:
            _height == ScMetrics.buttonCompact ? tokens.space3 : tokens.space4,
      ),
      enabled: canPress,
      onTap: loading ? null : onPressed,
      child: content,
    );
  }
}

/// An icon-only studio button with a full 44 px hit area.
///
/// [label] is required: it is both the tooltip and the accessible name, so
/// the control never depends on the icon's meaning.
class ScIconButton extends StatelessWidget {
  /// Build an icon button.
  const ScIconButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.selected = false,
    this.enabled = true,
    this.size = ScMetrics.iconButtonVisual,
  });

  /// The glyph drawn in the visual square.
  final IconData icon;

  /// The accessible name and tooltip.
  final String label;

  /// Called when the button is tapped or activated from the keyboard.
  final VoidCallback? onPressed;

  /// Whether the control is in its pressed, accent-tinted state.
  final bool selected;

  /// Whether the control accepts pointer and keyboard input.
  final bool enabled;

  /// The visual square. The pointer target stays at [ScMetrics.iconButton].
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final transparent = palette.surface.withValues(alpha: 0);
    final selectedFill = Color.alphaBlend(
      palette.accent.withValues(alpha: 0.12),
      palette.surface,
    );

    return _Pressable(
      background: selected ? selectedFill : transparent,
      hoverBackground: selected
          ? Color.alphaBlend(
              palette.accent.withValues(alpha: 0.18),
              palette.surface,
            )
          : palette.surfaceWarm,
      pressedBackground: selected
          ? Color.alphaBlend(
              palette.accent.withValues(alpha: 0.24),
              palette.surface,
            )
          : Color.alphaBlend(
              palette.fg.withValues(alpha: 0.10),
              palette.surfaceWarm,
            ),
      borderColor: selected
          ? Color.alphaBlend(
              palette.accent.withValues(alpha: 0.50),
              palette.surface,
            )
          : transparent,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      width: size,
      height: size,
      hitWidth: ScMetrics.iconButton,
      hitHeight: ScMetrics.iconButton,
      enabled: enabled && onPressed != null,
      onTap: onPressed,
      semanticsLabel: label,
      selected: selected,
      tooltip: label,
      child: Icon(
        icon,
        size: size / 2,
        color: selected ? palette.accent : palette.fg2,
      ),
    );
  }
}

/// A 30 px toolbar tool with an accent-tinted pressed state.
///
/// [label] is required: it is both the tooltip and the accessible name.
class ScToolbarButton extends StatelessWidget {
  /// Build a toolbar tool.
  const ScToolbarButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.selected = false,
    this.enabled = true,
  });

  /// The 18 px glyph drawn in the tool.
  final IconData icon;

  /// The accessible name and tooltip.
  final String label;

  /// Called when the tool is tapped or activated from the keyboard.
  final VoidCallback? onPressed;

  /// Whether the tool is pressed, as a rail toggle is when its rail shows.
  final bool selected;

  /// Whether the tool accepts pointer and keyboard input.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final transparent = palette.surface.withValues(alpha: 0);

    return _Pressable(
      background: selected
          ? Color.alphaBlend(
              palette.accent.withValues(alpha: 0.12),
              palette.surface,
            )
          : transparent,
      hoverBackground: selected
          ? Color.alphaBlend(
              palette.accent.withValues(alpha: 0.18),
              palette.surface,
            )
          : palette.surfaceWarm,
      pressedBackground: selected
          ? Color.alphaBlend(
              palette.accent.withValues(alpha: 0.24),
              palette.surface,
            )
          : Color.alphaBlend(
              palette.fg.withValues(alpha: 0.12),
              palette.surfaceWarm,
            ),
      borderColor: selected
          ? Color.alphaBlend(
              palette.accent.withValues(alpha: 0.60),
              palette.surface,
            )
          : transparent,
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      width: ScMetrics.toolButton,
      height: ScMetrics.toolButton,
      enabled: enabled && onPressed != null,
      onTap: onPressed,
      semanticsLabel: label,
      selected: selected,
      tooltip: label,
      child: Icon(
        icon,
        size: ScMetrics.toolbarIcon,
        color: selected ? palette.accent : palette.fg2,
      ),
    );
  }
}

/// A keyboard-shortcut keycap, such as the command palette hint.
class ScKeycap extends StatelessWidget {
  /// Build a keycap.
  const ScKeycap({super.key, required this.label});

  /// The shortcut text drawn inside the cap.
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space1,
        vertical: tokens.space1 / 2,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        label,
        style: typography.chrome9.copyWith(color: palette.muted),
      ),
    );
  }
}

/// The shared press, hover, focus, and disabled mechanics for the action
/// controls in this file.
class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.background,
    required this.hoverBackground,
    required this.pressedBackground,
    required this.borderColor,
    required this.borderRadius,
    this.onTap,
    this.enabled = true,
    this.width,
    this.height,
    this.hitWidth,
    this.hitHeight,
    this.padding,
    this.semanticsLabel,
    this.selected,
    this.tooltip,
    required this.child,
  });

  final Color background;
  final Color hoverBackground;
  final Color pressedBackground;
  final Color borderColor;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;
  final bool enabled;
  final double? width;
  final double? height;
  final double? hitWidth;
  final double? hitHeight;
  final EdgeInsetsGeometry? padding;
  final String? semanticsLabel;
  final bool? selected;
  final String? tooltip;
  final Widget child;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
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

  Color get _background {
    if (!_interactive) {
      return widget.background;
    }
    if (_pressed) {
      return widget.pressedBackground;
    }
    if (_hovered) {
      return widget.hoverBackground;
    }
    return widget.background;
  }

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);

    Widget content = Padding(
      padding: widget.padding ?? EdgeInsets.zero,
      child: widget.child,
    );

    if (widget.width != null || widget.height != null) {
      content = SizedBox(
        width: widget.width,
        height: widget.height,
        child: Center(child: content),
      );
    }

    Widget surface = Stack(
      children: <Widget>[
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: tokens.motionFast,
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: _background,
                borderRadius: widget.borderRadius,
                border: Border.all(color: widget.borderColor),
              ),
            ),
          ),
        ),
        content,
      ],
    );

    surface = ScFocusRing.overlay(
      palette: palette,
      focused: _focused && widget.enabled,
      child: surface,
    );

    if (widget.hitWidth != null || widget.hitHeight != null) {
      surface = SizedBox(
        width: widget.hitWidth,
        height: widget.hitHeight,
        child: Center(child: surface),
      );
    }

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

    surface = Opacity(
      opacity: widget.enabled ? 1 : 0.45,
      child: surface,
    );

    if (widget.tooltip != null) {
      surface = Tooltip(
        message: widget.tooltip!,
        excludeFromSemantics: true,
        child: surface,
      );
    }

    return surface;
  }
}
