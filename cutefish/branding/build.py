#!/usr/bin/env python3
"""Build the pinned compositor inside the disposable image/CI chroot only."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import urllib.request
from PySide6.QtCore import QSettings
from PySide6.QtSvg import QSvgRenderer


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    source = Path('/tmp/makos/source')
    if os.environ.get('MAKOS_COMPOSITOR_CHROOT') != '1' or not (source/'cutefish/base.json').is_file() or os.getuid() != 0:
        raise SystemExit('Use the isolated Cutefish CI rootfs.')
    directory = source/'cutefish/branding'
    logo = source/'installer/branding/makos-ck-symbol.svg'
    if not logo.is_file() or not QSvgRenderer(str(logo)).isValid():
        raise SystemExit('The native menu-bar SVG is missing or invalid.')
    manifest = json.loads((directory/'source.json').read_text())
    assert manifest['commit'] == json.loads((source/'cutefish/base.json').read_text())['compositor_source']
    scratch = Path('/tmp/makos/compositor-branding')
    scratch.mkdir(exist_ok=False)
    archive = scratch/'source.tar.gz'
    with urllib.request.urlopen(manifest['url'], timeout=60) as response, archive.open('wb') as output:
        total = 0
        while chunk := response.read(1024*1024):
            total += len(chunk)
            if total > 32*1024*1024:
                raise RuntimeError('Unexpectedly large source archive')
            output.write(chunk)
    assert archive.stat().st_size == manifest['archive_bytes']
    assert digest(archive) == manifest['archive_sha256'], 'Pinned source digest mismatch'
    prefix = 'cutefish-compositor-' + manifest['commit']
    with tarfile.open(archive) as bundle:
        members = bundle.getmembers()
        assert sum(member.size for member in members) < 64*1024*1024
        for member in members:
            parts = Path(member.name).parts
            assert parts and parts[0] == prefix and '..' not in parts
            assert member.isdir() or member.isfile(), member.name
        bundle.extractall(scratch, members=members, filter='data')
    upstream = scratch/prefix
    shortcut_header = directory/'lone_modifier_tap.h'
    shutil.copy2(shortcut_header, upstream/'src/input/lone_modifier_tap.h')
    shortcut_test = scratch/'lone-modifier-tap-test'
    subprocess.run(['c++', '-std=c++20', '-Wall', '-Wextra', '-Werror',
                    str(directory/'test_lone_modifier_tap.cpp'), '-o', str(shortcut_test)], check=True)
    subprocess.run([str(shortcut_test)], check=True)
    patches = [directory/'menu-bar-brand-icon.patch', directory/'external-shell.patch', directory/'osd-external.patch', directory/'headless-render.patch']
    for patch in patches:
        subprocess.run(['patch', '--batch', '--forward', '--fuzz=0', '-p1', '-i', str(patch)], cwd=upstream, check=True)
    assert (upstream/'protocols/cutefish-shell-v1.xml').read_bytes() == (source/'cutefish/protocols/cutefish-shell-v1.xml').read_bytes()
    build = scratch/'build'
    subprocess.run(['cmake', '-S', str(upstream), '-B', str(build), '-G', 'Ninja',
                    '-DCMAKE_BUILD_TYPE=Release', '-DCMAKE_INSTALL_PREFIX=/usr',
                    '-DBUILD_TESTING=OFF', '-DCUTEFISH_ENABLE_XWAYLAND=ON'], check=True)
    subprocess.run(['cmake', '--build', str(build), '--target', 'cutefish-compositor', '-j2'], check=True)
    binary = build/'cutefish-compositor'
    subprocess.run(['strip', '--strip-unneeded', str(binary)], check=True)
    installed = Path('/usr/bin/cutefish-compositor')
    original_sha = digest(installed)
    shutil.copy2(binary, installed)
    installed.chmod(0o755)
    report = {**manifest, 'patches_sha256': {patch.name:digest(patch) for patch in patches},
              'lone_modifier_tap_sha256': digest(shortcut_header), 'original_binary_sha256': original_sha,
              'patched_binary_sha256': digest(installed),
              'note': 'Development image binary override; upstream dpkg package version is unchanged. Native-session tests run after this build.'}
    Path('/etc/makos').mkdir(exist_ok=True)
    (Path('/etc/makos')/'compositor-branding.json').write_text(json.dumps(report, indent=2)+'\n')
    (Path('/tmp/makos/results')/'compositor-branding.json').write_text(json.dumps(report, indent=2)+'\n')
    # The test user's skeleton points to the checkout. Image finalization changes
    # this to the persistent /opt/makos path before live users are created.
    settings_file = Path('/etc/skel/.config/cutefish/shell.conf')
    settings_file.parent.mkdir(parents=True, exist_ok=True)
    settings = QSettings(str(settings_file), QSettings.Format.IniFormat)
    settings.setValue('MenuBar/BrandIcon', str(logo)); settings.sync()
    assert settings.status() == QSettings.Status.NoError
    print('PASS: built and installed the pinned compositor with shell-only branding; native session validation follows.')


if __name__ == '__main__':
    main()
