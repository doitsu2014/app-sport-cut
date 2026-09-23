import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

/// The application shell: theme, routing, and the root route.
class SportcutApp extends StatelessWidget {
  /// Build the shell.
  const SportcutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sportcut',
      theme: buildSportcutTheme(Brightness.light),
      darkTheme: buildSportcutTheme(Brightness.dark),
      initialRoute: AppRoutes.library,
      onGenerateRoute: AppRouter.onGenerateRoute,
      debugShowCheckedModeBanner: false,
    );
  }
}
