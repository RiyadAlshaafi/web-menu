import '../models/models.dart';

/// Tells which orders are new since the last look, so the cashier is alerted once per guest order.
/// The first look only learns what is already on screen, so opening the app never rings.
class NewOrderWatch {
  /// Order id to the newest round seen on it.
  Map<String, int>? _known;

  /// Orders in [current] that were not there last time, or got a new round that is waiting for
  /// Accept (a guest ordering again on the same table), and still need the cashier (not paid).
  List<CafeOrder> newOrders(List<CafeOrder> current) {
    final known = _known;
    _known = {for (final order in current) order.id: order.latestRound};
    if (known == null) return const [];
    return [
      for (final order in current)
        if (order.status != OrderStatus.paid &&
            (!known.containsKey(order.id) ||
                (order.latestRound > known[order.id]! && order.status == OrderStatus.received)))
          order,
    ];
  }

  /// Starts over (after sign-out), so the next look is a first look again.
  void reset() => _known = null;
}

/// Tells which staff calls and bill requests are new since the last look. A request is keyed by
/// its kind and table, so the server's copy of a request this device already knew stays quiet.
/// Like [NewOrderWatch], the first look only learns.
class NewRequestWatch {
  Set<String>? _known;

  /// Kinds ('bill', 'assistance', ...) of the requests in [current] that were not there last time.
  Set<String> newKinds(Iterable<({String kind, String tableId})> current) {
    final known = _known;
    final keys = {for (final request in current) '${request.kind}:${request.tableId}'};
    _known = keys;
    if (known == null) return const {};
    return {
      for (final request in current)
        if (!known.contains('${request.kind}:${request.tableId}')) request.kind,
    };
  }

  /// Starts over (after sign-out), so the next look is a first look again.
  void reset() => _known = null;
}
