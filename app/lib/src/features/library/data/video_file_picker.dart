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
/// Abstracted so the library screen can be tested, and so a future macOS-native
/// picker can be swapped in without touching the screen.
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

// On macOS the system file chooser returns the selected file's path directly.
// `RecordingStore` still takes custody of the file before anything is stored,
// so a match never depends on the original location surviving.
