part of '../cashier_screens.dart';

class CashierShiftsScreen extends StatefulWidget {
  const CashierShiftsScreen({super.key});

  @override
  State<CashierShiftsScreen> createState() => _CashierShiftsScreenState();
}

class _CashierShiftsScreenState extends State<CashierShiftsScreen> {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final shift = store.currentShift ?? store.openShift;
    final sales = shift?.cashSales ?? 0;
    final txs = shift?.transactionCount ?? 0;
    final pending = store.billTables.fold<double>(
      0,
      (sum, table) => sum + store.tabTotal(table.id),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 900;
              final cards = [
                _mini(
                  context.l10n.cashierTotalShiftGrossSales,
                  store.currency.format(sales),
                  color: CafeSurfaces.of(context).header,
                  expand: !stacked,
                ),
                _mini(
                  context.l10n.cashierSettledOrders,
                  '$txs',
                  detail: txs == 0
                      ? null
                      : context.l10n.cashierAvgTicket(
                          store.currency.format(sales / txs),
                        ),
                  expand: !stacked,
                ),
                _mini(
                  context.l10n.cashierActivePendingBalance,
                  store.currency.format(pending),
                  color: const Color(0xFF95600F),
                  detail: store.billTables.isEmpty
                      ? null
                      : store.billTables
                            .map(
                              (table) =>
                                  '${context.l10n.cashierTableShort(table.number)} ${store.currency.format(store.tabTotal(table.id))}',
                            )
                            .join(' • '),
                  expand: !stacked,
                ),
              ];
              if (stacked) {
                return Column(
                  children: [
                    for (final card in cards)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: card,
                      ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (var i = 0; i < cards.length; i++) ...[if (i > 0) const SizedBox(width: 14), cards[i]]],
              );
            },
          ),
          const SizedBox(height: 18),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final shiftId = shift?.id;
                final events = <Object>[
                  ...store.payments,
                  ...store.expenses.where((item) => !item.voided && (shiftId == null || item.shiftId == shiftId)),
                ]..sort((a, b) {
                    DateTime at(Object item) => item is Payment ? item.paidAt : (item as ShiftExpense).createdAt;
                    return at(b).compareTo(at(a));
                  });
                final ledger = WideTable(
                  minWidth: 860,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: events.isEmpty
                        ? EmptyHint(context.l10n.noTransactions)
                        : ListView(
                            children: [
                              _ledgerRow(
                                header: true,
                                first: TableHead(context.l10n.cashierColOrderTable),
                                time: TableHead(context.l10n.cashierColTime),
                                method: TableHead(context.l10n.salesColMethod),
                                status: TableHead(context.l10n.cashierColStatus),
                                amount: TableHead(context.l10n.cashierColAmount, align: TextAlign.end),
                                actions: TableHead(context.l10n.cashierColActions, align: TextAlign.end),
                              ),
                              for (final event in events)
                                if (event is ShiftExpense)
                                  _expenseLedgerRow(context, store, event)
                                else
                                  _paymentLedgerRow(context, store, event as Payment),
                              if (store.salesHasMore)
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: TextButton(
                                      onPressed: () => store.loadMoreSales(),
                                      child: Text(context.l10n.salesLoadMore),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                  ),
                );
                final bar = TawlaPanel(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: shift == null ? null : () => _addExpense(context, store),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: CafeColors.terracottaDark,
                            backgroundColor: const Color(0xFFFFF4EF),
                            side: const BorderSide(color: Color(0xFFF3C2B3), width: 1.5),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(context.l10n.cashierAddExpense, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                      ),
                      SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: shift == null ? null : () => _closeRegister(context, store, shift),
                          style: FilledButton.styleFrom(
                            backgroundColor: CafeSurfaces.of(context).button,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.lock_outline, size: 18),
                          label: Text(context.l10n.cashierCloseRegister, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: ledger),
                    const SizedBox(height: 12),
                    bar,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _mini(
    String label,
    String value, {
    String? detail,
    Color? color,
    bool expand = true,
  }) {
    final card = FigureCard(label: label, value: value, caption: detail, valueColor: color ?? CafeColors.ink);
    return expand ? Expanded(child: card) : card;
  }

  /// One line of the shift ledger; the header uses the same column widths.
  Widget _ledgerRow({
    bool header = false,
    Color? background,
    required Widget first,
    required Widget time,
    required Widget method,
    required Widget status,
    required Widget amount,
    required Widget actions,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: header ? 14 : 10),
      decoration: BoxDecoration(
        color: background,
        border: const Border(bottom: BorderSide(color: TawlaTokens.hairline)),
      ),
      child: Row(
        children: [
          Expanded(child: first),
          SizedBox(width: 90, child: time),
          SizedBox(width: 120, child: Align(alignment: AlignmentDirectional.centerStart, child: method)),
          SizedBox(width: 110, child: Align(alignment: AlignmentDirectional.centerStart, child: status)),
          SizedBox(width: 120, child: amount),
          SizedBox(width: 150, child: Align(alignment: AlignmentDirectional.centerEnd, child: actions)),
        ],
      ),
    );
  }

  Widget _twoLines(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: TawlaTokens.muted, fontSize: 12)),
      ],
    );
  }

  Widget _paymentLedgerRow(BuildContext context, CafeStore store, Payment payment) {
    final place = payment.isTakeout || store.paymentIsTakeout(payment) ? context.l10n.serviceTakeout : context.l10n.cashierTableNumber(payment.tableNumber);
    return _ledgerRow(
      first: _twoLines(
        context.l10n.salesReceiptLine(store.receiptNumber(payment)),
        '$place  ·  ${context.l10n.cashierOrderNumber(store.orderNumber(payment.shiftOrderNumber))}',
      ),
      time: Text(formatTripoliTime(payment.paidAt), style: const TextStyle(fontSize: 14)),
      method: StatusBadge(store.typeName(payment.paymentTypeId), tone: BadgeTone.navy),
      status: StatusBadge(context.l10n.cashierSettled, tone: BadgeTone.success, dot: true),
      amount: Text(
        store.currency.format(payment.totalDue),
        textAlign: TextAlign.end,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      ),
      actions: OutlinedButton.icon(
        style: _rowActionStyle,
        onPressed: () {
          final host = context;
          showReceiptPrint(store, payment, host.l10n).catchError((error) {
            if (!host.mounted) return;
            ScaffoldMessenger.of(host).showSnackBar(SnackBar(content: Text(host.l10n.receiptPrintFailed)));
          });
        },
        icon: const Icon(Icons.print_outlined, size: 16),
        label: Text(context.l10n.cashierPrintChit, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _expenseLedgerRow(
    BuildContext context,
    CafeStore store,
    ShiftExpense expense,
  ) {
    final open = store.currentShift ?? store.openShift;
    final mine = store.currentCashier?.id == expense.cashierId;
    final canEdit = mine &&
        open != null &&
        open.isOpen &&
        open.id == expense.shiftId &&
        !expense.voided;
    return _ledgerRow(
      background: CafeColors.card,
      first: _twoLines(
        store.expenseCategoryLabel(expense),
        [expense.shortId, if (expense.description.isNotEmpty) expense.description].join('  ·  '),
      ),
      time: Text(formatTripoliTime(expense.createdAt), style: const TextStyle(fontSize: 14)),
      method: StatusBadge(context.l10n.cashierCashOut, tone: BadgeTone.terracotta),
      status: _expenseStatusPill(
        context,
        label: expense.editedFrom == null ? context.l10n.expenseLogged : context.l10n.expenseEdited,
        edited: expense.editedFrom != null,
        onTap: expense.editedFrom == null ? null : () => _showOriginal(context, store, expense),
      ),
      amount: Text(
        store.currency.format(-expense.amount),
        textAlign: TextAlign.end,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: CafeColors.alert),
      ),
      actions: canEdit
          ? OutlinedButton.icon(
              style: _rowActionStyle,
              onPressed: () => _addExpense(context, store, editing: expense),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text(context.l10n.expenseEdit, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _expenseStatusPill(
    BuildContext context, {
    required String label,
    required bool edited,
    VoidCallback? onTap,
  }) {
    final pill = StatusBadge(label, tone: edited ? BadgeTone.danger : BadgeTone.navy, dot: true);
    if (onTap == null) return pill;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: pill);
  }

  void _showOriginal(BuildContext context, CafeStore store, ShiftExpense expense) {
    final prior = store.expenses.where((item) => item.id == expense.editedFrom);
    final original = prior.isEmpty ? null : prior.first;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.expenseOriginal),
        content: Text(
          original == null
              ? context.l10n.expenseOriginalMissing
              : '${original.shortId}\n${original.description}\n${store.currency.format(-original.amount)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonCancel),
          ),
        ],
      ),
    );
  }

  Future<void> _addExpense(
    BuildContext context,
    CafeStore store, {
    ShiftExpense? editing,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x99000000),
      builder: (context) => _ExpenseDialog(store: store, editing: editing),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.cashierExpenseSaved)));
    }
  }

  Future<void> _closeRegister(
    BuildContext context,
    CafeStore store,
    CashShift shift,
  ) async {
    final counted = TextEditingController();
    final actual = await showDialog<double>(
      context: context,
      barrierColor: const Color(0x99000000),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.cashierCloseRegister,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: counted,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: context.l10n.cashierActualCashCounted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(context.l10n.commonCancel),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.pop(
                          context,
                          double.tryParse(counted.text.trim()) ?? 0,
                        ),
                        child: Text(context.l10n.cashierCloseRegister),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    counted.dispose();
    if (actual == null || !context.mounted) return;
    final expected = store.expectedDrawer(shift);
    final error = await store.closeShift(actualCash: actual);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ??
              context.l10n.cashierDifference(
                store.currency.format(actual - expected),
              ),
        ),
      ),
    );
  }

}

class _ExpenseDialog extends StatefulWidget {
  const _ExpenseDialog({required this.store, this.editing});

  final CafeStore store;
  final ShiftExpense? editing;

  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  late final amount = TextEditingController(
    text: widget.editing == null ? '' : widget.editing!.amount.toString(),
  );
  late final description = TextEditingController(
    text: widget.editing?.description ?? '',
  );
  late String? categoryId = _initialCategoryId();

  String? _initialCategoryId() {
    final editing = widget.editing;
    if (editing == null) return null;
    if (editing.categoryId != null) return editing.categoryId;
    final name = editing.paidToCafe ? 'Café Expense' : 'Cash Withdrawal';
    final match = widget.store.expenseCategories.where((item) => item.nameEn == name);
    return match.isEmpty ? null : match.first.id;
  }
  var saving = false;
  String? error;

  @override
  void dispose() {
    amount.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (saving) return;
    final parsed = double.tryParse(amount.text.trim().replaceAll(',', '.'));
    if (categoryId == null ||
        parsed == null ||
        parsed <= 0 ||
        description.text.trim().isEmpty) {
      setState(() => error = context.l10n.cashierExpenseInvalid);
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final editing = widget.editing;
    final failure = editing == null
        ? await widget.store.addShiftExpense(
            categoryId: categoryId!,
            amount: parsed,
            description: description.text,
          )
        : await widget.store.editShiftExpense(
            expense: editing,
            categoryId: categoryId!,
            amount: parsed,
            description: description.text,
          );
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        saving = false;
        error = failure;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.editing == null
                    ? context.l10n.cashierAddExpense
                    : context.l10n.expenseEdit,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: categoryId,
                decoration: InputDecoration(
                  labelText: context.l10n.expenseType,
                ),
                items: [
                  for (final category in widget.store.expenseCategories.where((item) => item.enabled || item.id == categoryId).toList()
                    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)))
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.label(widget.store.locale)),
                    ),
                ],
                onChanged: saving
                    ? null
                    : (value) => setState(() => categoryId = value),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amount,
                enabled: !saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: context.l10n.cashierExpenseAmount,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: description,
                enabled: !saving,
                decoration: InputDecoration(
                  labelText: context.l10n.cashierExpenseDescription,
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error!,
                  style: const TextStyle(color: CafeColors.alert, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.pop(context, false),
                    child: Text(context.l10n.commonCancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: saving ? null : _save,
                    child: Text(context.l10n.cashierExpenseAdd),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final _rowActionStyle = OutlinedButton.styleFrom(
  foregroundColor: CafeColors.ink,
  minimumSize: const Size(0, 40),
  padding: const EdgeInsets.symmetric(horizontal: 12),
  side: const BorderSide(color: Color(0xFFE3DED5), width: 1.5),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
);
