import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'admin_reset_file_stub.dart' if (dart.library.io) 'admin_reset_file_io.dart' as impl;

/// Name of the one-time ticket the Windows setup writes beside the exe when the seller ticks
/// "Reset the offline admin password" (windows/installer/cafe_pos.iss).
const adminResetFileName = 'admin_reset.json';

/// How long a ticket stays usable after the setup wrote it.
const adminResetLifetime = Duration(hours: 24);

/// Small allowance for a ticket stamped slightly ahead of the app's clock.
const _clockSkew = Duration(minutes: 5);

// The release workflow can pass a private key (`ADMIN_RESET_KEY` in .env -> --dart-define and
// /DResetKey). It must match the setup's ResetKey, or every ticket is refused.
const _definedKey = String.fromEnvironment('ADMIN_RESET_KEY');
const adminResetKey = _definedKey == '' ? 'tawla-offline-admin-reset-v1' : _definedKey;

/// Signature the setup puts on a ticket: SHA-256 of `key|nonce|issued` in lowercase hex.
/// Must match AdminResetSignature in cafe_pos.iss.
String adminResetSignature(String nonce, String issued, {String key = adminResetKey}) =>
    sha256.convert(utf8.encode('$key|$nonce|$issued')).toString();

/// A checked reset ticket: lets the cafe set a new offline admin password once.
///
/// The seller can only make one by running the setup, which checks the seller password online.
/// Sales, menu and settings are never touched by a reset.
class AdminResetTicket {
  const AdminResetTicket({required this.nonce, required this.issuedAt});

  /// Random id of this ticket, saved once used so a copied ticket cannot be used again.
  final String nonce;

  /// When the setup wrote it, in this PC's local time (setup and app share the clock).
  final DateTime issuedAt;

  static final _nonceShape = RegExp(r'^[0-9a-f]{16,128}$');

  /// The ticket in [text], or null when it is missing, broken, wrongly signed, expired or
  /// already in [used].
  static AdminResetTicket? check(
    String? text, {
    required DateTime now,
    required Set<String> used,
    String key = adminResetKey,
  }) {
    if (text == null) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final nonce = decoded['nonce'];
    final issued = decoded['issued'];
    final sig = decoded['sig'];
    if (nonce is! String || issued is! String || sig is! String) return null;
    final id = nonce.toLowerCase();
    if (!_nonceShape.hasMatch(id) || used.contains(id)) return null;
    if (sig.toLowerCase() != adminResetSignature(nonce, issued, key: key)) return null;
    final issuedAt = DateTime.tryParse(issued);
    if (issuedAt == null) return null;
    if (issuedAt.isAfter(now.add(_clockSkew)) || now.difference(issuedAt) > adminResetLifetime) return null;
    return AdminResetTicket(nonce: id, issuedAt: issuedAt);
  }
}

/// Reads and removes the ticket file beside the exe. Tests pass a fake.
class AdminResetFile {
  const AdminResetFile();

  /// The ticket's text, or null when there is none (web, tests, no reset asked).
  Future<String?> read() => impl.readAdminResetFile();

  Future<void> delete() => impl.deleteAdminResetFile();
}
