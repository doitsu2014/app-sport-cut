import 'dart:io' show File, Platform;

import 'package:path/path.dart' as p;

/// Locates the inference assets a packaged macOS app carries inside its bundle.
///
/// A packaged build places the TFLite runtime in `Contents/Frameworks` and the
/// model weights in `Contents/Resources`. During development those files do not
/// exist, so each resolved path is `null` and the engine falls back to the
/// environment-variable paths the evaluation flow sets.
abstract final class InferenceAssets {
  /// The bundled runtime and model paths, or `null` for each when not bundled.
  static ({String? runtimePath, String? modelPath}) resolve() {
    // The runner binary lives at <app>/Contents/MacOS/<name>, so two dirname
    // hops reach <app>/Contents and the standard Frameworks/Resources dirs.
    final contents = p.dirname(p.dirname(Platform.resolvedExecutable));
    final runtime = p.join(
      contents,
      'Frameworks',
      'libtensorflowlite_c.dylib',
    );
    final model = p.join(contents, 'Resources', 'model.tflite');
    return (
      runtimePath: File(runtime).existsSync() ? runtime : null,
      modelPath: File(model).existsSync() ? model : null,
    );
  }
}
