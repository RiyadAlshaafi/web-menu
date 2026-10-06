class DevLogBackup {
  DevLogBackup({required this.receipts, required this.expenses});

  final List<DevReceipt> receipts;
  final List<DevExpense> expenses;
}

class DevReceipt {
  DevReceipt({
    required this.paidAt,
    required this.receipt,
    required this.monthly,
    required this.table,
    required this.service,
    required this.totalDue,
    required this.lines,
  });

  final String paidAt;
  final String receipt;
  final String monthly;
  final String table;
  final String service;
  final String totalDue;
  final List<DevReceiptLine> lines;

  Map<String, dynamic> toJson() => {
    'paid_at': paidAt,
    'receipt': receipt,
    'monthly': monthly,
    'table': table,
    'service': service,
    'total_due': totalDue,
    'lines': [
      for (final line in lines)
        {'name': line.name, 'qty': line.qty, 'unit_price': line.unitPrice},
    ],
  };
}

class DevReceiptLine {
  DevReceiptLine({required this.name, required this.qty, required this.unitPrice});

  final String name;
  final int qty;
  final String unitPrice;
}

class DevExpense {
  DevExpense({
    required this.createdAt,
    required this.amount,
    required this.description,
    required this.kind,
    required this.paidToCafe,
  });

  final String createdAt;
  final String amount;
  final String description;
  final String kind;
  final bool paidToCafe;

  Map<String, dynamic> toJson() => {
    'created_at': createdAt,
    'amount': amount,
    'description': description,
    'kind': kind,
    'paid_to_cafe': paidToCafe,
  };
}

const receiptHeader = 'paid_at,receipt,monthly,table,service,item,qty,unit_price,total_due';
const expenseHeader = 'created_at,amount,description,kind,paid_to_cafe';

/// Reads one or more CSV files from a Download All Logs export.
/// Throws [FormatException] before any row is treated as valid if a file
/// does not match either export header.
DevLogBackup parseDevLogFiles(Map<String, String> files) {
  if (files.isEmpty) {
    throw const FormatException('Choose the receipts file, the expenses file, or both.');
  }
  final receipts = <DevReceipt>[];
  final expenses = <DevExpense>[];
  for (final entry in files.entries) {
    final rows = _parseCsv(entry.value);
    if (rows.isEmpty) {
      throw FormatException('${entry.key} is empty.');
    }
    final header = rows.first.join(',');
    if (header == receiptHeader) {
      receipts.addAll(_receipts(rows.skip(1), entry.key));
    } else if (header == expenseHeader) {
      expenses.addAll(_expenses(rows.skip(1), entry.key));
    } else {
      throw FormatException('${entry.key} is not a receipts or expenses export.');
    }
  }
  if (receipts.isEmpty && expenses.isEmpty) {
    throw const FormatException('The file has headers but no rows to import.');
  }
  return DevLogBackup(receipts: receipts, expenses: expenses);
}

List<DevReceipt> _receipts(Iterable<List<String>> rows, String fileName) {
  final grouped = <String, DevReceipt>{};
  var lineNo = 1;
  for (final row in rows) {
    lineNo += 1;
    if (row.every((cell) => cell.trim().isEmpty)) continue;
    if (row.length != 9) {
      throw FormatException('$fileName line $lineNo does not have 9 columns.');
    }
    final service = row[4].trim();
    if (service != 'dine_in' && service != 'takeout') {
      throw FormatException('$fileName line $lineNo has an unknown service.');
    }
    DateTime.parse(row[0].trim());
    final total = row[8].trim();
    if (double.tryParse(total) == null) {
      throw FormatException('$fileName line $lineNo has a bad total.');
    }
    final key = '${row[0].trim()}|${row[1].trim()}|${row[2].trim()}|${row[3].trim()}|$service|$total';
    final receipt = grouped.putIfAbsent(
      key,
      () => DevReceipt(
        paidAt: row[0].trim(),
        receipt: row[1].trim(),
        monthly: row[2].trim(),
        table: row[3].trim(),
        service: service,
        totalDue: total,
        lines: [],
      ),
    );
    final item = row[5].trim();
    if (item.isEmpty) continue;
    final qty = int.tryParse(row[6].trim());
    final price = row[7].trim();
    if (qty == null || qty <= 0 || double.tryParse(price) == null) {
      throw FormatException('$fileName line $lineNo has a bad item quantity or price.');
    }
    receipt.lines.add(DevReceiptLine(name: item, qty: qty, unitPrice: price));
  }
  return grouped.values.toList();
}

List<DevExpense> _expenses(Iterable<List<String>> rows, String fileName) {
  final expenses = <DevExpense>[];
  var lineNo = 1;
  for (final row in rows) {
    lineNo += 1;
    if (row.every((cell) => cell.trim().isEmpty)) continue;
    if (row.length != 5) {
      throw FormatException('$fileName line $lineNo does not have 5 columns.');
    }
    DateTime.parse(row[0].trim());
    if (double.tryParse(row[1].trim()) == null) {
      throw FormatException('$fileName line $lineNo has a bad amount.');
    }
    final paid = row[4].trim().toLowerCase();
    if (paid != 'true' && paid != 'false') {
      throw FormatException('$fileName line $lineNo has a bad paid_to_cafe value.');
    }
    expenses.add(
      DevExpense(
        createdAt: row[0].trim(),
        amount: row[1].trim(),
        description: row[2].trim(),
        kind: row[3].trim().isEmpty ? 'cash_out' : row[3].trim(),
        paidToCafe: paid == 'true',
      ),
    );
  }
  return expenses;
}

List<List<String>> _parseCsv(String source) {
  final rows = <List<String>>[];
  final row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  final text = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (quoted) {
      if (char == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i += 1;
        } else {
          quoted = false;
        }
      } else {
        cell.write(char);
      }
      continue;
    }
    if (char == '"') {
      quoted = true;
    } else if (char == ',') {
      row.add(cell.toString());
      cell.clear();
    } else if (char == '\n') {
      row.add(cell.toString());
      cell.clear();
      rows.add(List<String>.from(row));
      row.clear();
    } else {
      cell.write(char);
    }
  }
  if (quoted) throw const FormatException('A quoted value was not closed.');
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(List<String>.from(row));
  }
  return rows;
}
