import 'package:flutter/material.dart';

import '../../../app/placeholder_screen.dart';
import '../../library/domain/match_record.dart';

/// Export settings: the final video, with score overlays and music.
class ExportScreen extends StatelessWidget {
  /// Build the export screen.
  const ExportScreen({required this.match, super.key});

  /// Match being exported.
  final MatchRecord match;

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
        title: 'Export',
        description:
            'Building the highlight video for ${match.title} lands with the '
            'export phase, after the media library decision is settled.',
      );
}
