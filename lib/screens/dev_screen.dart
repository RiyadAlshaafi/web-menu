import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/app_database.dart';
import '../csv_safe.dart';
import '../save_bytes.dart';
import '../dev_logs.dart';
import '../state/cafe_store.dart';
import '../theme/cafe_theme.dart';
import '../widgets/cafe_widgets.dart';

class DevScreen extends StatefulWidget {
  const DevScreen({super.key, required this.password});

  final String password;

  @override
  State<DevScreen> createState() => _DevScreenState();
}

class _DevScreenState extends State<DevScreen> {
  bool exporting = false;
  String? notice;
  List<Map<String, dynamic>> slots = [];
  int? selectedSlot;
  bool slotsLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSlots());
  }

  @override
  void dispose() {
    AppDatabase.instance.devSlot = null;
    super.dispose();
  }

  Map<String, dynamic>? get _selected {
    for (final slot in slots) {
      if (slot['slot'] == selectedSlot) return slot;
    }
    return null;
  }

  Future<void> _loadSlots() async {
    final result = await AppDatabase.instance.devCall('dev_list_slots', widget.password);
    if (!mounted) return;
    final raw = result?['slots'];
    setState(() {
      slotsLoading = false;
      if (result?['ok'] != true || raw is! List) {
        notice = 'Could not load the cafe slots. Apply the multi-cafe migration first.';
        return;
      }
      slots = [for (final row in raw) Map<String, dynamic>.from(row as Map)];
      selectedSlot ??= AppDatabase.instance.boundSlot ?? (slots.isEmpty ? null : slots.first['slot'] as int?);
      AppDatabase.instance.devSlot = selectedSlot;
    });
  }

  void _select(int slot) {
    setState(() => selectedSlot = slot);
    AppDatabase.instance.devSlot = slot;
  }

  Future<void> _linkDevice() async {
    final slot = selectedSlot;
    if (slot == null) return;
    final error = await context.read<CafeStore>().linkDeviceToSlot(slot);
    if (!mounted) return;
    setState(() => notice = error ?? 'This device is now linked to cafe slot $slot.');
    await _loadSlots();
  }

  Future<void> _issueCode() async {
    final slot = selectedSlot;
    if (slot == null) return;
    final result = await AppDatabase.instance.devCall('dev_issue_setup_code', widget.password, {'p_slot': slot});
    if (!mounted) return;
    final code = result?['code'];
    if (result?['ok'] != true || code is! String) {
      setState(() => notice = '${result?['error'] ?? 'Could not issue a setup code.'}');
      return;
    }
    await _showCode(slot, code);
    if (mounted) await _loadSlots();
  }

  Future<void> _showCode(int slot, String code) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Setup code for cafe slot $slot'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(code, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 2)),
            const SizedBox(height: 8),
            const Text('Shown once and works once. Give it to the cafe owner to create their admin account.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: code)),
            child: const Text('Copy'),
          ),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ],
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    bool requireCheckbox = false,
    String actionLabel = 'Delete',
  }) async {
    final typed = TextEditingController();
    var checked = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(body),
              const SizedBox(height: 12),
              TextField(
                controller: typed,
                decoration: const InputDecoration(labelText: 'Type DELETE to confirm'),
                onChanged: (_) => setLocal(() {}),
              ),
              if (requireCheckbox)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: checked,
                  title: const Text('I understand this cannot be undone.'),
                  onChanged: (value) => setLocal(() => checked = value ?? false),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB42318)),
              onPressed: typed.text == 'DELETE' && (!requireCheckbox || checked)
                  ? () => Navigator.pop(context, true)
                  : null,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
    typed.dispose();
    return ok == true;
  }

  Future<void> _resetAdmin() async {
    final store = context.read<CafeStore>();
    final go = await _confirm(
      title: 'Reset admin',
      body: 'This deletes the admin profile and the matching auth user for this restaurant. You will have to create a new admin. This cannot be undone.',
    );
    if (!go || !mounted) return;
    final result = await AppDatabase.instance.devCall('dev_reset_admin', widget.password);
    if (!mounted) return;
    if (result?['ok'] != true) {
      setState(() => notice = 'Reset did not run.');
      return;
    }
    await store.db.refreshFromDisk();
    store.admin = null;
    store.signOut();
    // A new admin now needs a setup code, so issue one right away.
    final slot = selectedSlot;
    if (slot != null) {
      final issued = await AppDatabase.instance.devCall('dev_issue_setup_code', widget.password, {'p_slot': slot});
      final code = issued?['code'];
      if (mounted && code is String) await _showCode(slot, code);
    }
    if (!mounted) return;
    await _loadSlots();
    if (mounted && selectedSlot == store.deviceSlot) context.go('/admin/setup');
  }

  void _fail(Object error) {
    if (!mounted) return;
    setState(() {
      exporting = false;
      notice = '$error';
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
  }

  Future<void> _export() async {
    setState(() {
      exporting = true;
      notice = null;
    });
    try {
      final result = await AppDatabase.instance.devCall('dev_export_logs', widget.password);
      if (!mounted) return;
      if (result == null || result['ok'] != true) {
        _fail(result?['error'] ?? 'Export did not run.');
        return;
      }
      final payments = result['payments'];
      final expenses = result['expenses'];
      if (payments is! List || expenses is! List) {
        _fail('Export returned an unexpected result.');
        return;
      }
      final receiptBytes = utf8.encode(_receiptsCsv(payments));
      final expenseBytes = utf8.encode(_expensesCsv(expenses));
      setState(() => exporting = false);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Save logs'),
          content: Text('Ready to save ${payments.length} receipts and ${expenses.length} expenses.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            FilledButton(
              onPressed: () => _saveCsv(context, 'Save receipts', 'all-receipts.csv', receiptBytes),
              child: const Text('Save receipts'),
            ),
            FilledButton(
              onPressed: () => _saveCsv(context, 'Save expenses', 'all-expenses.csv', expenseBytes),
              child: const Text('Save expenses'),
            ),
          ],
        ),
      );
    } catch (error) {
      _fail(error);
    }
  }

  Future<void> _saveCsv(BuildContext context, String title, String fileName, List<int> bytes) async {
    try {
      final path = await saveBytesFile(
        dialogTitle: title,
        fileName: fileName,
        bytes: Uint8List.fromList(bytes),
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      if (!context.mounted) return;
      if (path == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$fileName was not saved.')));
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _import() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      allowMultiple: true,
      withData: true,
    );
    if (picked == null || !mounted) return;
    final files = <String, String>{};
    for (final file in picked.files) {
      final bytes = file.bytes;
      if (bytes == null) {
        _fail('${file.name} could not be read.');
        return;
      }
      files[file.name] = utf8.decode(bytes);
    }
    final DevLogBackup backup;
    try {
      backup = parseDevLogFiles(files);
    } on FormatException catch (error) {
      _fail(error.message);
      return;
    }
    final go = await _confirm(
      title: 'Import logs',
      body: 'This will import ${backup.receipts.length} receipts and ${backup.expenses.length} expense entries as new rows. Existing logs stay. This is hard to undo by hand.',
      actionLabel: 'Import',
    );
    if (!go || !mounted) return;
    try {
      final result = await AppDatabase.instance.devCall('dev_import_logs', widget.password, {
        'p_receipts': [for (final receipt in backup.receipts) receipt.toJson()],
        'p_expenses': [for (final expense in backup.expenses) expense.toJson()],
      });
      if (!mounted) return;
      if (result == null || result['ok'] != true) {
        _fail(result?['error'] ?? 'Import did not run.');
        return;
      }
      setState(() => notice = 'Imported ${result['receipts']} receipts and ${result['expenses']} expenses.');
    } catch (error) {
      _fail(error);
    }
  }

  Future<void> _wipeLogs() async {
    final go = await _confirm(
      title: 'Delete all logs',
      body: 'This permanently deletes every receipt, order line, order, and expense for this restaurant, and resets the receipt number counters. Shifts themselves stay. This cannot be undone.',
      requireCheckbox: true,
    );
    if (!go || !mounted) return;
    final result = await AppDatabase.instance.devCall('dev_wipe_logs', widget.password);
    if (!mounted) return;
    setState(() => notice = result?['ok'] == true ? 'Logs deleted.' : 'Delete did not run.');
  }

  Future<void> _wipeMenu() async {
    final go = await _confirm(
      title: 'Delete all dishes',
      body: 'This permanently deletes every dish and category. Past receipts keep their saved item names and prices. This cannot be undone.',
    );
    if (!go || !mounted) return;
    final result = await AppDatabase.instance.devCall('dev_wipe_menu', widget.password);
    if (!mounted) return;
    setState(() => notice = result?['ok'] == true ? 'Menu deleted.' : 'Delete did not run.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CafeColors.paper,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Developer', style: CafeTheme.display.copyWith(fontSize: 32)),
          const SizedBox(height: 8),
          const Text('These tools are not linked from the rest of the app.'),
          if (notice != null) ...[
            const SizedBox(height: 12),
            Text(notice!, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 16),
          _slotCard(),
          if (selectedSlot != null) _DevicesCard(key: ValueKey(selectedSlot), password: widget.password),
          _card(
            title: 'Reset admin',
            body: 'Removes the current admin account so a new one can be created.',
            label: 'Reset admin',
            danger: true,
            onPressed: selectedSlot == null ? null : _resetAdmin,
          ),
          _card(
            title: 'Download all logs',
            body: 'Saves every receipt and every expense for this restaurant, with no date filter.',
            label: exporting ? 'Exporting…' : 'Export',
            danger: false,
            onPressed: exporting || selectedSlot == null ? null : _export,
          ),
          _card(
            title: 'Import logs',
            body: 'Restores receipts and expenses from the files saved by Download all logs.',
            label: 'Import',
            danger: true,
            onPressed: selectedSlot == null ? null : _import,
          ),
          _card(
            title: 'Delete all logs',
            body: 'Permanently deletes every receipt, order, and expense.',
            label: 'Delete all logs',
            danger: true,
            onPressed: selectedSlot == null ? null : _wipeLogs,
          ),
          _card(
            title: 'Delete all dishes',
            body: 'Permanently empties the menu. Past receipts keep their item text.',
            label: 'Delete all dishes',
            danger: true,
            onPressed: selectedSlot == null ? null : _wipeMenu,
          ),
        ],
      ),
    );
  }

  Widget _slotCard() {
    final store = context.watch<CafeStore>();
    final current = _selected;
    final adminSet = current?['has_admin'] == true;
    final name = current?['name'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cafe slots', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 6),
            Text(
              store.deviceSlot == null
                  ? 'This device is not linked to a cafe yet.'
                  : 'This device is linked to cafe slot ${store.deviceSlot}.',
            ),
            const SizedBox(height: 12),
            if (slotsLoading)
              const LinearProgressIndicator()
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final slot in slots)
                    ChoiceChip(
                      label: Text('${slot['slot']}${slot['has_admin'] == true ? ' \u2713' : ''}'),
                      selected: slot['slot'] == selectedSlot,
                      onSelected: (_) => _select(slot['slot'] as int),
                    ),
                ],
              ),
            if (current != null) ...[
              const SizedBox(height: 12),
              Text(
                'Slot ${current['slot']}: ${name != null && name.isNotEmpty ? name : '(no name yet)'}'
                ' \u00b7 link /c/${current['slug']} \u00b7 ${adminSet ? 'has an admin' : 'no admin yet'}'
                '${current['has_setup_code'] == true ? ' \u00b7 setup code pending' : ''}',
              ),
              const SizedBox(height: 4),
              const Text('Every action below applies to the selected slot.', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: CafeColors.terracotta),
                    onPressed: store.deviceSlot == selectedSlot ? null : _linkDevice,
                    child: const Text('Link this device to this slot'),
                  ),
                  OutlinedButton(
                    onPressed: adminSet ? null : _issueCode,
                    child: const Text('Issue setup code'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _card({
    required String title,
    required String body,
    required String label,
    required bool danger,
    required VoidCallback? onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 6),
            Text(body),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: danger ? const Color(0xFFB42318) : CafeColors.terracotta,
              ),
              onPressed: onPressed,
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

String _receiptsCsv(List<dynamic> payments) {
  final buffer = StringBuffer('paid_at,receipt,monthly,table,service,item,qty,unit_price,total_due\n');
  for (final raw in payments) {
    final row = Map<String, dynamic>.from(raw as Map);
    final lines = row['lines'] as List? ?? const [];
    if (lines.isEmpty) {
      buffer.writeln([
        row['paid_at'],
        row['shift_display_number'],
        row['monthly_display_number'],
        row['service_type'] == 'takeout' ? 'Takeout' : row['table_number'],
        row['service_type'],
        '',
        '',
        '',
        row['total_due'],
      ].map(csvCell).join(','));
      continue;
    }
    for (final lineRaw in lines) {
      final line = Map<String, dynamic>.from(lineRaw as Map);
      buffer.writeln([
        row['paid_at'],
        row['shift_display_number'],
        row['monthly_display_number'],
        row['service_type'] == 'takeout' ? 'Takeout' : row['table_number'],
        row['service_type'],
        line['name'],
        line['qty'],
        line['unit_price'],
        row['total_due'],
      ].map(csvCell).join(','));
    }
  }
  return buffer.toString();
}

String _expensesCsv(List<dynamic> expenses) {
  final buffer = StringBuffer('created_at,amount,description,kind,paid_to_cafe\n');
  for (final raw in expenses) {
    final row = Map<String, dynamic>.from(raw as Map);
    buffer.writeln([
      row['created_at'],
      row['amount'],
      row['description'],
      row['kind'],
      row['paid_to_cafe'],
    ].map(csvCell).join(','));
  }
  return buffer.toString();
}

/// App version of every signed-in till of the selected slot, and the oldest version still allowed.
/// Old database columns or functions are removed only once every till shows the new version.
class _DevicesCard extends StatefulWidget {
  const _DevicesCard({super.key, required this.password});

  final String password;

  @override
  State<_DevicesCard> createState() => _DevicesCardState();
}

class _DevicesCardState extends State<_DevicesCard> {
  final minVersion = TextEditingController();
  List<Map<String, dynamic>> devices = [];
  String? message;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    minVersion.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final result = await AppDatabase.instance.devCall('dev_list_devices', widget.password);
    if (!mounted) return;
    setState(() {
      loading = false;
      if (result?['ok'] != true) {
        message = 'Could not load the tills. Apply the app-updates migration first.';
        return;
      }
      devices = [for (final row in (result!['devices'] as List? ?? const [])) Map<String, dynamic>.from(row as Map)];
      minVersion.text = result['min_app_version'] as String? ?? '';
    });
  }

  Future<void> _saveMin() async {
    final result = await AppDatabase.instance.devCall(
      'dev_set_min_app_version',
      widget.password,
      {'p_version': minVersion.text.trim()},
    );
    if (!mounted) return;
    setState(
      () => message = result?['ok'] == true
          ? 'Minimum version is now ${result!['min_app_version']}. Older tills must update before signing in.'
          : (result?['error'] as String? ?? 'Not saved.'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = context.select<CafeStore, String>((store) => store.appVersion);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tills and app versions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 6),
            Text('This device runs ${current.isEmpty ? 'an unknown version' : current}. Tills report their version while a cashier is signed in.'),
            const SizedBox(height: 12),
            if (loading)
              const LinearProgressIndicator()
            else if (devices.isEmpty)
              const Text('No signed-in tills right now.')
            else
              for (final device in devices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${device['online'] == true ? '\u25cf' : '\u25cb'} '
                    '${(device['cashier'] as String?)?.isNotEmpty == true ? device['cashier'] : 'Cashier'}'
                    ' \u00b7 ${(device['app_version'] as String?)?.isNotEmpty == true ? 'version ${device['app_version']}' : 'old app (no version)'}',
                  ),
                ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: minVersion,
                    decoration: const InputDecoration(labelText: 'Minimum version', hintText: '1.2.0'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(onPressed: _saveMin, child: const Text('Save')),
                const SizedBox(width: 8),
                TextButton(onPressed: _load, child: const Text('Refresh')),
              ],
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ],
        ),
      ),
    );
  }
}
