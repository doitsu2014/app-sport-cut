import 'package:flutter/material.dart';

import '../../library/domain/match_record.dart';
import 'export_view.dart';

/// Full-screen route wrapper for export settings and render.
///
/// The view itself is embedded by the studio; this wrapper only adds the
/// chrome.
class ExportScreen extends StatelessWidget {
  /// Build the screen.
  const ExportScreen({required this.match, super.key});

  /// Match being exported.
  final MatchRecord match;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Export ${match.title}')),
      body: ExportView(match: match),
    );
  }
}
