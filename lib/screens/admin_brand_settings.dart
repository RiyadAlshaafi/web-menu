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
import '../widgets/cafe_widgets.dart';

class AdminBrandSettings extends StatefulWidget {
  const AdminBrandSettings({super.key});

  @override
  State<AdminBrandSettings> createState() => _AdminBrandSettingsState();
}

class _AdminBrandSettingsState extends State<AdminBrandSettings> {
  late final TextEditingController name;
  String? pendingLogo;
  bool removeLogo = false;
  late Color header;
  late Color sidebar;
  late Color background;
  late Color button;

  @override
  void initState() {
    super.initState();
    final store = context.read<CafeStore>();
    name = TextEditingController(text: (store.cafe['name'] as String?) ?? '');
    final surfaces = CafeSurfaces.fromCafe(store.cafe);
    header = surfaces.header;
    sidebar = surfaces.sidebar;
    background = surfaces.background;
    button = surfaces.button;
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
    return Column(
      children: [
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.catalogCompanyInfo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _logoPreview(previewLogo),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(onPressed: _pickLogo, child: Text(context.l10n.catalogChooseLogo)),
                        TextButton(
                          onPressed: () => setState(() {
                            pendingLogo = null;
                            removeLogo = true;
                          }),
                          child: Text(context.l10n.catalogRemoveLogo),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: name, decoration: InputDecoration(labelText: context.l10n.catalogCafeName)),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () async {
                    await store.saveCompany(
                      name: name.text,
                      logoDataUrl: pendingLogo != null && pendingLogo!.startsWith('data:') ? pendingLogo : null,
                      removeLogo: removeLogo,
                    );
                    if (mounted) setState(() => pendingLogo = null);
                  },
                  child: Text(context.l10n.catalogSaveCompany),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.catalogAppearance, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 12),
              _swatch(context.l10n.catalogHeaderColor, header, (color) => setState(() => header = color)),
              _swatch(context.l10n.catalogSidebarColor, sidebar, (color) => setState(() => sidebar = color)),
              _swatch(context.l10n.catalogBackgroundColor, background, (color) => setState(() => background = color)),
              _swatch(context.l10n.catalogButtonColor, button, (color) => setState(() => button = color)),
              const SizedBox(height: 8),
              Container(
                height: 72,
                decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12), border: Border.all(color: CafeColors.line)),
                child: Row(
                  children: [
                    Container(
                      width: 72,
                      color: sidebar,
                      alignment: Alignment.center,
                      child: Text('Aa', style: TextStyle(color: CafeColors.contrastOn(sidebar), fontWeight: FontWeight.w800)),
                    ),
                    Expanded(
                      child: ColoredBox(
                        color: header,
                        child: Align(
                          alignment: Alignment.center,
                          child: Text(name.text.trim().isEmpty ? store.cafeName : name.text.trim(), style: TextStyle(color: CafeColors.contrastOn(header), fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ),
                    Container(
                      width: 72,
                      color: button,
                      alignment: Alignment.center,
                      child: Text('Aa', style: TextStyle(color: CafeColors.contrastOn(button), fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
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
                    child: Text(context.l10n.catalogResetColors),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => store.saveAppearance(header: header, sidebar: sidebar, background: background, button: button),
                    child: Text(context.l10n.catalogSaveColors),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _CafeLocationCard(),
      ],
    );
  }

  Widget _logoPreview(String value) {
    Widget child = const Icon(Icons.local_cafe, color: CafeColors.terracottaDark);
    if (value.startsWith('data:')) {
      final comma = value.indexOf(',');
      if (comma > 0) {
        child = Image.memory(base64Decode(value.substring(comma + 1)), fit: BoxFit.cover);
      }
    } else if (value.startsWith('http')) {
      child = Image.network(value, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.local_cafe));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(width: 64, height: 64, child: ColoredBox(color: CafeColors.key, child: child)),
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

  Widget _swatch(String label, Color color, ValueChanged<Color> onPick) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: InkWell(
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
        child: Container(width: 36, height: 36, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8), border: Border.all(color: CafeColors.line))),
      ),
    );
  }
}

class _CafeLocationCard extends StatefulWidget {
  const _CafeLocationCard();

  @override
  State<_CafeLocationCard> createState() => _CafeLocationCardState();
}

class _CafeLocationCardState extends State<_CafeLocationCard> {
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
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.cafeLocationTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text(context.l10n.cafeLocationRequire, style: const TextStyle(fontWeight: FontWeight.w700))),
              Switch(value: requireNear, onChanged: (value) => setState(() => requireNear = value)),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _useCurrent, child: Text(context.l10n.cafeLocationUseCurrent)),
          const SizedBox(height: 12),
          TextField(controller: lat, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: InputDecoration(labelText: context.l10n.cafeLocationLatitude)),
          const SizedBox(height: 8),
          TextField(controller: lng, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: InputDecoration(labelText: context.l10n.cafeLocationLongitude)),
          const SizedBox(height: 8),
          TextField(controller: radius, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: context.l10n.cafeLocationRadius)),
          const SizedBox(height: 8),
          Text(context.l10n.cafeLocationGpsNote, style: const TextStyle(color: CafeColors.inkMuted, fontSize: 13)),
          if (validation != null) ...[
            const SizedBox(height: 8),
            Text(validation!, style: const TextStyle(color: CafeColors.alert, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: saving ? null : _save,
              child: Text(context.l10n.cafeLocationSave),
            ),
          ),
        ],
      ),
    );
  }
}
