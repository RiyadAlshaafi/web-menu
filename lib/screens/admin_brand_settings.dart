import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';

import '../device_location.dart';
import '../report_error.dart';
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
  late final TextEditingController menuUrl;
  String? pendingLogo;
  bool removeLogo = false;

  @override
  void initState() {
    super.initState();
    final cafe = context.read<CafeStore>().cafe;
    name = TextEditingController(text: (cafe['name'] as String?) ?? '');
    menuUrl = TextEditingController(text: (cafe['publicMenuUrl'] as String?) ?? '');
  }

  @override
  void dispose() {
    name.dispose();
    menuUrl.dispose();
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
          LabeledField(
            label: context.l10n.catalogPublicMenuUrl,
            child: TextField(
              controller: menuUrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(hintText: context.l10n.catalogPublicMenuUrlHint),
            ),
          ),
          const SizedBox(height: 14),
          NavyButton(
            label: context.l10n.catalogSaveCompany,
            onPressed: () async {
              await store.saveCompany(
                name: name.text,
                publicMenuUrl: menuUrl.text,
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
    const numbers = TextInputType.numberWithOptions(decimal: true, signed: true);
    return TawlaPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(context.l10n.settingsOrderingTitle, size: 18),
          const SizedBox(height: 4),
          SwitchRow(
            title: context.l10n.cafeLocationRequire,
            hint: context.l10n.cafeLocationRequireHint,
            value: requireNear,
            onChanged: (value) => setState(() => requireNear = value),
          ),
          SwitchRow(
            title: context.l10n.adminAutoPrintReceipt,
            hint: context.l10n.adminAutoPrintReceiptHint,
            value: store.autoPrintReceipt,
            onChanged: (value) => store.setAutoPrintReceipt(value),
          ),
          SwitchRow(
            title: context.l10n.adminRequireCashierOnline,
            hint: context.l10n.adminRequireCashierOnlineHint,
            value: store.requireCashierOnline,
            onChanged: (value) => store.setRequireCashierOnline(value),
          ),
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
      ),
    );
  }
}
