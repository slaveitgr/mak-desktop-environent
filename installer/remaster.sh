#!/usr/bin/env bash
set -euo pipefail
[[ "${GITHUB_ACTIONS:-}" == true && "${MAKOS_BUILD_RECOVERY_ISO:-}" == 1 ]] || exit 2
MAKOS_ROOTFS="$RUNNER_TEMP/makos-cutefish-root"
MAKOS_BASE="$RUNNER_TEMP/base/cutefish-1.0-nightly-20261108-2229-amd64.iso"
MAKOS_IMAGE_DIR="$RUNNER_TEMP/makos-image"
mkdir -p "$MAKOS_IMAGE_DIR" artifacts
sudo env GITHUB_ACTIONS=true python3 installer/stage_image.py --rootfs "$MAKOS_ROOTFS" --source "$PWD"
sudo env GITHUB_ACTIONS=true python3 cutefish/stage_session.py --rootfs "$MAKOS_ROOTFS" --source "$PWD"
sudo unshare --mount --pid --fork --kill-child --mount-proc="$MAKOS_ROOTFS/proc" chroot "$MAKOS_ROOTFS" /bin/bash -se <<'ROOT'
python3 -m venv --system-site-packages /opt/makos/cutefish/build/venv
/opt/makos/cutefish/build/venv/bin/pip install chess==1.11.2
XDG_DATA_HOME=/usr/share python3 /opt/makos/cutefish/install_preview.py
MAKOS_IMAGE_CHROOT=1 python3 /opt/makos/installer/boot/seed_dock.py
# The X11 renderer and virtual display are validation tools, not boot dependencies.
apt-get purge -y plymouth-x11 xvfb xauth
# Rebuild the actual live initramfs. The live-tools update-initramfs wrapper
# may skip live media; mkinitramfs is its underlying builder, without GRUB hooks.
MAKOS_KERNEL=6.12.116+deb13-amd64
test "$(plymouth-set-default-theme)" = makos
test -d "/lib/modules/$MAKOS_KERNEL"
mkinitramfs -o "/boot/initrd.img-$MAKOS_KERNEL.makos" "$MAKOS_KERNEL"
mv "/boot/initrd.img-$MAKOS_KERNEL.makos" "/boot/initrd.img-$MAKOS_KERNEL"
python3 /opt/makos/installer/boot/verify_initrd.py "/boot/initrd.img-$MAKOS_KERNEL" /etc/makos/boot-verification.json
apt-get clean
userdel --remove makos-test
rm -rf /tmp/makos
# ci.sh's private PID namespace has stopped its temporary system bus. Do not
# carry that daemon's stale socket into the image's otherwise static /run.
if [[ -S /run/dbus/system_bus_socket ]]; then
  rm -f /run/dbus/system_bus_socket
fi
rm -f /usr/sbin/policy-rc.d /etc/machine-id /var/lib/dbus/machine-id
: > /etc/machine-id
: > /etc/resolv.conf
ROOT
# ci.sh has unmounted the private /dev and /proc before this stage.
if mountpoint -q "$MAKOS_ROOTFS/dev" || mountpoint -q "$MAKOS_ROOTFS/proc"; then
  echo 'The private test mounts are still active.' >&2; exit 2
fi
sudo cp "$MAKOS_ROOTFS/boot/initrd.img-6.12.116+deb13-amd64" "$MAKOS_IMAGE_DIR/initrd.img-6.12.116+deb13-amd64"
sudo cp "$MAKOS_ROOTFS/etc/makos/boot-verification.json" artifacts/boot-verification.json
sudo mksquashfs "$MAKOS_ROOTFS" "$MAKOS_IMAGE_DIR/filesystem.squashfs" -comp xz -b 1M -noappend -no-progress -processors 2
sudo chroot "$MAKOS_ROOTFS" dpkg-query -W -f='${Package} ${Version}\n' > "$MAKOS_IMAGE_DIR/filesystem.packages"
"$RUNNER_TEMP/inspect/bin/python" installer/iso_metadata.py --base "$MAKOS_BASE" --directory "$MAKOS_IMAGE_DIR"
xorriso -indev "$MAKOS_BASE" -outdev artifacts/makOS-Recovery-0.1-amd64.iso \
  -boot_image any replay -volid MAKOS_RECOVERY \
  -map "$MAKOS_IMAGE_DIR/filesystem.squashfs" /live/filesystem.squashfs \
  -map "$MAKOS_IMAGE_DIR/filesystem.packages" /live/filesystem.packages \
  -map "$MAKOS_IMAGE_DIR/grub.cfg" /boot/grub/grub.cfg \
  -map "$MAKOS_IMAGE_DIR/initrd.img-6.12.116+deb13-amd64" /live/initrd.img-6.12.116+deb13-amd64 \
  -map "$MAKOS_IMAGE_DIR/sha256sum.txt" /sha256sum.txt -commit -end
xorriso -indev artifacts/makOS-Recovery-0.1-amd64.iso -report_el_torito plain > artifacts/boot-layout.txt 2>&1
(cd artifacts && sha256sum makOS-Recovery-0.1-amd64.iso) > artifacts/SHA256SUMS
cat artifacts/SHA256SUMS artifacts/boot-layout.txt
