import 'package:flutter/material.dart';

import '../../../app/placeholder_screen.dart';
import '../../library/domain/match_record.dart';

/// Highlight review: the suggested clips, ranked, kept or removed.
class HighlightsScreen extends StatelessWidget {
  /// Build the highlights screen.
  const HighlightsScreen({required this.match, super.key});

  /// Match being reviewed.
  final MatchRecord match;

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
        title: 'Highlights',
        description:
            'Ranked highlight clips for ${match.title} land with the highlight '
            'intelligence phase.',
      );
}
