# makOS Recovery development image

The first screen follows the dark macOS Recovery references supplied by the user: a menu bar, a centered
four-option utilities window, keyboard selection, double-click and Continue.
The preview uses original Mac resource renderings for Disk Utility, Time Machine,
Safari, drive icons and seven toolbar symbols, with provenance hashes in
`assets/original/provenance.json`. The OS installation icon remains makOS artwork;
the corresponding macOS installer resource was not found on this machine. It is not a verified pixel-identical copy.

```sh
./installer/run --preview
```

A preview can open the makOS installer interface, but cannot discover real destination disks or start installation. In a live image, startup
requires both the mounted `/run/live/medium` and the image's `/etc/makos/live.json`.
The image's Cutefish autostart entry opens Recovery. Its window uses the actual
Cutefish menu bar through the same native bridge as Finder and Settings; the
preview draws its own menu bar. The Dock hides while Recovery runs and returns
to its previous auto-hide setting when choosing Try makOS.

## What Continue opens

| Choice | Live utility | Current boundary |
| --- | --- | --- |
| Restore from Backup | Déjà Dup restore wizard | Compatible file backups; no Apple Time Machine restoration |
| Install makOS | makOS installer interface + original Cutefish system daemon | Whole-disk erase only; account/time zone, explicit disk confirmation and fresh layout verification |
| Web Browser | Chromium in a separate temporary profile | No Safari or Apple account services |
| Disk Utility | makOS Disk Utility | Read-only Linux inventory; explicit handoff to GNOME Disks for changes |

Utilities also exposes Cutefish Terminal. These processes start only when the
user selects them. Closing a utility returns to Recovery. Starting Recovery
itself does not select, partition, erase or install to any disk. The makOS installer adapter calls the privileged daemon’s `Install` method only after the user reviews and confirms the exact destination. The original Cutefish installer window is not launched. Progress and completion come from daemon signals; a disconnected or timed-out request is not reported as success.

The image also installs `org.makos.Installer.desktop` for this interface. The
stock Cutefish wizard's desktop entry is hidden and replaced with the makOS
command; its privileged service stays installed. The welcome panel follows
the observed light Tahoe installer layout, while Recovery and Disk Utility
keep the supplied dark reference appearance.

The original Cutefish installer package is
`1.0~git20261030043000.0cb8ef5-1`, from commit
`0cb8ef507f7be0f3dc26ce56d0a168f9210881a5` of
[cutefish-installer](https://github.com/cutefishos/cutefish-installer).
Its service copies `/run/live/medium/live/filesystem.squashfs`, validates disk
and account choices, and asks polkit before installation. Its packages and
licenses remain in the image.

## Disk Utility

The makOS window has a device/volume sidebar, View menu (hide sidebar, volumes
only, all devices), capacity and mounted-filesystem usage, and a details table.
Live scans use bounded asynchronous `lsblk --json` calls with explicit columns.
Unavailable usage is shown as unavailable, rather than as an empty disk.
Refresh preserves the selected device when it remains present.

The toolbar opens operation information and an explicit **Open Disk Tools**
button. That button selects the device in GNOME Disks; it does not erase or
format it. Name, filesystem, partition map, authentication and final destructive
confirmation still belong to GNOME Disks. No APFS formatting or macOS container
support is claimed. The makOS erase sheet is not yet the complete native form.

```sh
./installer/run --preview --disk-utility
```

Preview uses clearly labelled example disks and cannot open system disk tools.
The native Cutefish session exports this window's View menu to the actual topbar.

## Installer and first-start references

`visual-references.json` records the supplied Recovery/Disk Utility screenshots
and the linked installation guides, including the Tahoe version linked from the
macOS 27 article. The first-start country/account screens are reference material;
a makOS first-start assistant is not yet implemented or enabled in this image.

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

The chooser and Disk Utility render locally. Ten Recovery/disk unit checks cover
launch isolation, inventory semantics and explicit disk-tool handoff. A real QML
smoke test checks two Recovery/Disk Utility round trips and volume selection.
Native menu integration is checked under the shipped headless compositor.
An assembled image and valid boot metadata do not establish a successful boot
or installation on hardware. The complete disk-install/restore flow and final
utility appearance require testing in a disposable VM before normal use. The
current work does not claim that the entire installation wizard matches Tahoe.
