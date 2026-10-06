import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:menu_web_v1/pdf_text.dart';
import 'package:menu_web_v1/save_bytes.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

Future<Uint8List?> tableQrPng(String data) async {
  final painter = QrPainter(data: data, version: QrVersions.auto, gapless: true);
  final image = await painter.toImageData(512);
  return image?.buffer.asUint8List();
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
