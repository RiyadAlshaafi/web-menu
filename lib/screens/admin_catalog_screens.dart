import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/app_database.dart';
import '../features/app_feature.dart';
import '../l10n/l10n_ext.dart';
import '../models/models.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';
import '../widgets/cafe_dialogs.dart';
import '../widgets/cafe_widgets.dart';
import '../widgets/tawla_ui.dart';
import 'admin_brand_settings.dart';
import 'admin_feedback_card.dart';
import 'admin_printers_kitchens_card.dart';
import 'admin_receipt_editor.dart';
import 'admin_service_charge_card.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  String query = '';
  String? categoryFilter;
  bool showFilters = false;

  // The promo form on the right.
  String? targetCategoryId;
  double percent = 15;
  bool activateNow = true;
  bool applying = false;
  final labelController = TextEditingController();

  @override
  void dispose() {
    labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final dishes = store.menuItems.where((item) {
      final category = store.categories.where((entry) => entry.id == item.categoryId);
      final name = item.displayName(store.locale).toLowerCase();
      final catName = category.isEmpty ? '' : category.first.nameEn.toLowerCase();
      final matchesQuery = query.isEmpty || name.contains(query.toLowerCase()) || catName.contains(query.toLowerCase());
      final matchesCategory = categoryFilter == null || item.categoryId == categoryFilter;
      return matchesQuery && matchesCategory;
    }).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final list = TawlaPanel(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: PageSearchField(hint: context.l10n.catalogSearchDishesHint, filled: CafeColors.key, onChanged: (value) => setState(() => query = value)),
              ),
              const SizedBox(width: 10),
              FiltersButton(
                open: showFilters,
                active: categoryFilter == null ? 0 : 1,
                onPressed: () => setState(() => showFilters = !showFilters),
              ),
            ],
          ),
          if (showFilters) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterPill(
                label: context.l10n.catalogAllCategoriesCount('${store.menuItems.length}'),
                selected: categoryFilter == null,
                height: 40,
                onTap: () => setState(() => categoryFilter = null),
              ),
              for (final category in store.orderedCategories)
                FilterPill(label: category.nameEn, selected: categoryFilter == category.id, height: 40, onTap: () => setState(() => categoryFilter = category.id)),
            ],
          ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: TawlaTokens.hairline),
          Expanded(
            child: store.menuItems.isEmpty
                ? EmptyHint(context.l10n.catalogNoDishesHint)
                : ListView.separated(
                    itemCount: dishes.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: TawlaTokens.hairline),
                    itemBuilder: (context, index) => _dishRow(context, store, dishes[index]),
                  ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 900) {
            return ListView(
              children: [
                SizedBox(height: 560, child: list),
                const SizedBox(height: 18),
                _promoForm(context, store),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 13, child: list),
              const SizedBox(width: 18),
              Expanded(flex: 8, child: SingleChildScrollView(child: _promoForm(context, store))),
            ],
          );
        },
      ),
    );
  }

  Widget _dishRow(BuildContext context, CafeStore store, MenuItem dish) {
    final category = store.categories.where((item) => item.id == dish.categoryId);
    return InkWell(
      onTap: () => _editDish(context, store, dish),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dish.displayName(store.locale), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: CafeColors.ink)),
                  if (category.isNotEmpty) Text(category.first.nameEn, style: const TextStyle(fontSize: 12, color: TawlaTokens.muted)),
                ],
              ),
            ),
            if (dish.hasDiscount) ...[
              Text(
                store.currency.format(dish.price),
                style: const TextStyle(fontSize: 12, color: TawlaTokens.muted, decoration: TextDecoration.lineThrough),
              ),
              const SizedBox(width: 8),
            ],
            Text(store.currency.format(dish.salePrice), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CafeSurfaces.of(context).header)),
            const SizedBox(width: 12),
            SizedBox(
              width: 86,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: StatusBadge(
                  dish.hasDiscount ? context.l10n.catalogPercentOff('${dish.discountPercent.round()}') : context.l10n.catalogNoPromo,
                  tone: dish.hasDiscount ? BadgeTone.terracotta : BadgeTone.neutral,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _promoForm(BuildContext context, CafeStore store) {
    // Running promos, grouped by category and rate.
    final groups = <(String?, double), List<MenuItem>>{};
    for (final dish in store.menuItems.where((item) => item.hasDiscount)) {
      groups.putIfAbsent((dish.categoryId, dish.discountPercent), () => []).add(dish);
    }
    String categoryName(String? id) {
      final match = store.categories.where((item) => item.id == id);
      return match.isEmpty ? context.l10n.catalogAllCategories : match.first.nameEn;
    }

    final valid = store.categories.any((item) => item.id == targetCategoryId) ? targetCategoryId : null;
    return TawlaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(context.l10n.catalogApplyDiscountPromo, size: 19),
          Text(context.l10n.catalogNewDiscount, style: const TextStyle(fontSize: 13, color: TawlaTokens.muted)),
          const SizedBox(height: 14),
          EyebrowLabel(context.l10n.catalogTargetCategory, color: CafeColors.ink),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SelectBox<String?>(
              value: valid,
              filled: CafeColors.key,
              items: [
                DropdownMenuItem(value: null, child: Text(context.l10n.catalogAllCategories)),
                ...store.orderedCategories.map((category) => DropdownMenuItem(value: category.id, child: Text(category.nameEn))),
              ],
              onChanged: (value) => setState(() => targetCategoryId = value),
            ),
          ),
          const SizedBox(height: 16),
          EyebrowLabel(context.l10n.catalogDiscountRate, color: CafeColors.ink),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: percent,
                  max: 100,
                  activeColor: CafeSurfaces.of(context).button,
                  inactiveColor: CafeColors.line,
                  onChanged: (value) => setState(() => percent = value.roundToDouble()),
                ),
              ),
              Container(
                width: 56,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFFFDF1EB), borderRadius: BorderRadius.circular(10)),
                child: Text('${percent.round()}%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CafeColors.terracottaDark)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          EyebrowLabel(context.l10n.catalogPromoLabel, color: CafeColors.ink),
          const SizedBox(height: 8),
          TextField(controller: labelController, decoration: InputDecoration(hintText: context.l10n.catalogPromoLabelHint)),
          const SizedBox(height: 14),
          Material(
            color: CafeColors.key,
            borderRadius: BorderRadius.circular(12),
            child: CheckboxListTile(
              value: activateNow,
              onChanged: (value) => setState(() => activateNow = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text(context.l10n.catalogActivateImmediately, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: Text(context.l10n.catalogActivateImmediatelyDesc, style: const TextStyle(fontSize: 12, color: TawlaTokens.muted)),
            ),
          ),
          const SizedBox(height: 14),
          TerracottaButton(
            label: context.l10n.catalogApplyDiscount,
            busy: applying,
            onPressed: () async {
              setState(() => applying = true);
              await store.applyCategoryDiscount(categoryId: valid, percent: percent, activate: activateNow);
              if (mounted) setState(() => applying = false);
            },
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: TawlaTokens.hairline),
          const SizedBox(height: 14),
          EyebrowLabel(context.l10n.catalogActivePromos),
          const SizedBox(height: 10),
          if (groups.isEmpty)
            Text(context.l10n.catalogNoActivePromos, style: const TextStyle(color: TawlaTokens.muted, fontSize: 13))
          else
            for (final entry in groups.entries)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: TawlaTokens.border)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${context.l10n.catalogPercentOff('${entry.key.$2.round()}')} · ${categoryName(entry.key.$1)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                    OutlineAction(
                      label: context.l10n.catalogRemovePromo,
                      danger: true,
                      onPressed: () async {
                        for (final dish in entry.value) {
                          await store.setDishDiscount(dish, percent: dish.discountPercent, applied: false);
                        }
                      },
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  /// One dish's own discount, for a promo that does not cover its whole category.
  Future<void> _editDish(BuildContext context, CafeStore store, MenuItem dish) async {
    final controller = TextEditingController(text: dish.discountPercent == 0 ? '' : dish.discountPercent.toStringAsFixed(dish.discountPercent % 1 == 0 ? 0 : 1));
    var applied = dish.discountApplied;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModal) => AlertDialog(
          title: Text(context.l10n.catalogEditDishDiscount(dish.displayName(store.locale))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: context.l10n.catalogDiscount, suffixText: '%'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: applied,
                onChanged: (value) => setModal(() => applied = value ?? false),
                title: Text(context.l10n.catalogApply),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.commonCancel)),
            FilledButton(
              onPressed: () async {
                await store.setDishDiscount(dish, percent: double.tryParse(controller.text) ?? 0, applied: applied);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(context.l10n.catalogApply),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }
}

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final cashierName = TextEditingController();
  final cashierPin = TextEditingController();
  String staffRole = StaffJob.cashier;
  bool staffUsesDevice = false;

  /// A cashier always has a PIN; a server only online, when they use a tablet or phone.
  bool get _staffNeedsPin =>
      staffRole == StaffJob.cashier ||
      (staffRole == StaffJob.server && staffUsesDevice && !context.read<CafeStore>().isLocalMode);
  final currentPassword = TextEditingController();
  final newPassword = TextEditingController();
  bool changingPassword = false;
  String? pendingLocale;

  @override
  void dispose() {
    cashierName.dispose();
    cashierPin.dispose();
    currentPassword.dispose();
    newPassword.dispose();
    super.dispose();
  }

  Future<void> _changePassword(CafeStore store) async {
    setState(() => changingPassword = true);
    final error = await store.changeAdminPassword(current: currentPassword.text, next: newPassword.text);
    if (!mounted) return;
    setState(() => changingPassword = false);
    if (error == null) {
      currentPassword.clear();
      newPassword.clear();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? context.l10n.catalogPasswordUpdated)),
    );
  }

  Future<void> _removeCashier(CafeStore store, Cashier member) async {
    final confirmed = await showCafeConfirmDialog(
      context,
      title: context.l10n.catalogDeleteCashierTitle,
      message: context.l10n.catalogDeleteCashierMessage(member.name),
      confirm: context.l10n.catalogDeleteCashierConfirm,
    );
    if (!confirmed || !mounted) return;
    final error = await store.deleteCashier(member.id);
    if (error == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.errorText(error))));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    // Left and right column cards, in the order of the design board. A null card's feature is off.
    final rows = <(Widget?, Widget?)>[
      (const CompanyInfoCard(), store.allows(AppFeature.branding) ? const AppearanceCard() : null),
      (_cashierPanel(store), store.allows(AppFeature.paymentTypes) ? const PaymentTypesCard() : null),
      // "Ordering online": the guest location check and the cashier-online rule for QR orders.
      (store.allows(AppFeature.languages) ? _languagePanel(store) : null, store.allows(AppFeature.locationCheck) ? const OrderingCard() : null),
      (_passwordPanel(store), store.allows(AppFeature.expenses) ? const ExpenseCategoriesCard() : null),
      (const PrintersKitchensCard(), store.isLocalMode ? null : const FeedbackCard()),
      (
        store.allows(AppFeature.takeoutLayout) ? const TakeoutLayoutCard() : null,
        store.allows(AppFeature.serviceCharge) || store.savedServiceChargeRate > 0 ? const ServiceChargeCard() : null,
      ),
      // Local mode has no guest QR menu, so menuDesign is never allowed there.
      (store.allows(AppFeature.receiptEditor) ? const ReceiptEditorCard() : null, store.allows(AppFeature.menuDesign) ? const GuestMenuLayoutCard() : null),
    ];
    final left = [for (final (card, _) in rows) ?card];
    final right = [for (final (_, card) in rows) ?card];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1000) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (final (first, second) in rows) ...[
                if (first != null) ...[first, const SizedBox(height: 16)],
                if (second != null) ...[second, const SizedBox(height: 16)],
              ],
              const _SoonCard(),
            ],
          );
        }
        // Two independent columns: some cards lay out by their own width, so rows cannot share a height.
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stretch, so a card with little in it is as wide as its column like the others.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (final card in left) ...[card, const SizedBox(height: 16)]],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final card in right) ...[card, const SizedBox(height: 16)],
                    const _SoonCard(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _roleLabel(String role) => switch (role) {
    StaffJob.chef => context.l10n.staffRoleChef,
    StaffJob.server => context.l10n.staffRoleServer,
    StaffJob.cleaner => context.l10n.staffRoleCleaner,
    _ => context.l10n.staffRoleCashier,
  };

  Widget _cashierPanel(CafeStore store) {
    return TawlaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(context.l10n.catalogCashierStaffAccess, size: 18),
          const SizedBox(height: 6),
          if (store.cashiers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(context.l10n.noCashiers, style: const TextStyle(color: TawlaTokens.muted)),
            ),
          for (final member in store.cashiers)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: TawlaTokens.hairline))),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: Color(0xFFE1EEF5), shape: BoxShape.circle),
                    child: Text(member.initials, style: const TextStyle(color: Color(0xFF1F5873), fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(member.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: CafeColors.ink)),
                        Text(
                          [
                            _roleLabel(member.role),
                            if (member.isWaiter) context.l10n.staffDeviceTag,
                            if (member.canSignIn) context.l10n.catalogCashierPinMasked,
                          ].join(' · '),
                          style: const TextStyle(fontSize: 12, color: TawlaTokens.muted),
                        ),
                      ],
                    ),
                  ),
                  OutlineAction(label: context.l10n.commonRemove, danger: true, onPressed: () => _removeCashier(store, member)),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: LabeledField(
                  label: context.l10n.catalogCashierName,
                  child: TextField(controller: cashierName, decoration: InputDecoration(hintText: context.l10n.catalogCashierNameHint)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: LabeledField(
                  label: context.l10n.catalogStaffRoleLabel,
                  child: DropdownButtonFormField<String>(
                    initialValue: staffRole,
                    items: [
                      for (final role in StaffJob.all) DropdownMenuItem(value: role, child: Text(_roleLabel(role))),
                    ],
                    onChanged: (value) => setState(() => staffRole = value ?? StaffJob.cashier),
                  ),
                ),
              ),
              if (_staffNeedsPin) ...[
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: LabeledField(
                    label: context.l10n.catalogCashierPinLabel,
                    child: TextField(
                      controller: cashierPin,
                      maxLength: 4,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: '••••', counterText: ''),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (staffRole == StaffJob.server)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: staffUsesDevice,
              onChanged: (value) => setState(() => staffUsesDevice = value),
              title: Text(context.l10n.staffUsesDevice, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              subtitle: Text(context.l10n.staffUsesDeviceHint, style: const TextStyle(fontSize: 12, color: TawlaTokens.muted)),
            ),
          const SizedBox(height: 14),
          NavyButton(
            label: context.l10n.catalogSaveCashier,
            onPressed: () async {
              final needsPin = _staffNeedsPin;
              if (cashierName.text.trim().isEmpty || (needsPin && cashierPin.text.length != 4)) return;
              await store.addCashier(
                name: cashierName.text,
                pin: needsPin ? cashierPin.text : '',
                role: staffRole,
                usesDevice: staffRole == StaffJob.server && staffUsesDevice,
              );
              cashierName.clear();
              cashierPin.clear();
            },
          ),
        ],
      ),
    );
  }

  Widget _languagePanel(CafeStore store) {
    final selected = pendingLocale ?? store.locale;
    return TawlaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(context.l10n.catalogSystemLanguage, size: 18),
          const SizedBox(height: 2),
          Text(context.l10n.catalogSystemLanguageDesc, style: const TextStyle(color: TawlaTokens.muted, fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _lang(selected, 'en', context.l10n.catalogEnglishUs, context.l10n.catalogLangDefault)),
              const SizedBox(width: 10),
              Expanded(child: _lang(selected, 'ar', 'العربية', context.l10n.catalogLangRegional)),
            ],
          ),
          const SizedBox(height: 16),
          NavyButton(
            label: context.l10n.catalogSaveLanguage,
            onPressed: selected == store.locale
                ? null
                : () async {
                    await store.setLocale(selected);
                    if (mounted) setState(() => pendingLocale = null);
                  },
          ),
        ],
      ),
    );
  }

  Widget _lang(String selectedCode, String code, String title, String caption) {
    final selected = selectedCode == code;
    final accent = CafeSurfaces.of(context).button;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: () => setState(() => pendingLocale = code),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? accent : TawlaTokens.border, width: 2),
            color: selected ? const Color(0xFFFFF4EF) : Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: CafeColors.ink)),
              const SizedBox(height: 2),
              Text(caption, style: const TextStyle(color: TawlaTokens.muted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _passwordPanel(CafeStore store) {
    // Offline the admin has a PIN of digits instead of a password.
    final local = store.isLocalMode;
    final rules = local
        ? context.l10n.authPinHint('${Secrets.minAdminPin}')
        : [
            context.l10n.authReqMinLength,
            context.l10n.authReqCapital,
            context.l10n.authReqNumber,
            context.l10n.authReqSymbol,
          ].join(' · ');
    return TawlaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(local ? context.l10n.catalogChangePin : context.l10n.catalogChangePassword, size: 18),
          const SizedBox(height: 12),
          LabeledField(
            label: local ? context.l10n.catalogCurrentPin : context.l10n.catalogCurrentPassword,
            child: TextField(
              controller: currentPassword,
              obscureText: true,
              keyboardType: local ? TextInputType.number : null,
              autofillHints: local ? null : const [AutofillHints.password],
            ),
          ),
          const SizedBox(height: 12),
          LabeledField(
            label: local ? context.l10n.authNewPin : context.l10n.catalogNewPassword,
            child: TextField(
              controller: newPassword,
              obscureText: true,
              keyboardType: local ? TextInputType.number : null,
              inputFormatters: local ? [FilteringTextInputFormatter.digitsOnly] : null,
              autofillHints: local ? null : const [AutofillHints.newPassword],
            ),
          ),
          const SizedBox(height: 10),
          Text(rules, style: const TextStyle(fontSize: 12, color: TawlaTokens.muted)),
          const SizedBox(height: 14),
          NavyButton(
            label: local ? context.l10n.catalogUpdatePin : context.l10n.catalogUpdatePassword,
            onPressed: changingPassword ? null : () => _changePassword(store),
          ),
        ],
      ),
    );
  }
}

/// One payment type or expense category: names, edit and delete, and the enabled switch.
class _NamedTypeRow extends StatelessWidget {
  const _NamedTypeRow({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: TawlaTokens.hairline))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: CafeColors.ink)),
                if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(fontSize: 13, color: TawlaTokens.muted)),
              ],
            ),
          ),
          IconAction(icon: Icons.edit_outlined, tooltip: context.l10n.commonEdit, size: 40, onPressed: onEdit),
          const SizedBox(width: 8),
          IconAction(icon: Icons.delete_outline, tooltip: context.l10n.commonDelete, size: 40, danger: true, onPressed: onDelete),
          const SizedBox(width: 12),
          Switch(value: enabled, onChanged: onToggle),
        ],
      ),
    );
  }
}

/// English and Arabic name fields with Save and Cancel, shown while adding or editing a row.
class _NamesEditor extends StatelessWidget {
  const _NamesEditor({required this.nameEn, required this.nameAr, required this.editing, required this.onSave, required this.onCancel});

  final TextEditingController nameEn;
  final TextEditingController nameAr;
  final bool editing;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: LabeledField(label: context.l10n.payTypeNameEn, child: TextField(controller: nameEn))),
            const SizedBox(width: 10),
            Expanded(
              child: LabeledField(
                label: context.l10n.payTypeNameAr,
                child: TextField(controller: nameAr, textDirection: TextDirection.rtl),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            NavyButton(label: editing ? context.l10n.payTypeSave : context.l10n.payTypeAdd, onPressed: onSave),
            const SizedBox(width: 8),
            OutlineAction(label: context.l10n.commonCancel, height: 44, onPressed: onCancel),
          ],
        ),
      ],
    );
  }
}

class PaymentTypesCard extends StatefulWidget {
  const PaymentTypesCard({super.key});

  @override
  State<PaymentTypesCard> createState() => _PaymentTypesCardState();
}

class _PaymentTypesCardState extends State<PaymentTypesCard> {
  final nameEn = TextEditingController();
  final nameAr = TextEditingController();
  String? editingId;
  bool adding = false;

  @override
  void dispose() {
    nameEn.dispose();
    nameAr.dispose();
    super.dispose();
  }

  void _close() {
    setState(() {
      editingId = null;
      adding = false;
    });
    nameEn.clear();
    nameAr.clear();
  }

  Future<void> _delete(BuildContext context, CafeStore store, PaymentType type) async {
    final ok = await showCafeConfirmDialog(
      context,
      title: context.l10n.payDeleteTitle(type.label(store.locale)),
      message: context.l10n.payDeleteMessage,
    );
    if (!ok || !context.mounted) return;
    final error = await store.deletePaymentType(type.id);
    if (!context.mounted) return;
    if (editingId == type.id) _close();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.errorText(error))));
    }
  }

  Future<void> _save(BuildContext context, CafeStore store) async {
    final en = nameEn.text.trim();
    final ar = nameAr.text.trim();
    if (en.isEmpty || ar.isEmpty) return;
    final String? error;
    if (editingId != null) {
      final match = store.paymentTypes.where((type) => type.id == editingId);
      if (match.isEmpty) return;
      final type = match.first
        ..nameEn = en
        ..nameAr = ar;
      error = await store.savePaymentType(type);
    } else {
      error = await store.addPaymentType(en, ar);
    }
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.errorText(error))));
      return;
    }
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final types = store.paymentTypes.where((type) => !type.archived).toList();
    return TawlaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(context.l10n.payTypesTitle, size: 18),
          const SizedBox(height: 2),
          Text(context.l10n.payTypesHint, style: const TextStyle(color: TawlaTokens.muted, fontSize: 13)),
          const SizedBox(height: 6),
          for (final type in types)
            _NamedTypeRow(
              title: type.label(store.locale),
              subtitle: store.locale == 'ar' ? type.nameEn : type.nameAr,
              enabled: type.enabled,
              onEdit: () => setState(() {
                editingId = type.id;
                adding = false;
                nameEn.text = type.nameEn;
                nameAr.text = type.nameAr;
              }),
              onDelete: () => _delete(context, store, type),
              onToggle: (value) async {
                final previous = type.enabled;
                type.enabled = value;
                final error = await store.savePaymentType(type);
                if (!context.mounted) return;
                if (error != null) {
                  type.enabled = previous;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.errorText(error))));
                }
              },
            ),
          const SizedBox(height: 14),
          if (adding || editingId != null)
            _NamesEditor(nameEn: nameEn, nameAr: nameAr, editing: editingId != null, onSave: () => _save(context, store), onCancel: _close)
          else
            OutlineAction(label: '+ ${context.l10n.payTypeAdd}', height: 44, onPressed: () => setState(() => adding = true)),
        ],
      ),
    );
  }
}

class ExpenseCategoriesCard extends StatefulWidget {
  const ExpenseCategoriesCard({super.key});

  @override
  State<ExpenseCategoriesCard> createState() => _ExpenseCategoriesCardState();
}

class _ExpenseCategoriesCardState extends State<ExpenseCategoriesCard> {
  final nameEn = TextEditingController();
  final nameAr = TextEditingController();
  String? editingId;
  bool adding = false;

  @override
  void dispose() {
    nameEn.dispose();
    nameAr.dispose();
    super.dispose();
  }

  void _close() {
    setState(() {
      editingId = null;
      adding = false;
    });
    nameEn.clear();
    nameAr.clear();
  }

  Future<void> _delete(BuildContext context, CafeStore store, ExpenseCategory category) async {
    final ok = await showCafeConfirmDialog(
      context,
      title: context.l10n.payDeleteTitle(category.label(store.locale)),
      message: context.l10n.expenseCategoryDeleteMessage,
    );
    if (!ok || !context.mounted) return;
    final error = await store.deleteExpenseCategory(category.id);
    if (!context.mounted) return;
    if (editingId == category.id) _close();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.errorText(error))));
    }
  }

  Future<void> _save(BuildContext context, CafeStore store) async {
    final en = nameEn.text.trim();
    final ar = nameAr.text.trim();
    if (en.isEmpty || ar.isEmpty) return;
    final String? error;
    if (editingId != null) {
      final match = store.expenseCategories.where((item) => item.id == editingId);
      if (match.isEmpty) return;
      final category = match.first
        ..nameEn = en
        ..nameAr = ar;
      error = await store.saveExpenseCategory(category);
    } else {
      error = await store.addExpenseCategory(en, ar);
    }
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.errorText(error))));
      return;
    }
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final categories = [...store.expenseCategories]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return TawlaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(context.l10n.expenseCategoriesTitle, size: 18),
          const SizedBox(height: 2),
          Text(context.l10n.expenseCategoriesHint, style: const TextStyle(color: TawlaTokens.muted, fontSize: 13)),
          const SizedBox(height: 6),
          for (final category in categories)
            _NamedTypeRow(
              title: category.label(store.locale),
              subtitle: store.locale == 'ar' ? category.nameEn : category.nameAr,
              enabled: category.enabled,
              onEdit: () => setState(() {
                editingId = category.id;
                adding = false;
                nameEn.text = category.nameEn;
                nameAr.text = category.nameAr;
              }),
              onDelete: () => _delete(context, store, category),
              onToggle: (value) async {
                final previous = category.enabled;
                category.enabled = value;
                final error = await store.saveExpenseCategory(category);
                if (!context.mounted) return;
                if (error != null) {
                  category.enabled = previous;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.errorText(error))));
                }
              },
            ),
          const SizedBox(height: 14),
          if (adding || editingId != null)
            _NamesEditor(nameEn: nameEn, nameAr: nameAr, editing: editingId != null, onSave: () => _save(context, store), onCancel: _close)
          else
            OutlineAction(label: '+ ${context.l10n.payTypeAdd}', height: 44, onPressed: () => setState(() => adding = true)),
        ],
      ),
    );
  }
}

/// A greyed-out card marking where a new setting is on its way. It does nothing when tapped.
class _SoonCard extends StatelessWidget {
  const _SoonCard();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        TawlaPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 18, width: 160, decoration: BoxDecoration(color: CafeColors.line, borderRadius: BorderRadius.circular(6))),
              const SizedBox(height: 12),
              Container(height: 12, decoration: BoxDecoration(color: CafeColors.line, borderRadius: BorderRadius.circular(6))),
              const SizedBox(height: 8),
              FractionallySizedBox(
                widthFactor: 0.7,
                child: Container(height: 12, decoration: BoxDecoration(color: CafeColors.line, borderRadius: BorderRadius.circular(6))),
              ),
              const SizedBox(height: 20),
              Container(height: 44, width: 140, decoration: BoxDecoration(color: CafeColors.line, borderRadius: BorderRadius.circular(10))),
            ],
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.72), borderRadius: BorderRadius.circular(16)),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.settingsSoon,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: CafeSurfaces.of(context).header),
                  ),
                  const SizedBox(height: 4),
                  Text(context.l10n.settingsSoonHint, style: const TextStyle(color: TawlaTokens.muted, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
