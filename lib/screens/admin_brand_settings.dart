import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';

import '../platform/device_location.dart';
import '../core/report_error.dart';
import '../features/app_feature.dart';
import '../l10n/l10n_ext.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';
import '../widgets/tawla_ui.dart';

/// Cafe name and logo.
class CompanyInfoCard extends StatefulWidget {
  const CompanyInfoCard({super.key});

  @override
  State<CompanyInfoCard> createState() => _CompanyInfoCardState();
}

class _CompanyInfoCardState extends State<CompanyInfoCard> {
  late final TextEditingController name;
  String? pendingLogo;
  bool removeLogo = false;

  @override
  void initState() {
    super.initState();
    final cafe = context.read<CafeStore>().cafe;
    name = TextEditingController(text: (cafe['name'] as String?) ?? '');
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final previewLogo = removeLogo ? '' : (pendingLogo ?? store.logoUrl);
    return TawlaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(context.l10n.catalogCompanyInfo, size: 18),
          const SizedBox(height: 12),
          Row(
            children: [
              _logoPreview(previewLogo),
              const SizedBox(width: 12),
              OutlineAction(label: context.l10n.catalogChooseLogo, height: 44, onPressed: _pickLogo),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() {
                  pendingLogo = null;
                  removeLogo = true;
                }),
                child: Text(context.l10n.catalogRemoveLogo, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LabeledField(label: context.l10n.catalogCafeName, child: TextField(controller: name)),
          const SizedBox(height: 14),
          // Read-only: only the developer changes it, on the dev screen.
          LabeledField(
            label: context.l10n.catalogPublicMenuUrl,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: CafeColors.key, borderRadius: BorderRadius.circular(10), border: Border.all(color: TawlaTokens.border)),
              child: SelectableText(store.guestMenuBase, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            store.publicMenuUrl.isEmpty ? context.l10n.catalogPublicMenuUrlDefault : context.l10n.catalogPublicMenuUrlReadOnly,
            style: const TextStyle(color: TawlaTokens.muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          NavyButton(
            label: context.l10n.catalogSaveCompany,
            onPressed: () async {
              await store.saveCompany(
                name: name.text,
                logoDataUrl: pendingLogo != null && pendingLogo!.startsWith('data:') ? pendingLogo : null,
                removeLogo: removeLogo,
              );
              if (mounted) setState(() => pendingLogo = null);
            },
          ),
        ],
      ),
    );
  }

  Widget _logoPreview(String value) {
    Widget child = Center(child: Text('[${context.l10n.catalogLogoPlaceholder}]', style: const TextStyle(fontSize: 11, color: TawlaTokens.muted)));
    if (value.startsWith('data:')) {
      final comma = value.indexOf(',');
      if (comma > 0) {
        child = Image.memory(base64Decode(value.substring(comma + 1)), cacheWidth: 192, fit: BoxFit.cover);
      }
    } else if (value.startsWith('http')) {
      child = Image.network(value, cacheWidth: 192, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.local_cafe));
    }
    return Container(
      width: 64,
      height: 64,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: CafeColors.key, borderRadius: BorderRadius.circular(12), border: Border.all(color: TawlaTokens.border)),
      child: child,
    );
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (bytes == null) return;
    final mime = (file!.extension ?? 'png').toLowerCase() == 'png' ? 'image/png' : 'image/jpeg';
    setState(() {
      pendingLogo = 'data:$mime;base64,${base64Encode(bytes)}';
      removeLogo = false;
    });
  }

}

/// The four theme colours with a small preview of the console.
class AppearanceCard extends StatefulWidget {
  const AppearanceCard({super.key});

  @override
  State<AppearanceCard> createState() => _AppearanceCardState();
}

class _AppearanceCardState extends State<AppearanceCard> {
  late Color header;
  late Color sidebar;
  late Color background;
  late Color button;

  @override
  void initState() {
    super.initState();
    final surfaces = CafeSurfaces.fromCafe(context.read<CafeStore>().cafe);
    header = surfaces.header;
    sidebar = surfaces.sidebar;
    background = surfaces.background;
    button = surfaces.button;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final swatches = [
      _swatch(context.l10n.catalogHeaderColor, header, (color) => setState(() => header = color)),
      _swatch(context.l10n.catalogSidebarColor, sidebar, (color) => setState(() => sidebar = color)),
      _swatch(context.l10n.catalogBackgroundColor, background, (color) => setState(() => background = color)),
      _swatch(context.l10n.catalogButtonColor, button, (color) => setState(() => button = color)),
    ];
    return TawlaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(context.l10n.catalogAppearance, size: 18),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth < 420 ? constraints.maxWidth : (constraints.maxWidth - 10) / 2;
              return Wrap(spacing: 10, runSpacing: 10, children: [for (final swatch in swatches) SizedBox(width: width, child: swatch)]);
            },
          ),
          const SizedBox(height: 12),
          ExcludeSemantics(
            child: Container(
              height: 120,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: TawlaTokens.border)),
              child: Column(
                children: [
                  Container(
                    height: 30,
                    color: header,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(store.cafeName, style: TextStyle(color: CafeColors.contrastOn(header), fontWeight: FontWeight.w800, fontSize: 11)),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Container(width: 70, color: sidebar),
                        Expanded(
                          child: ColoredBox(
                            color: background,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: button, borderRadius: BorderRadius.circular(6)),
                                child: Text(context.l10n.catalogPreviewButton, style: TextStyle(color: CafeColors.contrastOn(button), fontWeight: FontWeight.w700, fontSize: 11)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              NavyButton(
                label: context.l10n.catalogSaveColors,
                onPressed: () => store.saveAppearance(header: header, sidebar: sidebar, background: background, button: button),
              ),
              OutlineAction(
                label: context.l10n.catalogResetColors,
                height: 44,
                onPressed: () async {
                  await store.resetAppearance();
                  if (!mounted) return;
                  setState(() {
                    header = CafeColors.defaultHeader;
                    sidebar = CafeColors.defaultSidebar;
                    background = CafeColors.defaultBackground;
                    button = CafeColors.defaultButton;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _swatch(String label, Color color, ValueChanged<Color> onPick) {
    return Material(
      color: CafeColors.key,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          var next = color;
          final picked = await showDialog<Color>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(label),
              content: SingleChildScrollView(
                child: ColorPicker(
                  pickerColor: color,
                  onColorChanged: (value) => next = value,
                  enableAlpha: false,
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.commonCancel)),
                FilledButton(onPressed: () => Navigator.pop(context, next), child: Text(context.l10n.catalogSaveColors)),
              ],
            ),
          );
          if (picked != null) onPick(picked);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6), border: Border.all(color: TawlaTokens.border))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: CafeColors.ink)),
                    Text(CafeColors.toHex(color), style: const TextStyle(fontSize: 12, color: TawlaTokens.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Guest ordering rules and receipts: the cafe radius, auto print and the cashier-online pause.
class OrderingCard extends StatefulWidget {
  const OrderingCard({super.key});

  @override
  State<OrderingCard> createState() => _OrderingCardState();
}

class _OrderingCardState extends State<OrderingCard> {
  final lat = TextEditingController();
  final lng = TextEditingController();
  final radius = TextEditingController(text: '100');
  bool requireNear = false;
  String? validation;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    lat.dispose();
    lng.dispose();
    radius.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final store = context.read<CafeStore>();
    try {
      final saved = await store.loadCafeLocation();
      if (!mounted || saved == null) return;
      setState(() {
        requireNear = saved.enabled;
        lat.text = saved.lat == null ? '' : saved.lat!.toStringAsFixed(6);
        lng.text = saved.lng == null ? '' : saved.lng!.toStringAsFixed(6);
        radius.text = '${saved.radiusM}';
      });
    } catch (error, stackTrace) {
      reportError('cafe location', 'load failed', stackTrace);
    }
  }

  double? _coord(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  String? _validate() {
    final meters = int.tryParse(radius.text.trim());
    if (meters == null || meters < 30 || meters > 500) return context.l10n.cafeLocationRadiusRange;
    final latitude = _coord(lat);
    final longitude = _coord(lng);
    final latText = lat.text.trim();
    final lngText = lng.text.trim();
    final latBad = latText.isNotEmpty && (latitude == null || latitude < -90 || latitude > 90);
    final lngBad = lngText.isNotEmpty && (longitude == null || longitude < -180 || longitude > 180);
    if (latBad || lngBad || (requireNear && (latitude == null || longitude == null))) {
      return context.l10n.cafeLocationNeedPoint;
    }
    return null;
  }

  Future<void> _useCurrent() async {
    try {
      final point = await readDeviceLocation();
      if (!mounted) return;
      setState(() {
        lat.text = point.latitude.toStringAsFixed(6);
        lng.text = point.longitude.toStringAsFixed(6);
        validation = null;
      });
    } on DeviceLocationException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.cafeLocationReadFailed)));
    }
  }

  Future<void> _save() async {
    final message = _validate();
    if (message != null) {
      setState(() => validation = message);
      return;
    }
    setState(() {
      validation = null;
      saving = true;
    });
    final error = await context.read<CafeStore>().saveCafeLocation(
          enabled: requireNear,
          lat: _coord(lat),
          lng: _coord(lng),
          radiusM: int.parse(radius.text.trim()),
        );
    if (!mounted) return;
    setState(() {
      saving = false;
      validation = error == null ? null : context.l10n.cafeLocationSaveFailed;
    });
    if (error == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.cafeLocationSaved)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final locationCheck = store.allows(AppFeature.locationCheck);
    const numbers = TextInputType.numberWithOptions(decimal: true, signed: true);
    return TawlaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(context.l10n.settingsOrderingTitle, size: 18),
          const SizedBox(height: 4),
          if (locationCheck)
          SwitchRow(
            title: context.l10n.cafeLocationRequire,
            hint: context.l10n.cafeLocationRequireHint,
            value: requireNear,
            onChanged: (value) => setState(() => requireNear = value),
          ),
          if (store.allows(AppFeature.qrOrdering))
          SwitchRow(
            title: context.l10n.adminRequireCashierOnline,
            hint: context.l10n.adminRequireCashierOnlineHint,
            value: store.requireCashierOnline,
            onChanged: (value) => store.setRequireCashierOnline(value),
          ),
          if (locationCheck) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(flex: 3, child: LabeledField(label: context.l10n.cafeLocationLatitude, child: TextField(controller: lat, keyboardType: numbers))),
              const SizedBox(width: 8),
              Expanded(flex: 3, child: LabeledField(label: context.l10n.cafeLocationLongitude, child: TextField(controller: lng, keyboardType: numbers))),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: LabeledField(label: context.l10n.cafeLocationRadius, child: TextField(controller: radius, keyboardType: TextInputType.number))),
            ],
          ),
          if (validation != null) ...[
            const SizedBox(height: 8),
            Text(validation!, style: const TextStyle(color: CafeColors.alert, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlineAction(label: context.l10n.cafeLocationUseCurrent, height: 44, onPressed: _useCurrent),
              NavyButton(label: context.l10n.cafeLocationSave, onPressed: saving ? null : _save),
              Text(context.l10n.cafeLocationGpsNote, style: const TextStyle(color: TawlaTokens.muted, fontSize: 12)),
            ],
          ),
          ],
        ],
      ),
    );
  }
}

/// Settings: which takeout counter the cashiers get. Two big buttons, each with a small picture of
/// its screen; the choice is kept only when Save is pressed.
class TakeoutLayoutCard extends StatefulWidget {
  const TakeoutLayoutCard({super.key});

  @override
  State<TakeoutLayoutCard> createState() => _TakeoutLayoutCardState();
}

class _TakeoutLayoutCardState extends State<TakeoutLayoutCard> {
  /// The option picked on screen; null until the admin picks, then the saved one is not shown.
  bool? picked;
  var saving = false;

  Future<void> _save(CafeStore store, bool cards) async {
    final l10n = context.l10n;
    setState(() => saving = true);
    String message;
    try {
      await store.setTakeoutCards(cards);
      message = l10n.takeoutLayoutSaved;
    } on Exception catch (error, stackTrace) {
      reportError('takeout layout', error, stackTrace);
      message = l10n.takeoutLayoutSaveFailed;
    }
    if (!mounted) return;
    setState(() {
      saving = false;
      picked = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CafeStore>();
    final cards = picked ?? store.takeoutCards;
    final changed = cards != store.takeoutCards;
    return TawlaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(context.l10n.takeoutScreenTitle, size: 18),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _TakeoutLayoutOption(
                  title: context.l10n.takeoutLayoutClassic,
                  hint: context.l10n.takeoutLayoutClassicHint,
                  selected: !cards,
                  picture: const _LayoutPicture(cards: false),
                  onTap: () => setState(() => picked = false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TakeoutLayoutOption(
                  title: context.l10n.takeoutLayoutCards,
                  hint: context.l10n.takeoutLayoutCardsHint,
                  selected: cards,
                  picture: const _LayoutPicture(cards: true),
                  onTap: () => setState(() => picked = true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: NavyButton(
              label: context.l10n.takeoutLayoutSave,
              height: 44,
              onPressed: changed && !saving ? () => _save(store, cards) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _TakeoutLayoutOption extends StatelessWidget {
  const _TakeoutLayoutOption({
    required this.title,
    required this.hint,
    required this.selected,
    required this.picture,
    required this.onTap,
  });

  final String title;
  final String hint;
  final bool selected;
  final Widget picture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = CafeSurfaces.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      excludeSemantics: true,
      child: Material(
        color: CafeColors.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? surfaces.button : CafeColors.line, width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(aspectRatio: 1.5, child: picture),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: CafeColors.ink))),
                    if (selected) Icon(Icons.check_circle, size: 20, color: surfaces.button),
                  ],
                ),
                const SizedBox(height: 4),
                Text(hint, style: const TextStyle(color: CafeColors.inkMuted, fontSize: 12, height: 1.35)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small drawing of the takeout counter: a category bar over dishes, or a grid of category cards.
class _LayoutPicture extends StatelessWidget {
  const _LayoutPicture({required this.cards});

  final bool cards;

  @override
  Widget build(BuildContext context) {
    final accent = CafeSurfaces.of(context).button;
    Widget box({Color? color, bool border = true}) => Expanded(
          child: Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: color ?? Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: border ? Border.all(color: CafeColors.line) : null,
            ),
          ),
        );
    Widget pill(bool on) => Container(
          width: 26,
          height: 10,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: on ? accent : Colors.white,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: on ? accent : CafeColors.line),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: CafeColors.creamDark, borderRadius: BorderRadius.circular(10)),
      child: cards
          ? Column(
              children: [
                Expanded(child: Row(children: [box(color: const Color(0xFFE9B48F)), box(color: const Color(0xFF9CC3E0))])),
                Expanded(child: Row(children: [box(color: const Color(0xFFB9D9A8)), box(color: const Color(0xFFE6C6D8))])),
              ],
            )
          : Column(
              children: [
                Row(children: [pill(true), pill(false), pill(false), pill(false)]),
                const SizedBox(height: 4),
                Expanded(child: Row(children: [box(), box(), box()])),
                Expanded(child: Row(children: [box(), box(), box()])),
              ],
            ),
    );
  }
}
