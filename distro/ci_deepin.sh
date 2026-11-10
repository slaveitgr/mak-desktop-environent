#!/usr/bin/env bash
set -euo pipefail
[[ "${GITHUB_ACTIONS:-}" == "true" ]] || { echo 'This isolated rootfs harness is only for GitHub Actions.' >&2; exit 2; }
MAKOS_ROOTFS="$RUNNER_TEMP/makos-deepin-root"
MAKOS_ISO="$RUNNER_TEMP/base/deepin-desktop-community-25.2.0-amd64.iso"
[[ ! -e "$MAKOS_ROOTFS" ]] || { echo 'Refusing to overwrite an existing rootfs.' >&2; exit 2; }
mkdir -p ci-results
MAKOS_LAYERS=$("$RUNNER_TEMP/inspect/bin/python" - "$MAKOS_ISO" <<'PY'
import pycdlib,sys
iso=pycdlib.PyCdlib();iso.open(sys.argv[1])
with iso.open_file_from_iso(rr_path='/live/filesystem.module') as stream:
    modules=stream.read().decode().splitlines()
assert modules == ['filesystem.squashfs', 'filesystem-extra.squashfs'], modules
for module in modules:
    print(iso.get_record(rr_path='/live/'+module).extent_location()*2048)
iso.close()
PY
)
# The second live layer supplies /var/lib/dpkg and the combined package database.
# Extract both in the order declared by the image; the first alone is incomplete.
while read -r MAKOS_OFFSET; do
  sudo unsquashfs -force -no-progress -no-xattrs -d "$MAKOS_ROOTFS" -offset "$MAKOS_OFFSET" "$MAKOS_ISO"
done <<< "$MAKOS_LAYERS"
sudo mkdir -p "$MAKOS_ROOTFS/tmp/makos"
sudo cp -a . "$MAKOS_ROOTFS/tmp/makos/source"
# Replace only the rootfs's resolver link; never follow an absolute symlink.
sudo rm -f "$MAKOS_ROOTFS/etc/resolv.conf"
sudo cp /etc/resolv.conf "$MAKOS_ROOTFS/etc/resolv.conf"
cleanup() {
  sudo cp -a "$MAKOS_ROOTFS/tmp/makos/results/." ci-results/ 2>/dev/null || true
  for point in dev/pts dev/shm dev proc; do sudo umount "$MAKOS_ROOTFS/$point" 2>/dev/null || true; done
}
trap cleanup EXIT
sudo mount -t proc proc "$MAKOS_ROOTFS/proc"
sudo mount -t tmpfs -o size=64m tmpfs "$MAKOS_ROOTFS/dev"
for spec in 'null 1 3' 'zero 1 5' 'random 1 8' 'urandom 1 9' 'tty 5 0'; do
  read -r name major minor <<< "$spec"
  sudo mknod -m 666 "$MAKOS_ROOTFS/dev/$name" c "$major" "$minor"
done
sudo mkdir -p "$MAKOS_ROOTFS/dev/pts" "$MAKOS_ROOTFS/dev/shm"
sudo mount -t devpts -o newinstance,ptmxmode=0666 devpts "$MAKOS_ROOTFS/dev/pts"
sudo ln -s pts/ptmx "$MAKOS_ROOTFS/dev/ptmx"
sudo mount -t tmpfs -o size=512m tmpfs "$MAKOS_ROOTFS/dev/shm"
# All service descendants belong to this PID namespace and are reaped when
# its init shell exits. Its proc mount is private to the namespace.
sudo unshare --mount --pid --fork --kill-child --mount-proc="$MAKOS_ROOTFS/proc" \
  chroot "$MAKOS_ROOTFS" /bin/bash -se <<'SH'
export DEBIAN_FRONTEND=noninteractive
test -s /var/lib/dpkg/status
test -s /usr/share/keyrings/deepin-archive-crimson-keyring.gpg
# The immutable live image leaves sources.list empty. Use only its signed base
# archive for CI dependencies; no driver/app-store sources or service startup.
echo 'deb [signed-by=/usr/share/keyrings/deepin-archive-crimson-keyring.gpg] https://community-packages.deepin.com/deepin/beige crimson main' > /tmp/makos/sources.list
printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d
chmod 755 /usr/sbin/policy-rc.d
apt_args=(-o Dir::Etc::sourcelist=/tmp/makos/sources.list -o Dir::Etc::sourceparts=- -o Acquire::SmartMirrors::Enable=false -o APT::Update::Error-Mode=any)
apt-get "${apt_args[@]}" update
apt-get "${apt_args[@]}" install -y --no-install-recommends python3-venv dbus-x11 libqt6test6 qml6-module-org-kde-layershell \
  libqt6webenginequick6 qml6-module-qtcore qml6-module-qtqml qml6-module-qtqml-base \
  qml6-module-qtqml-models qml6-module-qtqml-workerscript qml6-module-qtquick \
  qml6-module-qtquick-window qml6-module-qtquick-layouts qml6-module-qtquick-dialogs \
  qml6-module-qtquick-effects qml6-module-qtquick-controls \
  qml6-module-qtmultimedia qml6-module-qtwebengine fonts-inter
python3 -m venv /tmp/makos/venv
/tmp/makos/venv/bin/pip install PySide6==6.8.0.2 chess==1.11.2 pyte==0.8.2 wcwidth==0.9.4
# Wheel RPATHs take precedence over LD_LIBRARY_PATH. Keep the wheel's Qt
# libraries outside its search path so bindings and distribution QML plugins
# share the actual Deepin Qt. Preserve them only as unused CI diagnostics.
/tmp/makos/venv/bin/python - <<'QT'
from pathlib import Path
import shutil,sysconfig
libraries=Path(sysconfig.get_path('purelib'))/'PySide6'/'Qt'/'lib'
assert libraries.is_dir(), libraries
shutil.move(str(libraries), '/tmp/makos/unused-wheel-qt-libraries')
qml=libraries.parent/'qml'
shutil.move(str(qml), '/tmp/makos/unused-wheel-qml')
QT
useradd --create-home --shell /bin/bash makos-test
mkdir -p /tmp/makos/results
chown -R makos-test:makos-test /tmp/makos
# DConfig is a system-bus service, not provided by dbus-run-session. Use the
# account, policy and service executable shipped in the verified image.
id deepin-daemon
install -d -m 755 /run/dbus
install -d -m 700 -o deepin-daemon -g deepin-daemon /var/lib/dde-dconfig-daemon
install -d -m 755 -o deepin-daemon -g deepin-daemon /var/log/deepin
dbus-uuidgen --ensure=/etc/machine-id
export DSG_DATA_DIRS=/usr/share/dsg:/var/lib/linglong/entries/share/dsg
dbus-daemon --system --fork --nopidfile
dbus-send --system --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus \
  org.freedesktop.DBus.StartServiceByName string:org.desktopspec.ConfigManager uint32:0
runuser -u makos-test -- /bin/bash -se <<'USER'
cd /tmp/makos/source
export XDG_RUNTIME_DIR=/tmp/makos/runtime
mkdir -m 700 "$XDG_RUNTIME_DIR"
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu
export QML_IMPORT_PATH=/usr/lib/x86_64-linux-gnu/qt6/qml
export QT_PLUGIN_PATH=/usr/lib/x86_64-linux-gnu/qt6/plugins
export QTWEBENGINE_DISABLE_SANDBOX=1
export QT_QUICK_CONTROLS_STYLE=Basic
/tmp/makos/venv/bin/python distro/probe.py > /tmp/makos/results/readiness.json
/tmp/makos/venv/bin/python - <<'CHECK'
import json
qt=json.load(open('/tmp/makos/results/readiness.json'))['qt']
assert qt['runtime'] == '6.8.0', qt
assert qt.get('loaded_libraries') and all(p.startswith('/usr/lib/') for p in qt['loaded_libraries']), qt
CHECK
native_status=0
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software /tmp/makos/venv/bin/python tests/smoke_ui.py --native-windows > /tmp/makos/results/native-apps.log 2>&1 || native_status=$?
treeland_status=0
dbus-run-session -- /tmp/makos/venv/bin/python distro/ci_treeland.py > /tmp/makos/results/treeland-check.log 2>&1 || treeland_status=$?
echo "Native apps: $native_status; Treeland surfaces: $treeland_status"
[[ "$native_status" == 0 && "$treeland_status" == 0 ]]
USER
SH
