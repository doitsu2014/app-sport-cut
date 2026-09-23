import 'package:flutter/material.dart';

import '../../../app/placeholder_screen.dart';
import '../../library/domain/match_record.dart';

/// Analysis progress and review: job progress, cancellation, and the artifacts
/// the engine produced.
class AnalysisScreen extends StatelessWidget {
  /// Build the analysis screen.
  const AnalysisScreen({required this.match, super.key});

  /// Match being analysed.
  final MatchRecord match;

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
        title: 'Analysis',
        description:
            'Job progress and artifact review for ${match.title} lands with the '
            'detection and tracking phases.',
      );
}
