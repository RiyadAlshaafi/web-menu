import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:menu_web_v1/pdf_text.dart';
import 'package:menu_web_v1/save_bytes.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Draws [data] as a QR code on an opaque white square with a blank border
/// (the "quiet zone" scanners need). A transparent, edge-to-edge image reads
/// badly on dark viewers and when printed on coloured paper.
Future<Uint8List?> tableQrPng(String data, {int size = 768}) async {
  final painter = QrPainter(
    data: data,
    version: QrVersions.auto,
    errorCorrectionLevel: QrErrorCorrectLevel.Q,
    gapless: true,
  );
  final side = size.toDouble();
  final margin = side * 0.12;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, side, side), ui.Paint()..color = const ui.Color(0xFFFFFFFF));
  canvas.translate(margin, margin);
  painter.paint(canvas, ui.Size(side - margin * 2, side - margin * 2));
  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes?.buffer.asUint8List();
}

Future<String?> saveTableQr({required String url, required String tableNumber}) async {
  final bytes = await tableQrPng(url);
  if (bytes == null) return 'Could not draw the QR code.';
  try {
    final path = await saveBytesFile(
      dialogTitle: 'Save table QR',
      fileName: 'table-$tableNumber.png',
      type: FileType.custom,
      allowedExtensions: const ['png'],
      bytes: bytes,
    );
    if (path == null) return null;
    return null;
  } catch (error) {
    return '$error';
  }
}

Future<String?> printTableQr({
  required String url,
  required String tableNumber,
  required String cafeName,
}) async {
  final bytes = await tableQrPng(url);
  if (bytes == null) return 'Could not draw the QR code.';
  await Printing.layoutPdf(
    name: 'Table $tableNumber',
    onLayout: (PdfPageFormat format) async {
      final theme = await PdfFonts.theme();
      final doc = pw.Document(theme: theme);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a6,
          theme: theme,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pdfText(cafeName, align: pw.TextAlign.center, size: 16, bold: true),
              pw.SizedBox(height: 6),
              pdfText('Table $tableNumber', align: pw.TextAlign.center),
              pw.SizedBox(height: 12),
              pw.Image(pw.MemoryImage(bytes), width: 180, height: 180),
              pw.SizedBox(height: 8),
              pdfText(url, align: pw.TextAlign.center, size: 8),
            ],
          ),
        ),
      );
      return doc.save();
    },
  );
  return null;
}
