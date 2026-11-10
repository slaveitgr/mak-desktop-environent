# makOS Recovery development image

The first screen follows the macOS Recovery layout: a menu bar, a centered
four-option utilities window, keyboard selection, double-click and Continue.
The development preview uses original makOS vector artwork for three utility
icons and the existing browser asset. It is not a verified pixel-identical copy.

```sh
./installer/run --preview
```

A preview cannot launch installation or disk tools. In a live image, startup
requires both the mounted `/run/live/medium` and the image's `/etc/makos/live.json`.
The image's Cutefish autostart entry opens Recovery. Its window uses the actual
Cutefish menu bar through the same native bridge as Finder and Settings; the
preview draws its own menu bar. The Dock hides while Recovery runs and returns
to its previous auto-hide setting when choosing Try makOS.

## What Continue opens

| Choice | Live utility | Current boundary |
| --- | --- | --- |
| Restore from Backup | Déjà Dup restore wizard | Compatible file backups; no Apple Time Machine restoration |
| Install makOS | The ISO's Cutefish installer | Copies the remastered makOS filesystem; its installation wizard still uses Cutefish's interface and confirmation flow |
| Web Browser | Chromium in a separate temporary profile | No Safari or Apple account services |
| Disk Utility | GNOME Disks | Real disk tools, using their own authorization/confirmation UI |

Utilities also exposes Cutefish Terminal. These processes start only when the
user selects them. Closing a utility returns to Recovery. Starting Recovery
itself does not select, partition, erase or install to any disk. The launch
adapter never calls the privileged installer `Install` method directly.

The original Cutefish installer package is
`1.0~git20261030043000.0cb8ef5-1`, from commit
`0cb8ef507f7be0f3dc26ce56d0a168f9210881a5` of
[cutefish-installer](https://github.com/cutefishos/cutefish-installer).
Its service copies `/run/live/medium/live/filesystem.squashfs`, validates disk
and account choices, and asks polkit before installation. Its packages and
licenses remain in the image.

## Building

`.github/workflows/recovery-image.yml` starts on changes to `installer/` in the
`makos-cutefish` branch. It verifies the pinned ISO, builds/tests the Qt clients,
adds the Recovery utilities, stages makOS in `/opt/makos`, and remasters the ISO
with xorriso's boot-configuration replay. It updates the filesystem package list
and checksums and publishes an ISO with a SHA-256 digest as a workflow artifact.
The isolated image rootfs is the only filesystem remastered; no host disk is a
partitioning target. `stage_image.py` and `remaster.sh` are workflow-only tools.

Installed Finder/Settings launchers use the user's home directory, rather than
a writable workspace inside `/opt`. Recovery autostart is live-only. The
underlying system remains Debian 13 with Cutefish, with makOS development
branding and the two native makOS clients added.

## Verification boundaries

The local chooser renders and its four launch routes have isolated tests.
Native menu integration is checked under the shipped headless compositor.
An assembled image and valid boot metadata do not establish a successful boot
or installation on hardware. The complete disk-install/restore flow and final
utility appearance require testing in a disposable VM before normal use. The
current work does not claim that the entire installation wizard matches Tahoe.
