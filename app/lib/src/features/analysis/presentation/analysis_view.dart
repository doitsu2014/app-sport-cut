import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/sportcut_tokens.dart';
import '../../library/domain/match_record.dart';
import 'analysis_panel.dart';
import 'analysis_providers.dart';

/// The legacy full-screen host for the analysis panel.
///
/// The studio shows [AnalysisPanel] directly in its inspector, so this view
/// only keeps the old route working: it opens the app-wide analysis controller
/// for [match] once and composes the same panel in a scrolling column. The
/// constructor and callbacks are unchanged for the route wrapper and tests.
class AnalysisView extends ConsumerStatefulWidget {
  /// Build the analysis view.
  const AnalysisView({super.key, required this.match, this.onOpenTracking});

  /// Match being inspected.
  final MatchRecord match;

  /// Called when the user wants to review player analysis; the route wrapper
  /// pushes the tracking screen.
  final VoidCallback? onOpenTracking;

  @override
  ConsumerState<AnalysisView> createState() => _AnalysisViewState();
}

class _AnalysisViewState extends ConsumerState<AnalysisView> {
  @override
  void initState() {
    super.initState();
    _openAfterFrame();
  }

  @override
  void didUpdateWidget(AnalysisView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The studio reuses this view when another video is selected.
    if (oldWidget.match.id != widget.match.id) {
      _openAfterFrame();
    }
  }

  void _openAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          ref.read(analysisControllerProvider.notifier).open(widget.match),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final SportcutTokens tokens = SportcutTokens.of(context);
    return ListView(
      padding: EdgeInsets.all(tokens.space4),
      children: <Widget>[
        AnalysisPanel(
          match: widget.match,
          onOpenTracking: widget.onOpenTracking,
        ),
      ],
    );
  }
}
