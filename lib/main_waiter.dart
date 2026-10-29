import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'waiter/hub_client.dart';
import 'waiter/waiter_app.dart';
import 'waiter/waiter_state.dart';

/// The waiter phone app. It never signs in and never talks to the internet: it finds the
/// cashier's till on the cafe Wi-Fi and sends orders there.
/// Build: flutter build apk -t lib/main_waiter.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind the status and nav bars; screens pad themselves with SafeArea.
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  final controller = WaiterController(LanHubClient());
  runApp(WaiterApp(controller: controller));
  await controller.start();
}
