#!/usr/bin/env bash
set -euo pipefail
TAHOE_SOURCE="$(cd -- "$(dirname -- "$0")/.." && pwd)"
if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
    echo 'This installer supports Intel/AMD Ubuntu 22.04, 24.04, 26.04 and 26.10.' >&2
    exit 1
fi
if [[ $EUID == 0 ]]; then
    echo 'Run ./linux/install.sh as your ordinary user. It asks sudo only for apt installation.' >&2
    exit 1
fi
source /etc/os-release
if [[ "$ID" != ubuntu || ( "$VERSION_ID" != 22.04 && "$VERSION_ID" != 24.04 && "$VERSION_ID" != 26.04 && "$VERSION_ID" != 26.10 ) ]]; then
    echo 'Supported target: Ubuntu 22.04 / 24.04 / 26.04 / 26.10. Other releases need a separately verified Qt/Python package.' >&2
    exit 1
fi
sudo apt-get update
sudo apt-get install --no-install-recommends python3-venv dpkg-dev
python3 "$TAHOE_SOURCE/linux/build_deb.py"
TAHOE_VERSION="$(python3 -c 'import sys; sys.path.insert(0,sys.argv[1]); from package_release import VERSION; print(VERSION)' "$TAHOE_SOURCE")"
sudo apt-get install --reinstall "$TAHOE_SOURCE/dist/tahoe-desktop_${TAHOE_VERSION}.0_amd64.deb"
/usr/bin/tahoe-session --check
echo 'Installed. Log out, select your user, then choose Tahoe Desktop (Experimental) from the session menu and log in.'
