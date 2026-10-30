/// Shared plumbing for the screenshot suites.
///
/// The suites render the real app at the studio's reference window size and
/// capture the tree through a [RepaintBoundary]. Two runtimes share this
/// harness: a headless widget test (`flutter test test/screenshots`) and the
/// macOS integration test (`flutter test integration_test -d macos`). Only the
/// surface sizing differs; the capture path is the same because
/// `IntegrationTestWidgetsFlutterBinding.takeScreenshot` is not implemented on
/// macOS.
///
/// PNGs are build output: they go to `app/build/screenshots` unless a caller
/// overrides `SPORTCUT_SCREENSHOT_DIR`. Nothing here writes outside that
/// directory.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// The logical window the screenshots are laid out at.
///
/// This is the size the studio targets on macOS; at [kScreenshotPixelRatio] it
/// produces a 2360x1520 PNG, the same raster a Retina display would show.
const Size kScreenshotLogicalSize = Size(1180, 760);

/// The raster scale applied when capturing a PNG.
///
/// A value of `2.0` turns the 1180x760 logical window into a 2360x1520 image.
const double kScreenshotPixelRatio = 2.0;

/// Whether [loadScreenshotFonts] has already registered the families.
bool _screenshotFontsLoaded = false;

/// The directory screenshot PNGs are written to.
///
/// Resolution order: the compile-time `SPORTCUT_SCREENSHOT_DIR` define, then
/// the same variable in the process environment, then `build/screenshots`
/// relative to the working directory. The directory is not created; the
/// capture helper does that when it writes its first file.
Directory screenshotOutputDirectory() {
  const compileTime = String.fromEnvironment('SPORTCUT_SCREENSHOT_DIR');
  if (compileTime.isNotEmpty) {
    return Directory(compileTime);
  }
  final fromEnvironment = Platform.environment['SPORTCUT_SCREENSHOT_DIR'];
  if (fromEnvironment != null && fromEnvironment.isNotEmpty) {
    return Directory(fromEnvironment);
  }
  return Directory(p.join('build', 'screenshots'));
}

/// Load the app's real fonts into the test engine.
///
/// `flutter_test` starts with the Ahem placeholder font, so without this the
/// PNG shows solid boxes instead of text. The assets are already part of the
/// test bundle through `pubspec.yaml`; this only registers them. Calling it
/// more than once is safe: the families are registered once and a duplicate
/// registration is ignored.
Future<void> loadScreenshotFonts() async {
  if (_screenshotFontsLoaded) {
    return;
  }
  await Future.wait<void>(<Future<void>>[
    _loadScreenshotFont(
      'Archivo',
      const <String>['assets/fonts/Archivo-Variable.ttf'],
    ),
    _loadScreenshotFont(
      'IBMPlexSans',
      const <String>['assets/fonts/IBMPlexSans-Variable.ttf'],
    ),
    _loadScreenshotFont(
      'IBMPlexMono',
      const <String>[
        'assets/fonts/IBMPlexMono-Regular.ttf',
        'assets/fonts/IBMPlexMono-Medium.ttf',
      ],
    ),
    _loadScreenshotFont(
      'MaterialIcons',
      const <String>['fonts/MaterialIcons-Regular.otf'],
    ),
  ]);
  _screenshotFontsLoaded = true;
}

/// Register one family from one or more asset files.
Future<void> _loadScreenshotFont(
  String family,
  List<String> assets,
) async {
  final loader = FontLoader(family);
  for (final asset in assets) {
    loader.addFont(rootBundle.load(asset));
  }
  try {
    await loader.load();
  } on StateError catch (error) {
    // A loader can only be loaded once. If another suite already registered
    // this family through the same kind of helper, treat it as done.
    if (error.message.contains('already loaded')) {
      return;
    }
    rethrow;
  }
}

/// Size the headless test view for a screenshot.
///
/// Sets the device pixel ratio and the physical size so the logical layout is
/// [logicalSize], resets both when the test ends, and forces the light theme
/// branch so captures do not depend on the host's appearance setting.
void useWidgetScreenshotView(
  WidgetTester tester, {
  Size logicalSize = kScreenshotLogicalSize,
  double pixelRatio = kScreenshotPixelRatio,
}) {
  tester.view.devicePixelRatio = pixelRatio;
  tester.view.physicalSize = logicalSize * pixelRatio;
  addTearDown(tester.view.reset);

  tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

/// Size the live macOS integration-test surface for a screenshot.
///
/// The integration binding owns the surface, so this uses `setSurfaceSize`
/// rather than the test view. Resetting to `null` restores the runner default
/// when the test ends.
Future<void> useIntegrationScreenshotSurface(
  WidgetTester tester, {
  Size logicalSize = kScreenshotLogicalSize,
}) async {
  await tester.binding.setSurfaceSize(logicalSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Wrap [child] in the boundary [captureScreenshot] reads from.
///
/// Wrap the whole app (normally `ProviderScope` + `MaterialApp`), not an inner
/// widget: a route push moves the home route offstage, and a boundary around a
/// subtree would clip the content that is actually on screen.
Widget screenshotBoundary(GlobalKey key, Widget child) =>
    RepaintBoundary(key: key, child: child);

/// Capture the boundary identified by [key] as `<output>/<name>.png`.
///
/// The image is rasterised at [pixelRatio] and saved as PNG under
/// [screenshotOutputDirectory], which is created recursively first. Fails with
/// a descriptive [StateError] when the key has no painted boundary or the
/// engine cannot encode the image: a missing screenshot is a test failure, not
/// a silent skip.
Future<File> captureScreenshot(
  WidgetTester tester,
  GlobalKey key,
  String name, {
  double pixelRatio = kScreenshotPixelRatio,
}) async {
  final context = key.currentContext;
  if (context == null) {
    throw StateError(
      'Cannot capture "$name": the screenshot boundary has no context. '
      'Pump the widget tree with this key before capturing.',
    );
  }
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderRepaintBoundary) {
    throw StateError(
      'Cannot capture "$name": the widget under the screenshot key is a '
      '${renderObject.runtimeType}, not a RenderRepaintBoundary. Wrap the app '
      'in screenshotBoundary().',
    );
  }

  final directory = screenshotOutputDirectory();
  final file = File(p.join(directory.path, '$name.png'));

  final saved = await tester.runAsync(() async {
    await directory.create(recursive: true);
    final image = await renderObject.toImage(pixelRatio: pixelRatio);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        throw StateError(
          'Cannot capture "$name": the engine returned no PNG bytes for the '
          'repaint boundary.',
        );
      }
      await file.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
    } finally {
      image.dispose();
    }
    return file;
  });

  if (saved == null) {
    throw StateError(
      'Cannot capture "$name": tester.runAsync returned without a file. The '
      'capture must run outside the fake-async zone.',
    );
  }
  return saved;
}
