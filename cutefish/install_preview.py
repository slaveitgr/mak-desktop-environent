#!/usr/bin/env python3
"""Register only makOS launchers/icons in the current user's XDG data directory."""
import os
from pathlib import Path
import shutil

root = Path(__file__).resolve().parents[1]
data = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share'))
applications = data / 'applications'; applications.mkdir(parents=True, exist_ok=True)
icons = data / 'icons/hicolor/128x128/apps'; icons.mkdir(parents=True, exist_ok=True)
symbols = data / 'icons/hicolor/32x32/actions'; symbols.mkdir(parents=True, exist_ok=True)
def quoted(value):
    # Desktop Entry Exec quoting is distinct from shell quoting.
    return '"' + str(value).replace('\\', '\\\\').replace('"', '\\"').replace('`', '\\`').replace('$', '\\$').replace('%', '%%') + '"'
for kind, title in [('finder','Finder'), ('settings','System Settings')]:
    app_id = 'org.makos.' + kind.capitalize()
    shutil.copy2(root / ('assets/' + kind + '.png'), icons / (app_id + '.png'))
    (applications / (app_id + '.desktop')).write_text(
        '[Desktop Entry]\nType=Application\nName=' + title + '\nComment=makOS Cutefish preview\n'
        'Exec=' + quoted(root / 'cutefish/run-app') + ' ' + kind + '\nIcon=' + app_id + '\n'
        'Terminal=false\nCategories=Utility;\nStartupNotify=true\n')
for source in (root / 'assets/symbols').glob('menu-*.png'):
    shutil.copy2(source, symbols / ('makos-' + source.name))
print('Registered Finder and System Settings launchers for this checkout.')
