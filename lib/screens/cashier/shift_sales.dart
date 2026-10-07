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
          Text(
            context.l10n.cashierSoloStationSync,
            style: const TextStyle(
              letterSpacing: 0.8,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: CafeColors.inkMuted,
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                context.l10n.cashierShiftSalesTitle,
                style: CafeTheme.display.copyWith(
                  fontSize: AppSections.titleSize(
                    MediaQuery.sizeOf(context).width,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 900;
              final cards = [
                _mini(
                  context.l10n.cashierTotalShiftGrossSales,
                  store.currency.format(sales),
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
              return Row(children: cards);
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stack = constraints.maxWidth < 980;
                final ledger = WideTable(
                  minWidth: 760,
                  child: SoftCard(
                  radius: 16,
                  child: store.payments.isEmpty &&
                          (shift == null ||
                              store.expenses.every(
                                (item) => item.voided || item.shiftId != shift.id,
                              ))
                      ? EmptyHint(context.l10n.noTransactions)
                      : ListView(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      context.l10n.cashierColOrderTable,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        color: CafeColors.inkMuted,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 64,
                                    child: Text(
                                      context.l10n.cashierColTime,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        color: CafeColors.inkMuted,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      context.l10n.cashierColAmount,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        color: CafeColors.inkMuted,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 72,
                                    child: Text(
                                      context.l10n.cashierColStatus,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        color: CafeColors.inkMuted,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 88,
                                    child: Text(
                                      context.l10n.cashierColActions,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        color: CafeColors.inkMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...(() {
                              final shiftId = shift?.id;
                              final events = <Object>[
                                ...store.payments,
                                ...store.expenses.where(
                                  (item) =>
                                      !item.voided &&
                                      (shiftId == null || item.shiftId == shiftId),
                                ),
                              ]..sort((a, b) {
                                  DateTime at(Object item) => item is Payment
                                      ? item.paidAt
                                      : (item as ShiftExpense).createdAt;
                                  return at(b).compareTo(at(a));
                                });
                              return events.map((event) {
                                if (event is ShiftExpense) {
                                  return _expenseLedgerRow(context, store, event);
                                }
                                final payment = event as Payment;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text.rich(
                                          TextSpan(
                                            children: [
                                              TextSpan(
                                                text: store.receiptNumber(
                                                  payment,
                                                ),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              TextSpan(
                                                text:
                                                    '  ·  ${context.l10n.cashierOrderNumber(store.orderNumber(payment.shiftOrderNumber))}',
                                                style: const TextStyle(
                                                  color: CafeColors.inkMuted,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              TextSpan(
                                                text:
                                                    '  •  ${payment.isTakeout || store.paymentIsTakeout(payment) ? context.l10n.serviceTakeout : context.l10n.cashierTableShort(payment.tableNumber)}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 64,
                                        child: Text(
                                          formatTripoliTime(payment.paidAt),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 80,
                                        child: Text(
                                          store.currency.format(
                                            payment.totalDue,
                                          ),
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 72,
                                        child: Text(
                                          context.l10n.cashierSettled,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            color: CafeColors.success,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 88,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton.icon(
                                            onPressed: () {
                                              final host = context;
                                              showReceiptPrint(store, payment, host.l10n).catchError((error) {
                                                if (!host.mounted) return;
                                                ScaffoldMessenger.of(host).showSnackBar(SnackBar(content: Text(host.l10n.receiptPrintFailed)));
                                              });
                                            },
                                            icon: const Icon(
                                              Icons.print_outlined,
                                              size: 14,
                                            ),
                                            label: Text(
                                              context.l10n.cashierPrintChit,
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
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
                                child: TextButton(
                                  onPressed: () => store.loadMoreSales(),
                                  child: Text(context.l10n.salesLoadMore),
                                ),
                              ),
                          ],
                        ),
                  ),
                );
                final till = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TerracottaButton(
                      label: context.l10n.cashierAddExpense,
                      onPressed: shift == null
                          ? null
                          : () => _addExpense(context, store),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: shift == null
                          ? null
                          : () => _closeRegister(context, store, shift),
                      child: Text(context.l10n.cashierCloseRegister),
                    ),
                  ],
                );
                if (stack) {
                  return Column(
                    children: [
                      Expanded(child: ledger),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: (constraints.maxHeight * 0.52).clamp(280, 420),
                        child: till,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: ledger),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: (constraints.maxWidth * 0.34).clamp(260, 360),
                      child: till,
                    ),
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
    bool expand = true,
  }) {
    final card = Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SoftCard(
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12),
            ),
            Text(value, style: CafeTheme.display.copyWith(fontSize: 24)),
            if (detail != null)
              Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: CafeColors.inkMuted,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
    return expand ? Expanded(child: card) : card;
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: expense.shortId,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(
                        text: '  ${expense.description}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(
                        text:
                            '  •  ${store.expenseCategoryLabel(expense)}',
                        style: const TextStyle(
                          color: CafeColors.inkMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(formatTripoliTime(expense.createdAt)),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  store.currency.format(-expense.amount),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: CafeColors.alert,
                  ),
                ),
              ),
              SizedBox(
                width: 72,
                child: Center(
                  child: _expenseStatusPill(
                    context,
                    label: expense.editedFrom == null
                        ? context.l10n.expenseLogged
                        : context.l10n.expenseEdited,
                    edited: expense.editedFrom != null,
                    onTap: expense.editedFrom == null
                        ? null
                        : () => _showOriginal(context, store, expense),
                  ),
                ),
              ),
              SizedBox(
                width: 88,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: canEdit
                      ? IconButton(
                          tooltip: context.l10n.expenseEdit,
                          onPressed: () =>
                              _addExpense(context, store, editing: expense),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
      ),
    );
  }

  Widget _expenseStatusPill(
    BuildContext context, {
    required String label,
    required bool edited,
    VoidCallback? onTap,
  }) {
    final color = edited ? CafeColors.alert : CafeColors.inkMuted;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11),
      ),
    );
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
