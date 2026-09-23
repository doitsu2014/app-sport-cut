import 'package:flutter/material.dart';

import '../../../app/placeholder_screen.dart';
import '../../library/domain/match_record.dart';

/// Score confirmation: the human-in-the-loop step that keeps the product from
/// being an automated referee.
class ScoreScreen extends StatelessWidget {
  /// Build the score screen.
  const ScoreScreen({required this.match, super.key});

  /// Match being scored.
  final MatchRecord match;

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
        title: 'Score confirmation',
        description:
            'Confirming suggested rally winners for ${match.title} lands with '
            'the semi-automatic scoring phase.',
      );
}
