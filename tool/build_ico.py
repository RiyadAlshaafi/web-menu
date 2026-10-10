"""Packs build/icons/*.png (from tool/render_icons.dart) into the Windows .ico and web icons."""
import shutil
import struct
from pathlib import Path

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
print('icons written')
