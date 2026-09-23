import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/import_cancel_token.dart';
import '../domain/match_import_exception.dart';
import 'match_paths.dart';
import 'video_file_picker.dart';

/// A recording the application has taken custody of.
class CustodiedRecording {
  /// Record one completed copy.
  const CustodiedRecording({
    required this.path,
    required this.name,
    required this.bytes,
  });

  /// Absolute path of the app-owned copy.
  final String path;

  /// File name the copy was stored under.
  final String name;

  /// Size of the copy in bytes.
  final int bytes;
}

/// Takes durable custody of the recording a user picked.
///
/// The platform pickers hand back a copy they made themselves, in a directory
/// the operating system is free to empty — `NSTemporaryDirectory()` on iOS and
/// the app cache on Android. The picked path is therefore an *input* to this
/// copy and never a value worth storing: a match that pointed at it would stop
/// playing the first time the system reclaimed that space.
///
/// What is copied is the platform's temporary hand-off, not the user's file.
/// The file the user selected is never written to, moved, renamed, or deleted.
class RecordingStore {
  /// Take custody of recordings under the given paths.
  const RecordingStore(this._paths);

  final MatchPaths _paths;

  /// Longest base name kept from a picked file, before the extension.
  static const int _maxBaseNameLength = 80;

  /// Copy [video] into the match's recording directory.
  ///
  /// The copy is streamed, so a multi-gigabyte recording never has to fit in
  /// memory, and it is written to a `.part` file that is renamed only once it is
  /// complete — an interrupted copy can therefore never be mistaken for a
  /// recording. Any failure or cancellation removes the match's recording
  /// directory, leaving nothing behind.
  Future<CustodiedRecording> takeCustody({
    required String matchId,
    required PickedVideo video,
    ImportCancelToken? cancelToken,
  }) async {
    final name = _nameFor(video);
    final directory = Directory(_paths.recordingDir(matchId));
    final destination = File(p.join(directory.path, name));
    final partial = File('${destination.path}.part');

    try {
      await directory.create(recursive: true);
      await _copy(source: File(video.path), partial: partial, cancelToken: cancelToken);
      await partial.rename(destination.path);
    } on MatchImportException {
      await remove(matchId);
      rethrow;
    } on FileSystemException catch (error) {
      await remove(matchId);
      throw _describe(error, video);
    }

    return CustodiedRecording(
      path: destination.path,
      name: name,
      bytes: destination.lengthSync(),
    );
  }

  /// Delete a match's app-owned recording directory, if it exists.
  ///
  /// Removes the whole directory rather than the stored file so an abandoned
  /// `.part` file cannot survive a cancelled or failed import.
  Future<void> remove(String matchId) async {
    final directory = Directory(_paths.recordingDir(matchId));
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  }

  /// Whether a recording at [path] can still be read.
  ///
  /// A cheap stat, with no engine call: it exists so the library can report a
  /// recording that has gone missing instead of failing later, when the user
  /// asks to play or analyze it.
  static bool isAvailable(String path) {
    final file = File(path);
    try {
      if (file.statSync().type != FileSystemEntityType.file) {
        return false;
      }
      return file.lengthSync() > 0;
    } on FileSystemException {
      return false;
    }
  }

  Future<void> _copy({
    required File source,
    required File partial,
    ImportCancelToken? cancelToken,
  }) async {
    final sink = partial.openWrite();
    try {
      await for (final chunk in source.openRead()) {
        if (cancelToken?.isCancelled ?? false) {
          throw MatchImportException(
            'Import cancelled.',
            kind: MatchImportKind.cancelled,
          );
        }
        sink.add(chunk);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  MatchImportException _describe(FileSystemException error, PickedVideo video) {
    final name = video.displayName ?? p.basename(video.path);
    if (isOutOfSpace(error)) {
      return MatchImportException(
        'There is not enough free space left on the device to store $name.',
        kind: MatchImportKind.noSpace,
        cause: error,
      );
    }
    return MatchImportException(
      'The recording could not be stored: ${error.message}',
      kind: MatchImportKind.storage,
      cause: error,
    );
  }

  /// Whether a write failed because the device is full.
  ///
  /// Dart exposes no portable free-space query, so the shortage is recognized
  /// from the failed write: `ENOSPC` is 28 on Linux, Android, iOS and macOS,
  /// and `ERROR_DISK_FULL` is 112 on Windows.
  static bool isOutOfSpace(FileSystemException error) {
    final code = error.osError?.errorCode;
    if (code == 28 || code == 112) {
      return true;
    }
    return error.message.toLowerCase().contains('no space');
  }

  /// A safe file name for the copy, derived from the picked file.
  ///
  /// The display name comes from the picker, so it is sanitized rather than
  /// trusted: no path separators, no `..`, and a bounded length. The extension
  /// is kept when it looks like one, because the media toolchain uses it.
  static String _nameFor(PickedVideo video) {
    final raw = video.displayName ?? p.basename(video.path);
    final base = p.basenameWithoutExtension(raw);
    final extension = p.extension(raw);

    final sanitized = base.replaceAll(RegExp(r'[^A-Za-z0-9 ._-]'), '_').trim();
    final truncated = sanitized.length > _maxBaseNameLength
        ? sanitized.substring(0, _maxBaseNameLength).trim()
        : sanitized;
    final safeBase = truncated.isEmpty || truncated == '.' || truncated == '..'
        ? 'recording'
        : truncated;

    final safeExtension =
        RegExp(r'^\.[A-Za-z0-9]{1,5}$').hasMatch(extension) ? extension : '.mp4';

    return '$safeBase$safeExtension';
  }
}
