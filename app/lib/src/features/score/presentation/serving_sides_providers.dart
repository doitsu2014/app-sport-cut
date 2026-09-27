import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../bridge/sportcut_engine.dart';
import '../../editing/domain/rally.dart';
import '../../editing/presentation/editing_providers.dart';

/// The side that served each rally, keyed by rally id.
///
/// Rallies without a derivable server (the first rally, or one whose previous
/// rally is unscored) are absent from the map. Recomputed whenever the edit
/// reloads.
final servingSidesProvider = FutureProvider<Map<String, RallySideDto>>(
  (ref) async {
    final edit = ref.watch(editingControllerProvider).edit;
    if (edit == null || edit.rallies.isEmpty) {
      return const <String, RallySideDto>{};
    }
    final engine = ref.read(sportcutEngineProvider);
    final sides = await engine.servingSides(<RallyOutcomeDto>[
      for (final rally in edit.rallies)
        RallyOutcomeDto(
          rallyId: rally.id,
          winner: rally.winnerSide == null
              ? null
              : (rally.winnerSide == WinnerSide.left
                  ? RallySideDto.left
                  : RallySideDto.right),
        ),
    ]);
    return <String, RallySideDto>{
      for (final side in sides)
        if (side.side != null) side.rallyId: side.side!,
    };
  },
);
