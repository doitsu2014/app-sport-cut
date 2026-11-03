import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'sportcut_engine.dart';

/// Starts and owns the packaged service helper.
///
/// Development runs supply `SPORTCUT_ENDPOINT` or `SPORTCUT_STATE_ROOT` and
/// never reach the supervisor. A packaged app has no environment, so it starts
/// the helper embedded at `Contents/Helpers/SportcutService` against a state
/// root under Application Support, then hands the endpoint and token to
/// [SportcutEngine.initialize].
class ServiceSupervisor {
  ServiceSupervisor._();

  static Process? _process;

  /// The endpoint and token the app should connect to.
  ///
  /// Reuses a running helper for the same state root (its token file and socket
  /// answer), so relaunching the app does not spawn a second service.
  static Future<ServiceTarget> ensure() async {
    final environment = Platform.environment;
    final configured =
        (environment['SPORTCUT_ENDPOINT']?.isNotEmpty ?? false) ||
            (environment['SPORTCUT_STATE_ROOT']?.isNotEmpty ?? false);
    if (configured) {
      return SportcutEngine.resolveTarget();
    }

    final support = await getApplicationSupportDirectory();
    final stateRoot = p.join(support.path, 'state');
    final endpoint = p.join(stateRoot, 'run', 's.sock');
    final tokenFile = p.join(stateRoot, 'run', 'token');

    final running = await _connect(endpoint, tokenFile);
    if (running != null) {
      return running;
    }

    final helper = _helperPath();
    if (!File(helper).existsSync()) {
      throw SportcutEngineException(
        'The Sportcut service helper is missing at $helper. '
        'Reinstall the app or run it from a complete build.',
      );
    }

    await Directory(stateRoot).create(recursive: true);
    // A stale socket or token from a crashed helper must not shadow the new
    // process; the connect attempt above already proved neither answers.
    for (final path in <String>[endpoint, tokenFile]) {
      final file = File(path);
      if (await file.exists()) {
        try {
          await file.delete();
        } on FileSystemException {
          // The helper will replace it, or fail with a clear log.
        }
      }
    }

    final arguments = <String>[
      '--state-root',
      stateRoot,
      '--endpoint',
      endpoint,
      '--token-file',
      tokenFile,
    ];
    final ffmpeg = _findTool('ffmpeg');
    final ffprobe = _findTool('ffprobe');
    if (ffmpeg != null) {
      arguments.addAll(<String>['--ffmpeg', ffmpeg]);
    }
    if (ffprobe != null) {
      arguments.addAll(<String>['--ffprobe', ffprobe]);
    }

    final contents = p.dirname(p.dirname(Platform.resolvedExecutable));
    final runtime = p.join(contents, 'Frameworks', 'libtensorflowlite_c.dylib');
    final model = p.join(contents, 'Resources', 'model.tflite');
    if (_supportsBundledInference &&
        File(runtime).existsSync() &&
        File(model).existsSync()) {
      arguments.addAll(<String>[
        '--tflite-library',
        runtime,
        '--person-model',
        model,
      ]);
    }

    final process = await Process.start(helper, arguments);
    _process = process;
    // Drain the pipes so a chatty helper cannot block on a full buffer.
    process.stdout.listen((_) {});
    process.stderr.listen((_) {});

    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(deadline)) {
      final target = await _connect(endpoint, tokenFile);
      if (target != null) {
        return target;
      }
      final exitCode = await process.exitCode
          .timeout(const Duration(milliseconds: 150), onTimeout: () => -1);
      if (exitCode != -1) {
        _process = null;
        throw SportcutEngineException(
          'The Sportcut service stopped while starting (exit $exitCode). '
          'See ${p.join(stateRoot, 'logs', 'service.log')}.',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    stop();
    throw SportcutEngineException(
      'The Sportcut service did not start. '
      'See ${p.join(stateRoot, 'logs', 'service.log')}.',
    );
  }

  /// Stop the helper this app started. A helper reused from a previous launch
  /// is left running; it is reused on the next launch.
  static void stop() {
    final process = _process;
    _process = null;
    process?.kill();
  }

  static Future<ServiceTarget?> _connect(
    String endpoint,
    String tokenFile,
  ) async {
    final token = File(tokenFile);
    if (!await token.exists() || !await File(endpoint).exists()) {
      return null;
    }
    try {
      final socket = await Socket.connect(
        InternetAddress(endpoint, type: InternetAddressType.unix),
        0,
        timeout: const Duration(seconds: 1),
      );
      await socket.close();
      final value = (await token.readAsString()).trim();
      return value.isEmpty ? null : (endpoint: endpoint, token: value);
    } on Object {
      return null;
    }
  }

  /// `Contents/Helpers/SportcutService` beside the running executable.
  static String _helperPath() {
    final contents = p.dirname(p.dirname(Platform.resolvedExecutable));
    return p.join(contents, 'Helpers', 'SportcutService');
  }

  /// Find a media tool a Finder-launched app can reach.
  ///
  /// The packaged app carries its own LGPL ffmpeg/ffprobe, so the bundle wins.
  /// A checkout that starts the helper itself can still use the system tools;
  /// those are checked next, and a GUI process's minimal PATH last.
  static String? _findTool(String name) {
    final contents = p.dirname(p.dirname(Platform.resolvedExecutable));
    final bundled = p.join(contents, 'Helpers', name);
    if (File(bundled).existsSync()) {
      return bundled;
    }
    for (final candidate in <String>[
      '/opt/homebrew/bin/$name',
      '/usr/local/bin/$name',
      '/usr/bin/$name',
    ]) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    final path = Platform.environment['PATH'] ?? '';
    for (final directory in path.split(':')) {
      if (directory.isEmpty) {
        continue;
      }
      final candidate = p.join(directory, name);
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }
    return null;
  }

  /// The packaged TFLite runtime is an Apple Silicon build whose minimum macOS
  /// is 15.0; handing it to an Intel launch or an older macOS would make the
  /// service advertise tracking and then fail when the interpreter loads. The
  /// rest of the engine is universal and works from macOS 12.
  static bool get _supportsBundledInference {
    if (!_runsOnAppleSilicon) {
      return false;
    }
    try {
      final result = Process.runSync('sw_vers', <String>['-productVersion']);
      final major = result.stdout.toString().trim().split('.').first;
      return (int.tryParse(major) ?? 0) >= 15;
    } on Object {
      return false;
    }
  }

  static bool get _runsOnAppleSilicon {
    if (Platform.operatingSystem != 'macos') {
      return false;
    }
    try {
      final result = Process.runSync('uname', <String>['-m']);
      return result.stdout.toString().trim() == 'arm64';
    } on Object {
      return false;
    }
  }
}
