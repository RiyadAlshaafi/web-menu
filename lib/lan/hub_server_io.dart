import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/report_error.dart';
import 'lan_protocol.dart';
import 'waiter_hub.dart';

/// Opens the cashier PC to waiter phones on the Wi-Fi: an HTTP port for their requests and a
/// UDP port that answers "is a cashier here?". Only a desktop till does this.
class HubServer {
  HubServer(this.hub, {this.httpPort = LanProtocol.httpPort, this.discoveryPort = LanProtocol.discoveryPort});

  final WaiterHub hub;
  final int httpPort;
  final int discoveryPort;

  HttpServer? _http;
  RawDatagramSocket? _udp;
  Future<void>? _starting;

  bool get supported => Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  bool get running => _http != null;

  /// The port the HTTP server really got (useful when a test asks for port 0).
  int? get boundPort => _http?.port;

  Future<void> start() => _starting ??= _start().whenComplete(() => _starting = null);

  Future<void> _start() async {
    if (running) return;
    try {
      await hub.load();
      final http = await HttpServer.bind(InternetAddress.anyIPv4, httpPort);
      _http = http;
      http.listen(_serve, onError: (Object error, StackTrace stack) => reportError('waiter hub http', error, stack));
    } on SocketException catch (error, stack) {
      // Another copy of the app already has the port; this one simply does not host phones.
      reportError('waiter hub start', error, stack);
      return;
    }
    try {
      final udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, discoveryPort);
      _udp = udp;
      udp.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = udp.receive();
        if (datagram == null || utf8.decode(datagram.data, allowMalformed: true) != LanProtocol.discoverMessage) return;
        udp.send(utf8.encode(jsonEncode(hub.discoveryAnswer())), datagram.address, datagram.port);
      });
    } on SocketException catch (error, stack) {
      // Phones can still connect by typing the PC's address.
      reportError('waiter hub discovery', error, stack);
    }
  }

  Future<void> stop() async {
    await _starting;
    final http = _http;
    _http = null;
    _udp?.close();
    _udp = null;
    await http?.close(force: true);
  }

  Future<void> _serve(HttpRequest request) async {
    final response = request.response;
    try {
      final body = await _readBody(request);
      final answer = body == _tooLarge
          ? HubResponse.error(413, 'too_large')
          : await hub.handle(
              HubRequest(
                method: request.method,
                path: request.uri.path,
                token: request.headers.value(LanProtocol.tokenHeader),
                body: body is Map<String, dynamic> ? body : null,
              ),
            );
      response.statusCode = answer.status;
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode(answer.body));
    } on Exception catch (error, stack) {
      reportError('waiter hub request', error, stack);
      response.statusCode = HttpStatus.internalServerError;
    } finally {
      await response.close().catchError((Object _) => null);
    }
  }

  static const _tooLarge = Object();

  Future<Object?> _readBody(HttpRequest request) async {
    if (request.method != 'POST') return null;
    final bytes = <int>[];
    await for (final chunk in request) {
      bytes.addAll(chunk);
      if (bytes.length > LanProtocol.maxBodyBytes) return _tooLarge;
    }
    if (bytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(bytes));
    } on FormatException {
      return null;
    }
  }
}
