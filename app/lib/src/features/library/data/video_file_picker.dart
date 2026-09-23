import 'package:file_picker/file_picker.dart';

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
    final files = await FilePicker.pickFiles(type: FileType.video);
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
