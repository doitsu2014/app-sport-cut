import 'package:flutter/material.dart';

import '../sc_elevation.dart';
import '../sc_icons.dart';
import '../sc_metrics.dart';
import '../sc_motion.dart';
import '../sc_typography.dart';
import '../sportcut_tokens.dart';

/// The search icon size, a touch below the toolbar scale.
const double _searchIconSize = ScMetrics.chip * 0.8;

/// A compact toolbar search field.
///
/// At rest the field shows the search glyph, the hint, and the `⌘K` keycap.
/// Focus removes the keycap and draws the studio ring; typing replaces the
/// keycap with a clear action. The field is [ScMetrics.toolButton] tall so it
/// sits level with the toolbar tools.
class ScSearchField extends StatefulWidget {
  /// Build a search field.
  const ScSearchField({
    required this.controller,
    required this.hint,
    required this.clearLabel,
    this.focusNode,
    this.width = ScMetrics.searchFieldWidth,
    super.key,
  });

  /// The external controller. The widget never disposes it.
  final TextEditingController controller;

  /// The placeholder and semantic label of the field.
  final String hint;

  /// The accessible name of the clear action.
  final String clearLabel;

  /// An optional external focus node. The widget owns one when this is null.
  final FocusNode? focusNode;

  /// The field width. Defaults to [ScMetrics.searchFieldWidth].
  final double width;

  @override
  State<ScSearchField> createState() => _ScSearchFieldState();
}

class _ScSearchFieldState extends State<ScSearchField> {
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
    widget.controller.addListener(_handleText);
  }

  @override
  void didUpdateWidget(ScSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleText);
      widget.controller.addListener(_handleText);
    }
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

  void _handleText() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _clear() {
    widget.controller.clear();
    _node.requestFocus();
  }

  @override
  void dispose() {
    _node.removeListener(_handleFocus);
    _ownedNode?.dispose();
    widget.controller.removeListener(_handleText);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final hasText = widget.controller.text.isNotEmpty;
    final showKeycap = !_focused && !hasText;

    return SizedBox(
      width: widget.width,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: ScMetrics.toolButton),
        child: ScFocusRing.overlay(
          palette: palette,
          focused: _focused,
          child: Container(
            decoration: BoxDecoration(
              color: palette.bg,
              border: Border.all(
                color: _focused ? palette.accent : palette.controlBorder,
              ),
              borderRadius: BorderRadius.circular(
                tokens.radiusSm + tokens.space1 / 2,
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: tokens.space2),
            child: Row(
              children: <Widget>[
                ExcludeSemantics(
                  child: Icon(
                    ScIcons.search,
                    size: _searchIconSize,
                    color: palette.muted,
                  ),
                ),
                SizedBox(width: tokens.space2),
                Expanded(
                  child: Semantics(
                    label: widget.hint,
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _node,
                      style: typography.xs12.copyWith(color: palette.fg),
                      cursorColor: palette.accent,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        constraints: const BoxConstraints(),
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: widget.hint,
                        hintStyle: typography.xs12.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    ),
                  ),
                ),
                if (showKeycap) ...<Widget>[
                  SizedBox(width: tokens.space2),
                  ExcludeSemantics(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: tokens.space1,
                        vertical: tokens.space1 / 2,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        border: Border.all(color: palette.controlBorder),
                        borderRadius:
                            BorderRadius.circular(tokens.radiusSm / 2),
                      ),
                      child: Text(
                        '⌘K',
                        style:
                            typography.chrome9.copyWith(color: palette.muted),
                      ),
                    ),
                  ),
                ] else if (hasText) ...<Widget>[
                  SizedBox(width: tokens.space1),
                  _ClearAction(
                    label: widget.clearLabel,
                    onPressed: _clear,
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

/// The icon-only clear action inside the search field.
class _ClearAction extends StatefulWidget {
  const _ClearAction({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  State<_ClearAction> createState() => _ClearActionState();
}

class _ClearActionState extends State<_ClearAction> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);

    return Tooltip(
      message: widget.label,
      child: ScFocusRing.overlay(
        palette: palette,
        focused: _focused,
        child: Semantics(
          button: true,
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
                  : palette.surfaceWarm,
              focusColor: palette.surface.withValues(alpha: 0),
              child: SizedBox.square(
                dimension: ScMetrics.toolButton,
                child: Icon(
                  ScIcons.close,
                  size: _searchIconSize,
                  color: palette.muted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
