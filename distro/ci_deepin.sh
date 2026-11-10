#!/usr/bin/env bash
set -euo pipefail
[[ "${GITHUB_ACTIONS:-}" == "true" ]] || { echo 'This isolated rootfs harness is only for GitHub Actions.' >&2; exit 2; }
MAKOS_ROOTFS="$RUNNER_TEMP/makos-deepin-root"
MAKOS_ISO="$RUNNER_TEMP/base/deepin-desktop-community-25.2.0-amd64.iso"
[[ ! -e "$MAKOS_ROOTFS" ]] || { echo 'Refusing to overwrite an existing rootfs.' >&2; exit 2; }
mkdir -p ci-results
MAKOS_OFFSET=$("$RUNNER_TEMP/inspect/bin/python" - "$MAKOS_ISO" <<'PY'
import pycdlib,sys
iso=pycdlib.PyCdlib();iso.open(sys.argv[1])
print(iso.get_record(rr_path='/live/filesystem.squashfs').extent_location()*2048)
iso.close()
PY
)
sudo unsquashfs -no-progress -no-xattrs -d "$MAKOS_ROOTFS" -offset "$MAKOS_OFFSET" "$MAKOS_ISO"
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
sudo chroot "$MAKOS_ROOTFS" /bin/bash -se <<'SH'
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends python3-venv dbus-x11 qml6-module-org-kde-layershell \
  libqt6webenginequick6 qml6-module-qtquick-effects qml6-module-qtquick-controls \
  qml6-module-qtmultimedia qml6-module-qtwebengine fonts-inter
python3 -m venv /tmp/makos/venv
/tmp/makos/venv/bin/pip install PySide6==6.8.0.2 chess==1.11.2 pyte==0.8.2 wcwidth==0.9.4
useradd --create-home --shell /bin/bash makos-test
mkdir -p /tmp/makos/results
chown -R makos-test:makos-test /tmp/makos
runuser -u makos-test -- /bin/bash -se <<'USER'
cd /tmp/makos/source
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu
export QML_IMPORT_PATH=/usr/lib/x86_64-linux-gnu/qt6/qml
export QTWEBENGINE_DISABLE_SANDBOX=1
export QT_QUICK_CONTROLS_STYLE=Basic
/tmp/makos/venv/bin/python distro/probe.py > /tmp/makos/results/readiness.json
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software /tmp/makos/venv/bin/python tests/smoke_ui.py --native-windows > /tmp/makos/results/native-apps.log 2>&1
dbus-run-session -- /tmp/makos/venv/bin/python distro/ci_treeland.py > /tmp/makos/results/treeland-check.log 2>&1
USER
SH
