import 'models/models.dart';

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
