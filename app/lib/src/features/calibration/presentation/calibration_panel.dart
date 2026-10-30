import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/components/sc_actions.dart';
import '../../../app/design/components/sc_banner.dart';
import '../../../app/design/components/sc_panel.dart';
import '../../../app/design/components/sc_segmented_tabs.dart';
import '../../../app/design/sc_icons.dart';
import '../../../app/design/sc_typography.dart';
import '../../../app/design/sportcut_tokens.dart';
import '../../library/domain/match_record.dart';
import '../domain/court_calibration.dart';
import 'calibration_controller.dart';

/// The Mark court work surface in the studio inspector.
///
/// The panel carries everything that is not the overlay itself: the current
/// orientation, the control that changes it, the save and cancel actions, the
/// corner hint, and the controller's validation message. It reads the shared
/// [calibrationControllerProvider], so the stage overlay and this panel always
/// describe the same corners.
///
/// Saving keeps the controller's behaviour: the controller stores the court and
/// returns the refreshed match, and the panel reports that match through
/// [onSaved] (the studio refreshes its facts, the legacy route pops with it).
class CalibrationPanel extends ConsumerStatefulWidget {
  /// Build the panel for [match].
  const CalibrationPanel({
    super.key,
    required this.match,
    this.onSaved,
    this.onCancel,
  });

  /// Match being calibrated.
  final MatchRecord match;

  /// Called with the updated match after a successful save.
  final ValueChanged<MatchRecord>? onSaved;

  /// Leave the Mark court stage without saving.
  final VoidCallback? onCancel;

  @override
  ConsumerState<CalibrationPanel> createState() => _CalibrationPanelState();
}

class _CalibrationPanelState extends ConsumerState<CalibrationPanel> {
  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(covariant CalibrationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.id != widget.match.id) {
      _open();
    }
  }

  /// Restore the stored calibration; opening the same match is a no-op.
  void _open() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(calibrationControllerProvider.notifier).open(widget.match);
    });
  }

  /// Store the marked court and report the refreshed match.
  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final updated = await ref
        .read(calibrationControllerProvider.notifier)
        .save(widget.match);
    if (updated == null || !mounted) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text('Court marked for ${updated.title}')),
    );
    widget.onSaved?.call(updated);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calibrationControllerProvider);
    final controller = ref.read(calibrationControllerProvider.notifier);
    final palette = SportcutPalette.of(context);
    final tokens = SportcutTokens.of(context);
    final typography = SportcutTypography.of(context);
    final canSave = state.isComplete && !state.saving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const ScSectionHeader(label: 'Court'),
        ScMetaList(
          items: <(String, String)>[
            ('Court runs', _orientationLabel(state.orientation)),
            ('Corners', '${state.corners.length} of 4'),
          ],
        ),
        SizedBox(height: tokens.space2),
        Text(
          'Which way does the court run?',
          style: typography.xs12.copyWith(
            color: palette.fg2,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: tokens.space1),
        ScSegmentedControl(
          options: const <String>['Away from you', 'Across the view'],
          selectedIndex: state.orientation == CourtOrientation.away ? 0 : 1,
          enabled: !state.saving,
          onChanged: (int index) => unawaited(
            controller.setOrientation(
              index == 0 ? CourtOrientation.away : CourtOrientation.across,
            ),
          ),
        ),
        if (state.problem != null) ...<Widget>[
          SizedBox(height: tokens.space3),
          ScBanner(message: state.problem!, tone: ScBannerTone.danger),
        ],
        SizedBox(height: tokens.space3),
        Text(
          _progressLabel(state),
          style: typography.xs12.copyWith(color: palette.muted),
        ),
        SizedBox(height: tokens.space3),
        ScButton(
          label: state.stored ? 'Update court' : 'Save court',
          icon: ScIcons.check,
          expanded: true,
          loading: state.saving,
          enabled: canSave,
          onPressed: canSave ? _save : null,
        ),
        SizedBox(height: tokens.space2),
        ScButton(
          label: 'Cancel',
          variant: ScButtonVariant.secondary,
          expanded: true,
          enabled: widget.onCancel != null,
          onPressed: widget.onCancel,
        ),
      ],
    );
  }

  /// The orientation in the same words the control uses.
  String _orientationLabel(CourtOrientation orientation) =>
      orientation == CourtOrientation.away ? 'Away from you' : 'Across the view';

  /// The one supporting line under the controls.
  String _progressLabel(CalibrationState state) {
    if (!state.isComplete) {
      return 'Place all four corners to see the projected net.';
    }
    if (state.isProjected) {
      return 'The dashed line is the net the engine projects from your '
          'corners. Adjust until it sits on the real one.';
    }
    return 'Drag a handle to project the net.';
  }
}
