import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/components/sc_actions.dart';
import '../../../app/design/components/sc_banner.dart';
import '../../../app/design/components/sc_dialog.dart';
import '../../../app/design/components/sc_progress_job.dart';
import '../../../app/design/sc_metrics.dart';
import '../../../app/design/sportcut_tokens.dart';
import '../../../app/router.dart';
import '../../editing/domain/match_edit.dart';
import '../../editing/presentation/editing_providers.dart';
import '../../library/domain/match_record.dart';
import 'export_form.dart';
import 'export_progress.dart';
import 'export_providers.dart';
import 'export_success.dart';
import 'export_summary.dart';

/// The 440 px export sheet: the only place the reel is assembled and rendered.
///
/// It is shown with `showDialog` over the studio, not as a full-screen route.
/// The studio's `exportSheetOpen` flag mirrors whether it is open: the host
/// opens and closes this sheet from the flag, and the shortcut layer's Escape
/// order remains the single Escape path. The dialog route's own dismiss still
/// works and the host writes the closed flag back afterwards.
///
/// While a render runs the sheet shows only its determinate progress. Once it
/// finishes, the success card sits above the same settings form, so "render
/// again" keeps the settings editable. The form's "Include score overlays"
/// choice is ephemeral here; there is no persisted filename and no new durable
/// setting (D11).
class ExportSheet extends ConsumerStatefulWidget {
  /// Build the export sheet for [match].
  const ExportSheet({
    super.key,
    required this.match,
    required this.recordingAvailable,
    this.onExported,
  });

  /// Match being exported.
  final MatchRecord match;

  /// Whether the match's recording can still be read.
  final bool recordingAvailable;

  /// Called after a render finishes so the studio refreshes its stage facts.
  final VoidCallback? onExported;

  @override
  ConsumerState<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<ExportSheet> {
  /// The ephemeral score-overlay choice, default on.
  bool _includeScoreOverlays = true;

  /// The last reel this session produced, kept across a failed re-render.
  ExportedReel? _lastReel;

  @override
  void initState() {
    super.initState();
    // The studio opens the review with the selected video, but the sheet can
    // also be reached from the legacy route; opening the same match is a no-op.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          ref.read(editingControllerProvider.notifier).ensureOpen(widget.match),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final SportcutTokens tokens = SportcutTokens.of(context);
    final EditingState editing = ref.watch(editingControllerProvider);
    final ExportState export = ref.watch(exportControllerProvider);
    final MatchEdit? edit =
        editing.match?.id == widget.match.id ? editing.edit : null;

    // Keep the last finished reel through the controller's failure reset.
    final ExportedReel? finished = export.reel;
    if (finished != null) {
      _lastReel = finished;
    }
    final ExportedReel? previous = finished ?? _lastReel;

    final Widget body;
    final List<Widget> actions;
    if (edit == null) {
      body = editing.problem == null
          ? const ScProgressJob(
              stageLabel: 'Opening the export settings…',
              fraction: null,
            )
          : ScBanner(message: editing.problem!, tone: ScBannerTone.danger);
      actions = <Widget>[
        ScButton(
          label: 'Cancel',
          variant: ScButtonVariant.ghost,
          onPressed: _close,
        ),
      ];
    } else if (export.running) {
      body = ExportProgress(
        stageLabel: exportStageLabel(export.stage),
        fraction: export.stage == null && export.progress <= 0
            ? null
            : export.progress.clamp(0.0, 1.0),
        onCancel: ref.read(exportControllerProvider.notifier).cancel,
      );
      actions = const <Widget>[];
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ExportSummary(
            edit: edit,
            match: widget.match,
            includeScoreOverlays: _includeScoreOverlays,
            reel: previous,
          ),
          SizedBox(height: tokens.space4),
          if (export.problem != null) ...<Widget>[
            ExportFailure(
              message: export.problem!,
              previousReel: previous,
              onPlay: previous == null ? null : () => _play(previous),
            ),
            SizedBox(height: tokens.space4),
          ],
          if (finished != null) ...<Widget>[
            ExportSuccess(
              reel: finished,
              onPlay: () => _play(finished),
              onDone: _close,
            ),
            SizedBox(height: tokens.space4),
          ],
          ExportForm(
            match: widget.match,
            edit: edit,
            recordingAvailable: widget.recordingAvailable,
            includeScoreOverlays: _includeScoreOverlays,
            onIncludeScoreOverlaysChanged: (bool value) {
              setState(() => _includeScoreOverlays = value);
            },
            onRender: _render,
            renderLabel: previous == null ? 'Export reel' : 'Render again',
          ),
        ],
      );
      actions = finished == null
          ? <Widget>[
              ScButton(
                label: 'Cancel',
                variant: ScButtonVariant.ghost,
                onPressed: _close,
              ),
            ]
          : const <Widget>[];
    }

    return ScDialog(
      title: 'Export highlight reel',
      width: ScMetrics.exportSheetWidth,
      actions: actions,
      child: ConstrainedBox(
        // Bound the scrolling body so the card still fits a 720 px window.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height - tokens.space12 * 5,
        ),
        child: SingleChildScrollView(child: body),
      ),
    );
  }

  /// Render the current settings with the ephemeral overlay choice.
  Future<void> _render() async {
    final EditingState editing = ref.read(editingControllerProvider);
    final MatchEdit? edit = editing.edit;
    if (edit == null || editing.match?.id != widget.match.id) {
      return;
    }
    await ref.read(exportControllerProvider.notifier).render(
          match: widget.match,
          edit: edit,
          includeScoreOverlays: _includeScoreOverlays,
        );
    widget.onExported?.call();
  }

  /// Close the sheet. The host sees the route finish and clears the flag.
  void _close() {
    Navigator.of(context).pop();
  }

  /// Close the sheet and open the reel in the shared player.
  void _play(ExportedReel reel) {
    final NavigatorState navigator = Navigator.of(context);
    navigator.pop();
    unawaited(
      navigator.pushNamed(
        AppRoutes.player,
        arguments: widget.match.copyWith(
          title: '${widget.match.title} — highlight reel',
          videoPath: reel.path,
        ),
      ),
    );
  }
}
