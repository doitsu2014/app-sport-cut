import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/import_cancel_token.dart';
import '../domain/match_import_exception.dart';
import '../domain/match_record.dart';
import 'library_providers.dart';

/// What the library shows about an import.
enum ImportPhase {
  /// Nothing is being imported.
  idle,

  /// The platform picker is open.
  picking,

  /// A recording was chosen and is being probed and copied into app-owned
  /// storage.
  importing,
}

/// The state of the current import.
class ImportState {
  /// Describe the import.
  const ImportState({this.phase = ImportPhase.idle, this.problem});

  /// What the import is doing.
  final ImportPhase phase;

  /// Why the last import failed, when it did.
  final MatchImportException? problem;

  /// Whether an import is in flight.
  bool get isRunning => phase != ImportPhase.idle;

  /// What to tell the user while the import runs.
  String get description => switch (phase) {
        ImportPhase.idle => '',
        ImportPhase.picking => 'Choosing a recording…',
        ImportPhase.importing => 'Importing recording…',
      };
}

/// How an attempt to import a recording ended.
sealed class ImportOutcome {
  const ImportOutcome();
}

/// A match was created.
class ImportSucceeded extends ImportOutcome {
  /// Report the new match.
  const ImportSucceeded(this.match);

  /// The match that was added to the library.
  final MatchRecord match;
}

/// No match was created, and there is nothing to report: the user cancelled, or
/// an import was already running.
class ImportDeclined extends ImportOutcome {
  /// Report that nothing happened.
  const ImportDeclined();
}

/// The import failed, and the reason should be shown to the user.
class ImportFailed extends ImportOutcome {
  /// Report the failure.
  const ImportFailed(this.problem);

  /// Why the import failed.
  final MatchImportException problem;
}

/// Runs one import at a time and reports what it is doing.
///
/// The guard lives here rather than in the repository because it has to cover
/// the picker dialog as well as the copy: without it, two taps open two pickers
/// and the second import silently duplicates the first.
class ImportController extends Notifier<ImportState> {
  ImportCancelToken? _token;

  @override
  ImportState build() => const ImportState();

  /// Ask the user for a recording, then import it.
  ///
  /// Returns [ImportDeclined] when nothing should be shown — the user
  /// cancelled, or an import was already running when this was called.
  Future<ImportOutcome> start() async {
    if (state.isRunning) {
      return const ImportDeclined();
    }

    final token = ImportCancelToken();
    _token = token;
    state = const ImportState(phase: ImportPhase.picking);

    try {
      final picked = await ref.read(videoFilePickerProvider).pickVideo();
      if (picked == null || token.isCancelled) {
        return const ImportDeclined();
      }

      state = const ImportState(phase: ImportPhase.importing);
      final repository = await ref.read(matchRepositoryProvider.future);
      final match = await repository.importVideo(picked, cancelToken: token);
      ref.invalidate(matchListProvider);
      return ImportSucceeded(match);
    } on MatchImportException catch (error) {
      // A cancellation is the user's own doing, so it needs no explanation.
      if (error.kind != MatchImportKind.cancelled) {
        state = ImportState(problem: error);
        return ImportFailed(error);
      }
      return const ImportDeclined();
    } on Object catch (error) {
      // Anything the layers below did not classify still has to reach the user
      // as a message rather than as an unhandled async error.
      final problem = MatchImportException(
        'The recording could not be imported: $error',
        kind: MatchImportKind.storage,
        cause: error,
      );
      state = ImportState(problem: problem);
      return ImportFailed(problem);
    } finally {
      if (identical(_token, token)) {
        _token = null;
        state = ImportState(problem: state.problem);
      }
    }
  }

  /// Ask the running import to stop.
  ///
  /// The copy checks this between chunks, then removes what it had written, so
  /// cancelling leaves neither a catalog record nor a partial file.
  void cancel() => _token?.cancel();
}

/// The import in flight, if any.
final importControllerProvider =
    NotifierProvider<ImportController, ImportState>(ImportController.new);
