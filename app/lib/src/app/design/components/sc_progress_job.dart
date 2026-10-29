import 'package:flutter/material.dart';

import '../sc_elevation.dart';
import '../sc_metrics.dart';
import '../sc_typography.dart';
import '../sportcut_tokens.dart';

/// The height of the progress track, derived from the chip scale.
const double _barHeight = ScMetrics.chip / 4;

/// A determinate long-running job.
///
/// The stage label is always shown, whether or not the engine has reported a
/// completion fraction; a missing fraction renders an empty track rather than
/// an indeterminate spinner, so the user still knows what is running.
class ScProgressJob extends StatelessWidget {
  /// Build a job card.
  const ScProgressJob({
    required this.stageLabel,
    required this.fraction,
    this.detail,
    this.onCancel,
    super.key,
  });

  /// The stage the job is running, for example "Preparing analysis".
  final String stageLabel;

  /// Completion in the range 0 to 1, or null when no value has arrived yet.
  final double? fraction;

  /// The supporting line under the bar, for example "Rally detection · Court 3".
  final String? detail;

  /// Cancels the job. No cancel control is drawn when this is null.
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final detailText = detail;
    final cancel = onCancel;
    final value = fraction;
    final clamped = value == null ? 0.0 : value.clamp(0.0, 1.0).toDouble();
    final percent = (clamped * 100).round();

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.borderSoft),
        borderRadius: BorderRadius.circular(tokens.radiusMd),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.space4,
        vertical: tokens.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Expanded(
                child: Text(
                  stageLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.sm14.copyWith(
                    color: palette.fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (value != null) ...<Widget>[
                SizedBox(width: tokens.space3),
                Text(
                  '$percent%',
                  style: typography.timecode11.copyWith(color: palette.fg2),
                ),
              ],
            ],
          ),
          SizedBox(height: tokens.space2 + tokens.space1 / 2),
          Semantics(
            label: stageLabel,
            value: value == null ? null : '$percent%',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radiusPill),
              child: LinearProgressIndicator(
                value: clamped,
                minHeight: _barHeight,
                backgroundColor: palette.surfaceWarm,
                valueColor: AlwaysStoppedAnimation<Color>(
                  value == null ? palette.border : palette.accent,
                ),
              ),
            ),
          ),
          if (detailText != null || cancel != null) ...<Widget>[
            SizedBox(height: tokens.space2),
            Row(
              children: <Widget>[
                Expanded(
                  child: detailText == null
                      ? const SizedBox.shrink()
                      : Text(
                          detailText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.xs12.copyWith(
                            color: palette.muted,
                          ),
                        ),
                ),
                if (cancel != null)
                  _CancelAction(
                    label: 'Cancel',
                    onPressed: cancel,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The compact cancel control inside a job card.
class _CancelAction extends StatefulWidget {
  const _CancelAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_CancelAction> createState() => _CancelActionState();
}

class _CancelActionState extends State<_CancelAction> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);

    return ScFocusRing.overlay(
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
            hoverColor: palette.surfaceWarm,
            child: Container(
              constraints: const BoxConstraints(
                minHeight: ScMetrics.buttonCompact,
              ),
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: tokens.space3),
              child: Text(
                widget.label,
                style: typography.xs12.copyWith(
                  color: palette.fg2,
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
