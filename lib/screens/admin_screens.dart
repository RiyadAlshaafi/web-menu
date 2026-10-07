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
import '../widgets/table_qr.dart';

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
    final railWidth = drawer ? 260.0 : (AppSections.compact(width) ? 76.0 : 220.0);

    final surfaces = CafeSurfaces.of(context);
    final rail = Material(
            color: surfaces.sidebar,
            child: SizedBox(
              width: railWidth,
              // In a short window the menu scrolls instead of cutting off its last entries.
              child: ScrollWhenShort(
                minHeight: 640,
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(compact ? 12 : 18, 22, compact ? 12 : 16, 18),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: CafeColors.terracotta,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Icon(section.icon, color: Colors.white, size: 22),
                        ),
                        if (!compact) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  store.cafeName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: surfaces.onSidebar),
                                ),
                                Text(
                                  context.l10n.adminConsoleLabel,
                                  style: const TextStyle(fontSize: 10, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: CafeColors.inkMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!compact)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 8, 16, 10),
                      child: Text(
                        context.l10n.adminManagementHeading,
                        style: const TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w700, color: CafeColors.inkMuted),
                      ),
                    ),
                  for (final item in AppSections.admin)
                    _nav(context, item, item.matches(location), compact),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 12, 16),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFCF8),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: CafeColors.line),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: CafeColors.peach,
                            child: Text(
                              _initials(store.admin?.email),
                              style: const TextStyle(color: CafeColors.terracottaDark, fontWeight: FontWeight.w800, fontSize: 12),
                            ),
                          ),
                          if (!compact) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    store.admin?.displayName == 'Admin'
                                        ? (store.admin?.email.split('@').first ?? context.l10n.adminDefaultName)
                                        : (store.admin?.displayName ?? context.l10n.adminDefaultName),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                  ),
                                  Text(context.l10n.adminGeneralManager, style: const TextStyle(fontSize: 10, color: CafeColors.inkMuted)),
                                ],
                              ),
                            ),
                          ],
                          IconButton(
                            onPressed: () {
                              store.signOut();
                              context.go('/login');
                            },
                            icon: const Icon(Icons.logout, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              ),
            ),
          );
    return Scaffold(
      backgroundColor: surfaces.background,
      drawer: drawer ? Drawer(width: 260, child: rail) : null,
      body: Row(
        children: [
          if (!drawer) rail,
          Expanded(
            child: Column(
              children: [
                AppHeader(
                  title: '${context.l10n.adminWorkspace}  /  ${section.crumb(context)}',
                  showMenu: drawer,
                  actions: [
                    if (!drawer)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F0E4),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(context.l10n.adminTerminalBadge, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4F7A45))),
                      ),
                    OutlinedButton.icon(
                      onPressed: () {
                        if (store.activeTables.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.noTables)));
                          return;
                        }
                        context.go('/t/${store.activeTables.first.qrSlug}');
                      },
                      icon: const Icon(Icons.visibility_outlined, size: 16, color: CafeColors.terracotta),
                      label: drawer
                          ? const SizedBox.shrink()
                          : Text(context.l10n.adminCustomerView, style: const TextStyle(color: CafeColors.ink, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: CafeColors.line),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: ColoredBox(
                    color: surfaces.background,
                    // A short or narrow window scrolls the page instead of cutting its bottom off.
                    child: ScrollWhenShort(minHeightOf: (c) => c.maxWidth < 900 ? 900 : 620, child: child),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

  Widget _nav(BuildContext context, AppSection section, bool active, bool compact) {
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 10 : 12, 0, compact ? 10 : 12, 8),
      child: Material(
        color: active ? CafeSurfaces.of(context).button : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => context.go(section.path),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.fromLTRB(compact ? 10 : 14, 12, compact ? 10 : 12, 12),
            child: Row(
              children: [
                Icon(section.icon, color: active ? CafeSurfaces.of(context).onButton : CafeColors.inkMuted, size: 18),
                if (!compact) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      section.label(context),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        color: active ? CafeSurfaces.of(context).onButton : CafeColors.ink,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminTablesScreen extends StatefulWidget {
  const AdminTablesScreen({super.key});

  @override
  State<AdminTablesScreen> createState() => _AdminTablesScreenState();
}

class _AdminTablesScreenState extends State<AdminTablesScreen> {
  String query = '';
  String? selectedId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final filtered = store.activeTables.where((table) {
      if (query.isEmpty) return true;
      return table.number.toLowerCase().contains(query.toLowerCase());
    }).toList();
    selectedId ??= filtered.isEmpty ? null : filtered.first.id;
    final selected = store.activeTables.where((table) => table.id == selectedId);
    final table = selected.isEmpty ? null : selected.first;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.adminFloorOrderingHeading, style: const TextStyle(letterSpacing: 1.2, fontSize: 11, fontWeight: FontWeight.w800, color: CafeColors.inkMuted)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(context.l10n.adminTablesQrHub, style: CafeTheme.display.copyWith(fontSize: AppSections.titleSize(MediaQuery.sizeOf(context).width))),
              _miniStat('${store.diningTables.length}', context.l10n.adminStations),
              _miniStat('${store.diningTables.where((item) => item.status != TableStatus.free).length}', context.l10n.adminSessions),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(hintText: context.l10n.adminSearchTableHint, prefixIcon: const Icon(Icons.search)),
                  onChanged: (value) => setState(() => query = value),
                ),
              ),
              const SizedBox(width: 12),
              TerracottaButton(
                expanded: false,
                label: context.l10n.adminAddTableButton,
                onPressed: () => _addTable(context, store),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: store.activeTables.isEmpty ? null : () => _confirmRegenerate(context, store),
                child: Text(context.l10n.adminRegenerateAllQr),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: store.activeTables.isEmpty
                ? SoftCard(child: EmptyHint(context.l10n.noTables))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final stackInspector = constraints.maxWidth < 980;
                      final grid = GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: AppSections.columnsFor(constraints.maxWidth, max: 2),
                          childAspectRatio: stackInspector ? 1.05 : 1.15,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final url = store.guestLink(item.qrSlug);
                          final selected = item.id == selectedId;
                          return SoftCard(
                            selected: selected,
                            onTap: () => setState(() => selectedId = item.id),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        context.l10n.adminTableNumber(item.number),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: selected ? CafeSurfaces.of(context).button : CafeColors.ink,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(item.status == TableStatus.free ? context.l10n.adminTableAvailable : context.l10n.adminTableOccupied, style: const TextStyle(fontSize: 12, color: CafeColors.success)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Center(
                                    child: url.isEmpty
                                        ? const Icon(Icons.qr_code_2, color: CafeColors.inkMuted)
                                        : QrImageView(data: url, size: constraints.maxWidth < 600 ? 80 : 110, backgroundColor: Colors.white),
                                  ),
                                ),
                                Text('/t/${item.qrSlug}', style: const TextStyle(fontSize: 11, color: CafeColors.inkMuted)),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () => _confirmDelete(context, store, item),
                                    child: Text(context.l10n.commonDelete, style: const TextStyle(color: CafeColors.alert)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                      final inspector = SoftCard(
                        child: table == null
                            ? EmptyHint(context.l10n.noTables)
                            : Column(
                                children: [
                                  Text(context.l10n.adminTableNumber(table.number), style: CafeTheme.display.copyWith(fontSize: 28)),
                                  const SizedBox(height: 8),
                                  Flexible(
                                    child: store.guestLink(table.qrSlug).isEmpty
                                        ? const Icon(Icons.qr_code_2, size: 72, color: CafeColors.inkMuted)
                                        : QrImageView(data: store.guestLink(table.qrSlug), size: 180, backgroundColor: Colors.white),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(context.l10n.adminScanToOrderPay, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(
                                    context.l10n.adminNoAppInstall,
                                    style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                  const Spacer(),
                                  SelectableText(store.guestLink(table.qrSlug), style: const TextStyle(fontSize: 12)),
                                  const SizedBox(height: 8),
                                  TerracottaButton(
                                    label: context.l10n.adminPrintStandCard,
                                    onPressed: store.guestLink(table.qrSlug).isEmpty
                                        ? null
                                        : () async {
                                            final error = await printTableQr(
                                              url: store.guestLink(table.qrSlug),
                                              tableNumber: table.number,
                                              cafeName: store.cafeName,
                                            );
                                            if (error != null && context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                                            }
                                          },
                                  ),
                                  TextButton(
                                    onPressed: store.guestLink(table.qrSlug).isEmpty
                                        ? null
                                        : () async {
                                            final error = await saveTableQr(url: store.guestLink(table.qrSlug), tableNumber: table.number);
                                            if (error != null && context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                                            }
                                          },
                                    child: const Text('Save PNG'),
                                  ),
                                  TextButton(
                                    onPressed: () => _confirmRegenerate(context, store, table: table),
                                    child: Text(context.l10n.adminRegenerateQr),
                                  ),
                                ],
                              ),
                      );
                      if (stackInspector) {
                        return Column(
                          children: [
                            Expanded(flex: 3, child: grid),
                            const SizedBox(height: 12),
                            SizedBox(height: 280, child: inspector),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: grid),
                          const SizedBox(width: 12),
                          SizedBox(width: (constraints.maxWidth * 0.32).clamp(260, 360), child: inspector),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CafeColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(fontSize: 11, color: CafeColors.inkMuted)),
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


