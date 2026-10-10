// Renders the Tawla app icons from the in-app TawlaMark painter.
//
//   flutter test tool/render_icons.dart
//   python tool/build_ico.py
//
// PNGs land in build/icons; build_ico.py packs the Windows .ico and copies the web, iOS and Android icons.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/theme/cafe_theme.dart';
import 'package:menu_web_v1/widgets/tawla_mark.dart';

/// [markShare] is how much of the square the mark fills; [radiusShare] rounds the tile corners
/// (0 for tiles the OS crops itself: maskable, iOS and the Android adaptive layers);
/// [transparent] leaves the tile empty so only the mark is drawn (Android adaptive foreground).
typedef _Variant = ({int px, double markShare, double radiusShare, bool transparent});

_Variant _tile(int px, double markShare, {double radiusShare = 0.22, bool transparent = false}) =>
    (px: px, markShare: markShare, radiusShare: radiusShare, transparent: transparent);

final _variants = <String, _Variant>{
  'icon_16': _tile(16, 0.86),
  'icon_24': _tile(24, 0.84),
  'icon_32': _tile(32, 0.80),
  'icon_48': _tile(48, 0.74),
  'icon_64': _tile(64, 0.70),
  'icon_128': _tile(128, 0.66),
  'icon_192': _tile(192, 0.66),
  'icon_256': _tile(256, 0.66),
  'icon_512': _tile(512, 0.66),
  'maskable_192': _tile(192, 0.52, radiusShare: 0),
  'maskable_512': _tile(512, 0.52, radiusShare: 0),
  // iOS: opaque full-bleed squares; the system rounds them.
  for (final px in const [20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024]) 'ios_$px': _tile(px, 0.66, radiusShare: 0),
  // Android legacy launcher icons (mdpi to xxxhdpi).
  for (final px in const [48, 72, 96, 144, 192]) 'android_$px': _tile(px, 0.66),
  // Android adaptive foreground (108dp at mdpi to xxxhdpi); the mark stays inside the 66dp safe zone.
  for (final px in const [108, 162, 216, 324, 432]) 'adaptive_$px': _tile(px, 0.50, radiusShare: 0, transparent: true),
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
                  color: v.transparent ? null : CafeColors.cream,
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
