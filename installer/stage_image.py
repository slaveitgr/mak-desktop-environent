#!/usr/bin/env python3
"""Stage makOS into the workflow's extracted ISO, never the running host."""
import argparse
import configparser
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
    auth=root/'tmp/makos/source/cutefish/build/auth/makos-polkit-agent'
    if not auth.is_file() or not os.access(auth,os.X_OK):
        raise SystemExit('The compiled makOS authentication agent is missing.')
    installed_auth=target/'cutefish/build/auth/makos-polkit-agent'
    installed_auth.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(auth,installed_auth);installed_auth.chmod(0o755)
    # The compositor recognizes this exact system-dialog executable. Every
    # installed path component must remain outside ordinary users' control.
    for component in (installed_auth, *installed_auth.parents):
        if component == root:
            break
        if component.is_symlink() or component.stat().st_uid != 0 or component.stat().st_mode & 0o022:
            raise SystemExit('The installed authentication path is not root-owned and protected: '+str(component))
    auth_icon=root/'usr/share/icons/hicolor/scalable/apps/org.makos.Authentication.svg'
    auth_icon.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(source/'cutefish/auth/authentication.svg',auth_icon)
    # Keep base packages for their services and the optional Cutefish session,
    # but show one launcher for each replaced application in makOS.
    for name in ('filemanager', 'settings', 'terminal', 'calculator', 'calendar'):
        entry_path=root/('usr/share/applications/cutefish-'+name+'.desktop')
        if not entry_path.is_file():
            raise SystemExit('The pinned base application entry is missing: '+str(entry_path))
        entry=configparser.ConfigParser(interpolation=None);entry.optionxform=str
        entry.read(entry_path)
        excluded=entry['Desktop Entry'].get('NotShowIn','').split(';')
        excluded=[value for value in excluded if value and value!='makOS']+['makOS']
        entry['Desktop Entry']['NotShowIn']=';'.join(excluded)+';'
        with entry_path.open('w') as stream:entry.write(stream,space_around_delimiters=False)
    fetch=root/'usr/bin/makos-fetch'
    fetch.write_text('#!/bin/sh\nexec /usr/bin/python3 /opt/makos/makos_fetch.py "$@"\n')
    fetch.chmod(0o755)
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
