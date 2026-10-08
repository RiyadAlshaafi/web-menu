part of 'cafe_store.dart';

/// What the till shows about its last update, checked on the first start after it.
enum UpdateNotice {
  /// The new version runs and the server still has every upload.
  updated,

  /// The app started on the old version: the installer did not finish.
  notInstalled,

  /// The new version runs, but the server and the till disagree about the uploads.
  mismatch,
}

/// Self-update of the Windows cashier app. A new release is downloaded in the background and only
/// installed from the sign-in screen, after every upload is confirmed by the server and the till's
/// own data is copied to a backup folder. See docs/RELEASING.md.
extension CafeStoreUpdate on CafeStore {
  /// A newer release is downloaded, checked and ready to install.
  bool get updateReady => updateRelease != null && updateFile != null;

  /// This app is older than the oldest version the server still accepts; it must update before
  /// a cashier can sign in.
  bool get belowMinVersion =>
      updatePlatform.supported && isNewer(offline?.minAppVersion ?? minAppVersion, appVersion);

  Future<void> _initUpdates() async {
    try {
      appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (error, stackTrace) {
      reportError('read app version', error, stackTrace);
    }
    offline?.appVersion = appVersion;
    if (!updatePlatform.supported) return;
    if (db.client != null && !serverUnreachable) {
      try {
        final info = await db.callRpc('app_release_info', const {});
        if (info is Map && info['min_app_version'] is String) minAppVersion = info['min_app_version'] as String;
      } catch (error, stackTrace) {
        // Older database without the function, or no connection: no minimum.
        reportError('read minimum app version', error, stackTrace);
      }
    }
    await _checkAfterUpdate();
    unawaited(checkForUpdate());
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(minutes: 30), (_) => unawaited(checkForUpdate()));
  }

  /// Looks for a newer release and downloads it in the background. Quiet on any failure; the next
  /// check tries again.
  Future<void> checkForUpdate() async {
    if (!updatePlatform.supported || updateBusy) return;
    try {
      final release = ReleaseInfo.tryParse(await updatePlatform.fetchLatestJson());
      if (release == null || !isNewer(release.version, appVersion)) return;
      if (updateRelease?.version == release.version && updateFile != null) return;
      updateBusy = true;
      notifyListeners();
      updateFile = await updatePlatform.download(release);
      updateRelease = release;
    } catch (error, stackTrace) {
      reportError('download update', error, stackTrace);
    } finally {
      updateBusy = false;
      notifyListeners();
    }
  }

  /// Installs the downloaded release when it is safe: nobody signed in, nothing waiting to
  /// upload, the server confirms every receipt and expense this till uploaded, and the till's data
  /// is backed up. Returns why it stopped; on success the app closes and the installer reopens it.
  Future<UpdateBlock?> installUpdate() async {
    final release = updateRelease;
    final file = updateFile;
    if (release == null || file == null || updateBusy) return null;
    updateBusy = true;
    updateBlock = null;
    notifyListeners();
    try {
      final block = await _updateBlocker();
      if (block != null) return updateBlock = block;
      final String backup;
      try {
        backup = await updatePlatform.backup(
          offline?.store ?? MemoryOutboxStore(),
          OutboxStore.fileNameFor(AppDatabase.supabaseUrl),
        );
      } catch (error, stackTrace) {
        reportError('backup before update', error, stackTrace);
        return updateBlock = UpdateBlock.backup;
      }
      updateBackupPath = backup;
      await updatePlatform.writeMarker({
        'from': appVersion,
        'to': release.version,
        'at': DateTime.now().toUtc().toIso8601String(),
        'since': _sentWindowStart().toIso8601String(),
        'backup': backup,
      });
      await updatePlatform.install(file);
      return null;
    } catch (error, stackTrace) {
      reportError('install update', error, stackTrace);
      return updateBlock = UpdateBlock.download;
    } finally {
      updateBusy = false;
      notifyListeners();
    }
  }

  DateTime _sentWindowStart() => DateTime.now().toUtc().subtract(const Duration(days: 60));

  Future<UpdateBlock?> _updateBlocker() async {
    final sync = offline;
    final local = localUpdateBlock(
      signedIn: authKind != AuthKind.none,
      pending: sync?.pendingCount ?? 0,
      failed: sync?.failedCount ?? 0,
    );
    if (local != null) return local;
    if (db.client == null || !await db.serverReachable()) return UpdateBlock.offline;
    if (sync == null) return null;
    final matches = await _uploadsConfirmed(_sentWindowStart());
    if (matches == null) return UpdateBlock.offline;
    return matches ? null : UpdateBlock.serverMissing;
  }

  /// Whether the server has every receipt and expense this till uploaded since [since], with the
  /// same totals. Null when the server can't be asked.
  Future<bool?> _uploadsConfirmed(DateTime since) async {
    final sync = offline;
    if (sync == null) return true;
    final sent = await sync.store.sentSince(since);
    final local = UploadSummary.ofSent(sent);
    try {
      final server = await confirmOnServer([for (final record in sent) record.id], (chunk) async {
        final raw = await db.callRpc('confirm_uploads', {'p_ids': chunk});
        return Map<String, dynamic>.from(raw as Map);
      });
      lastUploadCheck = (local: local, server: server);
      return local.matches(server);
    } catch (error, stackTrace) {
      reportError('confirm uploads', error, stackTrace);
      return null;
    }
  }

  /// First start after an update: did it install, and does the server still have everything?
  Future<void> _checkAfterUpdate() async {
    final marker = await updatePlatform.readMarker();
    if (marker == null) return;
    final from = marker['from'] as String?;
    final to = marker['to'] as String?;
    updateBackupPath = marker['backup'] as String?;
    if (to != null && appVersion != to && appVersion == from) {
      updateNotice = UpdateNotice.notInstalled;
      await updatePlatform.writeMarker(null);
      return;
    }
    if (serverUnreachable || db.client == null) return; // checked again on the next start
    final since = DateTime.tryParse(marker['since'] as String? ?? '') ?? _sentWindowStart();
    final matches = await _uploadsConfirmed(since);
    if (matches == null) return;
    updateNotice = matches ? UpdateNotice.updated : UpdateNotice.mismatch;
    await updatePlatform.writeMarker(null);
  }

  void dismissUpdateNotice() {
    updateNotice = null;
    notifyListeners();
  }
}
