#!/usr/bin/env bash
set -euo pipefail
MAKOS_SOURCE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
[[ "$(uname -s)" == Linux ]] || { echo 'Run this inside the Cutefish Debian 13 environment.' >&2; exit 2; }
command -v cutefish-compositor >/dev/null || { echo 'Install/boot the pinned Cutefish image first.' >&2; exit 2; }
MAKOS_COMPOSITOR_VERSION=$(dpkg-query -W -f='${Version}' cutefish-compositor)
[[ "$MAKOS_COMPOSITOR_VERSION" == '1.0~git20261108143816.0e70913-1' ]] || {
  echo "This preview is pinned to compositor 0e70913; found $MAKOS_COMPOSITOR_VERSION." >&2; exit 2;
}
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  cmake ninja-build g++ pkg-config libwayland-dev qt6-base-dev qt6-base-private-dev \
  qt6-declarative-dev qt6-wayland-dev qt6-wayland-dev-tools qt6-wayland \
  python3-pyside6.qtcore python3-pyside6.qtgui python3-pyside6.qtqml python3-pyside6.qtquick \
  python3-pyside6.qtmultimedia python3-pyside6.qtwebenginequick python3-pyside6.qttest \
  python3-pyside6.qtdbus python3-venv python3-pyte fonts-inter \
  qml6-module-qtcore qml6-module-qtqml qml6-module-qtqml-models qml6-module-qtqml-workerscript \
  qml6-module-qtquick qml6-module-qtquick-window qml6-module-qtquick-layouts \
  qml6-module-qtquick-dialogs qml6-module-qtquick-effects qml6-module-qtquick-controls \
  qml6-module-qtmultimedia qml6-module-qtwebengine
cmake -S "$MAKOS_SOURCE/cutefish" -B "$MAKOS_SOURCE/cutefish/build" -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build "$MAKOS_SOURCE/cutefish/build" -j2
python3 -m venv --system-site-packages "$MAKOS_SOURCE/cutefish/build/venv"
"$MAKOS_SOURCE/cutefish/build/venv/bin/pip" install chess==1.11.2
python3 "$MAKOS_SOURCE/cutefish/install_preview.py"
echo 'Ready to launch: cutefish/run-app finder and cutefish/run-app settings'
