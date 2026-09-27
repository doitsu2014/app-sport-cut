import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../library/domain/match_record.dart';
import '../../library/presentation/library_providers.dart';
import '../../library/presentation/playback_controller.dart';
import 'score_view.dart';

/// Full-screen route wrapper for the rally timeline.
///
/// The screen owns its playback controller for the route's lifetime and hosts
/// [ScoreView], which the studio also hosts with a shared controller.
class ScoreScreen extends ConsumerStatefulWidget {
  /// Build the screen.
  ///
  /// [controller] is injected by tests; the app uses the platform player.
  const ScoreScreen({required this.match, this.controller, super.key});

  /// Match being reviewed.
  final MatchRecord match;

  /// Playback backend, when supplied by a test.
  final PlaybackController? controller;

  @override
  ConsumerState<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends ConsumerState<ScoreScreen> {
  late final PlaybackController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ?? ref.read(playbackControllerFactoryProvider)();
    _ownsController = widget.controller == null;
    unawaited(_controller.load(widget.match.videoPath));
  }

  @override
  void dispose() {
    if (_ownsController) {
      unawaited(_controller.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.match.title),
        actions: <Widget>[
          IconButton(
            tooltip: 'Highlights',
            onPressed: () => Navigator.of(context).pushNamed(
              AppRoutes.highlights,
              arguments: widget.match,
            ),
            icon: const Icon(Icons.movie_outlined),
          ),
        ],
      ),
      body: ScoreView(match: widget.match, controller: _controller),
    );
  }
}
