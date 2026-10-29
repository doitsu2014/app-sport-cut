import 'package:flutter/material.dart';

import '../sc_elevation.dart';
import '../sc_icons.dart';
import '../sc_metrics.dart';
import '../sc_motion.dart';
import '../sc_tints.dart';
import '../sc_typography.dart';
import '../sportcut_tokens.dart';

/// The error icon size, a little smaller than a toolbar icon.
const double _errorIconSize = ScMetrics.chip * 0.7;

/// A single-line text field with an external label, helper, and error state.
///
/// The label sits above the field so the field itself stays exactly
/// [ScMetrics.field] tall. Focus draws the studio ring instead of Material's
/// focus tint, and an error turns the border, the icon, and the message
/// danger-coloured together.
class ScTextField extends StatefulWidget {
  /// Build a text field.
  const ScTextField({
    this.label,
    this.hint,
    this.helper,
    this.error,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.maxLength,
    this.enabled = true,
    super.key,
  });

  /// The external label shown above the field.
  final String? label;

  /// The placeholder shown while the field is empty.
  final String? hint;

  /// The supporting line under the field.
  final String? helper;

  /// The error message. When set it replaces [helper] and marks the field.
  final String? error;

  /// An optional external controller.
  final TextEditingController? controller;

  /// An optional external focus node. The widget creates and owns one when
  /// this is null.
  final FocusNode? focusNode;

  /// Called on every edit.
  final ValueChanged<String>? onChanged;

  /// The maximum number of characters, which also shows the counter.
  final int? maxLength;

  /// Whether the field accepts input.
  final bool enabled;

  @override
  State<ScTextField> createState() => _ScTextFieldState();
}

class _ScTextFieldState extends State<ScTextField> {
  late FocusNode _node;
  FocusNode? _ownedNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    final FocusNode? provided = widget.focusNode;
    if (provided == null) {
      final FocusNode owned = FocusNode();
      _ownedNode = owned;
      _node = owned;
    } else {
      _node = provided;
    }
    _focused = _node.hasFocus;
    _node.addListener(_handleFocus);
  }

  @override
  void didUpdateWidget(ScTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _node.removeListener(_handleFocus);
      _ownedNode?.dispose();
      _ownedNode = null;
      final FocusNode? provided = widget.focusNode;
      if (provided == null) {
        final FocusNode owned = FocusNode();
        _ownedNode = owned;
        _node = owned;
      } else {
        _node = provided;
      }
      _focused = _node.hasFocus;
      _node.addListener(_handleFocus);
    }
  }

  void _handleFocus() {
    if (!mounted) {
      return;
    }
    setState(() => _focused = _node.hasFocus);
  }

  @override
  void dispose() {
    _node.removeListener(_handleFocus);
    _ownedNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final label = widget.label;
    final error = widget.error;
    final helper = widget.helper;
    final hasError = error != null;
    final borderColor = hasError
        ? palette.danger
        : (_focused ? palette.accent : palette.controlBorder);

    Widget field = TextField(
      controller: widget.controller,
      focusNode: _node,
      onChanged: widget.onChanged,
      maxLength: widget.maxLength,
      enabled: widget.enabled,
      style: typography.sm14.copyWith(color: palette.fg),
      cursorColor: palette.accent,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: typography.sm14.copyWith(color: palette.muted),
        counterStyle: typography.micro10.copyWith(color: palette.muted),
        filled: true,
        fillColor: palette.surface,
        border: _border(borderColor, tokens),
        enabledBorder: _border(borderColor, tokens),
        focusedBorder: _border(borderColor, tokens),
        disabledBorder: _border(palette.borderSoft, tokens),
      ),
    );
    if (label != null) {
      field = Semantics(label: label, child: field);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (label != null) ...<Widget>[
          Text(
            label,
            style: typography.xs12.copyWith(
              color: palette.fg2,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: tokens.space1),
        ],
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: ScMetrics.field),
          child: ScFocusRing.overlay(
            palette: palette,
            focused: _focused,
            child: field,
          ),
        ),
        if (hasError) ...<Widget>[
          SizedBox(height: tokens.space1),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.only(top: tokens.space1 / 2),
                child: Icon(
                  ScIcons.error,
                  size: _errorIconSize,
                  color: palette.danger,
                ),
              ),
              SizedBox(width: tokens.space1),
              Expanded(
                child: Text(
                  error,
                  style: typography.xs12.copyWith(color: palette.danger),
                ),
              ),
            ],
          ),
        ] else if (helper != null) ...<Widget>[
          SizedBox(height: tokens.space1),
          Text(
            helper,
            style: typography.xs12.copyWith(color: palette.muted),
          ),
        ],
      ],
    );
  }

  OutlineInputBorder _border(Color color, SportcutTokens tokens) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      borderSide: BorderSide(color: color),
    );
  }
}

/// A checkbox with a label and an optional helper line.
///
/// The whole row is the hit target and the focus owner, so the keycap-scale
/// box stays visually small while the row remains easy to click and reach by
/// keyboard.
class ScCheckboxRow extends StatefulWidget {
  /// Build a checkbox row.
  const ScCheckboxRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
    this.enabled = true,
    super.key,
  });

  /// The label shown beside the box.
  final String label;

  /// The current checked state.
  final bool value;

  /// Called with the new state when the row is activated.
  final ValueChanged<bool> onChanged;

  /// A supporting line under the label.
  final String? helper;

  /// Whether the row accepts input.
  final bool enabled;

  @override
  State<ScCheckboxRow> createState() => _ScCheckboxRowState();
}

class _ScCheckboxRowState extends State<ScCheckboxRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final helper = widget.helper;
    const double boxSize = ScMetrics.chip * 0.8;

    return Opacity(
      opacity: widget.enabled ? 1 : ScTints.disabledOpacity,
      child: ScFocusRing.overlay(
        palette: palette,
        focused: _focused,
        child: Semantics(
          container: true,
          checked: widget.value,
          enabled: widget.enabled,
          label: widget.label,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap:
                  widget.enabled ? () => widget.onChanged(!widget.value) : null,
              onFocusChange: (bool focused) {
                setState(() => _focused = focused);
              },
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              hoverColor: ScMotion.reduced(context)
                  ? palette.surface.withValues(alpha: 0)
                  : palette.surfaceWarm,
              focusColor: palette.surface.withValues(alpha: 0),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: tokens.space1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.only(top: tokens.space1 / 2),
                      child: Container(
                        width: boxSize,
                        height: boxSize,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color:
                              widget.value ? palette.accent : palette.surface,
                          border: Border.all(
                            color: widget.value
                                ? palette.accent
                                : palette.controlBorder,
                          ),
                          borderRadius: BorderRadius.circular(
                            tokens.radiusSm / 2,
                          ),
                        ),
                        child: widget.value
                            ? Icon(
                                ScIcons.check,
                                size: boxSize * 0.85,
                                color: palette.accentOn,
                              )
                            : null,
                      ),
                    ),
                    SizedBox(width: tokens.space2),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.label,
                            style: typography.xs12.copyWith(
                              color: palette.fg2,
                            ),
                          ),
                          if (helper != null) ...<Widget>[
                            SizedBox(height: tokens.space1 / 2),
                            Text(
                              helper,
                              style: typography.micro10.copyWith(
                                color: palette.muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One choice in an [ScSelect].
@immutable
class ScSelectOption<T> {
  /// Build a select option.
  const ScSelectOption({required this.value, required this.label});

  /// The value reported when this option is chosen.
  final T value;

  /// The label shown in the field and the menu.
  final String label;
}

/// A single-choice select field with an external label.
///
/// The menu is the Material dropdown menu so keyboard navigation and the
/// platform's menu behaviour stay native; the closed field carries the
/// studio's height, border, radius, and focus ring instead of Material's
/// input decoration.
class ScSelect<T> extends StatefulWidget {
  /// Build a select field.
  const ScSelect({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  /// The external label shown above the field.
  final String label;

  /// The choices, in menu order.
  final List<ScSelectOption<T>> options;

  /// The selected value; it must match one of [options].
  final T value;

  /// Called with the chosen value.
  final ValueChanged<T> onChanged;

  /// Whether the field accepts input.
  final bool enabled;

  @override
  State<ScSelect<T>> createState() => _ScSelectState<T>();
}

class _ScSelectState<T> extends State<ScSelect<T>> {
  late final FocusNode _node;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _node = FocusNode();
    _node.addListener(_handleFocus);
  }

  void _handleFocus() {
    if (!mounted) {
      return;
    }
    setState(() => _focused = _node.hasFocus);
  }

  @override
  void dispose() {
    _node.removeListener(_handleFocus);
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);

    return Opacity(
      opacity: widget.enabled ? 1 : ScTints.disabledOpacity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            widget.label,
            style: typography.xs12.copyWith(
              color: palette.fg2,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: tokens.space1),
          Semantics(
            label: widget.label,
            child: ScFocusRing.overlay(
              palette: palette,
              focused: _focused,
              child: Container(
                constraints: const BoxConstraints(minHeight: ScMetrics.field),
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.symmetric(horizontal: tokens.space3),
                decoration: BoxDecoration(
                  color: palette.surface,
                  border: Border.all(
                    color: _focused ? palette.accent : palette.controlBorder,
                  ),
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<T>(
                    value: widget.value,
                    focusNode: _node,
                    isDense: true,
                    isExpanded: true,
                    padding: EdgeInsets.zero,
                    dropdownColor: palette.surface,
                    focusColor: palette.surface.withValues(alpha: 0),
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    iconEnabledColor: palette.muted,
                    iconDisabledColor: palette.muted,
                    icon: RotatedBox(
                      quarterTurns: 1,
                      child: Icon(
                        ScIcons.chevronRight,
                        size: ScIcons.toolbarSize,
                        color: palette.muted,
                      ),
                    ),
                    style: typography.sm14.copyWith(color: palette.fg),
                    items: <DropdownMenuItem<T>>[
                      for (final ScSelectOption<T> option in widget.options)
                        DropdownMenuItem<T>(
                          value: option.value,
                          child: Text(
                            option.label,
                            overflow: TextOverflow.ellipsis,
                            style: typography.sm14.copyWith(
                              color: palette.fg,
                            ),
                          ),
                        ),
                    ],
                    onChanged: widget.enabled
                        ? (T? selected) {
                            if (selected != null) {
                              widget.onChanged(selected);
                            }
                          }
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
