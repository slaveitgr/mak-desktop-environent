#!/usr/bin/env bash
set -euo pipefail
[[ "${GITHUB_ACTIONS:-}" == "true" ]] || { echo 'This isolated rootfs harness is only for GitHub Actions.' >&2; exit 2; }
MAKOS_ROOTFS="$RUNNER_TEMP/makos-cutefish-root"
MAKOS_ISO="$RUNNER_TEMP/base/cutefish-1.0-nightly-20261108-2229-amd64.iso"
[[ ! -e "$MAKOS_ROOTFS" ]] || { echo 'Refusing to overwrite an existing rootfs.' >&2; exit 2; }
mkdir -p ci-results
MAKOS_LAYERS=$("$RUNNER_TEMP/inspect/bin/python" - "$MAKOS_ISO" <<'PY'
import pycdlib,sys
iso=pycdlib.PyCdlib();iso.open(sys.argv[1])
print(iso.get_record(rr_path='/live/filesystem.squashfs').extent_location()*2048)
iso.close()
PY
)
# Extract the verified Cutefish live filesystem without booting or installing it.
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
test -s /usr/share/keyrings/debian-archive-keyring.gpg
printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d
chmod 755 /usr/sbin/policy-rc.d
echo 'deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] https://deb.debian.org/debian trixie main' > /tmp/makos/sources.list
apt_args=(-o Dir::Etc::sourcelist=/tmp/makos/sources.list -o Dir::Etc::sourceparts=- -o APT::Update::Error-Mode=any)
apt-get "${apt_args[@]}" update
apt-get "${apt_args[@]}" install -y --no-install-recommends \
  cmake ninja-build g++ pkg-config libwayland-dev qt6-base-dev qt6-base-private-dev \
  qt6-declarative-dev qt6-wayland-dev qt6-wayland-dev-tools qt6-wayland \
  python3-pyside6.qtcore python3-pyside6.qtgui python3-pyside6.qtqml python3-pyside6.qtquick \
  python3-pyside6.qtmultimedia python3-pyside6.qtwebenginequick python3-pyside6.qttest \
  python3-pyside6.qtdbus python3-venv python3-pyte dbus-x11 fonts-inter \
  qml6-module-qtcore qml6-module-qtqml qml6-module-qtqml-models qml6-module-qtqml-workerscript \
  qml6-module-qtquick qml6-module-qtquick-window qml6-module-qtquick-layouts \
  qml6-module-qtquick-dialogs qml6-module-qtquick-effects qml6-module-qtquick-controls \
  qml6-module-qtmultimedia qml6-module-qtwebengine
mkdir -p /tmp/makos/results /run/dbus
dbus-uuidgen --ensure=/etc/machine-id
dbus-daemon --system --fork --nopidfile
useradd --create-home --shell /bin/bash makos-test
chown -R makos-test:makos-test /tmp/makos
runuser -u makos-test -- /bin/bash -se <<'USER'
cd /tmp/makos/source
export XDG_RUNTIME_DIR=/tmp/makos/runtime
mkdir -m 700 "$XDG_RUNTIME_DIR"
export QTWEBENGINE_DISABLE_SANDBOX=1 QT_QUICK_CONTROLS_STYLE=Basic
cmake -S cutefish -B cutefish/build -G Ninja -DCMAKE_BUILD_TYPE=Debug > /tmp/makos/results/build.log 2>&1
cmake --build cutefish/build -j2 >> /tmp/makos/results/build.log 2>&1
python3 -m venv --system-site-packages cutefish/build/venv
cutefish/build/venv/bin/pip install chess==1.11.2
export PATH="/tmp/makos/source/cutefish/build/venv/bin:$PATH"
python3 cutefish/install_preview.py
python3 distro/probe.py > /tmp/makos/results/readiness.json
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software python3 tests/smoke_ui.py --native-windows > /tmp/makos/results/native-apps.log 2>&1
dbus-run-session -- python3 cutefish/ci_session.py > /tmp/makos/results/cutefish-check.log 2>&1
USER
SH
