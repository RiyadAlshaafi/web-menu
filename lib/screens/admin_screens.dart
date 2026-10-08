import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../l10n/l10n_ext.dart';
import '../models/models.dart';
import '../navigation/app_sections.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/cafe_dialogs.dart';
import '../widgets/cafe_widgets.dart';
import '../widgets/scroll_when_short.dart';
import '../widgets/shell_parts.dart';
import '../widgets/table_qr.dart';
import '../widgets/tawla_ui.dart';

export 'admin_menu_layout_screen.dart';
export 'admin_catalog_screens.dart';
export 'admin_dashboard_screen.dart';
export 'admin_wages_screen.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final section = AppSections.forAdmin(location);
    final width = MediaQuery.sizeOf(context).width;
    final drawer = AppSections.useDrawer(width);
    final compact = AppSections.compact(width) && !drawer;
    final railWidth = drawer ? 270.0 : (AppSections.compact(width) ? 76.0 : 232.0);

    final surfaces = CafeSurfaces.of(context);
    final rail = Material(
            color: surfaces.sidebar,
            child: SizedBox(
              width: railWidth,
              // In a short window the menu scrolls instead of cutting off its last entries.
              child: ScrollWhenShort(
                minHeight: 640,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(compact ? 8 : 14, 20, compact ? 8 : 14, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!compact)
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 8, 12),
                          child: Text(
                            context.l10n.adminConsoleLabel,
                            style: const TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w800, color: Color(0xFF56606A)),
                          ),
                        ),
                      for (final item in AppSections.admin)
                        ShellNavItem(section: item, active: item.matches(location), compact: compact),
                      const Spacer(),
                      ShellProfileCard(
                        initials: _initials(store.admin?.email),
                        name: store.admin?.displayName == 'Admin'
                            ? (store.admin?.email.split('@').first ?? context.l10n.adminDefaultName)
                            : (store.admin?.displayName ?? context.l10n.adminDefaultName),
                        subtitle: context.l10n.adminGeneralManager,
                        compact: compact,
                        onLogOut: () {
                          store.signOut();
                          context.go('/login');
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
    return ShellFrame(
      drawer: drawer,
      drawerWidth: 260,
      rail: rail,
      header: AppHeader(
        title: section.crumb(context),
        showMenu: drawer,
        actions: [
          HeaderAction(
            icon: Icons.smartphone_outlined,
            label: drawer ? null : context.l10n.adminCustomerView,
            tooltip: drawer ? context.l10n.adminCustomerView : null,
            onPressed: () {
              if (store.activeTables.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.noTables)));
                return;
              }
              context.go('/t/${store.activeTables.first.qrSlug}');
            },
          ),
        ],
      ),
      // A short or narrow window scrolls the page instead of cutting its bottom off.
      body: ScrollWhenShort(minHeightOf: (c) => c.maxWidth < 900 ? 900 : 620, child: child),
    );
  }

  String _initials(String? email) {
    final value = (email ?? 'AD').trim();
    if (value.contains('@')) {
      final name = value.split('@').first;
      return name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
    }
    return value.length >= 2 ? value.substring(0, 2).toUpperCase() : 'AD';
  }
}

class AdminTablesScreen extends StatefulWidget {
  const AdminTablesScreen({super.key});

  @override
  State<AdminTablesScreen> createState() => _AdminTablesScreenState();
}

class _AdminTablesScreenState extends State<AdminTablesScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final filtered = store.activeTables.where((table) {
      if (query.isEmpty) return true;
      return table.number.toLowerCase().contains(query.toLowerCase()) || table.zone.toLowerCase().contains(query.toLowerCase());
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: PageSearchField(hint: context.l10n.adminSearchTableHint, onChanged: (value) => setState(() => query = value))),
              const SizedBox(width: 10),
              OutlineAction(
                label: context.l10n.adminRegenerateAllQr,
                height: 52,
                onPressed: store.activeTables.isEmpty ? null : () => _confirmRegenerate(context, store),
              ),
              const SizedBox(width: 10),
              TerracottaButton(
                expanded: false,
                label: context.l10n.adminAddTableButton,
                onPressed: () => _addTable(context, store),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: store.activeTables.isEmpty
                ? TawlaPanel(child: EmptyHint(context.l10n.noTables))
                : LayoutBuilder(
                    builder: (context, constraints) => GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: (constraints.maxWidth / 270).floor().clamp(1, 4),
                        mainAxisExtent: 284,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) => _tableCard(context, store, filtered[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tableCard(BuildContext context, CafeStore store, CafeTable item) {
    final url = store.guestLink(item.qrSlug);
    final free = item.status == TableStatus.free;
    return TawlaPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.adminTableNumber(item.number),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CafeColors.ink),
                ),
              ),
              _statusPill(free ? context.l10n.adminTableAvailable : context.l10n.adminTableOccupied, free),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 106,
                height: 106,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: TawlaTokens.hairline)),
                child: url.isEmpty
                    ? const Icon(Icons.qr_code_2, color: CafeColors.inkMuted, size: 48)
                    : QrImageView(data: url, padding: EdgeInsets.zero, backgroundColor: Colors.white, semanticsLabel: context.l10n.adminTableNumber(item.number)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.adminScanToOrderPay, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: CafeColors.ink)),
                    const SizedBox(height: 4),
                    Text(context.l10n.adminNoAppInstall, style: const TextStyle(fontSize: 12, color: TawlaTokens.muted)),
                    const SizedBox(height: 2),
                    Text('/t/${item.qrSlug}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: TawlaTokens.muted)),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          NavyButton(
            label: context.l10n.adminPrintStandCard,
            expanded: true,
            onPressed: url.isEmpty
                ? null
                : () async {
                    final error = await printTableQr(url: url, tableNumber: item.number, cafeName: store.cafeName);
                    if (error != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                    }
                  },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Flexible(
                child: OutlineAction(
                  label: context.l10n.adminRegenerateQr,
                  height: 44,
                  onPressed: () => _confirmRegenerate(context, store, table: item),
                ),
              ),
              const SizedBox(width: 8),
              IconAction(
                icon: Icons.download_outlined,
                tooltip: 'Save PNG',
                size: 44,
                onPressed: url.isEmpty
                    ? null
                    : () async {
                        final error = await saveTableQr(url: url, tableNumber: item.number);
                        if (error != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                        }
                      },
              ),
              const SizedBox(width: 8),
              IconAction(
                icon: Icons.delete_outline,
                tooltip: context.l10n.commonDelete,
                danger: true,
                size: 44,
                onPressed: () => _confirmDelete(context, store, item),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String label, bool free) {
    final fg = free ? const Color(0xFF2F5228) : CafeColors.terracottaDark;
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: free ? const Color(0xFFE4EEDF) : const Color(0xFFFBE7DD), borderRadius: BorderRadius.circular(13)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: free ? CafeColors.success : CafeColors.terracotta, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }

  Future<void> _addTable(BuildContext context, CafeStore store) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: CafeColors.paper,
        title: Text(context.l10n.adminAddTableTitle),
        content: TextField(controller: controller, decoration: InputDecoration(labelText: context.l10n.adminTableNumberLabel)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.commonCancel)),
          TerracottaButton(
            expanded: false,
            label: context.l10n.adminCreate,
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              await store.addTable(controller.text);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  /// Replacing a QR code invalidates the printed one, so ask first.
  Future<void> _confirmRegenerate(BuildContext context, CafeStore store, {CafeTable? table}) async {
    final ok = await showCafeConfirmDialog(
      context,
      title: context.l10n.adminRegenerateConfirmTitle,
      message: table == null ? context.l10n.adminRegenerateAllConfirmMessage : context.l10n.adminRegenerateConfirmMessage,
      confirm: context.l10n.adminRegenerateConfirm,
    );
    if (!ok) return;
    if (table == null) {
      await store.regenerateAllTableQrs();
    } else {
      await store.regenerateTableQr(table.id);
    }
  }

  Future<void> _confirmDelete(BuildContext context, CafeStore store, CafeTable table) async {
    if (store.tableHasOpenOrder(table.id)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.adminDeleteTableBusy)));
      return;
    }
    final ok = await showCafeConfirmDialog(
      context,
      title: context.l10n.adminDeleteTableTitle,
      message: context.l10n.adminDeleteTableMessage,
      confirm: context.l10n.adminDeleteTableConfirm,
    );
    if (ok) await store.deleteTable(table.id);
  }
}


