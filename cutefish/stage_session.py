#!/usr/bin/env python3
"""Enable only after native external-shell validation; never operates on the host."""
import argparse
import configparser
import os
from pathlib import Path
import shutil
import subprocess

parser=argparse.ArgumentParser();parser.add_argument('--rootfs',type=Path,required=True);parser.add_argument('--source',type=Path,required=True)
args=parser.parse_args();root=args.rootfs.resolve();source=args.source.resolve()
if os.environ.get('GITHUB_ACTIONS')!='true' or root.name!='makos-cutefish-root' or root==Path('/') or not (root/'etc/makos/live.json').is_file():
    raise SystemExit('Use the isolated image workflow after staging makOS.')
required=source/'ci-results/external-shell-validation.json'
if not required.is_file():raise SystemExit('External shell validation report missing; refusing to change the login default.')
import json
validation=json.loads(required.read_text())
if validation.get('result')!='passed':raise SystemExit('External shell validation did not pass.')
commit=subprocess.check_output(['git','-c','safe.directory='+str(source),'-C',str(source),'rev-parse','HEAD'],text=True).strip()
if validation.get('source_commit')!=commit:raise SystemExit('External shell validation belongs to a different source commit.')
destination=root/'usr/share/wayland-sessions/makos.desktop';destination.parent.mkdir(parents=True,exist_ok=True)
shutil.copy2(source/'cutefish/makos.desktop',destination)
hook=root/'usr/lib/live/config/0087-makos-session';shutil.copy2(source/'cutefish/0087-makos-session',hook);hook.chmod(0o755)
launcher=root/'opt/makos/cutefish/run-session'
if not launcher.is_file():raise SystemExit('makOS session launcher was not staged')
launcher.chmod(0o755)
config=configparser.ConfigParser(interpolation=None);config.optionxform=str
path=root/'etc/cutefish-dm.conf';config.read(path)
if not config.has_section('Session'):config.add_section('Session')
config['Session']['Default']='makos'
with path.open('w') as stream:config.write(stream,space_around_delimiters=False)
print('PASS: makOS login entry and live-session selection staged after native validation; no persistent autologin user added.')
