import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:provider/provider.dart';

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
  late final TextEditingController publicUrl;
  String? pendingLogo;
  bool removeLogo = false;
  late Color header;
  late Color sidebar;
  late Color background;

  @override
  void initState() {
    super.initState();
    final store = context.read<CafeStore>();
    name = TextEditingController(text: (store.cafe['name'] as String?) ?? '');
    publicUrl = TextEditingController(text: (store.cafe['publicMenuUrl'] as String?) ?? '');
    final surfaces = CafeSurfaces.fromCafe(store.cafe);
    header = surfaces.header;
    sidebar = surfaces.sidebar;
    background = surfaces.background;
  }

  @override
  void dispose() {
    name.dispose();
    publicUrl.dispose();
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
              const SizedBox(height: 8),
              TextField(controller: publicUrl, decoration: InputDecoration(labelText: context.l10n.catalogPublicMenuUrl, hintText: context.l10n.catalogPublicMenuUrlHint)),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () async {
                    await store.saveCompany(
                      name: name.text,
                      logoDataUrl: pendingLogo != null && pendingLogo!.startsWith('data:') ? pendingLogo : null,
                      removeLogo: removeLogo,
                      publicMenuUrl: publicUrl.text,
                    );
                    if (mounted) setState(() => pendingLogo = null);
                  },
                  style: FilledButton.styleFrom(backgroundColor: CafeColors.terracotta),
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
                      child: Container(
                        color: header,
                        alignment: Alignment.center,
                        child: Text(name.text.trim().isEmpty ? store.cafeName : name.text.trim(), style: TextStyle(color: CafeColors.contrastOn(header), fontWeight: FontWeight.w800)),
                      ),
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
                      });
                    },
                    child: Text(context.l10n.catalogResetColors),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => store.saveAppearance(header: header, sidebar: sidebar, background: background),
                    style: FilledButton.styleFrom(backgroundColor: CafeColors.terracotta),
                    child: Text(context.l10n.catalogSaveColors),
                  ),
                ],
              ),
            ],
          ),
        ),
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
