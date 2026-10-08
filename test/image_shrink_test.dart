import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:menu_web_v1/data/image_shrink.dart';

void main() {
  test('a large photo is scaled to the longest side and stored as JPEG', () {
    final photo = img.Image(width: 2400, height: 1200);
    final result = shrinkImage(img.encodeJpg(photo))!;
    final decoded = img.decodeImage(result.bytes)!;
    expect(result.extension, 'jpg');
    expect(decoded.width, maxImageSide);
    expect(decoded.height, maxImageSide ~/ 2);
  });

  test('a small logo with transparency stays PNG and keeps its size', () {
    final logo = img.Image(width: 120, height: 80, numChannels: 4);
    final result = shrinkImage(img.encodePng(logo))!;
    final decoded = img.decodeImage(result.bytes)!;
    expect(result.extension, 'png');
    expect(result.contentType, 'image/png');
    expect(decoded.width, 120);
  });

  test('bytes that are not an image return null', () {
    expect(
      shrinkImage(img.encodeJpg(img.Image(width: 1, height: 1)).sublist(0, 4)),
      isNull,
    );
  });
}
