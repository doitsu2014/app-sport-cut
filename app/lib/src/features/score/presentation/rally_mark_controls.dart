import 'package:flutter/material.dart';

import '../../../app/design/components/sc_actions.dart';
import '../../../app/design/sc_typography.dart';
import '../../../app/design/sportcut_tokens.dart';
import '../../library/presentation/formatters.dart';

/// The manual mark controls for one rally.
///
/// Mark start remembers the current playback position; mark end closes the
/// span and writes it. The widget is data-in / callback-out: the caller owns
/// the pending start and the player position.
class RallyMarkControls extends StatelessWidget {
  /// Build the mark controls.
  const RallyMarkControls({
    super.key,
    required this.pendingStart,
    required this.busy,
    required this.ready,
    required this.onMarkStart,
    required this.onMarkEnd,
    required this.onCancel,
  });

  /// Where the user marked the start of the rally being built, in seconds.
  final double? pendingStart;

  /// Whether a review change is being written.
  final bool busy;

  /// Whether the player can supply a position.
  final bool ready;

  /// Marks the start at the current position.
  final VoidCallback onMarkStart;

  /// Marks the end at the current position, or null while no start is held.
  final VoidCallback? onMarkEnd;

  /// Clears the pending start.
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final start = pendingStart;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ScButton.compact(
          label: start == null
              ? 'Mark start'
              : 'Start at ${formatDuration(start)}',
          variant: ScButtonVariant.secondary,
          enabled: ready && !busy,
          expanded: true,
          onPressed: onMarkStart,
        ),
        SizedBox(height: tokens.space2),
        Row(
          children: <Widget>[
            Expanded(
              child: ScButton.compact(
                label: 'Mark end',
                variant: ScButtonVariant.secondary,
                enabled: !busy,
                expanded: true,
                onPressed: onMarkEnd,
              ),
            ),
            if (start != null) ...<Widget>[
              SizedBox(width: tokens.space2),
              ScButton.compact(
                label: 'Cancel',
                variant: ScButtonVariant.ghost,
                onPressed: onCancel,
              ),
            ],
          ],
        ),
        if (start != null) ...<Widget>[
          SizedBox(height: tokens.space1),
          Text(
            'Start at ${formatDuration(start)}. Scrub to the end, then mark it.',
            style: typography.xs12.copyWith(color: palette.muted),
          ),
        ],
      ],
    );
  }
}
