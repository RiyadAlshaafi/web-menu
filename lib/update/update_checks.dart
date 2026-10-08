import '../offline/outbox_store.dart';

/// Why an update can't be installed right now. Every one of them protects sales data.
enum UpdateBlock {
  /// Updates only install from the cashier sign-in screen, never during a sale.
  signedIn,

  /// The server can't be reached, so the till's uploads can't be confirmed.
  offline,

  /// Sales or expenses made offline are still waiting to upload.
  pendingUploads,

  /// The server refused some uploads; they need a look before anything else.
  failedUploads,

  /// The server is missing receipts or expenses this till uploaded.
  serverMissing,

  /// The installer could not be downloaded, or it failed its fingerprint check.
  download,

  /// The backup of the till's data could not be written.
  backup,
}

/// Count and total of receipts and expenses, from the till or from the server.
class UploadSummary {
  const UploadSummary({
    required this.receipts,
    required this.receiptsTotal,
    required this.expenses,
    required this.expensesTotal,
  });

  factory UploadSummary.ofSent(List<SentRecord> sent) {
    var receipts = 0;
    var receiptsTotal = 0.0;
    var expenses = 0;
    var expensesTotal = 0.0;
    for (final record in sent) {
      if (record.kind == 'takeout') {
        receipts++;
        receiptsTotal += record.amount;
      } else if (record.kind == 'expense') {
        expenses++;
        expensesTotal += record.amount;
      }
    }
    return UploadSummary(
      receipts: receipts,
      receiptsTotal: _cents(receiptsTotal),
      expenses: expenses,
      expensesTotal: _cents(expensesTotal),
    );
  }

  /// Reads the answer of the `confirm_uploads` server function.
  factory UploadSummary.fromServer(Map<String, dynamic> json) => UploadSummary(
    receipts: (json['receipts'] as num?)?.toInt() ?? 0,
    receiptsTotal: _cents((json['receipts_total'] as num?)?.toDouble() ?? 0),
    expenses: (json['expenses'] as num?)?.toInt() ?? 0,
    expensesTotal: _cents((json['expenses_total'] as num?)?.toDouble() ?? 0),
  );

  factory UploadSummary.fromJson(Map<String, dynamic> json) => UploadSummary.fromServer(json);

  final int receipts;
  final double receiptsTotal;
  final int expenses;
  final double expensesTotal;

  UploadSummary operator +(UploadSummary other) => UploadSummary(
    receipts: receipts + other.receipts,
    receiptsTotal: _cents(receiptsTotal + other.receiptsTotal),
    expenses: expenses + other.expenses,
    expensesTotal: _cents(expensesTotal + other.expensesTotal),
  );

  /// Same counts and same totals to the cent.
  bool matches(UploadSummary other) =>
      receipts == other.receipts &&
      expenses == other.expenses &&
      (receiptsTotal - other.receiptsTotal).abs() < 0.005 &&
      (expensesTotal - other.expensesTotal).abs() < 0.005;

  Map<String, dynamic> toJson() => {
    'receipts': receipts,
    'receipts_total': receiptsTotal,
    'expenses': expenses,
    'expenses_total': expensesTotal,
  };

  static const empty = UploadSummary(receipts: 0, receiptsTotal: 0, expenses: 0, expensesTotal: 0);

  static double _cents(double value) => (value * 100).roundToDouble() / 100;
}

/// Asks the server about [ids] in chunks (the server takes up to 5000 at a time) and adds the answers.
Future<UploadSummary> confirmOnServer(
  List<String> ids,
  Future<Map<String, dynamic>> Function(List<String> chunk) ask, {
  int chunkSize = 2000,
}) async {
  var total = UploadSummary.empty;
  for (var start = 0; start < ids.length; start += chunkSize) {
    final end = start + chunkSize > ids.length ? ids.length : start + chunkSize;
    final answer = await ask(ids.sublist(start, end));
    if (answer['ok'] != true) throw StateError('confirm_uploads refused: $answer');
    total = total + UploadSummary.fromServer(answer);
  }
  return total;
}

/// The local checks that come before asking the server: signed out, nothing waiting, nothing refused.
UpdateBlock? localUpdateBlock({required bool signedIn, required int pending, required int failed}) {
  if (signedIn) return UpdateBlock.signedIn;
  if (pending > 0) return UpdateBlock.pendingUploads;
  if (failed > 0) return UpdateBlock.failedUploads;
  return null;
}
