/// The client end of the Sportcut Service Protocol v1.
///
/// This is the only thing in the app that talks to the engine process. It owns
/// the Unix-domain socket, the length-prefixed frame codec, the request/response
/// correlation, and the `service.hello` handshake described in
/// `docs/architecture/protocol.md`.
///
/// Nothing above this file knows how the engine is reached. There is no FFI, no
/// shared library, and no generated binding: the engine is a separate process
/// and this is a socket.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show InternetAddress, InternetAddressType, Socket;
import 'dart:typed_data';

/// A failure reported by the service, or by the connection to it.
///
/// The message is meant to be shown to a user: the service phrases protocol
/// errors as sentences that name the file and the reason.
class ProtocolFailure implements Exception {
  /// Create a failure with a protocol code and message.
  ProtocolFailure(this.code, this.message, {this.kind});

  /// JSON-RPC or protocol error code, as defined by protocol section 8.
  final int code;

  /// Human-readable reason.
  final String message;

  /// Stable error kind carried in `error.data.kind`, when the service sent one.
  final String? kind;

  @override
  String toString() => 'ProtocolFailure($code, $kind): $message';
}

/// Protocol version this client speaks.
const int protocolMajor = 1;

/// Protocol minor version this client speaks.
const int protocolMinor = 0;

/// Capabilities the client offers. The service intersects them with the ones it
/// serves, so offering a group this build does not use is harmless.
const List<String> clientCapabilities = <String>[
  'engine.v1',
  'catalog.v1',
  'custody.v1',
  'notifications.v1',
  'idempotency.v1',
  'playback.path.v1',
  'metrics.v1',
  'diagnostics.v1',
];

/// One frame larger than this is rejected by both sides.
const int maxFrameBytes = 16 * 1024 * 1024;

/// A notification pushed by the service, such as `job.progress`.
class ServiceNotification {
  /// Create a notification.
  ServiceNotification(this.method, this.params);

  /// Notification method name.
  final String method;

  /// Notification parameters, already decoded.
  final Map<String, dynamic> params;
}

/// A handshaken connection to the service.
class ServiceConnection {
  ServiceConnection._(this._socket) {
    _subscription = _socket.listen(
      _onData,
      onError: _onSocketError,
      onDone: _onSocketDone,
      cancelOnError: false,
    );
  }

  final Socket _socket;
  late final StreamSubscription<Uint8List> _subscription;

  final List<int> _pending = <int>[];
  final Map<int, Completer<Map<String, dynamic>?>> _calls =
      <int, Completer<Map<String, dynamic>?>>{};
  final StreamController<ServiceNotification> _notifications =
      StreamController<ServiceNotification>.broadcast();
  int _nextId = 1;
  bool _closed = false;

  /// The `service.hello` result, once the handshake has completed.
  Map<String, dynamic>? hello;

  /// Notifications from the service. Broadcast: several listeners are fine.
  Stream<ServiceNotification> get notifications => _notifications.stream;

  /// Whether the connection is closed or the peer went away.
  bool get isClosed => _closed;

  /// Connect to the service at [endpoint] and complete the handshake.
  ///
  /// [token] is the per-launch token from the service's token file.
  static Future<ServiceConnection> open({
    required String endpoint,
    required String token,
    String clientName = 'Sportcut.app',
    String clientVersion = '0.1.0',
    String clientBuild = 'dev',
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final address = InternetAddress(endpoint, type: InternetAddressType.unix);
    final socket = await Socket.connect(address, 0, timeout: timeout);
    socket.setOption(SocketOption.tcpNoDelay, true);
    final connection = ServiceConnection._(socket);
    try {
      connection.hello = await connection
          .call('service.hello', <String, dynamic>{
            'protocol': <String, dynamic>{
              'major': protocolMajor,
              'minor': protocolMinor,
            },
            'client': <String, dynamic>{
              'name': clientName,
              'version': clientVersion,
              'build': clientBuild,
            },
            'token': token,
            'capabilities': clientCapabilities,
          })
          .timeout(timeout);
      return connection;
    } on Object {
      await connection.close();
      rethrow;
    }
  }

  /// Send one request and return its `result`.
  ///
  /// `null` is a valid result for methods that answer "nothing", such as a
  /// calibration that was never stored.
  Future<Map<String, dynamic>?> call(
    String method, [
    Map<String, dynamic> params = const <String, dynamic>{},
  ]) {
    if (_closed) {
      throw ProtocolFailure(-32000, 'the service connection is closed');
    }
    final id = _nextId++;
    final completer = Completer<Map<String, dynamic>?>();
    _calls[id] = completer;
    _write(<String, dynamic>{
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    });
    return completer.future;
  }

  /// Close the connection. Safe to call more than once.
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    for (final completer in _calls.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          ProtocolFailure(-32000, 'the service connection was closed'),
        );
      }
    }
    _calls.clear();
    await _notifications.close();
    await _subscription.cancel();
    await _socket.close();
  }

  // --- framing -------------------------------------------------------------

  void _write(Map<String, dynamic> message) {
    final body = utf8.encode(jsonEncode(message));
    if (body.length > maxFrameBytes) {
      throw ProtocolFailure(-32003, 'request frame exceeds 16 MiB');
    }
    final header = ByteData(4)..setUint32(0, body.length, Endian.big);
    _socket.add(header.buffer.asUint8List());
    _socket.add(body);
  }

  void _onData(Uint8List chunk) {
    _pending.addAll(chunk);
    while (true) {
      if (_pending.length < 4) {
        return;
      }
      final header = Uint8List.fromList(_pending.sublist(0, 4));
      final length = ByteData.sublistView(header).getUint32(0, Endian.big);
      if (length > maxFrameBytes) {
        _failAll(ProtocolFailure(-32003, 'response frame exceeds 16 MiB'));
        return;
      }
      if (_pending.length < 4 + length) {
        return;
      }
      final body = _pending.sublist(4, 4 + length);
      _pending.removeRange(0, 4 + length);
      _dispatch(body);
    }
  }

  void _dispatch(List<int> body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(body));
    } on FormatException catch (error) {
      _failAll(ProtocolFailure(-32700, 'unreadable frame: ${error.message}'));
      return;
    }
    if (decoded is! Map<String, dynamic>) {
      _failAll(ProtocolFailure(-32600, 'frame is not a JSON object'));
      return;
    }

    final id = decoded['id'];
    if (id is int) {
      final completer = _calls.remove(id);
      if (completer == null || completer.isCompleted) {
        return;
      }
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        final data = error['data'];
        final kind = data is Map<String, dynamic> ? data['kind'] as String? : null;
        completer.completeError(
          ProtocolFailure(
            (error['code'] as num?)?.toInt() ?? -32603,
            error['message'] as String? ?? 'the service reported an error',
            kind: kind,
          ),
        );
        return;
      }
      final result = decoded['result'];
      completer.complete(
        result is Map<String, dynamic> ? result : null,
      );
      return;
    }

    final method = decoded['method'];
    if (method is String) {
      final params = decoded['params'];
      _notifications.add(
        ServiceNotification(
          method,
          params is Map<String, dynamic> ? params : <String, dynamic>{},
        ),
      );
    }
  }

  void _onSocketError(Object error) {
    _failAll(ProtocolFailure(-32000, 'service connection failed: $error'));
  }

  void _onSocketDone() {
    _failAll(ProtocolFailure(-32000, 'the service closed the connection'));
  }

  void _failAll(ProtocolFailure failure) {
    _closed = true;
    for (final completer in _calls.values) {
      if (!completer.isCompleted) {
        completer.completeError(failure);
      }
    }
    _calls.clear();
  }
}
