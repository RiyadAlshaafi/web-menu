import 'waiter_hub.dart';

/// A browser cannot listen on the network, so the web till never hosts waiter phones.
class HubServer {
  HubServer(this.hub);

  final WaiterHub hub;

  bool get supported => false;
  bool get running => false;

  Future<void> start() async {}

  Future<void> stop() async {}
}
