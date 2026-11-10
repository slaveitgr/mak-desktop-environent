#!/usr/bin/env python3
"""Install theme assets only into the workflow's extracted rootfs."""
import argparse
import os
from pathlib import Path
import shutil
import struct
import zlib


def pixel(red, green, blue):
    def chunk(kind, data):
        return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind+data))
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!2I5B', 1, 1, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(bytes([0, red, green, blue]))) + chunk(b'IEND', b'')


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--rootfs',type=Path,required=True);parser.add_argument('--source',type=Path,required=True)
    args=parser.parse_args();root=args.rootfs.resolve();source=args.source.resolve()
    if os.environ.get('GITHUB_ACTIONS')!='true' or root.name!='makos-cutefish-root' or root==Path('/') or not (root/'var/lib/dpkg/status').is_file():
        raise SystemExit('Use the isolated recovery-image workflow.')
    logo=source/'installer/branding/makos-ck-white.png'
    with logo.open('rb') as f:header=f.read(24)
    if header[:8]!=b'\x89PNG\r\n\x1a\n' or not all(struct.unpack('!II',header[16:24])):
        raise SystemExit('The makOS boot logo must be a valid PNG.')
    theme=root/'usr/share/plymouth/themes/makos';theme.mkdir(parents=True,exist_ok=False)
    shutil.copy2(logo,theme/'logo.png')
    for name in ('makos.plymouth','makos.script'):shutil.copy2(source/'installer/boot'/name,theme/name)
    (theme/'track.png').write_bytes(pixel(62,62,62));(theme/'fill.png').write_bytes(pixel(235,235,235))
    print('Staged makOS Plymouth theme in the isolated rootfs.')


if __name__=='__main__':main()
