"""Read installed launchers; GIO, not a shell parser, implements Desktop Entry Exec."""
import configparser
import os
from pathlib import Path
import shutil


def discover_applications(data_dirs=None, desktop='Tahoe', which=shutil.which):
    if data_dirs is None:
        data_dirs = [os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share'))]
        data_dirs += os.environ.get('XDG_DATA_DIRS', '/usr/local/share:/usr/share').split(':')
        # Ubuntu Snap/Flatpak launchers may not have reached the session environment.
        data_dirs += ['/var/lib/snapd/desktop', '/var/lib/flatpak/exports/share',
                      str(Path.home() / '.local/share/flatpak/exports/share')]
    result, seen = [], set()
    for directory in data_dirs:
        base = Path(directory) / 'applications'
        if not base.is_dir():
            continue
        for path in sorted(base.rglob('*.desktop')):
            identity = '-'.join(path.relative_to(base).parts)
            if identity in seen:
                continue
            seen.add(identity)  # Hidden user entries mask system entries too.
            config = configparser.ConfigParser(interpolation=None, strict=False)
            try:
                config.read(path, encoding='utf-8')
                entry = config['Desktop Entry']
                if entry.get('Type') != 'Application' or not entry.get('Name'):
                    continue
                if any(entry.getboolean(key, False) for key in ('Hidden', 'NoDisplay')):
                    continue
                only, exclude = entry.get('OnlyShowIn', ''), entry.get('NotShowIn', '')
                if (only and desktop not in only.split(';')) or desktop in exclude.split(';'):
                    continue
                executable = entry.get('TryExec', '')
                if executable and not which(executable):
                    continue
                if not entry.get('Exec') and not entry.getboolean('DBusActivatable', False):
                    continue
                result.append(dict(id='xdg:' + identity, name=entry['Name'],
                                   path=str(path.resolve()), icon=entry.get('Icon', ''),
                                   description=entry.get('Comment', 'Installed Linux application'),
                                   provider='Linux', image='appstore.png'))
            except (OSError, UnicodeError, configparser.Error, KeyError, ValueError):
                continue
    return sorted(result, key=lambda item: item['name'].casefold())
