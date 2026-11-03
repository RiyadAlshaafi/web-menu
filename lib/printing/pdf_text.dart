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

/// The pdf package draws Arabic vowel marks (such as the ً in نقداً) as stray glyphs over the
/// next letter, so they are left off printouts.
String pdfStripMarks(String value) => value.replaceAll(RegExp(r'[ً-ْ]'), '');

/// [value] cut into runs of Arabic words and runs of other words, in reading order.
/// "1× قهوة تركية" gives ["1", "×", "قهوة تركية"]; "قهوة (3)" gives ["قهوة", "(3)"].
/// A sign at the end of a number (the × of a quantity) is its own run, so on an Arabic line it
/// sits between the number and the word, as it reads.
List<String> pdfRuns(String value) {
  final runs = <String>[];
  bool? lastArabic;
  for (final word in value.trim().split(RegExp(r'\s+'))) {
    if (word.isEmpty) continue;
    final arabic = pdfHasArabic(word);
    if (arabic == lastArabic) {
      runs[runs.length - 1] = '${runs.last} $word';
    } else {
      runs.add(word);
    }
    lastArabic = arabic;
  }
  return [
    for (final run in runs)
      if (pdfHasArabic(run)) run else ...(_splitSign(run) ?? [run]),
  ];
}

List<String>? _splitSign(String run) {
  final match = RegExp(r'^(.*[0-9])([×x:])$').firstMatch(run);
  return match == null ? null : [match[1]!, match[2]!];
}

/// Draws [value] with Noto Naskh Arabic embedded.
/// Arabic strings are shaped and laid out right-to-left by the pdf package.
/// English strings stay left-to-right.
/// The pdf package mixes up numbers and brackets inside Arabic text ("قهوة (1)" printed the
/// bracket over the 1), so a line with both is drawn as separate runs placed right to left,
/// each run in its own direction. Set [fixedWidth] where the text gets no width limit (the amount
/// beside a label), so those runs keep their own width instead of wrapping.
pw.Widget pdfText(
  String value, {
  pw.TextAlign? align,
  double? size,
  bool bold = false,
  bool fixedWidth = false,
}) {
  final arabic = pdfHasArabic(value);
  // Neither embedded font has the long dash shown for an empty value.
  final text = pdfStripMarks(value.replaceAll('—', '-'));
  final style = pw.TextStyle(
    font: bold ? PdfFonts.bold : PdfFonts.regular,
    fontFallback: [bold ? PdfFonts._helveticaBold : PdfFonts._helvetica],
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    fontSize: size,
  );
  pw.Text run(String run, bool rtl, {pw.TextAlign? align}) => pw.Text(
        rtl ? pdfMirrorBrackets(run) : run,
        textAlign: align ?? (rtl ? pw.TextAlign.right : pw.TextAlign.left),
        textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        style: style,
      );
  final runs = arabic ? pdfRuns(text) : const <String>[];
  if (runs.length < 2) return run(text, arabic, align: align);
  final gap = (size ?? 10) * 0.3;
  final indent = (text.length - text.trimLeft().length) * gap;
  // The first run sits on the right, so the row lists the runs last to first.
  return pw.Padding(
    padding: pw.EdgeInsets.only(right: indent),
    child: pw.Row(
      mainAxisAlignment: switch (align) {
        pw.TextAlign.center => pw.MainAxisAlignment.center,
        pw.TextAlign.left => pw.MainAxisAlignment.start,
        _ => pw.MainAxisAlignment.end,
      },
      mainAxisSize: fixedWidth ? pw.MainAxisSize.min : pw.MainAxisSize.max,
      children: [
        for (final (index, part) in runs.reversed.indexed) ...[
          if (index > 0) pw.SizedBox(width: gap),
          // Only Arabic words wrap; a number or date always prints whole.
          if (fixedWidth || !pdfHasArabic(part))
            run(part, pdfHasArabic(part), align: pw.TextAlign.left)
          else
            pw.Flexible(child: run(part, pdfHasArabic(part), align: pw.TextAlign.left)),
        ],
      ],
    ),
  );
}

pw.Widget pdfPair(String label, String value) {
  final arabic = pdfHasArabic(label) || pdfHasArabic(value);
  final labelText = pdfText(label, align: arabic ? pw.TextAlign.right : null);
  final valueText = pdfText(value, fixedWidth: true);
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: arabic ? [valueText, pw.Expanded(child: labelText)] : [pw.Expanded(child: labelText), valueText],
  );
}
