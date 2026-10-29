import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/components/sc_panel.dart';
import '../../../app/design/sportcut_tokens.dart';
import '../../../app/router.dart';
import '../../editing/domain/highlight_clip.dart';
import '../../editing/domain/rally.dart';
import '../../editing/presentation/editing_providers.dart';
import '../../library/domain/match_record.dart';
import 'clip_inspector_panel.dart';
import 'reel_panel.dart';

/// The legacy highlights route host.
///
/// The studio no longer takes over the centre with this view: its Highlights
/// stage draws the shared preview and mounts [ClipInspectorPanel] and
/// [ReelPanel] through the inspector. This route wrapper composes the same two
/// panels in one scrollable column so `/match/highlights` keeps working, and it
/// still opens the editing session it owns because a legacy route has no shell
/// to open it (PR 6b; ADR-0003 D14).
class HighlightsView extends ConsumerStatefulWidget {
  /// Build the highlights view.
  const HighlightsView({super.key, required this.match});

  /// Match being reviewed.
  final MatchRecord match;

  @override
  ConsumerState<HighlightsView> createState() => _HighlightsViewState();
}

class _HighlightsViewState extends ConsumerState<HighlightsView> {
  /// The rally the user picked from the reel, for the Clip panel.
  String? _selectedRallyId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref.read(editingControllerProvider.notifier).open(widget.match),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final SportcutTokens tokens = SportcutTokens.of(context);
    final state = ref.watch(editingControllerProvider);
    final edit = state.edit;

    if (edit == null) {
      return Center(
        child: state.problem == null
            ? const CircularProgressIndicator()
            : Text(state.problem!),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(tokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ClipInspectorPanel(
            edit: edit,
            selectedRallyId: _selectedRallyId,
            problem: state.problem,
            busy: state.busy,
            onDismissProblem: () =>
                ref.read(editingControllerProvider.notifier).clearProblem(),
            onSetKept: _setKept,
            onTrim: _trim,
          ),
          SizedBox(height: tokens.space4),
          const ScDivider(),
          SizedBox(height: tokens.space4),
          ReelPanel(
            matchId: widget.match.id,
            edit: edit,
            selectedRallyId: _selectedRallyId,
            busy: state.busy,
            onSelectClip: _selectRally,
            onSetKept: _setKept,
            onReorder: _reorder,
            onKeepTop10: _keepTopTen,
            onExport: _openExport,
          ),
        ],
      ),
    );
  }

  /// Select a clip's rally; the legacy route has no shared player to seek.
  void _selectRally(Rally rally) {
    setState(() => _selectedRallyId = rally.id);
  }

  /// Put a rally in the reel, or take it out.
  void _setKept(Rally rally, bool kept) {
    unawaited(
      ref.read(editingControllerProvider.notifier).setKept(rally, kept),
    );
  }

  /// Write a trim chosen in the Clip panel's dialog.
  void _trim(HighlightClip clip, double startSeconds, double endSeconds) {
    unawaited(
      ref.read(editingControllerProvider.notifier).trimClip(
            clip.id,
            startSeconds: startSeconds,
            endSeconds: endSeconds,
          ),
    );
  }

  /// Write the reel's order.
  void _reorder(List<String> clipIds) {
    unawaited(
      ref.read(editingControllerProvider.notifier).reorderClips(clipIds),
    );
  }

  /// Keep the best ten of the rallies the reel passed back.
  Future<void> _keepTopTen(List<Rally> rallies) async {
    final controller = ref.read(editingControllerProvider.notifier);
    for (final Rally rally in rallies.take(10)) {
      await controller.setKept(rally, true);
    }
  }

  /// Open the export route, which the legacy app bar also offers.
  void _openExport() {
    Navigator.of(context).pushNamed(
      AppRoutes.export,
      arguments: widget.match,
    );
  }
}
