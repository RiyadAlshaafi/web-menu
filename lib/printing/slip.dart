import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'pdf_text.dart';

/// Paper widths a thermal printer can have, in mm.
const paperWidthsMm = [58, 80];

/// The width every printout had before widths could be picked.
const defaultPaperMm = 80;

/// The page of a thermal roll [paperMm] wide (58 mm paper prints about 48 mm, like a 57 mm roll).
PdfPageFormat rollFormat(int paperMm) => paperMm == 58 ? PdfPageFormat.roll57 : PdfPageFormat.roll80;

/// One line of a thermal printout (receipt, kitchen ticket, report). Each printout is built once
/// as a list of these, and [slipPdf] draws that list for both the preview and the printer, so
/// the two always match.
sealed class SlipLine {
  const SlipLine();
}

/// A line of text, centered or following its language.
final class SlipText extends SlipLine {
  const SlipText(this.text, {this.center = false, this.size = 10, this.bold = false, this.indent = false});

  final String text;
  final bool center;
  final double size;
  final bool bold;

  /// Set in a little, under the line above (a dish's choices on a kitchen ticket).
  final bool indent;

  @override
  String toString() => 'text($text,$center,$size,$bold,$indent)';
}

/// A label and its amount on one line, such as "Total  25.00".
final class SlipPair extends SlipLine {
  const SlipPair(this.label, this.value, {this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  String toString() => 'pair($label,$value,$bold)';
}

final class SlipDivider extends SlipLine {
  const SlipDivider();

  @override
  String toString() => 'divider';
}

final class SlipGap extends SlipLine {
  const SlipGap([this.height = 6]);

  final double height;

  @override
  String toString() => 'gap($height)';
}

/// The cafe logo, from a data: or http address.
final class SlipLogo extends SlipLine {
  const SlipLogo(this.url);

  final String url;

  @override
  String toString() => 'logo(${url.length})';
}

final Map<String, Uint8List> _logoCache = {};

/// Decodes or downloads the logo once per address, so repeat prints skip the fetch.
Future<pw.MemoryImage?> _logoFor(String url) async {
  try {
    var bytes = _logoCache[url];
    if (bytes == null) {
      if (url.startsWith('data:')) {
        bytes = base64Decode(url.split(',').last);
      } else if (url.startsWith('http')) {
        final data = await NetworkAssetBundle(Uri.parse(url)).load(url);
        bytes = data.buffer.asUint8List();
      } else {
        return null;
      }
      _logoCache[url] = bytes;
    }
    return pw.MemoryImage(bytes);
  } catch (_) {
    // A broken or unreachable logo (bad data throws errors, not only exceptions) is left off
    // rather than stopping the print.
    return null;
  }
}

/// Draws [lines] on one roll page [paperMm] wide. On 58 mm paper the text is a little smaller,
/// so a line that fits on 80 mm wraps less.
Future<Uint8List> slipPdf(List<SlipLine> lines, {required int paperMm}) async {
  final theme = await PdfFonts.theme();
  final scale = paperMm == 58 ? 0.85 : 1.0;
  final logos = <String, pw.MemoryImage?>{
    for (final line in lines)
      if (line is SlipLogo) line.url: await _logoFor(line.url),
  };
  final doc = pw.Document(theme: theme);
  doc.addPage(
    pw.Page(
      pageFormat: rollFormat(paperMm),
      theme: theme,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          for (final line in lines)
            switch (line) {
              SlipText(:final text, :final center, :final size, :final bold, :final indent) => pw.Padding(
                  padding: pw.EdgeInsets.symmetric(horizontal: indent ? 12 * scale : 0),
                  child: pdfText(text, align: center ? pw.TextAlign.center : null, size: size * scale, bold: bold),
                ),
              SlipPair(:final label, :final value, :final bold) => _pair(label, value, bold: bold, size: 10 * scale),
              SlipDivider() => pw.Divider(),
              SlipGap(:final height) => pw.SizedBox(height: height),
              SlipLogo(:final url) => switch (logos[url]) {
                  final logo? => pw.Center(child: pw.Image(logo, height: 48 * scale)),
                  null => pw.SizedBox(),
                },
            },
        ],
      ),
    ),
  );
  return doc.save();
}

/// Label and value on one line; with Arabic in either, the value goes to the left.
pw.Widget _pair(String label, String value, {required bool bold, required double size}) {
  final labelText = pdfText(label, size: size, bold: bold);
  final valueText = pdfText(value, size: size, bold: bold);
  final arabic = pdfHasArabic(label) || pdfHasArabic(value);
  return pw.Row(
    children: arabic ? [valueText, pw.Expanded(child: labelText)] : [pw.Expanded(child: labelText), valueText],
  );
}
