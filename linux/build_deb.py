#!/usr/bin/env python3
"""Build a relocatable, dpkg-owned Ubuntu package as an ordinary user."""
import argparse
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from package_release import DIRECTORIES, FILES, VERSION

DEPENDENCIES = ('python3 (>= 3.10), python3 (<< 3.16), openbox, picom, dbus-x11, '
                'xserver-xorg, x11-xserver-utils, wmctrl, xss-lock, i3lock, '
                'policykit-1-gnome, libglib2.0-bin, fonts-inter, '
                'libegl1, libgl1, libopengl0, libnss3, libxkbcommon-x11-0, '
                'libxcb-cursor0, libxcb-icccm4, libxcb-image0, libxcb-keysyms1, '
                'libxcb-render-util0, libxcb-xinerama0, libxcb-randr0, libxcb-shape0, '
                'libxcb-xfixes0, libxcb-sync1, libxcb-xkb1, libxcomposite1, '
                'libxdamage1, libxrandr2, libxtst6, libasound2t64 | libasound2')


def write(path, content, executable=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)
    path.chmod(0o755 if executable else 0o644)


def stage_source(destination):
    app = destination / 'opt/tahoe-desktop'
    for source in ROOT.rglob('*'):
        relative = source.relative_to(ROOT)
        if source.is_symlink() or not source.is_file() or any(part in ('__pycache__', '.git') for part in relative.parts) or source.suffix == '.pyc' or source.name == '.DS_Store':
            continue
        if relative.parts[0] in DIRECTORIES or (len(relative.parts) == 1 and (source.name in FILES or source.suffix == '.py')):
            target = app / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
    for name, file in [('tahoe-session', 'linux/session.py'), ('tahoe-session-control', 'linux/session_control.py'), ('tahoe-desktop', 'main.py')]:
        write(destination / 'usr/bin' / name,
              '#!/bin/sh\nexport PYTHONPATH=/opt/tahoe-desktop/vendor\nexec /usr/bin/python3 /opt/tahoe-desktop/' + file + ' "$@"\n', True)
    for target, source in [('usr/share/xsessions/tahoe.desktop', 'tahoe-session.desktop'),
                           ('usr/share/applications/tahoe-desktop.desktop', 'tahoe-desktop.desktop')]:
        write(destination / target, (ROOT / 'linux' / source).read_text())
    write(destination / 'DEBIAN/control', f'''Package: tahoe-desktop
Version: {VERSION}.0
Section: x11
Priority: optional
Architecture: amd64
Maintainer: Tahoe Desktop Contributors
Depends: {DEPENDENCIES}
Description: Experimental Tahoe-style Qt Quick desktop session
 A standalone X11 login session with Openbox, a Qt Quick shell,
 built-in applications, and an installed Linux application launcher.
''')
    return app


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=ROOT / 'dist')
    args = parser.parse_args()
    if sys.platform != 'linux' or platform.machine() not in ('x86_64', 'AMD64'):
        parser.error('Build on an Intel/AMD Ubuntu 22.04, 24.04, 26.04 or 26.10 machine.')
    if os.getuid() == 0:
        parser.error('Build as your normal user. Only installing the finished .deb needs sudo.')
    if not (3, 10) <= sys.version_info[:2] < (3, 16):
        parser.error('Python 3.10–3.15 is required by the pinned Qt runtime.')
    args.output.mkdir(parents=True, exist_ok=True)
    package = args.output.resolve() / f'tahoe-desktop_{VERSION}.0_amd64.deb'
    with tempfile.TemporaryDirectory(prefix='tahoe-package-') as folder:
        staging = Path(folder) / 'package'
        app = stage_source(staging)
        environment = Path(folder) / 'build-env'
        subprocess.run([sys.executable, '-m', 'venv', str(environment)], check=True)
        subprocess.run([str(environment / 'bin/python'), '-m', 'pip', 'install', '--only-binary=PySide6,PySide6_Addons,PySide6_Essentials,shiboken6',
                        '--no-compile', '--target', str(app / 'vendor'), '-r', str(ROOT / 'requirements.txt')], check=True)
        subprocess.run(['dpkg-deb', '--root-owner-group', '--build', str(staging), str(package)], check=True)
    print(package)


if __name__ == '__main__':
    main()
