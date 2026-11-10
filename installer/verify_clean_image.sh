#!/usr/bin/env bash
# Invoked only inside remaster.sh's private mount/PID namespaces and chroot.
set -euo pipefail
[[ "${MAKOS_IMAGE_CHROOT:-}" == 1 && "${GITHUB_ACTIONS:-}" == true ]] || exit 2
test -s /etc/makos/package-cleanup.json
test -d /tmp/makos/source
# Private device nodes for actual PTY and Wayland runtime checks after purge.
mount -t tmpfs -o size=64m tmpfs /dev
for spec in 'null 1 3' 'zero 1 5' 'random 1 8' 'urandom 1 9' 'tty 5 0'; do
  read -r name major minor <<< "$spec"
  mknod -m 666 "/dev/$name" c "$major" "$minor"
done
mkdir -p /dev/pts /dev/shm
mount -t devpts -o newinstance,ptmxmode=0666 devpts /dev/pts
ln -s pts/ptmx /dev/ptmx
mount -t tmpfs -o size=512m tmpfs /dev/shm
mkdir -p /run/dbus /tmp/makos/post-cleanup
rm -f /run/dbus/system_bus_socket
dbus-daemon --system --fork --nopidfile
chown -R makos-test:makos-test /tmp/makos/post-cleanup
export MAKOS_SOURCE_COMMIT
MAKOS_SOURCE_COMMIT=$(python3 -c 'import json; print(json.load(open("/etc/makos/live.json"))["source_commit"])')
runuser -u makos-test -- /bin/bash -se <<'USER'
cd /tmp/makos/source
export PATH="/tmp/makos/source/cutefish/build/venv/bin:$PATH"
export PYTHONPATH=/tmp/makos/source
export QTWEBENGINE_DISABLE_SANDBOX=1 QT_QUICK_CONTROLS_STYLE=Basic
export XDG_RUNTIME_DIR=/tmp/makos/runtime
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software
python3 -m unittest -v tests.test_image_cleanup tests.test_recovery tests.test_terminal tests.test_terminal_launcher > /tmp/makos/post-cleanup/tests.log 2>&1
dbus-run-session -- env MAKOS_EXTERNAL_SHELL_TEST=1 python3 cutefish/branding/probe_external.py --output /tmp/makos/post-cleanup > /tmp/makos/post-cleanup/external-shell.log 2>&1
# This repeats native startup for every app plus Recovery, Finder and Settings
# against the actual compositor, now with the legacy packages absent.
dbus-run-session -- python3 cutefish/ci_session.py > /tmp/makos/post-cleanup/native-clients.log 2>&1
cp /tmp/makos/results/integration.json /tmp/makos/post-cleanup/native-integration.json
cp /tmp/makos/results/installed-terminal-launcher.log /tmp/makos/post-cleanup/
# Also exercise the installed /opt copy, not just the source checkout.
/opt/makos/cutefish/build/venv/bin/python /opt/makos/installer/recovery.py --preview --smoke-test > /tmp/makos/post-cleanup/installed-recovery.log 2>&1
/opt/makos/cutefish/build/venv/bin/python /opt/makos/tests/smoke_ui.py --native-windows > /tmp/makos/post-cleanup/installed-apps.log 2>&1
USER
python3 - <<'PY'
import json, subprocess
from pathlib import Path
executables = ['/usr/bin/cutefish-compositor', '/usr/libexec/cutefish-installer-service',
 '/opt/makos/cutefish/build/settings/makos-settings-backend',
 '/opt/makos/cutefish/build/auth/makos-polkit-agent',
 '/opt/makos/cutefish/build/qml/MakOS/Cutefish/libmakoscutefish.so']
for binary in executables:
    result = subprocess.run(['ldd', binary], text=True, capture_output=True)
    if result.returncode or 'not found' in result.stdout:
        raise SystemExit(binary + ': ' + result.stdout + result.stderr)
report = json.loads(Path('/etc/makos/package-cleanup.json').read_text())
report['runtime_validation'] = {'result': 'passed', 'elf_dependencies': executables,
 'checks': ['external shell, Apps, Super, Control Center and OSD', '20 native apps',
            'Finder and Settings lifecycle', 'Recovery', 'installed QML apps', 'Terminal PTY'],
 'limits': ['Headless software rendering; not physical boot or GPU validation.']}
Path('/etc/makos/package-cleanup.json').write_text(json.dumps(report, indent=2) + '\n')
print('PASS: cleaned image runtime, installed applications and ELF dependencies')
PY
