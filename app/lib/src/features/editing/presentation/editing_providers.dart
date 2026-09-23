import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/domain/match_record.dart';
import '../../library/presentation/library_providers.dart';
import '../data/editing_repository.dart';
import '../data/editing_store.dart';
import '../domain/export_settings.dart';
import '../domain/match_edit.dart';
import '../domain/match_editing.dart';
import '../domain/rally.dart';

/// Read and write a match's review.
///
/// Built on the same catalog the library uses, through the raw database handle
/// the catalog exposes for feature tables it does not own.
final matchEditingProvider = FutureProvider<MatchEditing>((ref) async {
  final catalog = await ref.watch(matchCatalogProvider.future);
  return EditingRepository(store: EditingStore(catalog.database));
});

/// What a review session currently shows.
class EditingState {
  /// Describe a session.
  const EditingState({
    this.match,
    this.edit,
    this.busy = false,
    this.problem,
  });

  /// Match being reviewed, once a session has been opened.
  final MatchRecord? match;

  /// Everything the session shows, or `null` while it loads.
  final MatchEdit? edit;

  /// Whether a change is being written.
  final bool busy;

  /// Why the last action failed, when it did.
  final String? problem;

  /// This state with the given fields replaced.
  EditingState copyWith({
    MatchRecord? match,
    MatchEdit? edit,
    bool? busy,
    String? problem,
    bool clearProblem = false,
  }) =>
      EditingState(
        match: match ?? this.match,
        edit: edit ?? this.edit,
        busy: busy ?? this.busy,
        problem: clearProblem ? null : (problem ?? this.problem),
      );
}

/// The review session a screen drives.
///
/// One session at a time, like the import controller: a review screen owns the
/// open match, and every action reloads the records it derives from so the
/// screens never show a score that disagrees with the rallies behind it.
class EditingController extends Notifier<EditingState> {
  @override
  EditingState build() => const EditingState();

  /// Open a match for review, reloading anything already recorded for it.
  Future<void> open(MatchRecord match) async {
    state = EditingState(
      match: match,
      edit: state.match?.id == match.id ? state.edit : null,
    );
    await _reload();
  }

  /// Mark a span of the recording as a rally.
  Future<void> markRally({
    required double startSeconds,
    required double endSeconds,
  }) =>
      _apply(
        (editing, match) => editing.addRally(
          match,
          startSeconds: startSeconds,
          endSeconds: endSeconds,
        ),
      );

  /// Confirm the winner of a rally, or clear it when [side] is null.
  Future<void> setWinner(String rallyId, WinnerSide? side) => _apply(
        (editing, match) =>
            editing.setWinner(match, rallyId: rallyId, side: side),
      );

  /// Remove a rally from the match.
  Future<void> removeRally(String rallyId) => _apply(
        (editing, match) => editing.removeRally(match, rallyId: rallyId),
      );

  /// Put a rally in the reel, or take it out.
  Future<void> setKept(Rally rally, bool kept) => _apply(
        (editing, match) => editing.keepClip(match, rally: rally, kept: kept),
      );

  /// Trim a clip within its rally.
  Future<void> trimClip(
    String clipId, {
    double? startSeconds,
    double? endSeconds,
  }) =>
      _apply(
        (editing, match) => editing.trimClip(
          match,
          clipId: clipId,
          startSeconds: startSeconds,
          endSeconds: endSeconds,
        ),
      );

  /// Write the reel's order.
  Future<void> reorderClips(List<String> clipIds) => _apply(
        (editing, match) => editing.reorderClips(match, clipIds),
      );

  /// Store the choices that shape the export.
  Future<void> saveSettings(ExportSettings settings) => _apply(
        (editing, _) => editing.saveExportSettings(settings),
      );

  /// Clear the reported problem once the screen has shown it.
  void clearProblem() {
    if (state.problem != null) {
      state = state.copyWith(clearProblem: true);
    }
  }

  Future<void> _apply(
    Future<void> Function(MatchEditing editing, MatchRecord match) action,
  ) async {
    final match = state.match;
    if (match == null || state.busy) {
      return;
    }
    state = state.copyWith(busy: true, clearProblem: true);
    try {
      final editing = await ref.read(matchEditingProvider.future);
      await action(editing, match);
      await _reload();
    } on MatchEditingException catch (error) {
      state = state.copyWith(busy: false, problem: error.message);
    } on Object catch (error) {
      state = state.copyWith(
        busy: false,
        problem: 'That change could not be saved: $error',
      );
    }
  }

  Future<void> _reload() async {
    final match = state.match;
    if (match == null) {
      return;
    }
    try {
      final editing = await ref.read(matchEditingProvider.future);
      final edit = await editing.load(match);
      state = state.copyWith(edit: edit, busy: false, clearProblem: true);
    } on Object catch (error) {
      state = state.copyWith(
        busy: false,
        problem: 'This match could not be opened for review: $error',
      );
    }
  }
}

/// The review session in flight.
final editingControllerProvider =
    NotifierProvider<EditingController, EditingState>(EditingController.new);
