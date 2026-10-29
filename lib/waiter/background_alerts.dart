import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Keeps the waiter app alive with the screen off and shows a phone notification for an alert.
/// Only the Android waiter phone does this; everywhere else it does nothing.
abstract interface class BackgroundAlerts {
  /// Starts the "watching your tables" service that keeps the app running in the background.
  Future<void> keepAlive({required String title, required String text});

  Future<void> stopKeepAlive();

  /// Shows a notification (with the phone's notification sound) for an alert at [tableId].
  Future<void> notify({
    required int id,
    required String tableId,
    required String title,
    required String body,
    bool silent = false,
  });

  /// Tables whose notification the waiter tapped, including the one that opened the app.
  Stream<String> get openedTables;
}

BackgroundAlerts createBackgroundAlerts() =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? AndroidBackgroundAlerts() : const NoBackgroundAlerts();

class NoBackgroundAlerts implements BackgroundAlerts {
  const NoBackgroundAlerts();

  @override
  Future<void> keepAlive({required String title, required String text}) async {}

  @override
  Future<void> stopKeepAlive() async {}

  @override
  Future<void> notify({
    required int id,
    required String tableId,
    required String title,
    required String body,
    bool silent = false,
  }) async {}

  @override
  Stream<String> get openedTables => const Stream.empty();
}

/// The service needs a task to run; the work itself stays in the app (it keeps polling the till),
/// so this one does nothing.
@pragma('vm:entry-point')
void waiterServiceCallback() => FlutterForegroundTask.setTaskHandler(_IdleHandler());

class _IdleHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

class AndroidBackgroundAlerts implements BackgroundAlerts {
  static const _alertChannel = AndroidNotificationChannel(
    'waiter_alerts',
    'Table alerts',
    description: 'Food ready and guest calls',
    importance: Importance.max,
  );
  static const _quietChannel = AndroidNotificationChannel(
    'waiter_alerts_quiet',
    'Table alerts (no sound)',
    description: 'Food ready and guest calls, without a sound',
    importance: Importance.high,
    playSound: false,
  );

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final StreamController<String> _opened = StreamController.broadcast();
  bool _ready = false;

  @override
  Stream<String> get openedTables => _opened.stream;

  void _open(NotificationResponse response) {
    final tableId = response.payload;
    if (tableId != null && tableId.isNotEmpty) _opened.add(tableId);
  }

  Future<void> _prepare() async {
    if (_ready) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'waiter_service',
        channelName: 'Tawla Waiter running',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    await _notifications.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: _open,
    );
    // The app was closed and the waiter opened it from a notification.
    final launch = await _notifications.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    if (launch?.didNotificationLaunchApp == true && response != null) _open(response);
    final android = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_alertChannel);
    await android?.createNotificationChannel(_quietChannel);
    // Android 13+ asks once; without it nothing shows, but the app still works.
    await android?.requestNotificationsPermission();
    _ready = true;
  }

  @override
  Future<void> keepAlive({required String title, required String text}) async {
    try {
      await _prepare();
      if (await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: title,
        notificationText: text,
        callback: waiterServiceCallback,
      );
    } catch (error, stackTrace) {
      debugPrint('waiter keep-alive: $error\n$stackTrace');
    }
  }

  @override
  Future<void> stopKeepAlive() async {
    try {
      if (await FlutterForegroundTask.isRunningService) await FlutterForegroundTask.stopService();
    } catch (error, stackTrace) {
      debugPrint('waiter keep-alive stop: $error\n$stackTrace');
    }
  }

  @override
  Future<void> notify({
    required int id,
    required String tableId,
    required String title,
    required String body,
    bool silent = false,
  }) async {
    try {
      await _prepare();
      final channel = silent ? _quietChannel : _alertChannel;
      await _notifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.message,
          ),
        ),
        payload: tableId,
      );
    } catch (error, stackTrace) {
      debugPrint('waiter notification: $error\n$stackTrace');
    }
  }
}
