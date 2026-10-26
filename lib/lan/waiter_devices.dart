import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A waiter phone the cashier allowed. Only the hash of its token is kept, so a copy of the
/// saved list cannot be used to send orders.
class WaiterDevice {
  const WaiterDevice({required this.id, required this.name, required this.tokenHash, required this.lastSeen});

  final String id;
  final String name;
  final String tokenHash;
  final DateTime lastSeen;

  WaiterDevice seenAt(DateTime time) => WaiterDevice(id: id, name: name, tokenHash: tokenHash, lastSeen: time);

  factory WaiterDevice.fromJson(Map<String, dynamic> json) => WaiterDevice(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    tokenHash: json['tokenHash'] as String,
    lastSeen: DateTime.tryParse(json['lastSeen'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tokenHash': tokenHash,
    'lastSeen': lastSeen.toIso8601String(),
  };
}

/// Makes and checks the secret a waiter phone sends with every request.
abstract final class WaiterTokens {
  static final _random = Random.secure();

  static String create() => base64Url.encode(List<int>.generate(32, (_) => _random.nextInt(256))).replaceAll('=', '');

  static String hash(String token) => sha256.convert(utf8.encode(token)).toString();
}

/// Where the allowed phones are kept on the cashier PC.
abstract interface class WaiterDeviceStore {
  Future<List<WaiterDevice>> load();
  Future<void> save(List<WaiterDevice> devices);
}

class PrefsWaiterDeviceStore implements WaiterDeviceStore {
  static const _key = 'waiter_devices';

  @override
  Future<List<WaiterDevice>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const [];
    try {
      return [
        for (final entry in jsonDecode(raw) as List)
          WaiterDevice.fromJson(Map<String, dynamic>.from(entry as Map)),
      ];
    } on FormatException {
      return const [];
    } on TypeError {
      return const [];
    }
  }

  @override
  Future<void> save(List<WaiterDevice> devices) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode([for (final device in devices) device.toJson()]));
  }
}

class MemoryWaiterDeviceStore implements WaiterDeviceStore {
  List<WaiterDevice> devices = const [];

  @override
  Future<List<WaiterDevice>> load() async => devices;

  @override
  Future<void> save(List<WaiterDevice> devices) async => this.devices = List.unmodifiable(devices);
}
