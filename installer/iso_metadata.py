#!/usr/bin/env python3
import argparse
import hashlib
from pathlib import Path
import pycdlib

parser=argparse.ArgumentParser();parser.add_argument('--base',type=Path,required=True);parser.add_argument('--directory',type=Path,required=True)
args=parser.parse_args();iso=pycdlib.PyCdlib();iso.open(str(args.base))
with iso.open_file_from_iso(rr_path='/boot/grub/grub.cfg') as f: config=f.read().decode()
config=config.replace('Live system (amd64)', 'makOS Recovery (amd64)').replace('Live system (amd64 fail-safe mode)', 'makOS Recovery (safe graphics)').replace('hostname=cutefish', 'hostname=makos')
(args.directory/'grub.cfg').write_text(config)
with iso.open_file_from_iso(rr_path='/sha256sum.txt') as f: checksums=f.read().decode()
updates={'live/filesystem.squashfs':'filesystem.squashfs','live/filesystem.packages':'filesystem.packages','boot/grub/grub.cfg':'grub.cfg'}
digests={}
for path, local in updates.items():
 h=hashlib.sha256()
 with (args.directory/local).open('rb') as f:
  for chunk in iter(lambda:f.read(4*1024*1024),b''):h.update(chunk)
 digests[path]=h.hexdigest()
lines=[];found=set()
for line in checksums.splitlines():
 parts=line.split(maxsplit=1)
 if len(parts)==2:
  path=parts[1].lstrip('*').removeprefix('./').lstrip('/')
  if path in digests:line=digests[path]+'  '+parts[1].lstrip('*');found.add(path)
 lines.append(line)
for path in updates.keys()-found:lines.append(digests[path]+'  ./'+path)
(args.directory/'sha256sum.txt').write_text('\n'.join(lines)+'\n')
iso.close()
