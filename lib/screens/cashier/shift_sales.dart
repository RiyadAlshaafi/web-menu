part of '../cashier_screens.dart';

class CashierShiftsScreen extends StatefulWidget {
  const CashierShiftsScreen({super.key});

  @override
  State<CashierShiftsScreen> createState() => _CashierShiftsScreenState();
}

class _CashierShiftsScreenState extends State<CashierShiftsScreen> {
  final counted = TextEditingController();

  @override
  void dispose() {
    counted.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final shift = store.currentShift ?? store.openShift;
    final sales = shift?.cashSales ?? 0;
    final txs = shift?.transactionCount ?? 0;
    final pending = store.billTables.fold<double>(0, (sum, table) => sum + store.tabTotal(table.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.cashierSoloStationSync, style: const TextStyle(letterSpacing: 0.8, fontSize: 11, fontWeight: FontWeight.w800, color: CafeColors.inkMuted)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(context.l10n.cashierShiftSalesTitle, style: CafeTheme.display.copyWith(fontSize: AppSections.titleSize(MediaQuery.sizeOf(context).width))),
              GhostChip(label: DateFormat('HH:mm:ss').format(DateTime.now()), icon: Icons.schedule),
              const LanguageButton(),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.sim_card_download_outlined, size: 16),
                label: Text(context.l10n.cashierExportSummary),
              ),
              OutlinedButton.icon(
                onPressed: () => _clearShiftLogs(context, store),
                icon: const Icon(Icons.delete_outline, size: 16),
                style: OutlinedButton.styleFrom(foregroundColor: CafeColors.alert, side: const BorderSide(color: CafeColors.alert)),
                label: Text(context.l10n.clearShiftSales),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 900;
              final cards = [
                _mini(context.l10n.cashierTotalShiftGrossSales, store.currency.format(sales), expand: !stacked),
                _mini(
                  context.l10n.cashierSettledOrders,
                  '$txs',
                  detail: txs == 0 ? null : context.l10n.cashierAvgTicket(store.currency.format(sales / txs)),
                  expand: !stacked,
                ),
                _mini(
                  context.l10n.cashierActivePendingBalance,
                  store.currency.format(pending),
                  detail: store.billTables.isEmpty
                      ? null
                      : store.billTables.map((table) => '${context.l10n.cashierTableShort(table.number)} ${store.currency.format(store.tabTotal(table.id))}').join(' • '),
                  expand: !stacked,
                ),
              ];
              if (stacked) {
                return Column(children: [for (final card in cards) Padding(padding: const EdgeInsets.only(bottom: 8), child: card)]);
              }
              return Row(children: cards);
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stack = constraints.maxWidth < 980;
                final ledger = SoftCard(
                    radius: 16,
                    child: store.payments.isEmpty
                        ? EmptyHint(context.l10n.noTransactions)
                        : ListView(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(context.l10n.cashierColOrderTable, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: CafeColors.inkMuted))),
                                    SizedBox(width: 64, child: Text(context.l10n.cashierColTime, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: CafeColors.inkMuted))),
                                    SizedBox(width: 80, child: Text(context.l10n.cashierColAmount, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: CafeColors.inkMuted))),
                                    SizedBox(width: 72, child: Text(context.l10n.cashierColStatus, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: CafeColors.inkMuted))),
                                    SizedBox(width: 88, child: Text(context.l10n.cashierColActions, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: CafeColors.inkMuted))),
                                  ],
                                ),
                              ),
                              ...(() {
                                final rows = [...store.payments]..sort((a, b) => b.paidAt.compareTo(a.paidAt));
                                return rows.map((payment) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${store.saleNumber(payment, perShift: true)}  •  ${store.paymentIsTakeout(payment) ? context.l10n.serviceTakeout : context.l10n.cashierTableShort(store.tableById(payment.tableId).number)}',
                                          style: const TextStyle(fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      SizedBox(width: 64, child: Text(DateFormat.Hm().format(payment.paidAt))),
                                      SizedBox(
                                        width: 80,
                                        child: Text(store.currency.format(payment.totalDue), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800)),
                                      ),
                                      SizedBox(
                                        width: 72,
                                        child: Text(context.l10n.cashierSettled, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: CafeColors.success)),
                                      ),
                                      SizedBox(
                                        width: 88,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton.icon(
                                            onPressed: () => _cashierUnavailable(context),
                                            icon: const Icon(Icons.print_outlined, size: 14),
                                            label: Text(context.l10n.cashierPrintChit, style: const TextStyle(fontSize: 11)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                }).toList();
                              }()),
                              if (store.salesHasMore)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(onPressed: () => store.loadMoreSales(), child: Text(context.l10n.salesLoadMore)),
                                ),
                            ],
                          ),
                );
                final till = SoftCard(
                    radius: 16,
                    child: shift == null
                        ? EmptyHint(context.l10n.errNoOpenShift)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: const BoxDecoration(color: Color(0x1ABA5333), borderRadius: BorderRadius.all(Radius.circular(8))),
                                    child: const Icon(Icons.account_balance_wallet_outlined, color: CafeColors.terracotta, size: 18),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(context.l10n.cashierTillBalance, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                                    child: Text(context.l10n.cashierActive, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF166534))),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: context.l10n.cashierOpeningFloat,
                                  hintText: store.currency.format(shift.openingCash),
                                ),
                                onSubmitted: (value) {
                                  final parsed = double.tryParse(value);
                                  if (parsed != null) store.setOpeningCash(parsed);
                                },
                              ),
                              const SizedBox(height: 10),
                              _row(context.l10n.cashierOpeningFloatRow, store.currency.format(shift.openingCash)),
                              _row(context.l10n.cashierCashCollected, store.currency.format(shift.cashSales)),
                              _row(context.l10n.cashierCardDigitalPayments, store.currency.format(0)),
                              const Divider(),
                              _row(context.l10n.cashierExpectedInDrawer, store.currency.format(shift.expectedCash), strong: true),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: CafeColors.key, borderRadius: BorderRadius.circular(12), border: Border.all(color: CafeColors.line)),
                                child: Text(
                                  context.l10n.cashierToleranceNote,
                                  style: const TextStyle(fontSize: 11, color: CafeColors.inkMuted, height: 1.4),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: counted,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(labelText: context.l10n.cashierActualCashCounted),
                              ),
                              const SizedBox(height: 10),
                              TerracottaButton(
                                label: context.l10n.cashierCloseRegister,
                                onPressed: () async {
                                  final actual = double.tryParse(counted.text) ?? 0;
                                  await store.closeShift(actualCash: actual);
                                  if (context.mounted) {
                                    final diff = actual - shift.expectedCash;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(context.l10n.cashierDifference(store.currency.format(diff)))),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () {},
                                  child: Text(context.l10n.cashierMidShiftChit),
                                ),
                              ),
                            ],
                          ),
                );
                if (stack) {
                  return Column(
                    children: [
                      Expanded(child: ledger),
                      const SizedBox(height: 12),
                      SizedBox(height: (constraints.maxHeight * 0.52).clamp(280, 420), child: till),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: ledger),
                    const SizedBox(width: 12),
                    SizedBox(width: (constraints.maxWidth * 0.34).clamp(260, 360), child: till),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _mini(String label, String value, {String? detail, bool expand = true}) {
    final card = Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SoftCard(
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12)),
            Text(value, style: CafeTheme.display.copyWith(fontSize: 24)),
            if (detail != null) Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12)),
          ],
        ),
      ),
    );
    return expand ? Expanded(child: card) : card;
  }

  Widget _row(String label, String value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: strong ? CafeColors.ink : CafeColors.inkMuted, fontWeight: strong ? FontWeight.w800 : FontWeight.w500)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: strong ? 18 : 13,
              color: strong ? CafeColors.terracotta : CafeColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearShiftLogs(BuildContext context, CafeStore store) async {
    final confirmed = await showCafeConfirmDialog(
      context,
      title: context.l10n.clearShiftSales,
      message: context.l10n.clearShiftSalesConfirm,
    );
    if (!confirmed || !context.mounted) return;
    final error = await store.clearTestLogs('shift');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? context.l10n.clearLogsDone)));
  }
}

