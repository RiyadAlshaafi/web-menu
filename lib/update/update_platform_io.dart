import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../offline/outbox_store.dart';
import 'release_info.dart';
import 'update_platform.dart';

UpdatePlatform createUpdatePlatform() => IoUpdatePlatform();

/// Name of the folder (inside the app's data folder) that holds the backups made before updates.
const backupFolderName = 'backups';
const _markerFile = 'update_check.json';

class IoUpdatePlatform implements UpdatePlatform {
  IoUpdatePlatform({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  bool get supported => Platform.isWindows;

  @override
  Future<Object?> fetchLatestJson() async {
    final response = await _client.get(Uri.parse(latestReleaseUrl)).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return null;
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  @override
  Future<String> download(ReleaseInfo info) async {
    final target = File(p.join(Directory.systemTemp.path, 'CafePOS-setup-${info.version}.exe'));
    await downloadVerified(_client, Uri.parse(info.url), info.sha256, target);
    return target.path;
  }

  @override
  Future<String> backup(OutboxStore store, String outboxFileName) async => backupAppData(
    source: await getApplicationSupportDirectory(),
    store: store,
    outboxFileName: outboxFileName,
  );

  @override
  Future<Map<String, dynamic>?> readMarker() async {
    final file = File(p.join((await getApplicationSupportDirectory()).path, _markerFile));
    if (!file.existsSync()) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(await file.readAsString()) as Map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeMarker(Map<String, dynamic>? marker) async {
    final file = File(p.join((await getApplicationSupportDirectory()).path, _markerFile));
    if (marker == null) {
      if (file.existsSync()) await file.delete();
      return;
    }
    await file.writeAsString(jsonEncode(marker), flush: true);
  }

  @override
  Future<void> install(String installerPath) async {
    await Process.start(
      installerPath,
      const ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CLOSEAPPLICATIONS'],
      mode: ProcessStartMode.detached,
    );
    exit(0);
  }
}

/// Streams [url] into [target] while hashing it; deletes the file and throws if the SHA-256 is not
/// [sha256Hex], so a broken or changed installer is never run.
Future<void> downloadVerified(http.Client client, Uri url, String sha256Hex, File target) async {
  final response = await client.send(http.Request('GET', url)).timeout(const Duration(seconds: 30));
  if (response.statusCode != 200) {
    throw HttpException('download failed with status ${response.statusCode}', uri: url);
  }
  final digest = _DigestSink();
  final hasher = sha256.startChunkedConversion(digest);
  final sink = target.openWrite();
  try {
    await for (final chunk in response.stream.timeout(const Duration(minutes: 2))) {
      hasher.add(chunk);
      sink.add(chunk);
    }
  } finally {
    await sink.close();
  }
  hasher.close();
  if (digest.value.toString() != sha256Hex.toLowerCase()) {
    if (target.existsSync()) await target.delete();
    throw StateError('installer fingerprint does not match the release');
  }
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

/// Copies everything in [source] (except earlier backups and the live outbox files) to
/// `source/backups/<timestamp>`, writes a consistent copy of the outbox there, and keeps only the
/// newest [keep] backups. Returns the new backup folder.
Future<String> backupAppData({
  required Directory source,
  required OutboxStore store,
  required String outboxFileName,
  int keep = 3,
  DateTime? now,
}) async {
  final root = Directory(p.join(source.path, backupFolderName));
  final stamp = (now ?? DateTime.now()).toIso8601String().replaceAll(':', '-').split('.').first;
  final dest = Directory(p.join(root.path, stamp));
  await dest.create(recursive: true);
  final outboxBase = p.basenameWithoutExtension(outboxFileName);
  final outboxFiles = <File>[];
  await for (final entity in source.list(recursive: true, followLinks: false)) {
    final relative = p.relative(entity.path, from: source.path);
    final top = p.split(relative).first;
    if (top == backupFolderName) continue;
    // The outbox is copied below in one consistent piece, not file by file.
    if (entity is File && p.basename(entity.path).startsWith(outboxBase)) {
      outboxFiles.add(entity);
      continue;
    }
    final target = p.join(dest.path, relative);
    if (entity is Directory) {
      await Directory(target).create(recursive: true);
    } else if (entity is File) {
      await Directory(p.dirname(target)).create(recursive: true);
      await entity.copy(target);
    }
  }
  if (!await store.backupTo(p.join(dest.path, outboxFileName))) {
    // The outbox isn't open (it failed to open at start): copy its files as they are.
    for (final file in outboxFiles) {
      await file.copy(p.join(dest.path, p.relative(file.path, from: source.path)));
    }
  }
  final all = root.listSync().whereType<Directory>().toList()..sort((a, b) => b.path.compareTo(a.path));
  for (final old in all.skip(keep)) {
    await old.delete(recursive: true);
  }
  return dest.path;
}
