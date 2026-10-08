import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Longest side, in pixels, of a photo stored for the menu. Phones show
/// dishes far smaller than this, so anything bigger only costs storage and data.
const maxImageSide = 800;

const _jpegQuality = 80;

/// An image ready to upload.
typedef ShrunkImage = ({Uint8List bytes, String extension, String contentType});

/// Scales [bytes] down to [maxImageSide] and re-encodes it. Pictures with
/// transparency (logos) stay PNG; everything else becomes JPEG. Returns null
/// when the bytes are not an image this package can read, so the caller can
/// upload the original instead.
ShrunkImage? shrinkImage(Uint8List bytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } on Exception {
    decoded = null;
  } on RangeError {
    // Truncated data makes some decoders read past the end instead of
    // returning null.
    decoded = null;
  }
  if (decoded == null) return null;
  final longest = decoded.width > decoded.height
      ? decoded.width
      : decoded.height;
  final scaled = longest <= maxImageSide
      ? decoded
      : img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? maxImageSide : null,
          height: decoded.height > decoded.width ? maxImageSide : null,
          interpolation: img.Interpolation.average,
        );
  if (scaled.hasAlpha) {
    return (
      bytes: img.encodePng(scaled, level: 9),
      extension: 'png',
      contentType: 'image/png',
    );
  }
  return (
    bytes: img.encodeJpg(scaled, quality: _jpegQuality),
    extension: 'jpg',
    contentType: 'image/jpeg',
  );
}
