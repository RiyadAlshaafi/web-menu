/// What the cashier PC and a waiter phone agree on when they talk over the cafe's Wi-Fi.
abstract final class LanProtocol {
  /// The cashier PC answers waiter phones here (HTTP).
  static const httpPort = 47820;

  /// A phone broadcasts [discoverMessage] here; every cashier PC on the Wi-Fi answers.
  static const discoveryPort = 47821;

  static const discoverMessage = 'TAWLA_DISCOVER';

  /// Header that carries the token a phone got when the cashier allowed it.
  static const tokenHeader = 'x-waiter-token';

  /// How long a phone waits for the cashier to tap Allow.
  static const pairWait = Duration(seconds: 60);

  /// Largest request body the hub reads; an order of 99 dishes is far smaller.
  static const maxBodyBytes = 64 * 1024;

  /// Most dishes of one kind on one waiter order, matching the till's own limit.
  static const maxDishQty = 99;

  /// Most different lines on one waiter order.
  static const maxLines = 60;
}

/// Where a waiter order is: still waiting for the cashier, sent on, or turned down.
enum WaiterOrderStatus { pending, accepted, refused }

/// One cashier PC a phone found on the Wi-Fi.
class FoundHub {
  const FoundHub({required this.host, required this.port, required this.hubId, required this.cafeName});

  final String host;
  final int port;
  final String hubId;
  final String cafeName;

  /// Reads a discovery answer; null when it is not one.
  static FoundHub? fromAnswer(Map<String, dynamic> json, String host) {
    final hubId = json['hubId'];
    final port = json['port'];
    if (json['tawla'] != 1 || hubId is! String || port is! int) return null;
    final cafe = json['cafe'];
    return FoundHub(host: host, port: port, hubId: hubId, cafeName: cafe is String && cafe.isNotEmpty ? cafe : 'Tawla');
  }
}
