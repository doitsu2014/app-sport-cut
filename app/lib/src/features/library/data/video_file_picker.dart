import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show PlatformException;

import '../domain/match_import_exception.dart';

/// A recording the user chose from device storage.
class PickedVideo {
  /// Create a picked video.
  const PickedVideo({required this.path, this.displayName});

  /// Absolute path of the file on the device.
  final String path;

  /// Name shown to the user, usually the file name.
  final String? displayName;
}

/// Source of a recording to import.
///
/// Abstracted so the library screen can be tested, and so a future platform
/// picker (for example a photo-library picker on iOS) can be swapped in without
/// touching the screen.
abstract interface class VideoFilePicker {
  /// Ask the user for a video, or return `null` when they cancel.
  Future<PickedVideo?> pickVideo();
}

/// Picker backed by the platform file chooser.
class SystemVideoFilePicker implements VideoFilePicker {
  @override
  Future<PickedVideo?> pickVideo() async {
    final List<PlatformFile> files;
    try {
      files = await FilePicker.pickFiles(type: FileType.video);
    } on PlatformException catch (error) {
      // A picker that fails — permission denied, another picker already open —
      // must reach the user as a message, not as an unhandled async error.
      throw MatchImportException(
        'The video picker could not open: ${error.message ?? error.code}',
        kind: MatchImportKind.pickerFailed,
        cause: error,
      );
    }
    if (files.isEmpty) {
      return null;
    }
    final file = files.first;
    final path = file.path;
    if (path == null) {
      return null;
    }
    return PickedVideo(path: path, displayName: file.name);
  }
}

// Platform note: on iOS the picker offers both the photo library
// (`PHPickerViewController`) and the document picker, and both return their
// result through this one class. On Android a video is requested with
// `Intent.ACTION_GET_CONTENT` for `video/*` (android_file_picker 2.0.0), a
// Storage Access Framework picker that grants read access to the chosen file,
// so no runtime media permission is needed and the Android manifest declares
// none.
//
// Whichever entry point is used, the path handed back is a copy the platform
// made in a directory it may later purge — `NSTemporaryDirectory()` on iOS, the
// app cache on Android — and on Android the underlying URI grant does not
// outlive the process. That is why `RecordingStore` takes custody of the file
// before anything is stored.
