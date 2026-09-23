import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../bridge/sportcut_engine.dart';
import '../../editing/domain/match_edit.dart';
import '../../library/data/media_engine.dart';
import '../../library/domain/match_record.dart';
import '../../library/presentation/library_providers.dart';
import '../data/audio_file_picker.dart';
import '../data/overlay_renderer.dart';
import '../domain/export_exception.dart';

/// Picks the music a reel is mixed with.
final audioFilePickerProvider = Provider<AudioFilePicker>(
  (ref) => SystemAudioFilePicker(),
);

/// Draws the scoreboard and title images the engine composites.
final overlayRendererProvider = Provider<OverlayRenderer>(
  (ref) => const OverlayRenderer(),
);

/// A finished reel.
class ExportedReel {
  /// Record a rendered reel.
  const ExportedReel({
    required this.path,
    required this.durationSeconds,
    required this.clipCount,
  });

  /// Where the rendered file lives.
  final String path;

  /// Duration of the reel in seconds.
  final double durationSeconds;

  /// Number of clips it contains.
  final int clipCount;

  /// The file's name, for showing to the user.
  String get fileName => p.basename(path);
}

/// What the export screen shows.
class ExportState {
  /// Describe an export.
  const ExportState({
    this.jobId,
    this.stage,
    this.progress = 0,
    this.running = false,
    this.reel,
    this.problem,
  });

  /// Job the engine is running, while it runs.
  final String? jobId;

  /// Stage the engine last reported.
  final String? stage;

  /// Progress within that stage, in the range `0..1`.
  final double progress;

  /// Whether a render is in flight.
  final bool running;

  /// The finished reel, once one has been rendered.
  final ExportedReel? reel;

  /// Why the last render failed, when it did.
  final String? problem;

  /// This state with the given fields replaced.
  ExportState copyWith({
    String? jobId,
    String? stage,
    double? progress,
    bool? running,
    ExportedReel? reel,
    String? problem,
    bool clearProblem = false,
  }) =>
      ExportState(
        jobId: jobId ?? this.jobId,
        stage: stage ?? this.stage,
        progress: progress ?? this.progress,
        running: running ?? this.running,
        reel: reel ?? this.reel,
        problem: clearProblem ? null : (problem ?? this.problem),
      );
}

/// Renders a match's highlight reel and follows it while it runs.
class ExportController extends Notifier<ExportState> {
  /// How often the engine is asked how the render is going.
  static const Duration _pollInterval = Duration(milliseconds: 300);

  @override
  ExportState build() => const ExportState();

  /// Render [edit] into a reel for [match].
  Future<void> render({
    required MatchRecord match,
    required MatchEdit edit,
  }) async {
    if (state.running) {
      return;
    }
    state = const ExportState(running: true);

    try {
      final engine = ref.read(mediaEngineProvider);
      final request = await _request(match, edit);
      final handle = await engine.startExport(request);
      state = state.copyWith(jobId: handle.jobId);

      final status = await _follow(engine, handle.jobId);
      if (status.state == JobStateDto.cancelled) {
        state = const ExportState();
        return;
      }
      if (status.state != JobStateDto.completed) {
        throw ExportException(
          status.error ??
              'The reel could not be rendered: the engine did not say why.',
        );
      }

      state = state.copyWith(
        reel: await _finished(engine, match, edit),
        running: false,
        progress: 1,
        clearProblem: true,
      );
    } on ExportException catch (error) {
      state = ExportState(problem: error.message);
    } on Object catch (error) {
      state = ExportState(problem: 'The reel could not be rendered: $error');
    }
  }

  /// Ask the engine to stop rendering.
  ///
  /// Cancellation is cooperative, so the screen keeps showing progress until the
  /// job reports itself cancelled.
  Future<void> cancel() async {
    final jobId = state.jobId;
    if (jobId == null) {
      return;
    }
    await ref.read(mediaEngineProvider).jobCancel(jobId);
  }

  /// Clear the reported problem once the screen has shown it.
  void clearProblem() {
    if (state.problem != null) {
      state = state.copyWith(clearProblem: true);
    }
  }

  /// Build the edit decision list the engine renders.
  ///
  /// The scoreboard is drawn here rather than by the engine: burning text needs
  /// a font-capable media toolchain, and compositing an image does not.
  Future<ExportRequestDto> _request(MatchRecord match, MatchEdit edit) async {
    if (edit.clips.isEmpty) {
      throw ExportException(
        'Add at least one clip to the reel before exporting.',
      );
    }

    final width = match.videoWidth ?? 1920;
    final height = match.videoHeight ?? 1080;
    final overlayDir = p.join(match.matchDir, 'export', 'overlays');
    final renderer = ref.read(overlayRendererProvider);

    final clips = <EditClipDto>[];
    for (var index = 0; index < edit.clips.length; index += 1) {
      final clip = edit.clips[index];
      final score = edit.score.atSeconds(clip.effectiveStartSeconds);
      final overlay = await renderer.writeScoreboard(
        path: p.join(overlayDir, 'score-$index.png'),
        width: width,
        height: height,
        leftScore: score.left,
        rightScore: score.right,
      );
      clips.add(
        EditClipDto(
          startSeconds: clip.effectiveStartSeconds,
          endSeconds: clip.effectiveEndSeconds,
          overlayPath: overlay.path,
        ),
      );
    }

    final settings = edit.exportSettings;
    final title = settings.title?.trim();
    EditTitleDto? titleCard;
    if (title != null && title.isNotEmpty) {
      final image = await renderer.writeTitleCard(
        path: p.join(overlayDir, 'title.png'),
        width: width,
        height: height,
        title: title,
      );
      titleCard = EditTitleDto(imagePath: image.path, seconds: 2.5);
    }

    final music = settings.musicPath;
    final hasMusic = music != null && music.isNotEmpty;
    if (hasMusic && !File(music).existsSync()) {
      throw ExportException(
        'The music you chose is no longer on this device: $music',
      );
    }

    return ExportRequestDto(
      matchId: match.id,
      matchDir: match.matchDir,
      sourcePath: match.videoPath,
      clips: clips,
      leadInSeconds: settings.leadInSeconds,
      leadOutSeconds: settings.leadOutSeconds,
      title: titleCard,
      musicPath: hasMusic ? music : null,
      musicGain: settings.musicGain,
    );
  }

  Future<JobStatusDto> _follow(MediaEngine engine, String jobId) async {
    while (true) {
      final status = await engine.jobStatus(jobId);
      state = state.copyWith(
        stage: status.stage ?? state.stage,
        progress: status.progress?.value ?? state.progress,
      );
      switch (status.state) {
        case JobStateDto.completed:
        case JobStateDto.cancelled:
        case JobStateDto.failed:
          return status;
        case JobStateDto.pending:
        case JobStateDto.running:
          await Future<void>.delayed(_pollInterval);
      }
    }
  }

  /// Read the rendered reel back from the match manifest.
  Future<ExportedReel> _finished(
    MediaEngine engine,
    MatchRecord match,
    MatchEdit edit,
  ) async {
    final manifest = await engine.manifest(match.matchDir);
    for (final artifact in manifest.artifacts) {
      if (artifact.kind == 'export') {
        return ExportedReel(
          path: p.join(match.matchDir, artifact.relativePath),
          durationSeconds: edit.reelSeconds,
          clipCount: edit.clips.length,
        );
      }
    }
    throw ExportException(
      'The render finished but the match has no exported video recorded.',
    );
  }
}

/// The export in flight.
final exportControllerProvider =
    NotifierProvider<ExportController, ExportState>(ExportController.new);
