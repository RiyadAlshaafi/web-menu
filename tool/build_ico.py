"""Packs build/icons/*.png (from tool/render_icons.dart) into the Windows .ico and copies the web, iOS and Android icons."""
import shutil
import struct
import zlib
from pathlib import Path


def strip_alpha(png: bytes) -> bytes:
    """Re-encodes an 8-bit RGBA PNG as RGB (App Store icons must not have an alpha channel)."""
    pos = 8
    idat = b''
    width = height = 0
    while pos < len(png):
        length, kind = struct.unpack('>I4s', png[pos:pos + 8])
        body = png[pos + 8:pos + 8 + length]
        if kind == b'IHDR':
            width, height, depth, color, _, _, interlace = struct.unpack('>IIBBBBB', body)
            if (depth, color, interlace) != (8, 6, 0):
                raise ValueError('expected a non-interlaced 8-bit RGBA PNG')
        elif kind == b'IDAT':
            idat += body
        pos += 12 + length
    raw = zlib.decompress(idat)
    stride = width * 4
    rows = []
    prev = bytearray(stride)
    for y in range(height):
        start = y * (stride + 1)
        filter_type = raw[start]
        line = bytearray(raw[start + 1:start + 1 + stride])
        for i in range(stride):
            a = line[i - 4] if i >= 4 else 0
            b = prev[i]
            c = prev[i - 4] if i >= 4 else 0
            if filter_type == 1:
                line[i] = (line[i] + a) & 255
            elif filter_type == 2:
                line[i] = (line[i] + b) & 255
            elif filter_type == 3:
                line[i] = (line[i] + (a + b) // 2) & 255
            elif filter_type == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pred = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[i] = (line[i] + pred) & 255
        rows.append(line)
        prev = line
    out = b''
    for line in rows:
        out += b'\x00' + b''.join(bytes(line[i:i + 3]) for i in range(0, stride, 4))

    def chunk(kind: bytes, body: bytes) -> bytes:
        return struct.pack('>I', len(body)) + kind + body + struct.pack('>I', zlib.crc32(kind + body))

    header = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header) + chunk(b'IDAT', zlib.compress(out, 9)) + chunk(b'IEND', b'')

root = Path(__file__).resolve().parent.parent
src = root / 'build' / 'icons'

sizes = [16, 24, 32, 48, 64, 128, 256]
images = [(size, (src / f'icon_{size}.png').read_bytes()) for size in sizes]

# ICO container with PNG-compressed entries (supported since Windows Vista).
header = struct.pack('<HHH', 0, 1, len(images))
offset = 6 + 16 * len(images)
directory = b''
payload = b''
for size, data in images:
    directory += struct.pack('<BBBBHHII', size % 256, size % 256, 0, 0, 1, 32, len(data), offset + len(payload))
    payload += data
(root / 'windows' / 'runner' / 'resources' / 'app_icon.ico').write_bytes(header + directory + payload)

web = root / 'web'
shutil.copy(src / 'icon_192.png', web / 'icons' / 'Icon-192.png')
shutil.copy(src / 'icon_512.png', web / 'icons' / 'Icon-512.png')
shutil.copy(src / 'maskable_192.png', web / 'icons' / 'Icon-maskable-192.png')
shutil.copy(src / 'maskable_512.png', web / 'icons' / 'Icon-maskable-512.png')
shutil.copy(src / 'icon_48.png', web / 'favicon.png')

# iOS: every file named in the app icon set, by its pixel size.
ios_dir = root / 'ios' / 'Runner' / 'Assets.xcassets' / 'AppIcon.appiconset'
ios_px = {
    '20x20@1x': 20, '20x20@2x': 40, '20x20@3x': 60,
    '29x29@1x': 29, '29x29@2x': 58, '29x29@3x': 87,
    '40x40@1x': 40, '40x40@2x': 80, '40x40@3x': 120,
    '60x60@2x': 120, '60x60@3x': 180,
    '76x76@1x': 76, '76x76@2x': 152,
    '83.5x83.5@2x': 167, '1024x1024@1x': 1024,
}
for name, px in ios_px.items():
    (ios_dir / f'Icon-App-{name}.png').write_bytes(strip_alpha((src / f'ios_{px}.png').read_bytes()))

# Android: legacy launcher icons plus the adaptive icon (cream background, mark in the foreground).
res = root / 'android' / 'app' / 'src' / 'main' / 'res'
legacy = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
foreground = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432}
for density, px in legacy.items():
    shutil.copy(src / f'android_{px}.png', res / f'mipmap-{density}' / 'ic_launcher.png')
for density, px in foreground.items():
    shutil.copy(src / f'adaptive_{px}.png', res / f'mipmap-{density}' / 'ic_launcher_foreground.png')
(res / 'mipmap-anydpi-v26').mkdir(exist_ok=True)
adaptive_xml = [
    '<?xml version="1.0" encoding="utf-8"?>',
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">',
    '    <background android:drawable="@color/ic_launcher_background"/>',
    '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>',
    '</adaptive-icon>',
]
(res / 'mipmap-anydpi-v26' / 'ic_launcher.xml').write_text('\n'.join(adaptive_xml) + '\n', encoding='utf-8')
background_xml = [
    '<?xml version="1.0" encoding="utf-8"?>',
    '<resources>',
    '    <color name="ic_launcher_background">#FDF9F2</color>',
    '</resources>',
]
(res / 'values' / 'ic_launcher_background.xml').write_text('\n'.join(background_xml) + '\n', encoding='utf-8')
print('icons written')
