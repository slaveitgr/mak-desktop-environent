# Cutefish nightly ISO evidence

Read-only inspection of `cutefish-1.0-nightly-20261108-2229-amd64.iso`. No boot, installation, target execution, or product changes. Source trees were not reanalysed wholesale.

## Identity and coverage

- Input: `cutefish-1.0-nightly-20261108-2229-amd64.iso`, 1,563,197,440 bytes.
- SHA-256: `bedebb9260e9b413980fc62f192b72a9d2ddeca7c7bc98d6042c9dda7978e933`, matching the [official manifest](https://download.cutefish.org/iso/nightly/cutefish-1.0-nightly-20261108-2229-amd64.iso.sha256). The web tool retrieved this manifest; a direct urllib HTTP403 reported by the parent is an access-method limitation, not a checksum mismatch.
- Read `/live/filesystem.squashfs` directly with pycdlib/dissect.squashfs. Full pathname inventory: 52,216 entries, symlinks not followed. 859 Debian package records, 25 application desktop entries. `/Applications` is empty.
- `/etc/os-release`: Debian13 (trixie), `DEBIAN_VERSION_FULL=13.7`, build `20261108T223208Z`. Kernel package `linux-image-6.12.116+deb13-amd64` version `6.12.116-1`.
- Detailed raw evidence is retained in the development workspace under `work/cutefish-iso/`: `iso.json`, `inventory.json`, `header-scan.json`, selected extracted files under `rootfs/`, `selected-artifacts.json`, `source-provenance.json`, `rea-compositor-elf.json`, `rea-appruntime-elf.json`.

## Actual desktop architecture

The only installed Wayland session entry is `/usr/share/wayland-sessions/cutefish-wayland.desktop`, executing `cutefish-wayland-session`. Its shell wrapper sets Cutefish/Wayland environment variables and executes `cutefish-session`. The compositor package describes the status bar, Dock, launcher, notifications and capture as built into the compositor. These are not separately installed Plasma applets.

| Component | Installed package version | Payload/dependencies observed |
| --- | --- | --- |
| Compositor + shell | `1.0~git20261108143816.0e70913-1` | `/usr/bin/cutefish-compositor`; ELF dependency declarations include Wayland server, DRM/GBM/EGL/GLES, libseat, libinput, PipeWire, Cutefish toolkit and service clients |
| Toolkit | `1.0~git20261108054901.90c1a06-1` | `libcutefish-toolkit.so.1.0` and `libcutefish-toolkit-base.so.1.0`; Wayland/EGL, font/image libraries, ICU/systemd |
| Framework | `1.0~git20261104150900.1971254-1` | Files, thumbnails and display/audio/network/accounts/appearance service client libraries; package dependencies include NetworkManager, BlueZ, PipeWire/WirePlumber, UPower and GNOME Keyring |
| Core/session | `1.0~git20261107203419.98b846f-1` | `cutefish-session`, `cutefish-services`, `cutefish-appruntime`, polkit agent and session wrapper |
| Settings | `1.0~git20261107223125.d623dbd-1` | `/usr/bin/cutefish-settings`; Cutefish toolkit plus display/audio/network/BlueZ/accounts/appearance/timedate/power clients |
| Files | `1.0~git20261104215431.d326cd9-1` | `/usr/bin/cutefish-filemanager`; toolkit, files and thumbnails libraries; package also depends on UDisks2, FUSE3, archive, SMB, SSH, MTP and LZFSE libraries |
| Login manager | `1.0~git20261028062042.77e1229-1` | `cutefish-dm`, compositor, toolkit and PAM |

The inspected native compositor, toolkit, Settings and Files ELF dependency tables contain no Qt libraries. Qt5/Qt6 libraries and `cutefish-qt-plugins` are nevertheless installed for application integration. No KWin, Treeland or wlroots package was identified. This is a separate desktop/compositor/toolkit stack; it is not a drop-in theme for Treeland. `DT_NEEDED` declarations are static dependencies, not a complete account of possible runtime `dlopen` calls.

Additional shipped applications include Calculator, Calendar/reminders, Terminal, Text Editor, Video Player, System Monitor and Screenshot. Native launchers execute their corresponding Cutefish binaries. This inventory does not establish feature completeness.

## Reef investigation

No identifiable Reef executable or framework payload was found in the examined image. Evidence is narrower than a universal proof of absence:

1. None of the 859 package names identifies Reef, Darling, Objective-C/GNUstep or Swift.
2. A full bounded pathname inventory found no Reef paths, `.framework` payloads, AppKit, CoreGraphics, SwiftUI, dyld or libobjc paths. The broad regex produced three false positives belonging to the Linux `e2freefrag` utility. Package file lists attribute its binary/manual to `e2fsprogs` and its completion file to `bash-completion`.
3. The owned compositor, app runtime, session/services, Settings, Files and selected toolkit/framework libraries were extracted and hashed. Complete bytes of these selected files yielded no Reef/AppKit/Foundation.framework/CoreGraphics/SwiftUI/Mach-O string candidates. Their parsed ELF dependency declarations contain no such framework dependencies.
4. `/usr/bin/cutefish-appruntime` is owned by `cutefish-core`. It is a Linux ELF executable linked to toolkit-base, ICU, systemd and C++/C runtime libraries. Its generic name does not establish that it is Reef.
5. A first-16-byte content scan of all 39,881 regular files found 3,360 ELF files and zero Mach-O/fat-Mach-O magic candidates, with no read errors. Symlinks and nested archive contents were not followed. This excludes exposed Mach-O files at this inventory level, not compatibility logic compiled into a differently named ELF file.

The public [Reef announcement](https://cutefish.org/blog/running-mac-apps/) describes a closed-source compatibility implementation coupled to Cutefish's toolkit, compositor and shell. That is an upstream claim, not a runtime result from this inspection. The currently checked-out newer compositor source contains a `/usr/bin/reef` placement reference; the ISO does not contain that path. Integration code or a blog demonstration must not be treated as proof of a shipped working compatibility runtime.

## Source provenance and licensing

Shipped Debian changelogs name exact snapshot commits:

| Package/source | Claimed snapshot |
| --- | --- |
| [Compositor](https://github.com/cutefishos/cutefish-compositor) | `0e709136bd7056136e74e981acffc4b88d659e0b` |
| [Toolkit](https://github.com/cutefishos/cutefish-toolkit) | `90c1a06e3dbef3b2578b2c4e209e10f39959f95f` |
| [Framework](https://github.com/cutefishos/cutefish-framework) | `19712540d65ef7c270b4e937e3af674b860a0265` |
| [Core](https://github.com/cutefishos/cutefish-core) | `98b846f1d6848cc2ddb983d4b8c75fbc5107f2cc` |
| [Files](https://github.com/cutefishos/filemanager) | `d326cd9a831885367e983dc713aaa70571e84713` |
| [Settings](https://github.com/cutefishos/settings) | `d623dbdd2b0913f0d7d9dc19cb5ce1abbcf85805` |

These are package-provided provenance declarations, not independently reproduced builds. Of the four inspected source HEADs, only framework matches the ISO snapshot; compositor, toolkit and Files are newer/different revisions.

The shipped compositor copyright file lists BSD-3-Clause, APSL-2.0 for pointer acceleration, and Expat/MIT protocol notices. Toolkit lists BSD-3-Clause. Core/framework/Files/Settings copyright files contain only upstream/source headers, so they do not independently establish all per-file licenses; consult the exact source revision before importing code. Reef's availability/licensing is separate from those public repositories.

## Exact executable evidence and limits

REA's target-free ELF parser confirms the shipped compositor as x86-64 ELF: 9,118,672 bytes, SHA-256 `25719549c9994a1c99e0debc36b69c6d000cc3ab05215d1ecfebe10c212851b1`, GNU build ID `d96095289df4f3193113c0c6e1a127dbc2828a2a`. Evidence retained in `rea-compositor-elf.json`; no active REA disassembler session opened.

Other exact hashes and owners are in `selected-artifacts.json`, including app runtime SHA-256 `a71d6d636b086f6c76196f47571324025000691d59811dec9236d508438433f8`, Settings `f2ea3e0934442a93bbd622845d3646807ef566a133bc76c993647c24073c5bea`, and Files `a67a4985ddf5590f61c0c6bb14b4968542c5263bade4711f43c91bd2cd0b403a`.

No animation timing, visual fidelity, hardware support, runtime menu behavior or Mac-app compatibility was tested. Renamed, encrypted, embedded or later-downloaded compatibility payloads cannot be ruled out by the selected static investigation. Public Cutefish components can inform makOS design; the ISO provides no validated Reef backend to transplant.
