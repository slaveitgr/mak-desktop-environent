#!/usr/bin/env python3
"""Verify the rebuilt live initramfs's selected theme, boot support and AMD KMS."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

initrd=Path(sys.argv[1]);destination=Path(sys.argv[2])
listing=subprocess.check_output(['lsinitramfs',str(initrd)],text=True).splitlines()
required={
    'makos script':any(p.endswith('/plymouth/themes/makos/makos.script') for p in listing),
    'script plugin':any(p.endswith('/plymouth/script.so') for p in listing),
    'text fallback':any(p.endswith('/plymouth/text.so') for p in listing),
    'details fallback':any(p.endswith('/plymouth/details.so') for p in listing),
    'DRM renderer':any(p.endswith('/plymouth/renderers/drm.so') for p in listing),
    'live boot script':'scripts/live' in listing,
    'live boot executable':any(p.endswith('/bin/live-boot') for p in listing),
    'amdgpu kernel module':any(re.search(r'/amdgpu\.ko(?:\.(?:xz|zst|gz))?$',p) for p in listing),
    'AMD firmware':any('/firmware/amdgpu/' in p for p in listing),
}
assert all(required.values()),required

def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(4*1024*1024),b''):h.update(chunk)
    return h.hexdigest()

with tempfile.TemporaryDirectory(prefix='makos-initrd-check-') as directory:
    root=Path(directory)
    subprocess.run(['unmkinitramfs',str(initrd),str(root)],check=True)
    matches=list(root.rglob('makos.plymouth'))
    assert len(matches)==1,matches
    theme=matches[0].parent
    configs=list(root.rglob('plymouthd.conf'))
    assert len(configs)==1,configs
    assert re.search(r'^Theme=makos$',configs[0].read_text(),re.M),configs[0].read_text()
    sources=Path('/usr/share/plymouth/themes/makos')
    theme_hashes={}
    for name in ('makos.plymouth','makos.script','logo.png','track.png','fill.png'):
        theme_hashes[name]=digest(theme/name)
        assert theme_hashes[name]==digest(sources/name),name
report={'initrd_filename':initrd.name,'initrd_bytes':initrd.stat().st_size,'initrd_sha256':digest(initrd),
        'checks':required,'theme':'makos','theme_sha256':theme_hashes,
        'limits':['Static initramfs inclusion check; not a kernel boot.','Plymouth boot progress is its estimate, not an exact measurement of remaining work.','DRM rendering and the HP laptop remain untested.']}
destination.write_text(json.dumps(report,indent=2)+'\n')
print('PASS: rebuilt live initramfs contains makOS theme, text/details fallback, live-boot and AMD KMS support.')
