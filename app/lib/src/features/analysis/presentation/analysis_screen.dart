import 'package:flutter/material.dart';

import '../../../app/router.dart';
import '../../library/domain/match_record.dart';
import 'analysis_view.dart';

/// Full-screen route wrapper for the analysis summary.
///
/// The view itself is embedded by the studio; this wrapper only adds the
/// chrome and the tracking shortcut.
class AnalysisScreen extends StatelessWidget {
  /// Build the screen.
  const AnalysisScreen({required this.match, super.key});

  /// Match being inspected.
  final MatchRecord match;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analysis')),
      body: AnalysisView(
        match: match,
        onOpenTracking: () => Navigator.of(context).pushNamed(
          AppRoutes.playerTracking,
          arguments: match,
        ),
      ),
    );
  }
}
