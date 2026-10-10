// Renders the Tawla app icons from the in-app TawlaMark painter.
//
//   flutter test tool/render_icons.dart
//   python tool/build_ico.py
//
// PNGs land in build/icons; build_ico.py packs the Windows .ico and copies the web icons.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/theme/cafe_theme.dart';
import 'package:menu_web_v1/widgets/tawla_mark.dart';

/// [markShare] is how much of the square the mark fills; [radiusShare] rounds the tile corners
/// (0 for the full-bleed maskable icons, which the OS crops itself).
const _variants = <String, ({int px, double markShare, double radiusShare})>{
  'icon_16': (px: 16, markShare: 0.86, radiusShare: 0.22),
  'icon_24': (px: 24, markShare: 0.84, radiusShare: 0.22),
  'icon_32': (px: 32, markShare: 0.80, radiusShare: 0.22),
  'icon_48': (px: 48, markShare: 0.74, radiusShare: 0.22),
  'icon_64': (px: 64, markShare: 0.70, radiusShare: 0.22),
  'icon_128': (px: 128, markShare: 0.66, radiusShare: 0.22),
  'icon_192': (px: 192, markShare: 0.66, radiusShare: 0.22),
  'icon_256': (px: 256, markShare: 0.66, radiusShare: 0.22),
  'icon_512': (px: 512, markShare: 0.66, radiusShare: 0.22),
  'maskable_192': (px: 192, markShare: 0.52, radiusShare: 0),
  'maskable_512': (px: 512, markShare: 0.52, radiusShare: 0),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('render the Tawla icons', (tester) async {
    final out = Directory('build/icons')..createSync(recursive: true);
    for (final entry in _variants.entries) {
      final v = entry.value;
      final key = GlobalKey();
      tester.view.physicalSize = Size.square(v.px.toDouble());
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: Container(
                width: v.px.toDouble(),
                height: v.px.toDouble(),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: CafeColors.cream,
                  borderRadius: BorderRadius.circular(v.px * v.radiusShare),
                ),
                child: TawlaMark(size: v.px * v.markShare),
              ),
            ),
          ),
        ),
      );
      final bytes = await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      });
      File('${out.path}/${entry.key}.png').writeAsBytesSync(bytes!);
    }
    addTearDown(tester.view.reset);
  });
}
