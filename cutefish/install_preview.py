#!/usr/bin/env python3
"""Register all makOS native clients in an explicit XDG data directory."""
import os
from pathlib import Path
import shutil
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from applications import NATIVE_APPLICATIONS


def quoted(value):
    # Desktop Entry Exec quoting is distinct from shell quoting.
    return '"' + str(value).replace('\\', '\\\\').replace('"', '\\"').replace('`', '\\`').replace('$', '\\$').replace('%', '%%') + '"'


def install(data, source=root):
    data = Path(data); source = Path(source)
    applications = data / 'applications'; applications.mkdir(parents=True, exist_ok=True)
    icons = data / 'icons/hicolor/128x128/apps'; icons.mkdir(parents=True, exist_ok=True)
    symbols = data / 'icons/hicolor/32x32/actions'; symbols.mkdir(parents=True, exist_ok=True)
    for app in NATIVE_APPLICATIONS:
        kind, title, app_id = app['id'], app['name'], app['desktop_id']
        shutil.copy2(source / ('assets/' + kind + '.png'), icons / (app_id + '.png'))
        (applications / (app_id + '.desktop')).write_text(
            '[Desktop Entry]\nType=Application\nName=' + title + '\nComment=' + ('makOS native application' if app['windowed'] else 'makOS Apps shell launcher') + '\n'
            'Exec=' + quoted(source / 'cutefish/run-app') + ' ' + kind + '\nIcon=' + app_id + '\n'
            'Terminal=false\nCategories=Utility;\nStartupNotify=' + ('true' if app['windowed'] else 'false') + '\n')
    for symbol in (source / 'assets/symbols').glob('menu-*.png'):
        shutil.copy2(symbol, symbols / ('makos-' + symbol.name))
    return [app['desktop_id'] for app in NATIVE_APPLICATIONS]


if __name__ == '__main__':
    data = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share'))
    registered = install(data)
    print(f'Registered {len(registered)} makOS native application launchers.')
