# makOS boot branding

The image selects a custom `script` Plymouth theme: the provided white ck
monogram on black, with a 4-pixel track and a light progress fill below it.
The 1254-pixel branding canvas is scaled to 192 pixels on a 768-pixel-high
screen (bounded to 160–240 pixels); the logo artwork itself is unchanged.

The theme does not advance a synthetic timer. Its fill follows
`Plymouth.SetBootProgressFunction(duration, progress)`. This is Plymouth's boot
progress estimate, not an exact percentage of remaining kernel or desktop work.
Refresh only updates layout when display geometry changes. Passwords are drawn
from the daemon's bullet count; question and message callbacks remain visible.
The daemon's Esc/details behavior and text/details fallback plugins are retained.
The inherited compatibility boot entry disables splash and remains accessible
through Esc at GRUB; it is not a special AMD safe-graphics mode.

## Verified implementation contracts

The pinned Cutefish ISO ships Plymouth `24.004.60-5` and initramfs-tools `0.148.4`.
Its `/usr/share/initramfs-tools/hooks/plymouth` copies the selected theme, its
script plugin, text/details plugins, fonts and DRM renderer into the initramfs.
Its live-boot hook also copies the live root discovery and overlay support.
The ISO uses `/live/initrd.img-6.12.116+deb13-amd64`, separately from the rootfs.

`ci.sh` stages and renders the theme under the shipped Plymouth script plugin
using the matching Debian X11 renderer and Xvfb. These are synthetic daemon
messages in an isolated CI process namespace, not a boot test. The resulting
screenshots and logs are included with the validation artifact. The X11 test
packages are removed before packaging.

`remaster.sh` rebuilds the kernel's initramfs using `mkinitramfs` inside the
isolated image chroot. This is the builder used by update-initramfs, without
invoking bootloader update hooks. `verify_initrd.py` checks the selected theme,
its asset hashes, live-boot, AMD driver/firmware and fallback plugins. Both the
rootfs's initrd and the ISO's actual `/live/initrd.img-*` are replaced. Internal
ISO checksums include the new initrd. The boot verification JSON is published
in the small metadata artifact.

The rootfs's new-user skeleton also changes the stock Dock file-manager and
Settings pins to the installed `org.makos.Finder` and `org.makos.Settings` IDs,
while preserving the other pins. This applies to newly created live/installed
users, not existing profiles or desktop folder associations.

## Primary source references

- Pinned ISO files: `cutefish/base.json`; `/etc/plymouth/plymouthd.conf`,
  `/usr/share/plymouth/themes/cutefish-logo/cutefish-logo.script`, and the
  initramfs hooks/scripts described above.
- [Plymouth script example, matching source version](https://sources.debian.org/src/plymouth/24.004.60-5/themes/script/script.script/)
- [Plymouth callback bindings](https://sources.debian.org/src/plymouth/24.004.60-5/src/plugins/splash/script/script-lib-plymouth.c/)
- [Plymouth image bindings](https://sources.debian.org/src/plymouth/24.004.60-5/src/plugins/splash/script/script-lib-image.c/)
- [Plymouth X11 validation renderer package](https://packages.debian.org/trixie/plymouth-x11)

A successful image build or X11 render does not establish a successful physical
boot, GPU handoff, Secure Boot support, or measured animation parity with macOS.
