import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/app_database.dart';
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
    if (mounted) context.go('/admin/setup');
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
          _card(
            title: 'Reset admin',
            body: 'Removes the current admin account so a new one can be created.',
            label: 'Reset admin',
            danger: true,
            onPressed: _resetAdmin,
          ),
          _card(
            title: 'Download all logs',
            body: 'Saves every receipt and every expense for this restaurant, with no date filter.',
            label: exporting ? 'Exporting…' : 'Export',
            danger: false,
            onPressed: exporting ? null : _export,
          ),
          _card(
            title: 'Import logs',
            body: 'Restores receipts and expenses from the files saved by Download all logs.',
            label: 'Import',
            danger: true,
            onPressed: _import,
          ),
          _card(
            title: 'Delete all logs',
            body: 'Permanently deletes every receipt, order, and expense.',
            label: 'Delete all logs',
            danger: true,
            onPressed: _wipeLogs,
          ),
          _card(
            title: 'Delete all dishes',
            body: 'Permanently empties the menu. Past receipts keep their item text.',
            label: 'Delete all dishes',
            danger: true,
            onPressed: _wipeMenu,
          ),
        ],
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

String _cell(Object? value) => '"${'$value'.replaceAll('"', '""')}"';

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
      ].map(_cell).join(','));
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
      ].map(_cell).join(','));
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
    ].map(_cell).join(','));
  }
  return buffer.toString();
}
