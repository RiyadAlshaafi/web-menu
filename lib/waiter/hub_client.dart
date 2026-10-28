import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../lan/lan_protocol.dart';

/// A cashier PC's answer. [status] 0 means the PC could not be reached at all.
class HubReply {
  const HubReply(this.status, [this.body = const {}]);

  final int status;
  final Map<String, dynamic> body;

  bool get ok => status == 200;
  bool get unreachable => status == 0;
}

/// How the waiter phone finds and talks to the cashier PC.
abstract interface class HubClient {
  /// Asks the Wi-Fi which cashier PCs are there, waiting [wait] for answers.
  Future<List<FoundHub>> discover({Duration wait});

  Future<HubReply> send(
    String host,
    int port,
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
    Duration timeout,
  });
}

class LanHubClient implements HubClient {
  @override
  Future<List<FoundHub>> discover({Duration wait = const Duration(milliseconds: 1500)}) async {
    final found = <String, FoundHub>{};
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      final udp = socket;
      final listening = udp.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = udp.receive();
        if (datagram == null) return;
        try {
          final json = jsonDecode(utf8.decode(datagram.data));
          if (json is! Map<String, dynamic>) return;
          final hub = FoundHub.fromAnswer(json, datagram.address.address);
          if (hub != null) found[hub.hubId] = hub;
        } on FormatException {
          return;
        }
      });
      final ask = utf8.encode(LanProtocol.discoverMessage);
      final everyone = InternetAddress('255.255.255.255');
      // Ask twice: one broadcast is easily lost on a busy Wi-Fi.
      udp.send(ask, everyone, LanProtocol.discoveryPort);
      await Future<void>.delayed(wait ~/ 3);
      udp.send(ask, everyone, LanProtocol.discoveryPort);
      await Future<void>.delayed(wait - wait ~/ 3);
      await listening.cancel();
    } on SocketException {
      // No Wi-Fi: nothing found; the screen offers to type the address.
    } finally {
      socket?.close();
    }
    return found.values.toList();
  }

  @override
  Future<HubReply> send(
    String host,
    int port,
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final request = await client
          .openUrl(method, Uri(scheme: 'http', host: host, port: port, path: path))
          .timeout(timeout);
      if (token != null) request.headers.set(LanProtocol.tokenHeader, token);
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(timeout);
      final text = await response.transform(utf8.decoder).join().timeout(timeout);
      final json = text.isEmpty ? null : jsonDecode(text);
      return HubReply(response.statusCode, json is Map<String, dynamic> ? json : const {});
    } on SocketException {
      return const HubReply(0);
    } on HttpException {
      return const HubReply(0);
    } on TimeoutException {
      return const HubReply(0);
    } on FormatException {
      return const HubReply(0);
    } finally {
      client.close(force: true);
    }
  }
}
