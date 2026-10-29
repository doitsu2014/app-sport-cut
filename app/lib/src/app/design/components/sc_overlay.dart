import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../sc_elevation.dart';
import '../sc_icons.dart';
import '../sc_metrics.dart';
import '../sc_overlay_colors.dart';
import '../sc_tints.dart';
import '../sc_typography.dart';
import '../sportcut_tokens.dart';

/// The aspect ratio used until a player has reported a finite one.
const double _defaultAspectRatio = 16 / 9;

/// Secondary ink opacity for explanatory copy on the footage bed.
const double _secondaryInkAlpha = 0.62;

/// Ink opacity for a named file on the footage bed.
const double _fileInkAlpha = 0.86;

/// The hover wash over a bed control.
const double _hoverTintAlpha = 0.10;

/// A control border at rest.
const double _restBorderAlpha = 0.28;

/// A control border under the pointer.
const double _hoverBorderAlpha = 0.5;

/// The dark video bed that hosts a player and its footage overlays.
///
/// The bed is always [ScOverlayColors.bed] in both themes: it is footage
/// chrome, not UI chrome (ADR-0003 D16). The video child and every overlay are
/// laid out in one aspect-fit box, so an overlay can never drift away from the
/// frame it annotates.
class ScVideoStage extends StatelessWidget {
  /// Build a stage for [videoChild] at [aspectRatio].
  const ScVideoStage({
    super.key,
    required this.videoChild,
    required this.aspectRatio,
    this.overlay,
    this.errorSlot,
    this.showMissing = false,
    this.missingFileName = '',
  });

  /// The video surface, or null while nothing has loaded.
  final Widget? videoChild;

  /// The footage aspect ratio, as reported by the player.
  final double aspectRatio;

  /// An overlay drawn in the stage's aspect box, above the video.
  final Widget? overlay;

  /// A centred error treatment shown when playback fails.
  final Widget? errorSlot;

  /// Whether the recording is missing and the honest state should cover the
  /// frame.
  final bool showMissing;

  /// The name of the missing recording, shown in the missing state.
  final String missingFileName;

  @override
  Widget build(BuildContext context) {
    final video = videoChild;
    final error = errorSlot;
    final stageOverlay = overlay;
    final ratio = aspectRatio.isFinite && aspectRatio > 0
        ? aspectRatio
        : _defaultAspectRatio;

    return ColoredBox(
      color: ScOverlayColors.bed,
      child: Center(
        child: AspectRatio(
          aspectRatio: ratio,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: <Widget>[
              if (video != null) video,
              if (error != null) Center(child: error),
              if (stageOverlay != null) Positioned.fill(child: stageOverlay),
              if (showMissing)
                Positioned.fill(
                  child: ScMissingRecording(fileName: missingFileName),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The honest state for a match whose recording is no longer on disk.
///
/// It follows ADR-0003 D8: the state names the fact, never invents a relocate
/// action, and says that importing a replacement creates a new match. It is
/// designed to sit over [ScVideoStage]'s bed scrim.
class ScMissingRecording extends StatelessWidget {
  /// Build the missing-recording state.
  const ScMissingRecording({
    super.key,
    required this.fileName,
    this.actionLabel,
    this.onAction,
    this.note,
  });

  /// The name of the recording that could not be found.
  final String fileName;

  /// The label for the recovery action, or null for no action.
  final String? actionLabel;

  /// The recovery action, or null for no action.
  final VoidCallback? onAction;

  /// Explanatory copy shown under the file name.
  ///
  /// When null, the state explains that importing a replacement creates a new
  /// match.
  final String? note;

  /// The factual heading.
  static const String _title = 'Recording missing';

  /// The factual body from `DESIGN.md` §8.
  static const String _body =
      'The recording is no longer at its original path.';

  /// The default note required by ADR-0003 D8.
  static const String _defaultNote =
      'Importing a replacement creates a new match.';

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final typography = SportcutTypography.of(context);
    final tokens = SportcutTokens.of(context);
    final action = onAction;
    final actionText = actionLabel;
    final showAction = action != null && actionText != null;
    const ink = ScOverlayColors.ink;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ScTints.scrim(ScOverlayColors.bed),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: ScMetrics.dialogConfirm),
          child: Padding(
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
                  _title,
                  textAlign: TextAlign.center,
                  style: typography.title20.copyWith(color: ink),
                ),
                SizedBox(height: tokens.space2),
                if (fileName.isNotEmpty) ...<Widget>[
                  Text(
                    fileName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: typography.timecode11.copyWith(
                      color: ink.withValues(alpha: _fileInkAlpha),
                    ),
                  ),
                  SizedBox(height: tokens.space2),
                ],
                Text(
                  _body,
                  textAlign: TextAlign.center,
                  style: typography.xs12.copyWith(
                    color: ink.withValues(alpha: _secondaryInkAlpha),
                  ),
                ),
                SizedBox(height: tokens.space1),
                Text(
                  note ?? _defaultNote,
                  textAlign: TextAlign.center,
                  style: typography.xs12.copyWith(
                    color: ink.withValues(alpha: _secondaryInkAlpha),
                  ),
                ),
                if (showAction) ...<Widget>[
                  SizedBox(height: tokens.space4),
                  _MissingActionButton(label: actionText, onPressed: action),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A secondary action drawn on the footage bed.
///
/// The bed is fixed dark, so the control uses the overlay ink rather than a
/// theme surface: a light-theme surface would read as a floating page card.
class _MissingActionButton extends StatefulWidget {
  const _MissingActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_MissingActionButton> createState() => _MissingActionButtonState();
}

class _MissingActionButtonState extends State<_MissingActionButton> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final typography = SportcutTypography.of(context);
    final tokens = SportcutTokens.of(context);
    const ink = ScOverlayColors.ink;
    final background = _hovered
        ? ink.withValues(alpha: _hoverTintAlpha)
        : ink.withValues(alpha: 0);
    final border = ink.withValues(
      alpha: _hovered ? _hoverBorderAlpha : _restBorderAlpha,
    );

    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        mouseCursor: SystemMouseCursors.click,
        shortcuts: _activateShortcuts,
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (intent) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: widget.onPressed,
          child: ScFocusRing.overlay(
            palette: palette,
            focused: _focused,
            child: Container(
              constraints: const BoxConstraints(minHeight: ScMetrics.button),
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: tokens.space4),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(tokens.radiusMd),
                border: Border.all(color: border),
              ),
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typography.xs12.copyWith(
                  color: ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The two keys that activate a focused bed control.
const Map<ShortcutActivator, Intent> _activateShortcuts =
    <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
};
