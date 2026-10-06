import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// Shared Arabic-capable font for every PDF. The app UI keeps its own font.
class PdfFonts {
  static pw.Font? _regular;
  static pw.Font? _bold;

  static Future<pw.ThemeData> theme() async {
    _regular ??= pw.Font.ttf(await rootBundle.load('assets/fonts/NotoNaskhArabic-Regular.ttf'));
    _bold ??= pw.Font.ttf(await rootBundle.load('assets/fonts/NotoNaskhArabic-Bold.ttf'));
    return pw.ThemeData.withFont(
      base: _regular,
      bold: _bold,
      fontFallback: [pw.Font.helvetica(), pw.Font.helveticaBold()],
    );
  }

  static pw.Font get regular => _regular!;
  static pw.Font get bold => _bold!;
}

bool pdfHasArabic(String value) => RegExp(r'[\u0600-\u06FF]').hasMatch(value);

/// Draws [value] with Noto Naskh Arabic embedded.
/// Arabic strings are shaped and laid out right-to-left by the pdf package.
/// English strings stay left-to-right.
pw.Text pdfText(
  String value, {
  pw.TextAlign? align,
  double? size,
  bool bold = false,
}) {
  final arabic = pdfHasArabic(value);
  return pw.Text(
    value,
    textAlign: align ?? (arabic ? pw.TextAlign.right : pw.TextAlign.left),
    textDirection: arabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
    style: pw.TextStyle(
      font: bold ? PdfFonts.bold : PdfFonts.regular,
      fontFallback: [bold ? pw.Font.helveticaBold() : pw.Font.helvetica()],
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      fontSize: size,
    ),
  );
}

pw.Widget pdfPair(String label, String value) {
  final labelText = pdfText(label);
  final valueText = pdfText(value);
  final arabic = pdfHasArabic(label) || pdfHasArabic(value);
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: arabic ? [valueText, pw.Expanded(child: labelText)] : [pw.Expanded(child: labelText), valueText],
  );
}
