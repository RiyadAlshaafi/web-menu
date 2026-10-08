import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n_ext.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';
import '../update/update_checks.dart';
import 'cafe_widgets.dart';

/// Cashier sign-in screen: the result of the last update, the "update required" block, and the
/// "install now" card. Shows nothing when there is nothing to say.
class UpdatePanel extends StatelessWidget {
  const UpdatePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.select<CafeStore, ({bool ready, bool busy, bool required, String version, UpdateBlock? block, UpdateNotice? notice, String backup, String current})>(
      (store) => (
        ready: store.updateReady,
        busy: store.updateBusy,
        required: store.belowMinVersion,
        version: store.updateRelease?.version ?? '',
        block: store.updateBlock,
        notice: store.updateNotice,
        backup: store.updateBackupPath ?? '',
        current: store.appVersion,
      ),
    );
    final store = context.read<CafeStore>();
    final l10n = context.l10n;
    final children = <Widget>[];

    if (s.notice != null) {
      final (text, color) = switch (s.notice!) {
        UpdateNotice.updated => (l10n.updateNoticeUpdated(s.current), CafeColors.ink),
        UpdateNotice.notInstalled => (l10n.updateNoticeNotInstalled, CafeColors.ink),
        UpdateNotice.mismatch => (l10n.updateNoticeMismatch, CafeColors.alert),
      };
      children.add(
        _box(
          color: s.notice == UpdateNotice.mismatch ? const Color(0xFFF6DADA) : CafeColors.peach,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
                    if (s.backup.isNotEmpty && s.notice != UpdateNotice.updated) ...[
                      const SizedBox(height: 4),
                      SelectableText(l10n.updateBackupAt(s.backup), style: const TextStyle(fontSize: 12, color: CafeColors.inkMuted)),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: store.dismissUpdateNotice,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      );
    }

    if (s.required || s.ready) {
      children.add(
        _box(
          color: s.required ? const Color(0xFFF6DADA) : CafeColors.paper,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(s.required ? Icons.system_update_alt : Icons.new_releases_outlined, color: s.required ? CafeColors.alert : CafeColors.terracotta),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.required ? l10n.updateRequiredTitle : l10n.updateReady(s.version),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (s.required) Text(l10n.updateRequiredBody),
              if (s.ready) ...[
                Text(l10n.updateSafetyNote, style: const TextStyle(color: CafeColors.inkMuted, height: 1.35)),
                if (s.block != null) ...[
                  const SizedBox(height: 8),
                  Text(_blockText(context, s.block!), style: const TextStyle(color: CafeColors.alert, fontWeight: FontWeight.w700)),
                ],
                const SizedBox(height: 12),
                TerracottaButton(
                  label: s.busy ? l10n.updateInstalling : l10n.updateInstallNow,
                  busy: s.busy,
                  onPressed: s.busy ? null : () => store.installUpdate(),
                ),
              ] else if (s.busy)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(l10n.updateDownloading, style: const TextStyle(color: CafeColors.inkMuted)),
                ),
            ],
          ),
        ),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(children: children),
        ),
      ),
    );
  }

  Widget _box({required Color color, required Widget child}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: SoftCard(color: color, padding: const EdgeInsets.fromLTRB(18, 14, 10, 14), child: child),
  );
}

String _blockText(BuildContext context, UpdateBlock block) {
  final l10n = context.l10n;
  return switch (block) {
    UpdateBlock.signedIn => l10n.updateBlockSignedIn,
    UpdateBlock.offline => l10n.updateBlockOffline,
    UpdateBlock.pendingUploads => l10n.updateBlockPending,
    UpdateBlock.failedUploads => l10n.updateBlockFailed,
    UpdateBlock.serverMissing => l10n.updateBlockServerMissing,
    UpdateBlock.download => l10n.updateBlockDownload,
    UpdateBlock.backup => l10n.updateBlockBackup,
  };
}

/// Cashier screens: a thin line saying an update is ready and installs from the sign-in screen.
class UpdateReadyStrip extends StatelessWidget {
  const UpdateReadyStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final version = context.select<CafeStore, String?>((store) => store.updateReady ? store.updateRelease?.version : null);
    if (version == null) return const SizedBox.shrink();
    return Material(
      color: CafeColors.peach,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 16, 6),
        child: Row(
          children: [
            const Icon(Icons.new_releases_outlined, size: 16, color: CafeColors.terracotta),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.updateReadyAfterSignOut(version),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CafeColors.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
