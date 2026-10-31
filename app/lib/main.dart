import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/app.dart';
import 'src/app/di.dart';
import 'src/bridge/service_supervisor.dart';
import 'src/bridge/sportcut_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // In development the endpoint comes from the environment; a packaged build
  // starts the embedded helper and connects to it.
  final target = await ServiceSupervisor.ensure();
  final engine = await SportcutEngine.initialize(target: target);

  AppLifecycleListener(
    onExitRequested: () async {
      ServiceSupervisor.stop();
      return AppExitResponse.exit;
    },
  );

  runApp(
    ProviderScope(
      overrides: [sportcutEngineProvider.overrideWithValue(engine)],
      child: const SportcutApp(),
    ),
  );
}
