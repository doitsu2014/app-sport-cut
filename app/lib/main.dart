import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/app.dart';
import 'src/app/di.dart';
import 'src/bridge/sportcut_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The engine is loaded once at startup and injected into the widget tree, so
  // no screen has to deal with an uninitialized native library.
  final engine = await SportcutEngine.initialize();

  runApp(
    ProviderScope(
      overrides: [sportcutEngineProvider.overrideWithValue(engine)],
      child: const SportcutApp(),
    ),
  );
}
