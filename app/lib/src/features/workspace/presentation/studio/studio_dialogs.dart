import 'package:flutter/material.dart';

import '../../../../app/design/components/sc_actions.dart';
import '../../../../app/design/components/sc_dialog.dart';
import '../../../../app/design/components/sc_fields.dart';
import '../../../../app/design/sportcut_tokens.dart';
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
class DeleteMatchDialog extends StatelessWidget {
  /// Build the dialog for [match].
  const DeleteMatchDialog({super.key, required this.match});

  /// The video being deleted.
  final MatchRecord match;

  @override
  Widget build(BuildContext context) {
    return _DeleteDialog(
      title: 'Delete video',
      summary: '${match.title} will be removed from the workspace.',
      confirmLabel: 'Delete video',
    );
  }
}

/// Asks whether a whole workspace is deleted and what else goes with it.
class DeleteWorkspaceDialog extends StatelessWidget {
  /// Build the dialog for [workspace].
  const DeleteWorkspaceDialog({super.key, required this.workspace});

  /// The workspace being deleted.
  final Workspace workspace;

  @override
  Widget build(BuildContext context) {
    return _DeleteDialog(
      title: 'Delete workspace',
      summary: '${workspace.title} and all its videos will be removed. '
          'The original recordings are never deleted.',
      confirmLabel: 'Delete workspace',
    );
  }
}

/// The shared studio delete surface: a summary and the two options.
///
/// Both options start unchecked. Analysis files are deleted only when chosen,
/// and the stored recording copy is deleted only when chosen; the recordings
/// the user picked are never touched.
class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog({
    required this.title,
    required this.summary,
    required this.confirmLabel,
  });

  final String title;
  final String summary;
  final String confirmLabel;

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  bool _deleteArtifacts = false;
  bool _deleteRecording = false;

  void _confirm() {
    Navigator.of(context).pop(
      DeleteChoice(
        deleteArtifacts: _deleteArtifacts,
        deleteRecording: _deleteRecording,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = SportcutTokens.of(context);
    return Dialog(
      backgroundColor: SportcutPalette.of(context).surface.withValues(alpha: 0),
      elevation: 0,
      insetPadding: EdgeInsets.all(tokens.space6),
      child: FocusTraversalGroup(
        child: ScDialog(
          title: widget.title,
          description: widget.summary,
          actions: <Widget>[
            ScButton.compact(
              label: 'Cancel',
              variant: ScButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            ScButton.compact(
              label: widget.confirmLabel,
              variant: ScButtonVariant.destructive,
              onPressed: _confirm,
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ScCheckboxRow(
                label: 'Also delete analysis files',
                helper: 'Proxy, audio, and sampled frames',
                value: _deleteArtifacts,
                onChanged: (bool value) =>
                    setState(() => _deleteArtifacts = value),
              ),
              SizedBox(height: tokens.space2),
              ScCheckboxRow(
                label: 'Also delete the stored recording copy',
                helper: 'The copy Sportcut made for this video',
                value: _deleteRecording,
                onChanged: (bool value) =>
                    setState(() => _deleteRecording = value),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
