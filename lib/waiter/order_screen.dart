import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/choice_labels.dart';
import '../l10n/l10n_ext.dart';
import '../models/models.dart';
import '../theme/cafe_theme.dart';
import '../widgets/dish_choices_sheet.dart';
import 'tables_screen.dart';
import 'waiter_app.dart' show waiterSystemBars;
import 'waiter_motion.dart';
import 'waiter_state.dart';

/// One table's order: pick dishes, review, send to the cashier.
class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key, required this.tableId});

  final String tableId;

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  String? _categoryId;

  /// The waiter picked a category: dishes then show at once instead of rising in again.
  bool _picked = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final waiter = context.watch<WaiterController>();
    final l10n = context.l10n;
    final table = waiter.tableById(widget.tableId);
    final number = table?.number ?? '';
    final query = _query.trim().toLowerCase();
    final dishes = [
      for (final item in waiter.items)
        if ((_categoryId == null || item.categoryId == _categoryId) &&
            (query.isEmpty || item.nameEn.toLowerCase().contains(query) || item.nameIt.toLowerCase().contains(query)))
          item,
    ];
    final count = waiter.cartCount(widget.tableId);
    final surfaces = CafeSurfaces.of(context);
    return Scaffold(
      backgroundColor: surfaces.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: DecoratedBox(decoration: brandGradient(surfaces)),
        foregroundColor: surfaces.onHeader,
        systemOverlayStyle: waiterSystemBars(surfaces),
        title: Text(l10n.waiterReviewTitle(number), style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: const [WaiterLanguageButton()],
      ),
      body: Column(
        children: [
          if (!waiter.connected) const ReconnectingBanner(),
          if (waiter.ordersPaused) const OrdersPausedBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              textInputAction: TextInputAction.search,
              autocorrect: false,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: l10n.waiterSearchDish,
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _CategoryChip(
                  label: l10n.waiterAllCategories,
                  selected: _categoryId == null,
                  onTap: () => setState(() {
                    _categoryId = null;
                    _picked = true;
                  }),
                ),
                for (final category in waiter.categories)
                  _CategoryChip(
                    label: category.label(waiter.locale),
                    selected: _categoryId == category.id,
                    onTap: () => setState(() {
                      _categoryId = category.id;
                      _picked = true;
                    }),
                  ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 150,
              ),
              itemCount: dishes.length,
              itemBuilder: (context, index) => EntranceRise(
                key: ValueKey('${_categoryId ?? ''}/${dishes[index].id}'),
                index: index,
                animate: !_picked,
                child: _DishCard(tableId: widget.tableId, item: dishes[index]),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          // The review bar rises in with the first dish and pops each time the cart changes.
          child: AnimatedSlide(
            offset: count == 0 ? const Offset(0, 0.25) : Offset.zero,
            duration: CafeMotion.medium,
            curve: CafeMotion.easeOut,
            child: AnimatedOpacity(
              opacity: count == 0 ? 0.55 : 1,
              duration: CafeMotion.medium,
              child: PressScale(
                child: FilledButton.icon(
                  onPressed: count == 0 ? null : () => _openReview(context),
                  icon: const Icon(Icons.receipt_long),
                  label: BumpText(l10n.waiterReview(count, waiter.money.format(waiter.cartTotal(widget.tableId)))),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openReview(BuildContext context) async {
    final waiter = context.read<WaiterController>();
    final outcome = await showModalBottomSheet<SendOutcome>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ChangeNotifierProvider.value(
        value: waiter,
        child: _ReviewSheet(tableId: widget.tableId),
      ),
    );
    if (!context.mounted || outcome == null) return;
    final l10n = context.l10n;
    switch (outcome) {
      case SendOutcome.sent:
        await _showSent(context);
        if (context.mounted) Navigator.of(context).pop();
      case SendOutcome.unavailable:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.waiterUnavailable)));
      case SendOutcome.paused:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.waiterOrdersPaused)));
      case SendOutcome.failed:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.waiterSendFailed)));
    }
  }

  Future<void> _showSent(BuildContext context) {
    final navigator = Navigator.of(context);
    final closing = Timer(const Duration(milliseconds: 1600), () {
      if (navigator.canPop()) navigator.pop();
    });
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: MediaQuery.disableAnimationsOf(context) ? 1 : 0, end: 1),
              duration: const Duration(milliseconds: 650),
              curve: Curves.elasticOut,
              builder: (context, value, child) => Transform.scale(scale: value, child: child),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(color: CafeColors.success.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, size: 64, color: CafeColors.success),
              ),
            ),
            const SizedBox(height: 12),
            Text(context.l10n.waiterSentTitle, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(context.l10n.waiterSentBody, textAlign: TextAlign.center),
          ],
        ),
      ),
    ).whenComplete(closing.cancel);
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: CafeSurfaces.of(context).button,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: selected ? CafeSurfaces.of(context).onButton : CafeColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DishCard extends StatelessWidget {
  const _DishCard({required this.tableId, required this.item});

  final String tableId;
  final MenuItem item;

  Future<void> _add(BuildContext context) async {
    final waiter = context.read<WaiterController>();
    if (item.options.isEmpty) {
      unawaited(HapticFeedback.selectionClick());
      waiter.addDish(tableId, item);
      return;
    }
    final onIds = await showDishChoicesSheet(
      context,
      item: item,
      onIds: item.defaultOnIds,
      locale: waiter.locale,
      money: waiter.money.format,
    );
    if (onIds == null) return;
    unawaited(HapticFeedback.selectionClick());
    waiter.addDish(tableId, item, onIds: onIds);
  }

  @override
  Widget build(BuildContext context) {
    final waiter = context.watch<WaiterController>();
    final count = waiter.dishCount(tableId, item.id);
    final soldOut = item.soldOut;
    final surfaces = CafeSurfaces.of(context);
    final card = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: soldOut ? null : () => _add(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.displayName(waiter.locale),
                maxLines: 2,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: soldOut ? CafeColors.inkMuted : CafeColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                soldOut ? context.l10n.waiterSoldOut : waiter.money.format(item.salePrice),
                style: TextStyle(color: soldOut ? CafeColors.alert : CafeColors.inkMuted, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (!soldOut)
                count == 0
                    ? Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: IconButton.filled(
                          tooltip: context.l10n.waiterAdd,
                          onPressed: () => _add(context),
                          icon: Icon(item.options.isEmpty ? Icons.add : Icons.tune),
                        ),
                      )
                    : _Stepper(
                        count: count,
                        onMinus: () => waiter.removeOneDish(tableId, item.id),
                        onPlus: () => _add(context),
                      ),
            ],
          ),
        ),
      ),
    );
    return PressScale(
      child: AnimatedContainer(
        duration: CafeMotion.medium,
        curve: CafeMotion.easeOut,
        decoration: BoxDecoration(
          color: count > 0 ? Color.alphaBlend(surfaces.button.withValues(alpha: 0.10), Colors.white) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: count > 0 ? surfaces.button : Colors.transparent, width: 2),
          boxShadow: const [BoxShadow(color: Color(0x0F1B3A4B), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: card,
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.count, required this.onMinus, required this.onPlus});

  final int count;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton.outlined(onPressed: onMinus, icon: const Icon(Icons.remove)),
        BumpText('$count', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        IconButton.filled(onPressed: onPlus, icon: const Icon(Icons.add)),
      ],
    );
  }
}

class _ReviewSheet extends StatelessWidget {
  const _ReviewSheet({required this.tableId});

  final String tableId;

  @override
  Widget build(BuildContext context) {
    final waiter = context.watch<WaiterController>();
    final l10n = context.l10n;
    final lines = waiter.cartFor(tableId);
    final number = waiter.tableById(tableId)?.number ?? '';
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.waiterReviewTitle(number),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [for (final line in lines) _ReviewLine(tableId: tableId, line: line)],
                ),
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Text(l10n.waiterTotal, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  BumpText(
                    waiter.money.format(waiter.cartTotal(tableId)),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: lines.isEmpty || waiter.sending || !waiter.connected || waiter.ordersPaused
                    ? null
                    : () async {
                        final navigator = Navigator.of(context);
                        final outcome = await waiter.sendOrder(tableId);
                        navigator.pop(outcome);
                      },
                icon: waiter.sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send),
                label: Text(waiter.connected ? l10n.waiterSend : l10n.waiterReconnecting),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewLine extends StatelessWidget {
  const _ReviewLine({required this.tableId, required this.line});

  final String tableId;
  final WaiterLine line;

  @override
  Widget build(BuildContext context) {
    final waiter = context.read<WaiterController>();
    final priced = line.priced(waiter.locale);
    final choices = choicesText(
      priced.choices,
      waiter.locale,
      without: context.l10n.dishChoiceWithout,
      money: waiter.money.format,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(priced.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                if (choices.isNotEmpty) Text(choices, style: const TextStyle(color: CafeColors.inkMuted, fontSize: 13)),
                Text(waiter.money.format(priced.total), style: const TextStyle(color: CafeColors.inkMuted)),
              ],
            ),
          ),
          IconButton.outlined(
            onPressed: () => waiter.setLineQty(tableId, line.key, line.qty - 1),
            icon: Icon(line.qty == 1 ? Icons.delete_outline : Icons.remove),
          ),
          SizedBox(
            width: 36,
            child: Center(
              child: BumpText('${line.qty}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ),
          ),
          IconButton.filled(
            onPressed: () => waiter.setLineQty(tableId, line.key, line.qty + 1),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
