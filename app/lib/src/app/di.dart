import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bridge/sportcut_engine.dart';

/// The engine, loaded once at startup.
///
/// Overridden in `main.dart` with the initialized instance. Widget tests
/// override the repository instead, so they never touch the native library.
final sportcutEngineProvider = Provider<SportcutEngine>(
  (ref) => throw StateError(
    'sportcutEngineProvider was not overridden. '
    'Initialize SportcutEngine and override this provider in main().',
  ),
);
