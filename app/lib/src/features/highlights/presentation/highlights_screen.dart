import 'package:flutter/material.dart';

import '../../../app/router.dart';
import '../../library/domain/match_record.dart';
import 'highlights_view.dart';

/// Full-screen route wrapper for the highlight reel.
///
/// The view itself is embedded by the studio; this wrapper only adds the
/// chrome and the export shortcut.
class HighlightsScreen extends StatelessWidget {
  /// Build the screen.
  const HighlightsScreen({required this.match, super.key});

  /// Match being reviewed.
  final MatchRecord match;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Highlights'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Export',
            onPressed: () => Navigator.of(context).pushNamed(
              AppRoutes.export,
              arguments: match,
            ),
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: HighlightsView(match: match),
    );
  }
}
