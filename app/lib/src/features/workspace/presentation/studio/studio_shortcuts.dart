import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../library/presentation/playback_controller.dart';

/// The studio's keyboard layer.
///
/// One [Focus] owns the whole map so there is a single place to read. Every
/// binding is ignored while an [EditableText] has focus, so typing `L`, `R`,
/// `E`, or `Space` in a field enters the character and starts no action
/// (FR-SHL-24). The widget renders nothing itself and reads no provider: the
/// shell passes the current values and receives callbacks.
class StudioShortcuts extends StatelessWidget {
  /// Wrap [child] in the studio's shortcut scope.
  const StudioShortcuts({
    super.key,
    required this.child,
    this.controller,
    this.searchQuery = '',
    this.selectedRallyId,
    this.exportSheetOpen = false,
    this.focusMode = false,
    this.onScoreRally,
    this.onToggleFocusMode,
    this.onSelectExport,
    this.onFocusSearch,
    this.onCloseExportSheet,
    this.onExitFocusMode,
    this.onClearSearch,
    this.onToast,
  });

  /// The studio content the shortcuts act on.
  final Widget child;

  /// The shared player, or null while no video is loaded.
  final PlaybackController? controller;

  /// The current in-memory search query.
  final String searchQuery;

  /// The rally selected on the timeline, or null when none is selected.
  final String? selectedRallyId;

  /// Whether the export sheet is open.
  final bool exportSheetOpen;

  /// Whether focus mode is engaged.
  final bool focusMode;

  /// Score the selected rally; `true` is the left side, `false` the right.
  ///
  /// The score panel arrives in PR 6a, so this is optional for now.
  final void Function(bool left)? onScoreRally;

  /// Toggle focus mode.
  final VoidCallback? onToggleFocusMode;

  /// Select the Export stage.
  final VoidCallback? onSelectExport;

  /// Focus and select the search field.
  final VoidCallback? onFocusSearch;

  /// Close the export sheet.
  final VoidCallback? onCloseExportSheet;

  /// Leave focus mode and restore the rails it hid.
  final VoidCallback? onExitFocusMode;

  /// Clear the search query.
  final VoidCallback? onClearSearch;

  /// Explain why an action could not run.
  final void Function(String message)? onToast;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: child,
    );
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    // Never take a keystroke away from a field: the character belongs to it.
    if (_isEditingText()) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;

    if (key == LogicalKeyboardKey.keyK && keyboard.isMetaPressed) {
      onFocusSearch?.call();
      return KeyEventResult.handled;
    }
    // Other bindings are unmodified so they do not shadow system shortcuts.
    if (keyboard.isMetaPressed ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.space) {
      return _togglePlayback();
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      return _seek(const Duration(seconds: -5));
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      return _seek(const Duration(seconds: 5));
    }
    if (key == LogicalKeyboardKey.keyL) {
      return _score(left: true);
    }
    if (key == LogicalKeyboardKey.keyR) {
      return _score(left: false);
    }
    if (key == LogicalKeyboardKey.keyF) {
      onToggleFocusMode?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyE) {
      onSelectExport?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      return _escape();
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _togglePlayback() {
    final player = controller;
    if (player == null) {
      return KeyEventResult.ignored;
    }
    final state = player.state.value;
    if (!state.isReady || state.error != null) {
      return KeyEventResult.ignored;
    }
    if (state.isPlaying) {
      player.pause();
    } else {
      player.play();
    }
    return KeyEventResult.handled;
  }

  KeyEventResult _seek(Duration delta) {
    final player = controller;
    if (player == null) {
      return KeyEventResult.ignored;
    }
    final state = player.state.value;
    if (!state.isReady || state.error != null) {
      return KeyEventResult.ignored;
    }
    if (state.duration <= Duration.zero) {
      return KeyEventResult.ignored;
    }
    final target = state.position + delta;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > state.duration ? state.duration : target);
    player.seek(clamped);
    return KeyEventResult.handled;
  }

  KeyEventResult _score({required bool left}) {
    if (selectedRallyId == null) {
      onToast?.call('Select a rally on the timeline.');
      return KeyEventResult.handled;
    }
    onScoreRally?.call(left);
    return KeyEventResult.handled;
  }

  /// Esc has one order: export sheet, then focus mode, then search.
  KeyEventResult _escape() {
    if (exportSheetOpen) {
      onCloseExportSheet?.call();
      return KeyEventResult.handled;
    }
    if (focusMode) {
      onExitFocusMode?.call();
      return KeyEventResult.handled;
    }
    if (searchQuery.isNotEmpty) {
      onClearSearch?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Whether the primary focus is a text field, anywhere in its ancestry.
  bool _isEditingText() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) {
      return false;
    }
    if (context.widget is EditableText) {
      return true;
    }
    return context.findAncestorWidgetOfExactType<EditableText>() != null;
  }
}
