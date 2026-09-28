import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/router.dart';
import '../../editing/domain/export_settings.dart';
import '../../editing/domain/match_edit.dart';
import '../../editing/presentation/editing_providers.dart';
import '../../library/domain/match_record.dart';
import '../../library/presentation/formatters.dart';
import 'export_providers.dart';

/// Export settings and the render: title, music, padding, then the reel.
///
/// A form-style panel with no playback of its own, so the studio hosts it
/// directly in the center pane.
class ExportView extends ConsumerStatefulWidget {
  /// Build the export view.
  const ExportView({super.key, required this.match, this.onExported});

  /// Match being exported.
  final MatchRecord match;

  /// Called after a render finishes so the host can refresh the stage state
  /// derived from the manifest.
  final VoidCallback? onExported;

  @override
  ConsumerState<ExportView> createState() => _ExportViewState();
}

class _ExportViewState extends ConsumerState<ExportView> {
  final TextEditingController _title = TextEditingController();
  String? _titleLoadedFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref.read(editingControllerProvider.notifier).open(widget.match),
      );
    });
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = ref.watch(editingControllerProvider);
    final export = ref.watch(exportControllerProvider);
    final edit = editing.edit;

    if (edit != null && _titleLoadedFor != edit.exportSettings.matchId) {
      _titleLoadedFor = edit.exportSettings.matchId;
      _title.text = edit.exportSettings.title ?? '';
    }

    return edit == null
        ? Center(
            child: editing.problem == null
                ? const CircularProgressIndicator()
                : Text(editing.problem!),
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _ReelSummary(edit: edit),
              const SizedBox(height: 16),
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Title card',
                  helperText: 'Leave empty for no title card',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => _save(
                  edit.exportSettings.copyWith(
                    title: value.trim().isEmpty ? null : value,
                    clearTitle: value.trim().isEmpty,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _MusicPicker(match: widget.match, edit: edit),
              const SizedBox(height: 16),
              _Padding(edit: edit, onChanged: _save),
              const SizedBox(height: 24),
              _Render(
                export: export,
                edit: edit,
                match: widget.match,
                onExported: widget.onExported,
              ),
            ],
          );
  }

  void _save(ExportSettings settings) {
    unawaited(
      ref.read(editingControllerProvider.notifier).saveSettings(settings),
    );
  }
}

class _ReelSummary extends StatelessWidget {
  const _ReelSummary({required this.edit});

  final MatchEdit edit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = edit.score;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.movie_creation_outlined),
        title: Text(
          '${edit.clips.length} clips · '
          '${formatDuration(edit.reelSeconds)}',
        ),
        subtitle: Text(
          score.isEmpty
              ? 'No score confirmed yet, so no scoreboard will be burned in.'
              : 'Scoreboard through ${score.left}–${score.right}',
          style: theme.textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _MusicPicker extends ConsumerWidget {
  const _MusicPicker({required this.match, required this.edit});

  final MatchRecord match;
  final MatchEdit edit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final music = edit.exportSettings.musicPath;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.music_note_outlined),
        title: Text(
          music == null || music.isEmpty ? 'No music' : _name(music),
        ),
        subtitle: const Text('Music is mixed under the match audio'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (music != null && music.isNotEmpty)
              IconButton(
                tooltip: 'Remove music',
                onPressed: () => ref
                    .read(editingControllerProvider.notifier)
                    .saveSettings(
                      edit.exportSettings.copyWith(clearMusic: true),
                    ),
                icon: const Icon(Icons.close),
              ),
            TextButton(
              onPressed: () => _pick(context, ref),
              child: const Text('Choose'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await ref.read(audioFilePickerProvider).pickAudio();
      if (picked == null) {
        return;
      }
      await ref.read(editingControllerProvider.notifier).saveSettings(
            edit.exportSettings.copyWith(musicPath: picked.path),
          );
    } on Object catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  static String _name(String path) {
    final parts = path.split(Platform.pathSeparator);
    return parts.isEmpty ? path : parts.last;
  }
}

class _Padding extends StatelessWidget {
  const _Padding({required this.edit, required this.onChanged});

  final MatchEdit edit;
  final ValueChanged<ExportSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final settings = edit.exportSettings;
    return Card(
      child: Column(
        children: <Widget>[
          ListTile(
            title: const Text('Lead-in'),
            subtitle: Slider(
              value: settings.leadInSeconds.clamp(0, 5),
              max: 5,
              divisions: 10,
              label: '${settings.leadInSeconds.toStringAsFixed(1)}s',
              onChanged: (value) =>
                  onChanged(settings.copyWith(leadInSeconds: value)),
            ),
          ),
          ListTile(
            title: const Text('Lead-out'),
            subtitle: Slider(
              value: settings.leadOutSeconds.clamp(0, 5),
              max: 5,
              divisions: 10,
              label: '${settings.leadOutSeconds.toStringAsFixed(1)}s',
              onChanged: (value) =>
                  onChanged(settings.copyWith(leadOutSeconds: value)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Render extends ConsumerWidget {
  const _Render({
    required this.export,
    required this.edit,
    required this.match,
    this.onExported,
  });

  final ExportState export;
  final MatchEdit edit;
  final MatchRecord match;
  final VoidCallback? onExported;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(exportControllerProvider.notifier);
    final reel = export.reel;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (export.problem != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              export.problem!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (export.running) ...<Widget>[
          LinearProgressIndicator(value: export.progress),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(child: Text(_stageLabel(export))),
              TextButton(
                onPressed: controller.cancel,
                child: const Text('Cancel'),
              ),
            ],
          ),
        ] else
          FilledButton.icon(
            onPressed: edit.clips.isEmpty
                ? null
                : () => _render(controller),
            icon: const Icon(Icons.movie_filter_outlined),
            label: Text(reel == null ? 'Render reel' : 'Render again'),
          ),
        if (reel != null && !export.running) ...<Widget>[
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.primary),
            ),
            child: ListTile(
              leading: Icon(Icons.check_circle_outline, color: scheme.primary),
              title: Text('Reel ready · ${reel.fileName}'),
              subtitle: Text(
                '${reel.clipCount} clips · '
                '${formatDuration(reel.durationSeconds)}',
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pushNamed(
              AppRoutes.player,
              arguments: match.copyWith(
                title: '${match.title} — highlight reel',
                videoPath: reel.path,
              ),
            ),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Play the reel'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => _share(reel),
            icon: const Icon(Icons.ios_share),
            label: const Text('Save or share'),
          ),
        ],
      ],
    );
  }

  Future<void> _render(ExportController controller) async {
    await controller.render(match: match, edit: edit);
    onExported?.call();
  }

  static String _stageLabel(ExportState export) => switch (export.stage) {
        'prepare' => 'Reading the recording…',
        'render' => 'Rendering the reel…',
        'finalize' => 'Finishing the file…',
        _ => 'Working…',
      };

  static Future<void> _share(ExportedReel reel) async {
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(reel.path)],
        text: 'Badminton highlights',
      ),
    );
  }
}
