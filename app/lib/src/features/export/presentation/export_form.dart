import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../app/design/components/sc_actions.dart';
import '../../../app/design/components/sc_banner.dart';
import '../../../app/design/components/sc_fields.dart';
import '../../../app/design/sc_icons.dart';
import '../../../app/design/sc_typography.dart';
import '../../../app/design/sportcut_tokens.dart';
import '../../editing/domain/export_settings.dart';
import '../../editing/domain/match_edit.dart';
import '../../editing/presentation/editing_providers.dart';
import '../../library/domain/match_record.dart';
import 'export_providers.dart';

/// The export settings, mapped one-to-one onto [ExportSettings].
///
/// Title card, music, music volume, and lead-in/out are stored per match and
/// survive a reopen. "Include score overlays" is sheet-local and ephemeral:
/// the engine has no persisted option for it, so it is not written anywhere
/// (ADR-0003 D11). "Remove rest periods" is shown checked and disabled with a
/// helper, because the reel is already built from kept clips only; no setting
/// is invented for it.
///
/// The form blocks with a plain sentence when the reel has no clips or the
/// recording is missing, and reports that blocker to the host through nothing
/// but its disabled render control. The title card is optional by design
/// (FR-EXP-01), so there is no title blocker.
class ExportForm extends ConsumerStatefulWidget {
  /// Build the form for [edit].
  const ExportForm({
    super.key,
    required this.match,
    required this.edit,
    required this.recordingAvailable,
    required this.includeScoreOverlays,
    required this.onIncludeScoreOverlaysChanged,
    required this.onRender,
    this.renderLabel = 'Export reel',
  });

  /// Match being exported.
  final MatchRecord match;

  /// The current review.
  final MatchEdit edit;

  /// Whether the match's recording can still be read.
  final bool recordingAvailable;

  /// The ephemeral score-overlay choice.
  final bool includeScoreOverlays;

  /// Change the ephemeral score-overlay choice.
  final ValueChanged<bool> onIncludeScoreOverlaysChanged;

  /// Start the render with the current settings.
  final VoidCallback onRender;

  /// The render control's label.
  final String renderLabel;

  @override
  ConsumerState<ExportForm> createState() => _ExportFormState();
}

class _ExportFormState extends ConsumerState<ExportForm> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _music = TextEditingController();
  String? _titleLoadedFor;
  String? _musicLoadedFor;
  String? _musicProblem;

  @override
  void dispose() {
    _title.dispose();
    _music.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SportcutPalette palette = SportcutPalette.of(context);
    final SportcutTokens tokens = SportcutTokens.of(context);
    final SportcutTypography typography = SportcutTypography.of(context);
    final ExportSettings settings = widget.edit.exportSettings;

    _syncControllers(settings);

    final String? blocker = _blocker;
    final String? musicPath = settings.musicPath;
    final bool hasMusic = musicPath != null && musicPath.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ScTextField(
          label: 'Title card',
          hint: 'Leave empty for no title card',
          helper: 'Leave empty for no title card.',
          controller: _title,
          onChanged: (String value) {
            final String trimmed = value.trim();
            _save(
              settings.copyWith(
                title: trimmed.isEmpty ? null : value,
                clearTitle: trimmed.isEmpty,
              ),
            );
          },
        ),
        SizedBox(height: tokens.space4),
        ScTextField(
          label: 'Music',
          hint: 'No music',
          helper: hasMusic
              ? 'Mixed under the match audio at the volume below.'
              : 'Music is mixed under the match audio.',
          controller: _music,
          enabled: false,
        ),
        SizedBox(height: tokens.space2),
        Row(
          children: <Widget>[
            ScButton.compact(
              label: 'Choose music',
              variant: ScButtonVariant.secondary,
              onPressed: _pickMusic,
            ),
            if (hasMusic) ...<Widget>[
              SizedBox(width: tokens.space2),
              ScButton.compact(
                label: 'Remove',
                variant: ScButtonVariant.ghost,
                onPressed: () {
                  if (_musicProblem != null) {
                    setState(() => _musicProblem = null);
                  }
                  _save(settings.copyWith(clearMusic: true));
                },
              ),
            ],
          ],
        ),
        if (_musicProblem != null) ...<Widget>[
          SizedBox(height: tokens.space2),
          ScBanner(message: _musicProblem!, tone: ScBannerTone.danger),
        ],
        SizedBox(height: tokens.space4),
        _SliderField(
          label: 'Music volume',
          value: settings.musicGain.clamp(0.0, 1.0),
          max: 1,
          divisions: 20,
          valueLabel: '${(settings.musicGain * 100).round()}%',
          onChanged: (double value) =>
              _save(settings.copyWith(musicGain: value)),
        ),
        SizedBox(height: tokens.space2),
        _SliderField(
          label: 'Lead-in',
          value: settings.leadInSeconds.clamp(0.0, 5.0),
          max: 5,
          divisions: 10,
          valueLabel: '${settings.leadInSeconds.toStringAsFixed(1)}s',
          onChanged: (double value) =>
              _save(settings.copyWith(leadInSeconds: value)),
        ),
        SizedBox(height: tokens.space2),
        _SliderField(
          label: 'Lead-out',
          value: settings.leadOutSeconds.clamp(0.0, 5.0),
          max: 5,
          divisions: 10,
          valueLabel: '${settings.leadOutSeconds.toStringAsFixed(1)}s',
          onChanged: (double value) =>
              _save(settings.copyWith(leadOutSeconds: value)),
        ),
        SizedBox(height: tokens.space4),
        ScCheckboxRow(
          label: 'Include score overlays',
          value: widget.includeScoreOverlays,
          onChanged: widget.onIncludeScoreOverlaysChanged,
        ),
        SizedBox(height: tokens.space1),
        ScCheckboxRow(
          label: 'Remove rest periods',
          value: true,
          enabled: false,
          helper: 'The reel is built from kept clips, so rest periods are '
              'already removed.',
          onChanged: (_) {},
        ),
        SizedBox(height: tokens.space4),
        if (blocker != null) ...<Widget>[
          ScBanner(message: blocker, tone: ScBannerTone.warning),
          SizedBox(height: tokens.space3),
        ],
        ScButton(
          label: widget.renderLabel,
          icon: ScIcons.download,
          expanded: true,
          enabled: blocker == null,
          onPressed: blocker == null ? widget.onRender : null,
        ),
        SizedBox(height: tokens.space1),
        Text(
          'The file is written to this match’s export folder.',
          textAlign: TextAlign.center,
          style: typography.chrome9.copyWith(color: palette.muted),
        ),
      ],
    );
  }

  /// Load the stored values once per match (or music file).
  void _syncControllers(ExportSettings settings) {
    if (_titleLoadedFor != settings.matchId) {
      _titleLoadedFor = settings.matchId;
      _title.text = settings.title ?? '';
    }
    final String? musicPath = settings.musicPath;
    if (_musicLoadedFor != musicPath) {
      _musicLoadedFor = musicPath;
      _music.text =
          musicPath == null || musicPath.isEmpty ? '' : p.basename(musicPath);
    }
  }

  /// The one blocker that stops a render, or null when it may run.
  String? get _blocker {
    if (!widget.recordingAvailable) {
      return 'Import the recording again before exporting.';
    }
    if (widget.edit.clips.isEmpty) {
      return 'Keep at least one clip before exporting.';
    }
    return null;
  }

  void _save(ExportSettings settings) {
    unawaited(
      ref.read(editingControllerProvider.notifier).saveSettings(settings),
    );
  }

  Future<void> _pickMusic() async {
    try {
      final picked = await ref.read(audioFilePickerProvider).pickAudio();
      if (picked == null) {
        return;
      }
      await ref
          .read(editingControllerProvider.notifier)
          .saveSettings(widget.edit.exportSettings.copyWith(
            musicPath: picked.path,
          ));
      if (mounted) {
        setState(() => _musicProblem = null);
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _musicProblem = '$error');
    }
  }
}

/// A labelled slider with its current value on the trailing edge.
class _SliderField extends StatelessWidget {
  const _SliderField({
    required this.label,
    required this.value,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final SportcutPalette palette = SportcutPalette.of(context);
    final SportcutTokens tokens = SportcutTokens.of(context);
    final SportcutTypography typography = SportcutTypography.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: typography.xs12.copyWith(
                  color: palette.fg2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              valueLabel,
              style: typography.timecode11.copyWith(color: palette.muted),
            ),
          ],
        ),
        Slider(
          value: value,
          max: max,
          divisions: divisions,
          label: valueLabel,
          onChanged: onChanged,
        ),
        SizedBox(height: tokens.space1),
      ],
    );
  }
}
