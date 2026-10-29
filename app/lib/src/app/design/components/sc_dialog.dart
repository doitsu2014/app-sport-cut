import 'package:flutter/material.dart';

import '../sc_elevation.dart';
import '../sc_icons.dart';
import '../sc_metrics.dart';
import '../sc_motion.dart';
import '../sc_tints.dart';
import '../sc_typography.dart';
import '../sportcut_tokens.dart';
import 'sc_fields.dart';

/// The visual weight of a dialog action.
enum _DialogButtonTone { primary, secondary, danger }

/// A studio dialog surface: a titled card with a body and right-aligned
/// actions.
///
/// The widget is a plain card rather than a route, so the caller owns the
/// barrier and the dismissal; it reads the theme through the context and
/// takes every value and callback as a parameter. The width defaults to
/// [ScMetrics.dialogConfirm]; settings dialogs pass
/// [ScMetrics.dialogSettings].
class ScDialog extends StatelessWidget {
  /// Build a dialog card.
  const ScDialog({
    required this.title,
    required this.child,
    this.description,
    this.actions = const <Widget>[],
    this.width,
    super.key,
  });

  /// The dialog heading.
  final String title;

  /// The body content, rendered under the optional [description].
  final Widget child;

  /// A short paragraph between the heading and [child].
  final String? description;

  /// Right-aligned actions. The footer is omitted when this is empty.
  final List<Widget> actions;

  /// Overrides the card width. Defaults to [ScMetrics.dialogConfirm].
  final double? width;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final descriptionText = description;
    final effectiveWidth = width ?? ScMetrics.dialogConfirm;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: effectiveWidth),
      child: SizedBox(
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border.all(color: palette.border),
            borderRadius: BorderRadius.circular(tokens.radiusLg),
            boxShadow: Theme.of(context).brightness == Brightness.dark
                ? ScElevation.raisedDark
                : ScElevation.raisedLight,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radiusLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.space4,
                    vertical: tokens.space3,
                  ),
                  child: Text(
                    title,
                    style: typography.body16.copyWith(
                      color: palette.fg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Divider(),
                Padding(
                  padding: EdgeInsets.all(tokens.space4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (descriptionText != null) ...<Widget>[
                        Text(
                          descriptionText,
                          style: typography.sm14.copyWith(color: palette.fg2),
                        ),
                        SizedBox(height: tokens.space3),
                      ],
                      child,
                    ],
                  ),
                ),
                if (actions.isNotEmpty) ...<Widget>[
                  const Divider(),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.space4,
                      vertical: tokens.space3,
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: tokens.space2,
                      runSpacing: tokens.space2,
                      children: actions,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A confirmation dialog that names its object and its consequence.
///
/// [confirmLabel] must name the object, for example "Delete video", never
/// "Delete". A destructive confirmation uses danger text and border rather
/// than a filled red button; [onConfirm] and [onCancel] are the only exits,
/// so the caller decides when the route closes.
class ScConfirmDialog extends StatelessWidget {
  /// Build a confirmation dialog.
  const ScConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    this.destructive = true,
    this.onConfirm,
    this.onCancel,
    this.icon,
    super.key,
  });

  /// The dialog heading.
  final String title;

  /// The sentence explaining what will happen.
  final String message;

  /// The confirming action's label, which names the object.
  final String confirmLabel;

  /// The cancel action's label.
  final String cancelLabel;

  /// Whether the confirming action is destructive.
  final bool destructive;

  /// Invoked by the confirming action. The button is disabled when null.
  final VoidCallback? onConfirm;

  /// Invoked by the cancel action. The button is disabled when null.
  final VoidCallback? onCancel;

  /// An optional leading icon, for example [ScIcons.delete].
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final leadingIcon = icon;

    return ScDialog(
      title: title,
      actions: <Widget>[
        _DialogButton(
          label: cancelLabel,
          tone: _DialogButtonTone.secondary,
          onPressed: onCancel,
        ),
        _DialogButton(
          label: confirmLabel,
          tone: destructive
              ? _DialogButtonTone.danger
              : _DialogButtonTone.primary,
          onPressed: onConfirm,
        ),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (leadingIcon != null) ...<Widget>[
            Icon(
              leadingIcon,
              size: ScIcons.toolbarSize,
              color: destructive ? palette.danger : palette.fg2,
            ),
            SizedBox(width: tokens.space3),
          ],
          Expanded(
            child: Text(
              message,
              style: typography.sm14.copyWith(color: palette.fg2),
            ),
          ),
        ],
      ),
    );
  }
}

/// One selectable row in an [ScOptionDialog].
@immutable
class ScDialogOption {
  /// Build an option.
  const ScDialogOption({
    required this.key,
    required this.label,
    this.initial = true,
  });

  /// The identity returned when this option is selected.
  final Key key;

  /// The user-facing description of the option.
  final String label;

  /// Whether the row starts selected.
  final bool initial;
}

/// A dialog with a set of selectable options.
///
/// The confirm action closes the route and returns the selected keys, in the
/// order the options were declared, to the awaiting `showDialog` call:
///
/// ```dart
/// final keys = await showDialog<List<Key>>(
///   context: context,
///   builder: (context) => ScOptionDialog(
///     title: 'Delete video',
///     message: 'The recording copy and its analysis will be removed.',
///     confirmLabel: 'Delete video',
///     cancelLabel: 'Cancel',
///     options: options,
///   ),
/// );
/// ```
class ScOptionDialog extends StatefulWidget {
  /// Build an option dialog.
  const ScOptionDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.options,
    super.key,
  });

  /// The dialog heading.
  final String title;

  /// The sentence explaining what will happen.
  final String message;

  /// The confirming action's label, which names the object.
  final String confirmLabel;

  /// The cancel action's label.
  final String cancelLabel;

  /// The selectable rows.
  final List<ScDialogOption> options;

  @override
  State<ScOptionDialog> createState() => _ScOptionDialogState();
}

class _ScOptionDialogState extends State<ScOptionDialog> {
  late final Set<Key> _selected;

  @override
  void initState() {
    super.initState();
    _selected = <Key>{
      for (final ScDialogOption option in widget.options)
        if (option.initial) option.key,
    };
  }

  void _toggle(Key key, bool selected) {
    setState(() {
      if (selected) {
        _selected.add(key);
      } else {
        _selected.remove(key);
      }
    });
  }

  void _confirm() {
    final List<Key> keys = <Key>[
      for (final ScDialogOption option in widget.options)
        if (_selected.contains(option.key)) option.key,
    ];
    Navigator.of(context).pop<List<Key>>(keys);
  }

  void _cancel() {
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);

    return ScDialog(
      title: widget.title,
      actions: <Widget>[
        _DialogButton(
          label: widget.cancelLabel,
          tone: _DialogButtonTone.secondary,
          onPressed: _cancel,
        ),
        _DialogButton(
          label: widget.confirmLabel,
          tone: _DialogButtonTone.danger,
          onPressed: _confirm,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            widget.message,
            style: typography.sm14.copyWith(color: palette.fg2),
          ),
          if (widget.options.isNotEmpty) SizedBox(height: tokens.space3),
          for (int index = 0;
              index < widget.options.length;
              index++) ...<Widget>[
            if (index > 0) SizedBox(height: tokens.space2),
            ScCheckboxRow(
              label: widget.options[index].label,
              value: _selected.contains(widget.options[index].key),
              onChanged: (bool selected) {
                _toggle(widget.options[index].key, selected);
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// The dialog action button.
class _DialogButton extends StatefulWidget {
  const _DialogButton({
    required this.label,
    required this.tone,
    required this.onPressed,
  });

  final String label;
  final _DialogButtonTone tone;
  final VoidCallback? onPressed;

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final enabled = widget.onPressed != null;

    final Color background;
    final Color foreground;
    final Color border;
    final Color hover;
    switch (widget.tone) {
      case _DialogButtonTone.primary:
        background = palette.accent;
        foreground = palette.accentOn;
        border = palette.accent;
        hover = palette.accentHover;
      case _DialogButtonTone.secondary:
        background = palette.surface;
        foreground = palette.fg;
        border = palette.controlBorder;
        hover = palette.surfaceWarm;
      case _DialogButtonTone.danger:
        background = palette.surface;
        foreground = palette.danger;
        border = palette.danger;
        hover = ScTints.pressedTool(palette.danger);
    }

    return Opacity(
      opacity: enabled ? 1 : ScTints.disabledOpacity,
      child: ScFocusRing.overlay(
        palette: palette,
        focused: _focused,
        child: Semantics(
          button: true,
          enabled: enabled,
          label: widget.label,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onPressed,
              onFocusChange: (bool focused) {
                setState(() => _focused = focused);
              },
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              hoverColor: ScMotion.reduced(context)
                  ? palette.surface.withValues(alpha: 0)
                  : hover,
              focusColor: palette.surface.withValues(alpha: 0),
              child: Container(
                constraints: const BoxConstraints(minHeight: ScMetrics.button),
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(horizontal: tokens.space4),
                decoration: BoxDecoration(
                  color: background,
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                ),
                child: Text(
                  widget.label,
                  style: typography.xs12.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
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
