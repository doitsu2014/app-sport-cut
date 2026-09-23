import 'package:flutter/material.dart';

/// Screen used by features that later phases implement.
///
/// Each placeholder is reachable from the shell so the navigation structure is
/// real, while the screen itself states plainly that the work has not landed.
class PlaceholderScreen extends StatelessWidget {
  /// Build a placeholder.
  const PlaceholderScreen({
    required this.title,
    required this.description,
    super.key,
  });

  /// Screen title.
  final String title;

  /// What this screen will do when the phase lands.
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.construction_outlined,
                size: 48,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'Not built yet',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
