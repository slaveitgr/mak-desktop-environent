#!/usr/bin/env python3
"""Read-only makOS/Deepin readiness report. Never starts system services."""
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess


def run(arguments):
    try:
        result = subprocess.run(arguments, capture_output=True, text=True, timeout=8)
        return {'returncode': result.returncode, 'stdout': result.stdout.strip(), 'stderr': result.stderr.strip()}
    except (OSError, subprocess.TimeoutExpired) as error:
        return {'error': str(error)}


def report():
    result = {'platform': platform.system(), 'architecture': platform.machine(),
              'session': os.environ.get('XDG_SESSION_TYPE', ''),
              'desktop': os.environ.get('XDG_CURRENT_DESKTOP', ''),
              'wayland_display_present': bool(os.environ.get('WAYLAND_DISPLAY')),
              'executables': {name: shutil.which(name) for name in
                              ('treeland', 'dde-session', 'll-cli', 'busctl', 'wayland-info')},
              'services': [], 'warnings': []}
    release = Path('/etc/os-release')
    if release.is_file():
        result['os_release'] = release.read_text()
    if result['platform'] == 'Linux':
        if shutil.which('dpkg-query'):
            result['packages'] = run(['dpkg-query', '-W', '-f=${Package}\t${Version}\n',
                                      'treeland', 'dde-session', 'dde-daemon', 'dde-shell',
                                      'libqt6core6', 'libdtk6core', 'qml6-module-org-kde-layershell'])
        if shutil.which('busctl'):
            services = run(['busctl', '--user', '--no-pager', '--no-legend', 'list'])
            if services.get('returncode') == 0:
                result['services'] = [line.split()[0] for line in services['stdout'].splitlines()
                                      if line.startswith(('org.deepin.', 'org.dde.'))]
            else:
                result['warnings'].append('No readable session D-Bus inventory.')
    try:
        import PySide6
        from PySide6.QtCore import QLibraryInfo, qVersion
        result['qt'] = {'pyside': PySide6.__version__, 'runtime': qVersion(),
                        'libraries': QLibraryInfo.path(QLibraryInfo.LibrariesPath),
                        'qml_imports': QLibraryInfo.path(QLibraryInfo.QmlImportsPath)}
        maps = Path('/proc/self/maps')
        loaded = []
        if result['platform'] == 'Linux' and maps.is_file():
            loaded = sorted({line.split(maxsplit=5)[5].strip() for line in maps.read_text().splitlines()
                             if len(line.split(maxsplit=5)) == 6 and '/libQt6' in line.split(maxsplit=5)[5]})
            result['qt']['loaded_libraries'] = loaded
        # PySide's qt.conf changes QLibraryInfo even if the loader selected
        # distribution libraries. On Linux the process mappings are evidence.
        if any('site-packages' in path for path in loaded) or (not loaded and 'site-packages' in result['qt']['libraries']):
            result['warnings'].append('Bundled Qt: system DDE/LayerShell QML plugins must not be loaded without an ABI check.')
    except ImportError:
        result['warnings'].append('PySide6 is not available in this Python environment.')
    result['native_layer_session_validated'] = False
    return result


if __name__ == '__main__':
    print(json.dumps(report(), indent=2))
