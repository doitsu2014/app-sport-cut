import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pipeline_stage.dart';

/// A sentinel that distinguishes "leave this field alone" from "set it to null"
/// in [StudioState.copyWith].
const Object _unset = Object();

/// Everything the studio keeps in memory for one workspace.
///
/// The state is deliberately ephemeral: it is created with the studio, disposed
/// with it, and never written to disk or the engine (ADR-0003 D10). Search,
/// rail visibility, focus mode, the inspector tab, the selected rally, the
/// timeline window, the export sheet, and the toast message all live here.
@immutable
class StudioState {
  /// Describe the studio's current view.
  const StudioState({
    this.selectedStage,
    this.libraryVisible = true,
    this.inspectorVisible = true,
    this.focusMode = false,
    this.searchQuery = '',
    this.inspectorTab = 0,
    this.selectedRallyId,
    this.timelineWindowStart = Duration.zero,
    this.exportSheetOpen = false,
    this.toastMessage,
  });

  /// The selected pipeline stage, where null means Play.
  final PipelineStage? selectedStage;

  /// Whether the video rail is showing.
  final bool libraryVisible;

  /// Whether the inspector is showing.
  final bool inspectorVisible;

  /// Whether focus mode is engaged.
  final bool focusMode;

  /// The in-memory library search query.
  final String searchQuery;

  /// The selected inspector tab index.
  final int inspectorTab;

  /// The selected rally on the timeline, or null when none is selected.
  final String? selectedRallyId;

  /// The left edge of the timeline's visible window.
  final Duration timelineWindowStart;

  /// Whether the export sheet is open.
  final bool exportSheetOpen;

  /// The toast the shell should show, or null when there is none.
  final String? toastMessage;

  /// This state with the given fields replaced.
  ///
  /// Nullable fields use a sentinel so they can be cleared; every other field
  /// keeps its current value when omitted.
  StudioState copyWith({
    Object? selectedStage = _unset,
    bool? libraryVisible,
    bool? inspectorVisible,
    bool? focusMode,
    String? searchQuery,
    int? inspectorTab,
    Object? selectedRallyId = _unset,
    Duration? timelineWindowStart,
    bool? exportSheetOpen,
    Object? toastMessage = _unset,
  }) =>
      StudioState(
        selectedStage: identical(selectedStage, _unset)
            ? this.selectedStage
            : selectedStage as PipelineStage?,
        libraryVisible: libraryVisible ?? this.libraryVisible,
        inspectorVisible: inspectorVisible ?? this.inspectorVisible,
        focusMode: focusMode ?? this.focusMode,
        searchQuery: searchQuery ?? this.searchQuery,
        inspectorTab: inspectorTab ?? this.inspectorTab,
        selectedRallyId: identical(selectedRallyId, _unset)
            ? this.selectedRallyId
            : selectedRallyId as String?,
        timelineWindowStart: timelineWindowStart ?? this.timelineWindowStart,
        exportSheetOpen: exportSheetOpen ?? this.exportSheetOpen,
        toastMessage: identical(toastMessage, _unset)
            ? this.toastMessage
            : toastMessage as String?,
      );
}

/// The studio's in-memory state, one instance per workspace.
///
/// The controller performs no I/O: it does not reach the engine, read a file, or
/// persist anything (ADR-0003 D10). The screen watches it and the shell renders
/// from it; feature widgets keep receiving plain data and callbacks.
class StudioController extends Notifier<StudioState> {
  /// The rail flags focus mode found when it engaged, restored on exit.
  bool _libraryVisibleBeforeFocus = true;
  bool _inspectorVisibleBeforeFocus = true;

  @override
  StudioState build() => const StudioState();

  /// Select a pipeline stage, where null selects Play.
  void selectStage(PipelineStage? stage) {
    state = state.copyWith(selectedStage: stage);
  }

  /// Show or hide the video rail.
  ///
  /// Toggling a rail while focus mode is engaged leaves focus mode and shows
  /// the requested rail, matching the toolbar button's "off" appearance.
  void toggleLibrary() {
    if (state.focusMode) {
      state = _afterFocusExit().copyWith(libraryVisible: true);
      return;
    }
    state = state.copyWith(libraryVisible: !state.libraryVisible);
  }

  /// Show or hide the inspector.
  void toggleInspector() {
    if (state.focusMode) {
      state = _afterFocusExit().copyWith(inspectorVisible: true);
      return;
    }
    state = state.copyWith(inspectorVisible: !state.inspectorVisible);
  }

  /// Enter focus mode, or leave it and restore the rails it hid.
  void toggleFocusMode() {
    if (state.focusMode) {
      restoreRailsAfterFocus();
      return;
    }
    _libraryVisibleBeforeFocus = state.libraryVisible;
    _inspectorVisibleBeforeFocus = state.inspectorVisible;
    state = state.copyWith(
      focusMode: true,
      libraryVisible: false,
      inspectorVisible: false,
    );
  }

  /// Leave focus mode and put both rails back the way they were.
  void restoreRailsAfterFocus() {
    if (!state.focusMode) {
      return;
    }
    state = _afterFocusExit();
  }

  /// Replace the in-memory search query.
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Clear the search query.
  void clearSearch() {
    state = state.copyWith(searchQuery: '');
  }

  /// Select an inspector tab index.
  void setInspectorTab(int index) {
    state = state.copyWith(inspectorTab: index);
  }

  /// Select a rally on the timeline, or clear the selection with null.
  void selectRally(String? rallyId) {
    state = state.copyWith(selectedRallyId: rallyId);
  }

  /// Move the timeline's visible window.
  void setTimelineWindow(Duration start) {
    state = state.copyWith(timelineWindowStart: start);
  }

  /// Open or close the export sheet.
  void setExportSheet(bool open) {
    state = state.copyWith(exportSheetOpen: open);
  }

  /// Show a toast message, or clear the current one with null.
  void showToast(String? message) {
    state = state.copyWith(toastMessage: message);
  }

  StudioState _afterFocusExit() => state.copyWith(
        focusMode: false,
        libraryVisible: _libraryVisibleBeforeFocus,
        inspectorVisible: _inspectorVisibleBeforeFocus,
      );
}

/// The studio's ephemeral state for one workspace.
///
/// `autoDispose` gives the state the studio's lifetime: leaving the studio
/// releases it, and no client-owned durable state is introduced (D10).
final studioControllerProvider =
    NotifierProvider.autoDispose.family<StudioController, StudioState, String>(
  (_) => StudioController(),
);
