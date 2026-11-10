#!/usr/bin/env python3
"""Seed new live/installed users; call only inside the isolated image chroot."""
import os
from pathlib import Path
from PySide6.QtCore import QSettings

if os.environ.get('MAKOS_IMAGE_CHROOT')!='1' or not Path('/etc/makos/live.json').is_file():
    raise SystemExit('Use the isolated image chroot.')
path=Path('/etc/skel/.config/cutefish/shell.conf');path.parent.mkdir(parents=True,exist_ok=True)
config=QSettings(str(path),QSettings.Format.IniFormat)
pins=config.value('Dock/Pinned')
if pins is None:
    pins=['cutefish-filemanager','cutefish-terminal','chromium','cutefish-settings','cutefish-calculator','cutefish-debinstaller','cutefish-screenshot','cutefish-videoplayer']
elif isinstance(pins,str):pins=[pins]
if not isinstance(pins,list) or not all(isinstance(p,str) for p in pins):raise SystemExit('Unexpected Dock/Pinned type; refusing to replace existing configuration.')
replacements={'cutefish-filemanager':'org.makos.Finder','cutefish-settings':'org.makos.Settings',
              'cutefish-terminal':'org.makos.Terminal','cutefish-calculator':'org.makos.Calculator',
              'cutefish-calendar':'org.makos.Calendar'}
expected=[replacements.get(p,p) for p in pins]
brand=Path('/opt/makos/installer/branding/makos-ck-symbol.svg')
if not brand.is_file():raise SystemExit('Missing persistent native menu-bar SVG.')
config.setValue('Dock/Pinned',expected)
config.setValue('MenuBar/BrandIcon',str(brand));config.sync()
if config.status()!=QSettings.Status.NoError:raise SystemExit('Cannot write the new-user Dock configuration.')
check=QSettings(str(path),QSettings.Format.IniFormat)
actual=check.value('Dock/Pinned');actual=[actual] if isinstance(actual,str) else actual
assert actual==expected,(actual,expected)
assert check.value('MenuBar/BrandIcon')==str(brand)
print('PASS: new-user Dock preserves pins and substitutes makOS Finder/Settings:',actual)
print('PASS: new-user native menu bar references the persistent makOS SVG:',brand)
