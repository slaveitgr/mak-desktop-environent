#!/usr/bin/env python3
"""Remove replaced apps/build packages inside the disposable image chroot."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

REPLACED = {
    'cutefish-desktop', 'cutefish-filemanager', 'cutefish-settings',
    'cutefish-terminal', 'cutefish-calculator', 'cutefish-calendar',
}
BUILD_TOOLS = {
    'build-essential', 'dpkg-dev', 'cmake', 'cmake-data', 'ninja-build', 'make',
    'pkg-config', 'pkgconf', 'pkgconf-bin', 'patch', 'wayland-protocols',
    'qmake6', 'qmake6-bin', 'qt6-base-dev-tools', 'qt6-declarative-dev-tools',
    'qt6-wayland-dev-tools', 'plymouth-x11', 'xvfb', 'xauth',
}
BACKEND_FILES = (
    '/usr/libexec/cutefish-installer-service',
    '/usr/lib/systemd/system/cutefish-installer.service',
    '/usr/share/dbus-1/system-services/org.cutefish.Installer.service',
    '/usr/share/dbus-1/system.d/org.cutefish.Installer.conf',
    '/usr/share/polkit-1/actions/org.cutefish.installer.policy',
    '/usr/share/doc/cutefish-installer/copyright',
    '/usr/share/doc/cutefish-installer/changelog.Debian.gz',
)


def package_records(text):
    result = {}
    for paragraph in text.strip().split('\n\n'):
        fields = {}
        for line in paragraph.splitlines():
            if line and not line[0].isspace() and ': ' in line:
                key, value = line.split(': ', 1); fields[key] = value
        if fields.get('Status') == 'install ok installed':
            result[fields['Package']] = fields
    return result


def build_only(name):
    return (name in BUILD_TOOLS or name.endswith('-dev') or
            bool(re.fullmatch(r'(gcc|g\+\+|cpp)(-\d+)?(-x86-64-linux-gnu)?', name)))


def removal_plan(packages):
    return sorted(name for name in packages if name in REPLACED or build_only(name)
                  or name == 'cutefish-installer')


def validate_simulation(output, requested):
    removed = set()
    for line in output.splitlines():
        if line.startswith(('Inst ', 'Conf ')):
            raise RuntimeError('Cleanup must not install or reconfigure other packages: ' + line)
        if line.startswith(('Remv ', 'Purg ')):
            removed.add(line.split()[1].split(':')[0])
    unexpected = removed - set(requested)
    if unexpected:
        raise RuntimeError('APT would also remove runtime packages: ' + ', '.join(sorted(unexpected)))
    if removed != set(requested):
        raise RuntimeError('APT removal plan differs from the explicit requested packages')
    return sorted(removed)


def guard():
    if (sys.platform != 'linux' or os.getuid() != 0 or
        os.environ.get('MAKOS_IMAGE_CHROOT') != '1' or
        os.environ.get('GITHUB_ACTIONS') != 'true' or
        not Path('/tmp/makos/source/installer/clean_image.py').is_file() or
        not Path('/opt/makos/installer/clean_image.py').is_file() or
        not Path('/etc/makos/live.json').is_file()):
        raise SystemExit('Only run in the isolated, staged makOS image chroot.')


def backend_package(original, directory):
    """Repackage the original daemon, retaining its name for target cleanup."""
    package = directory / 'backend'; (package / 'DEBIAN').mkdir(parents=True)
    for name in BACKEND_FILES:
        source = Path(name)
        if not source.is_file() or source.is_symlink():
            raise RuntimeError('Missing pinned installer backend file: ' + name)
        target = package / name.lstrip('/'); target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    fields = {key: original[key] for key in ('Package', 'Architecture', 'Depends')}
    fields.update(Version=original['Version'] + '+makos1', Section='admin', Priority='optional',
                  Maintainer='makOS development <noreply@localhost>',
                  **{'Installed-Size': str(sum(p.stat().st_size for p in package.rglob('*') if p.is_file()) // 1024 + 1)})
    control = ''.join(f'{key}: {value}\n' for key, value in fields.items())
    control += ('Description: Installer backend for makOS Recovery\n'
                ' Original Cutefish installer service and authorization policy, repackaged\n'
                ' without the legacy GUI, launcher, autostart or graphical assets.\n')
    (package / 'DEBIAN/control').write_text(control)
    archive = directory / 'backend.deb'
    subprocess.run(['dpkg-deb', '--root-owner-group', '--build', str(package), str(archive)], check=True)
    return archive, fields['Version']


def main():
    guard()
    status = Path('/var/lib/dpkg/status')
    before = package_records(status.read_text())
    if not REPLACED.issubset(before) or 'cutefish-installer' not in before:
        raise RuntimeError('The expected pinned base packages are missing')
    requested = removal_plan(before)
    environment = dict(os.environ, LC_ALL='C', DEBIAN_FRONTEND='noninteractive')
    command = ['apt-get', '-o', 'APT::Get::AutomaticRemove=false', 'purge', '-y', *requested]
    simulation = subprocess.check_output(command[:1] + ['--simulate'] + command[1:], env=environment, text=True)
    validate_simulation(simulation, requested)
    report_dir = Path('/etc/makos'); report_dir.mkdir(exist_ok=True)
    (report_dir / 'package-cleanup-plan.txt').write_text(simulation)
    with tempfile.TemporaryDirectory(prefix='makos-packages-') as temporary:
        archive, version = backend_package(before['cutefish-installer'], Path(temporary))
        # Purge also removes the original installer's autostart conffile. Its
        # replacement has a separate makOS-owned filename and is left intact.
        subprocess.run(command, env=environment, check=True)
        subprocess.run(['dpkg', '--install', str(archive)], env=environment, check=True)
    after = package_records(status.read_text())
    removed = sorted(set(before) - set(after))
    if set(removed) != set(requested) - {'cutefish-installer'}:
        raise RuntimeError('Actual package removals differ from the validated plan')
    if after['cutefish-installer']['Version'] != version:
        raise RuntimeError('Backend-only installer package was not installed')
    absent_paths = ['/usr/bin/' + name for name in REPLACED - {'cutefish-desktop'}]
    absent_paths += ['/usr/bin/cutefish-installer', '/usr/share/cutefish-installer/logo.svg',
                     '/etc/xdg/autostart/cutefish-installer.desktop',
                     '/usr/share/applications/cutefish-installer.desktop']
    absent_paths += ['/usr/share/applications/' + name + '.desktop' for name in REPLACED - {'cutefish-desktop'}]
    for name in absent_paths:
        if Path(name).exists(): raise RuntimeError('Obsolete application file remains: ' + name)
    # Retained shared packages must remain installed, with no broken dependencies.
    subprocess.run(['apt-get', 'check'], env=environment, check=True)
    audit = subprocess.check_output(['dpkg', '--audit'], text=True)
    if audit.strip(): raise RuntimeError(audit)
    # The core package is shared with the new session. Divert its old login entry
    # instead of offering a second session whose GUI applications were removed.
    entry = Path('/usr/share/wayland-sessions/cutefish-wayland.desktop')
    if entry.exists():
        Path('/usr/share/makos').mkdir(exist_ok=True)
        subprocess.run(['dpkg-divert', '--local', '--rename', '--add', '--divert',
                        '/usr/share/makos/base-cutefish-session.desktop.disabled', str(entry)], check=True)
    report = {'result': 'passed', 'source_commit': json.loads((report_dir/'live.json').read_text())['source_commit'],
              'removed_packages': removed, 'removed_paths': absent_paths,
              'installer_backend': {'package': 'cutefish-installer', 'version': version, 'files': list(BACKEND_FILES)},
              'removed_installed_size_kib': sum(int(before[n].get('Installed-Size', 0)) for n in removed),
              'retained_package_count': len(after), 'autoremove_used': False}
    (report_dir / 'package-cleanup.json').write_text(json.dumps(report, indent=2) + '\n')
    print('PASS: removed', len(removed), 'packages; retained only the installer backend')


if __name__ == '__main__': main()
