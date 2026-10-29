import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/design/components/sc_actions.dart';
import '../../../../app/design/components/sc_dialog.dart';
import '../../../../app/design/components/sc_fields.dart';
import '../../../../app/design/sportcut_tokens.dart';
import '../../domain/workspace.dart';
import '../studio/studio_dialogs.dart' show DeleteChoice;

/// The delete option for the workspace's derived analysis files.
const String _artifactsKey = 'delete-analysis-files';

/// The delete option for the workspace's stored recording copies.
const String _recordingKey = 'delete-stored-recordings';

/// Ask for a new workspace's name.
///
/// Returns the typed name when the user chooses Create, including an empty one
/// (the repository then names it "Untitled workspace"), or null when they
/// cancel. The dialog uses the studio surface and field rather than Material's
/// alert defaults.
Future<String?> showNewWorkspaceDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) => Dialog(
      backgroundColor: SportcutPalette.of(context).surface.withValues(alpha: 0),
      elevation: 0,
      insetPadding: EdgeInsets.all(SportcutTokens.of(context).space6),
      child: const _NewWorkspaceDialog(),
    ),
  );
}

/// Ask what a workspace delete should take with it.
///
/// The two options keep the meaning they had in the studio's delete dialog:
/// neither is checked by default, analysis files are deleted only when chosen,
/// and the stored recording copy is deleted only when chosen. The original
/// recordings the user picked are never touched.
Future<DeleteChoice?> showDeleteWorkspaceDialog(
  BuildContext context, {
  required Workspace workspace,
}) async {
  final List<Key>? keys = await showDialog<List<Key>>(
    context: context,
    builder: (BuildContext dialogContext) => Dialog(
      backgroundColor: SportcutPalette.of(context).surface.withValues(alpha: 0),
      elevation: 0,
      insetPadding: EdgeInsets.all(SportcutTokens.of(context).space6),
      child: ScOptionDialog(
        title: 'Delete workspace',
        message: '${workspace.title} and all its videos will be removed. '
            'The original recordings are never deleted.',
        confirmLabel: 'Delete workspace',
        cancelLabel: 'Cancel',
        options: const <ScDialogOption>[
          ScDialogOption(
            key: ValueKey<String>(_artifactsKey),
            label: 'Also delete analysis files',
            initial: false,
          ),
          ScDialogOption(
            key: ValueKey<String>(_recordingKey),
            label: 'Also delete the stored recording copy',
            initial: false,
          ),
        ],
      ),
    ),
  );
  if (keys == null) {
    return null;
  }
  return DeleteChoice(
    deleteArtifacts: keys.contains(const ValueKey<String>(_artifactsKey)),
    deleteRecording: keys.contains(const ValueKey<String>(_recordingKey)),
  );
}

/// The create-workspace card, with the name field focused on open.
class _NewWorkspaceDialog extends StatefulWidget {
  const _NewWorkspaceDialog();

  @override
  State<_NewWorkspaceDialog> createState() => _NewWorkspaceDialogState();
}

class _NewWorkspaceDialogState extends State<_NewWorkspaceDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _create() {
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter): _create,
      },
      child: ScDialog(
        title: 'New workspace',
        description: 'Group recordings under one name. '
            'Videos can be added at any time.',
        actions: <Widget>[
          ScButton.compact(
            label: 'Cancel',
            variant: ScButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
          ),
          ScButton.compact(
            label: 'Create',
            onPressed: _create,
          ),
        ],
        child: ScTextField(
          controller: _controller,
          focusNode: _focusNode,
          label: 'Name',
          hint: 'e.g. Thursday club night',
        ),
      ),
    );
  }
}
