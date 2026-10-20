part of 'cafe_store.dart';

extension CafeStoreFeedback on CafeStore {
  /// Sends a message to the provider. Returns null when it was sent, otherwise an error to show.
  Future<String?> sendFeedback({
    required String kind,
    required String message,
  }) => db.sendFeedback(kind: kind, message: message, appVersion: appVersion);
}
