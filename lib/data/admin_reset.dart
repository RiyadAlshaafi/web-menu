import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:pinenacl/ed25519.dart';

import 'admin_reset_file_stub.dart' if (dart.library.io) 'admin_reset_file_io.dart' as impl;

/// Name of the one-time ticket the Windows setup writes beside the exe when the seller ticks
/// "Reset the offline admin password" (windows/installer/cafe_pos.iss).
const adminResetFileName = 'admin_reset.json';

/// How long a ticket stays usable after the server signed it.
const adminResetLifetime = Duration(hours: 24);

/// Allowance for an offline PC whose clock runs behind the server's.
const _clockSkew = Duration(hours: 1);

/// Public half of the Ed25519 key that signs tickets (hex). The private half exists only as the
/// ADMIN_RESET_PRIVATE_KEY secret of the admin-reset-ticket Edge Function, which signs a ticket
/// only after the seller password check, so this public code can check tickets but never make one.
const adminResetPublicKey = 'a3865715808335f57bfc210440e4c2093e33f22667ba79be40f38136d9bea11f';

/// The key [AdminResetTicket.check] uses when none is passed. Tests put their own key pair here.
@visibleForTesting
String adminResetCheckKey = adminResetPublicKey;

/// The text the server signs. Must match ticketMessage in supabase/functions/admin-reset-ticket.
String adminResetMessage(String nonce, String issued) => 'tawla-admin-reset-v2|$nonce|$issued';

Uint8List? _hexBytes(String hex, int length) {
  if (hex.length != length * 2 || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) return null;
  return Uint8List.fromList([
    for (var i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16),
  ]);
}

/// Whether [sig] (hex) is the server's signature on [nonce] and [issued], checked with [publicKey].
bool adminResetSignatureValid(String nonce, String issued, String sig, {String? publicKey}) {
  final key = _hexBytes(publicKey ?? adminResetCheckKey, 32);
  final signature = _hexBytes(sig, 64);
  if (key == null || signature == null) return false;
  try {
    return VerifyKey(key).verify(
      signature: Signature(signature),
      message: Uint8List.fromList(utf8.encode(adminResetMessage(nonce, issued))),
    );
  } on Exception {
    return false;
  }
}

/// A checked reset ticket: lets the cafe set a new offline admin password once.
///
/// The seller can only make one by running the setup, which checks the seller password online.
/// Sales, menu and settings are never touched by a reset.
class AdminResetTicket {
  const AdminResetTicket({required this.nonce, required this.issuedAt});

  /// Random id of this ticket, saved once used so a copied ticket cannot be used again.
  final String nonce;

  /// When the server signed it.
  final DateTime issuedAt;

  static final _nonceShape = RegExp(r'^[0-9a-f]{32,128}$');

  /// The ticket in [text], or null when it is missing, broken, wrongly signed, expired or
  /// already in [used].
  static AdminResetTicket? check(
    String? text, {
    required DateTime now,
    required Set<String> used,
    String? publicKey,
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
    if (!_nonceShape.hasMatch(nonce) || used.contains(nonce)) return null;
    if (!adminResetSignatureValid(nonce, issued, sig, publicKey: publicKey)) return null;
    final issuedAt = DateTime.tryParse(issued);
    if (issuedAt == null) return null;
    if (issuedAt.isAfter(now.add(_clockSkew)) || now.difference(issuedAt) > adminResetLifetime) return null;
    return AdminResetTicket(nonce: nonce, issuedAt: issuedAt);
  }
}

/// Reads and removes the ticket file beside the exe. Tests pass a fake.
class AdminResetFile {
  const AdminResetFile();

  /// The ticket's text, or null when there is none (web, tests, no reset asked).
  Future<String?> read() => impl.readAdminResetFile();

  Future<void> delete() => impl.deleteAdminResetFile();
}
