import '../models/models.dart';

/// Tells which orders are new since the last look, so the cashier is alerted once per guest order.
/// The first look only learns what is already on screen, so opening the app never rings.
class NewOrderWatch {
  Set<String>? _known;

  /// Orders in [current] that were not there last time and still need the cashier (not paid).
  List<CafeOrder> newOrders(List<CafeOrder> current) {
    final known = _known;
    _known = {for (final order in current) order.id};
    if (known == null) return const [];
    return [
      for (final order in current)
        if (!known.contains(order.id) && order.status != OrderStatus.paid) order,
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
