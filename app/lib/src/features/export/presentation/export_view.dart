import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// The legacy full-screen host for export settings and the render.
///
/// The studio opens the 440 px [ExportSheet] instead, so this view only keeps
/// the old `/export` route working: it composes the same summary, form,
/// progress, failure, and success widgets in a scrolling column. The
/// constructor and [onExported] callback are unchanged.
class ExportView extends ConsumerStatefulWidget {
  /// Build the export view.
  const ExportView({super.key, required this.match, this.onExported});

  /// Match being exported.
  final MatchRecord match;

  /// Called after a render finishes so the host can refresh the stage state
  /// derived from the manifest.
  final VoidCallback? onExported;

  @override
  ConsumerState<ExportView> createState() => _ExportViewState();
}

class _ExportViewState extends ConsumerState<ExportView> {
  /// The ephemeral score-overlay choice, default on.
  bool _includeScoreOverlays = true;

  /// The last reel this session produced, kept across a failed re-render.
  ExportedReel? _lastReel;

  @override
  void initState() {
    super.initState();
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

    if (edit == null) {
      return Center(
        child: editing.problem == null
            ? const CircularProgressIndicator()
            : Text(editing.problem!),
      );
    }

    final ExportedReel? finished = export.reel;
    if (finished != null) {
      _lastReel = finished;
    }
    final ExportedReel? previous = finished ?? _lastReel;

    return ListView(
      padding: EdgeInsets.all(tokens.space4),
      children: <Widget>[
        ExportSummary(
          edit: edit,
          match: widget.match,
          includeScoreOverlays: _includeScoreOverlays,
          reel: previous,
        ),
        SizedBox(height: tokens.space4),
        if (export.running)
          ExportProgress(
            stageLabel: exportStageLabel(export.stage),
            fraction: export.stage == null && export.progress <= 0
                ? null
                : export.progress.clamp(0.0, 1.0),
            onCancel: ref.read(exportControllerProvider.notifier).cancel,
          )
        else ...<Widget>[
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
            ),
            SizedBox(height: tokens.space4),
          ],
          ExportForm(
            match: widget.match,
            edit: edit,
            // The legacy route has no catalog entry for this check; the studio
            // sheet receives it from the selected entry instead.
            recordingAvailable: true,
            includeScoreOverlays: _includeScoreOverlays,
            onIncludeScoreOverlaysChanged: (bool value) {
              setState(() => _includeScoreOverlays = value);
            },
            onRender: _render,
            renderLabel: previous == null ? 'Export reel' : 'Render again',
          ),
        ],
      ],
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

  /// Open the reel in the player route, as the legacy view always did.
  void _play(ExportedReel reel) {
    unawaited(
      Navigator.of(context).pushNamed(
        AppRoutes.player,
        arguments: widget.match.copyWith(
          title: '${widget.match.title} — highlight reel',
          videoPath: reel.path,
        ),
      ),
    );
  }
}
