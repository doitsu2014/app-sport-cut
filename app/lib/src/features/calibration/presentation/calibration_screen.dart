import 'package:flutter/material.dart';

import '../../../app/placeholder_screen.dart';
import '../../library/domain/match_record.dart';

/// Court calibration: marking the court corners so later phases can map image
/// coordinates to court coordinates.
class CalibrationScreen extends StatelessWidget {
  /// Build the calibration screen.
  const CalibrationScreen({required this.match, super.key});

  /// Match being calibrated.
  final MatchRecord match;

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
        title: 'Court calibration',
        description:
            'Marking the court corners for ${match.title} lands with the court '
            'geometry phase.',
      );
}
