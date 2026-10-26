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
      fontFallback: [_helvetica, _helveticaBold],
    );
  }

  static pw.Font get regular => _regular!;
  static pw.Font get bold => _bold!;

  static final pw.Font _helvetica = pw.Font.helvetica();
  static final pw.Font _helveticaBold = pw.Font.helveticaBold();
}

bool pdfHasArabic(String value) => RegExp(r'[\u0600-\u06FF]').hasMatch(value);

/// The pdf package lays Arabic out right to left but does not mirror brackets, so "(x)" would
/// print as ")x(". Swapping them first makes them print the right way round.
String pdfMirrorBrackets(String value) {
  const pairs = {'(': ')', ')': '(', '[': ']', ']': '[', '{': '}', '}': '{', '<': '>', '>': '<'};
  return value.split('').map((char) => pairs[char] ?? char).join();
}

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
  // Neither embedded font has the long dash shown for an empty value.
  final text = value.replaceAll('—', '-');
  return pw.Text(
    arabic ? pdfMirrorBrackets(text) : text,
    textAlign: align ?? (arabic ? pw.TextAlign.right : pw.TextAlign.left),
    textDirection: arabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
    style: pw.TextStyle(
      font: bold ? PdfFonts.bold : PdfFonts.regular,
      fontFallback: [bold ? PdfFonts._helveticaBold : PdfFonts._helvetica],
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
