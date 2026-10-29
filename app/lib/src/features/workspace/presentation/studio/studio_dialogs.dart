import 'package:flutter/material.dart';

import '../../../library/domain/match_record.dart';
import '../../domain/workspace.dart';

/// What the user chose in a delete dialog.
class DeleteChoice {
  /// Record the two delete options.
  const DeleteChoice({
    required this.deleteArtifacts,
    required this.deleteRecording,
  });

  /// Whether analysis files should be deleted too.
  final bool deleteArtifacts;

  /// Whether the stored recording copy should be deleted too.
  final bool deleteRecording;
}

/// Asks whether a single video is deleted and what else goes with it.
class DeleteMatchDialog extends StatefulWidget {
  /// Build the dialog for [match].
  const DeleteMatchDialog({super.key, required this.match});

  /// The video being deleted.
  final MatchRecord match;

  @override
  State<DeleteMatchDialog> createState() => _DeleteMatchDialogState();
}

class _DeleteMatchDialogState extends State<DeleteMatchDialog> {
  bool _deleteArtifacts = false;
  bool _deleteRecording = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Delete video?'),
      content: DeleteBody(
        summary: '${widget.match.title} will be removed from the workspace.',
        deleteArtifacts: _deleteArtifacts,
        deleteRecording: _deleteRecording,
        onArtifactsChanged: (value) => setState(() => _deleteArtifacts = value),
        onRecordingChanged: (value) => setState(() => _deleteRecording = value),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(
            DeleteChoice(
              deleteArtifacts: _deleteArtifacts,
              deleteRecording: _deleteRecording,
            ),
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

/// Asks whether a whole workspace is deleted and what else goes with it.
class DeleteWorkspaceDialog extends StatefulWidget {
  /// Build the dialog for [workspace].
  const DeleteWorkspaceDialog({super.key, required this.workspace});

  /// The workspace being deleted.
  final Workspace workspace;

  @override
  State<DeleteWorkspaceDialog> createState() => _DeleteWorkspaceDialogState();
}

class _DeleteWorkspaceDialogState extends State<DeleteWorkspaceDialog> {
  bool _deleteArtifacts = false;
  bool _deleteRecording = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Delete workspace?'),
      content: DeleteBody(
        summary: '${widget.workspace.title} and all its videos will be '
            'removed. The original recordings are never deleted.',
        deleteArtifacts: _deleteArtifacts,
        deleteRecording: _deleteRecording,
        onArtifactsChanged: (value) => setState(() => _deleteArtifacts = value),
        onRecordingChanged: (value) => setState(() => _deleteRecording = value),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(
            DeleteChoice(
              deleteArtifacts: _deleteArtifacts,
              deleteRecording: _deleteRecording,
            ),
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

/// The shared body of the delete dialogs: a summary and the two options.
class DeleteBody extends StatelessWidget {
  /// Build the delete body.
  const DeleteBody({
    super.key,
    required this.summary,
    required this.deleteArtifacts,
    required this.deleteRecording,
    required this.onArtifactsChanged,
    required this.onRecordingChanged,
  });

  /// What will be removed, in one sentence.
  final String summary;

  /// Whether analysis files are selected for deletion.
  final bool deleteArtifacts;

  /// Whether the stored recording copy is selected for deletion.
  final bool deleteRecording;

  /// Change the analysis-files option.
  final ValueChanged<bool> onArtifactsChanged;

  /// Change the stored-recording option.
  final ValueChanged<bool> onRecordingChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(summary),
        const SizedBox(height: 12),
        CheckboxListTile(
          value: deleteArtifacts,
          onChanged: (value) => onArtifactsChanged(value ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Also delete analysis files'),
          subtitle: const Text('Proxy, audio, and sampled frames'),
        ),
        CheckboxListTile(
          value: deleteRecording,
          onChanged: (value) => onRecordingChanged(value ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Also delete the stored recording copy'),
          subtitle: const Text('The copy Sportcut made for this video'),
        ),
      ],
    );
  }
}
