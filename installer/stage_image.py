#!/usr/bin/env python3
"""Stage makOS into the workflow's extracted ISO, never the running host."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--rootfs',type=Path,required=True);parser.add_argument('--source',type=Path,required=True)
    args=parser.parse_args();root=args.rootfs.resolve();source=args.source.resolve()
    if os.environ.get('GITHUB_ACTIONS')!='true' or root.name!='makos-cutefish-root' or root==Path('/'):
        raise SystemExit('Use the isolated recovery-image workflow.')
    if not (root/'var/lib/dpkg/status').is_file() or not (root/'etc/debian_version').is_file():
        raise SystemExit('The verified Debian rootfs has not been extracted.')
    target=root/'opt/makos'
    if target.exists(): raise SystemExit('Refusing to overwrite an existing makOS installation.')
    target.mkdir(parents=True)
    files=subprocess.check_output(['git','-c','safe.directory='+str(source),'-C',str(source),'ls-files','-z']).decode().split('\0')
    for name in filter(None,files):
        path=source/name
        if path.is_symlink(): raise SystemExit('Unexpected source symlink: '+name)
        destination=target/name;destination.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(path,destination)
    bridge=root/'tmp/makos/source/cutefish/build/qml'
    shutil.copytree(bridge,target/'cutefish/build/qml')
    helper=root/'tmp/makos/source/cutefish/build/settings/makos-settings-backend'
    if not helper.is_file() or not os.access(helper,os.X_OK):
        raise SystemExit('The compiled Cutefish Settings backend is missing or not executable.')
    installed_helper=target/'cutefish/build/settings/makos-settings-backend'
    installed_helper.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(helper,installed_helper)
    installed_helper.chmod(0o755)
    (root/'etc/makos').mkdir(exist_ok=True)
    original=(root/'usr/lib/os-release').read_text()
    (root/'etc/makos/base-os-release').write_text(original)
    lines=[line for line in original.splitlines() if line.split('=',1)[0] not in {'NAME','PRETTY_NAME','ID','ID_LIKE','VERSION','VERSION_ID'}]
    lines += ['NAME="makOS"','PRETTY_NAME="makOS Development (Cutefish)"','ID=makos','ID_LIKE=debian','VERSION="0.1 Development"','VERSION_ID="0.1"']
    (root/'usr/lib/os-release').write_text('\n'.join(lines)+'\n')
    release=root/'etc/os-release';release.unlink(missing_ok=True);release.symlink_to('../usr/lib/os-release')
    commit=subprocess.check_output(['git','-c','safe.directory='+str(source),'-C',str(source),'rev-parse','HEAD'],text=True).strip()
    (root/'etc/makos/live.json').write_text(json.dumps({'version':'0.1-development','source_commit':commit,'base':json.loads((source/'cutefish/base.json').read_text())},indent=2)+'\n')
    (root/'etc/xdg/autostart/cutefish-installer.desktop').write_text('''[Desktop Entry]
Type=Application
Name=makOS Recovery
Exec=/opt/makos/installer/run --autostart
TryExec=/opt/makos/installer/run
NoDisplay=true
OnlyShowIn=Cutefish;
''')
    (root/'usr/share/applications/org.makos.Recovery.desktop').write_text('''[Desktop Entry]
Type=Application
Name=makOS Recovery
Exec=/opt/makos/installer/run
Icon=/opt/makos/installer/assets/install.svg
Terminal=false
Categories=System;
''')
    # Keep the installed package/daemon for its privileged backend, but never
    # expose its old graphical wizard in the application launcher.
    (root/'usr/share/applications/cutefish-installer.desktop').write_text("""[Desktop Entry]
Type=Application
Name=Install makOS
Exec=/opt/makos/cutefish/build/venv/bin/python /opt/makos/installer/makos_install.py --native-shell
Icon=/opt/makos/installer/assets/install.svg
Hidden=true
NoDisplay=true
Terminal=false
Categories=System;
""")
    (root/'usr/share/applications/org.makos.Installer.desktop').write_text("""[Desktop Entry]
Type=Application
Name=Install makOS
Exec=/opt/makos/cutefish/build/venv/bin/python /opt/makos/installer/makos_install.py --native-shell
TryExec=/opt/makos/cutefish/build/venv/bin/python
Icon=/opt/makos/installer/assets/install.svg
Terminal=false
StartupNotify=true
Categories=System;
""")
    print('Staged makOS source, native plugin, Recovery autostart and image identity.')


if __name__=='__main__':main()
