import 'package:flutter/material.dart';

import '../features/analysis/presentation/analysis_screen.dart';
import '../features/calibration/presentation/calibration_screen.dart';
import '../features/export/presentation/export_screen.dart';
import '../features/highlights/presentation/highlights_screen.dart';
import '../features/library/domain/match_record.dart';
import '../features/library/presentation/library_screen.dart';
import '../features/library/presentation/player_screen.dart';
import '../features/score/presentation/score_screen.dart';

/// Named routes of the application.
///
/// Navigation is deliberately a plain route table: the shell has seven screens
/// and no deep links yet, so a routing package would add a dependency without
/// removing code. This table is the single place to change if that stops being
/// true.
abstract final class AppRoutes {
  /// Match library: the home screen.
  static const String library = '/';

  /// Local playback of one match.
  static const String player = '/match/player';

  /// Court calibration (later phase).
  static const String calibration = '/match/calibration';

  /// Analysis progress and review (later phase).
  static const String analysis = '/match/analysis';

  /// Score confirmation (later phase).
  static const String score = '/match/score';

  /// Highlight review (later phase).
  static const String highlights = '/match/highlights';

  /// Export settings (later phase).
  static const String export = '/match/export';
}

/// Builds routes from the named route table.
abstract final class AppRouter {
  /// Route factory handed to `MaterialApp.onGenerateRoute`.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.library:
        return _route(settings, const LibraryScreen());
      case AppRoutes.player:
        return _route(settings, PlayerScreen(match: matchFrom(settings)));
      case AppRoutes.calibration:
        return _route(settings, CalibrationScreen(match: matchFrom(settings)));
      case AppRoutes.analysis:
        return _route(settings, AnalysisScreen(match: matchFrom(settings)));
      case AppRoutes.score:
        return _route(settings, ScoreScreen(match: matchFrom(settings)));
      case AppRoutes.highlights:
        return _route(settings, HighlightsScreen(match: matchFrom(settings)));
      case AppRoutes.export:
        return _route(settings, ExportScreen(match: matchFrom(settings)));
      default:
        return null;
    }
  }

  /// The match passed as a route argument.
  ///
  /// Throws [ArgumentError] when a route that needs a match is opened without
  /// one, which keeps a programming mistake visible instead of showing an empty
  /// screen.
  static MatchRecord matchFrom(RouteSettings settings) {
    final argument = settings.arguments;
    if (argument is MatchRecord) {
      return argument;
    }
    throw ArgumentError(
      'Route ${settings.name} needs a MatchRecord argument, '
      'got ${argument.runtimeType}',
    );
  }

  static MaterialPageRoute<dynamic> _route(
    RouteSettings settings,
    Widget screen,
  ) =>
      MaterialPageRoute<dynamic>(
        settings: settings,
        builder: (context) => screen,
      );
}
