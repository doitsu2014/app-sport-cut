import 'package:file_picker/file_picker.dart';

import '../domain/export_exception.dart';

/// A music file the user chose from device storage.
class PickedAudio {
  /// Create a picked track.
  const PickedAudio({required this.path, this.displayName});

  /// Absolute path of the file on the device.
  final String path;

  /// Name shown to the user, usually the file name.
  final String? displayName;
}

/// Source of background music for a reel.
///
/// Abstracted so the export screen can be tested without a platform picker.
abstract interface class AudioFilePicker {
  /// Ask the user for an audio file, or return `null` when they cancel.
  Future<PickedAudio?> pickAudio();
}

/// Picker backed by the platform file chooser.
class SystemAudioFilePicker implements AudioFilePicker {
  @override
  Future<PickedAudio?> pickAudio() async {
    final List<PlatformFile> files;
    try {
      files = await FilePicker.pickFiles(type: FileType.audio);
    } on Object catch (error) {
      // A picker that fails reaches the user as a message rather than as an
      // unhandled async error.
      throw ExportException(
        'The music picker could not open: $error',
        cause: error,
      );
    }
    final file = files.firstOrNull;
    final path = file?.path;
    if (path == null) {
      return null;
    }
    return PickedAudio(path: path, displayName: file!.name);
  }
}
