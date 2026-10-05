part of '../cashier_screens.dart';

class QuickTakeoutScreen extends StatefulWidget {
  const QuickTakeoutScreen({super.key});

  @override
  State<QuickTakeoutScreen> createState() => _QuickTakeoutScreenState();
}

class _QuickTakeoutScreenState extends State<QuickTakeoutScreen> {
  final search = TextEditingController();
  final lines = <OrderLine>[];
  String? categoryId;
  String? paymentTypeId;
  var paying = false;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  double get total => lines.fold<double>(0, (sum, line) => sum + line.total);

  void _add(CafeStore store, MenuItem item) {
    if (item.soldOut || !item.available) return;
    final existing = lines.where((line) => line.menuItemId == item.id);
    setState(() {
      if (existing.isEmpty) {
        lines.add(
          OrderLine(
            menuItemId: item.id,
            name: item.displayName(store.locale),
            qty: 1,
            unitPrice: item.salePrice,
            listUnitPrice: item.price,
          ),
        );
      } else {
        existing.first.qty += 1;
      }
    });
  }

  Future<void> _pay(CafeStore store) async {
    if (paying || lines.isEmpty) return;
    setState(() => paying = true);
    final error = await store.checkoutTakeout(
      lines: [
        for (final line in lines)
          OrderLine(
            menuItemId: line.menuItemId,
            name: line.name,
            qty: line.qty,
            unitPrice: line.unitPrice,
            listUnitPrice: line.listUnitPrice,
          ),
      ],
      paymentTypeId: paymentTypeId ?? (store.enabledPaymentTypes.isEmpty ? null : store.enabledPaymentTypes.first.id),
    );
    if (!mounted) return;
    setState(() => paying = false);
    if (error != null) {
      final message = switch (error) {
        'takeout_table' => context.l10n.quickTakeoutNeedTable,
        'in_flight' => context.l10n.quickTakeoutBusy,
        _ => error,
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    setState(lines.clear);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.quickTakeoutPaid)));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final needle = search.text.trim().toLowerCase();
    final categories = store.categories.where((item) => item.visible).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final dishes = store.menuItems.where((item) {
      if (categoryId != null && item.categoryId != categoryId) return false;
      if (needle.isEmpty) return true;
      return item.displayName(store.locale).toLowerCase().contains(needle) ||
          item.description.toLowerCase().contains(needle);
    }).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final button = CafeSurfaces.of(context).button;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.navQuickTakeout, style: CafeTheme.display.copyWith(fontSize: 28)),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 980;
                final catalog = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: search,
                      decoration: InputDecoration(
                        hintText: context.l10n.quickTakeoutSearch,
                        prefixIcon: const Icon(Icons.search),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _pill(context.l10n.quickTakeoutAll, categoryId == null, button, () => setState(() => categoryId = null)),
                          for (final category in categories) ...[
                            const SizedBox(width: 8),
                            _pill(
                              category.label(store.locale),
                              categoryId == category.id,
                              button,
                              () => setState(() => categoryId = category.id),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 240,
                          mainAxisExtent: 168,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: dishes.length,
                        itemBuilder: (context, index) {
                          final item = dishes[index];
                          return SoftCard(
                            radius: 16,
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.displayName(store.locale),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                  ),
                                ),
                                Text(
                                  item.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      store.currency.format(item.salePrice),
                                      style: TextStyle(color: button, fontWeight: FontWeight.w800, fontSize: 16),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      tooltip: context.l10n.quickTakeoutPay,
                                      onPressed: item.available && !item.soldOut ? () => _add(store, item) : null,
                                      icon: Icon(Icons.add, color: button),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
                final ticket = SoftCard(
                  radius: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(context.l10n.navQuickTakeout, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: button.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              context.l10n.serviceTakeout,
                              style: TextStyle(color: button, fontWeight: FontWeight.w800, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: lines.isEmpty
                            ? EmptyHint(context.l10n.quickTakeoutEmpty)
                            : ListView(
                                children: [
                                  for (final line in lines)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      child: Row(
                                        children: [
                                          Expanded(child: Text(line.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                          IconButton(
                                            onPressed: () => setState(() {
                                              line.qty -= 1;
                                              if (line.qty <= 0) lines.remove(line);
                                            }),
                                            icon: const Icon(Icons.remove, size: 18),
                                          ),
                                          Text('${line.qty}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                          IconButton(
                                            onPressed: () => setState(() => line.qty += 1),
                                            icon: const Icon(Icons.add, size: 18),
                                          ),
                                          SizedBox(
                                            width: 72,
                                            child: Text(store.currency.format(line.total), textAlign: TextAlign.right),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: paymentTypeId ?? (store.enabledPaymentTypes.isEmpty ? null : store.enabledPaymentTypes.first.id),
                        decoration: InputDecoration(labelText: context.l10n.expenseType),
                        items: [
                          for (final type in store.enabledPaymentTypes)
                            DropdownMenuItem(value: type.id, child: Text(type.label(store.locale))),
                        ],
                        onChanged: paying ? null : (value) => setState(() => paymentTypeId = value),
                      ),
                      const SizedBox(height: 8),
                      Text(store.currency.format(total), style: CafeTheme.display.copyWith(fontSize: 24)),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: lines.isEmpty || paying ? null : () => _pay(store),
                        child: Text(context.l10n.quickTakeoutPay),
                      ),
                    ],
                  ),
                );
                if (stacked) {
                  return Column(
                    children: [
                      Expanded(flex: 3, child: catalog),
                      const SizedBox(height: 12),
                      Expanded(flex: 2, child: ticket),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 8, child: catalog),
                    const SizedBox(width: 16),
                    Expanded(flex: 4, child: ticket),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, bool selected, Color button, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? button : CafeColors.paper,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? button : CafeColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(color: selected ? Colors.white : CafeColors.ink, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
