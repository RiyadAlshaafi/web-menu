import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:menu_web_v1/widgets/table_qr.dart';

void main() {
  testWidgets('saved QR is opaque white with a blank border around the code', (tester) async {
    await tester.runAsync(() async {
      final bytes = await tableQrPng('https://example.test/#/t/abc123');
      expect(bytes, isNotNull);
      // PNG signature.
      expect(bytes!.sublist(0, 4), [0x89, 0x50, 0x4e, 0x47]);

      final codec = await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;
      final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;

      int pixel(int x, int y) {
        final i = (y * image.width + x) * 4;
        return (data.getUint8(i) << 24) | (data.getUint8(i + 1) << 16) | (data.getUint8(i + 2) << 8) | data.getUint8(i + 3);
      }

      // Corner and edge are fully opaque white (the quiet zone).
      expect(pixel(0, 0), 0xFFFFFFFF);
      expect(pixel(image.width ~/ 2, 2), 0xFFFFFFFF);

      // Somewhere inside the code there are dark modules.
      var dark = 0;
      for (var y = 0; y < image.height; y += 4) {
        for (var x = 0; x < image.width; x += 4) {
          if (pixel(x, y) == 0x000000FF) dark++;
        }
      }
      expect(dark, greaterThan(100));
    });
  });
}
