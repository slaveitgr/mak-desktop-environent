#!/usr/bin/env bash
set -euo pipefail
[[ "${GITHUB_ACTIONS:-}" == true && "${MAKOS_BUILD_RECOVERY_ISO:-}" == 1 ]] || exit 2
MAKOS_ROOTFS="$RUNNER_TEMP/makos-cutefish-root"
MAKOS_BASE="$RUNNER_TEMP/base/cutefish-1.0-nightly-20261108-2229-amd64.iso"
MAKOS_IMAGE_DIR="$RUNNER_TEMP/makos-image"
mkdir -p "$MAKOS_IMAGE_DIR" artifacts
sudo env GITHUB_ACTIONS=true python3 installer/stage_image.py --rootfs "$MAKOS_ROOTFS" --source "$PWD"
sudo chroot "$MAKOS_ROOTFS" /bin/bash -se <<'ROOT'
python3 -m venv --system-site-packages /opt/makos/cutefish/build/venv
/opt/makos/cutefish/build/venv/bin/pip install chess==1.11.2
XDG_DATA_HOME=/usr/share python3 /opt/makos/cutefish/install_preview.py
apt-get clean
userdel --remove makos-test
rm -rf /tmp/makos
rm -f /usr/sbin/policy-rc.d /etc/machine-id /var/lib/dbus/machine-id
: > /etc/machine-id
: > /etc/resolv.conf
ROOT
# ci.sh has unmounted the private /dev and /proc before this stage.
if mountpoint -q "$MAKOS_ROOTFS/dev" || mountpoint -q "$MAKOS_ROOTFS/proc"; then
  echo 'The private test mounts are still active.' >&2; exit 2
fi
sudo mksquashfs "$MAKOS_ROOTFS" "$MAKOS_IMAGE_DIR/filesystem.squashfs" -comp xz -b 1M -noappend -no-progress -processors 2
sudo chroot "$MAKOS_ROOTFS" dpkg-query -W -f='${Package} ${Version}\n' > "$MAKOS_IMAGE_DIR/filesystem.packages"
"$RUNNER_TEMP/inspect/bin/python" installer/iso_metadata.py --base "$MAKOS_BASE" --directory "$MAKOS_IMAGE_DIR"
xorriso -indev "$MAKOS_BASE" -outdev artifacts/makOS-Recovery-0.1-amd64.iso \
  -boot_image any replay -volid MAKOS_RECOVERY \
  -map "$MAKOS_IMAGE_DIR/filesystem.squashfs" /live/filesystem.squashfs \
  -map "$MAKOS_IMAGE_DIR/filesystem.packages" /live/filesystem.packages \
  -map "$MAKOS_IMAGE_DIR/grub.cfg" /boot/grub/grub.cfg \
  -map "$MAKOS_IMAGE_DIR/sha256sum.txt" /sha256sum.txt -commit -end
xorriso -indev artifacts/makOS-Recovery-0.1-amd64.iso -report_el_torito plain > artifacts/boot-layout.txt 2>&1
sha256sum artifacts/makOS-Recovery-0.1-amd64.iso > artifacts/SHA256SUMS
