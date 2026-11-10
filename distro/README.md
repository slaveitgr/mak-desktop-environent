# makOS base and integration

The product target is a Deepin-based Linux system named **makOS**. Treeland owns
Wayland composition; DDE supplies selected system services. The Tahoe-style
shell and app interfaces remain project code. The earlier Ubuntu/Openbox target
is historical and its workflow is manual only.

## Verified base image

`base.json` pins Deepin 25.2.0 AMD64, 6,976,131,072 bytes, SHA-256
`f875c9a605bfe6a8425d1d353a3c1ec755bf37f5b0a3231ca19e2145da0ff450`.
The image was downloaded and matched the [official checksum](https://cdimage.deepin.com/releases/25.2.0/amd64/SHA256SUMS).

```sh
python3 distro/fetch_base.py --output "$HOME/Downloads/makOS"
python3 distro/probe.py
./run.sh --makos --settings
```

Fetching and probing do not install an operating system or modify a disk. The
download is resumable in fixed-size chunks, validates HTTP ranges, then assembles
and hashes the whole image before publishing the `.iso` filename.

Read-only inspection of the actual image, not just release notes, found:

| Component | Included version / mechanism |
| --- | --- |
| Base | Deepin 25, codename `crimson`, AMD64 |
| Treeland | 0.8.13, plus data and wallpaper factory |
| DDE | shell 2.0.49; session 2.0.27; daemon 6.1.99 |
| File Manager | 6.5.151, device/service plugins, indexing services |
| Qt | 6.8.0, with Deepin package revisions |
| DTK | 6.7.44; declarative 6.7.44.1; system settings 6.0.2 |
| Applications | Many supplied as Linglong apps, not ordinary Debian packages |
| Photos candidate | `org.deepin.album` 6.0.61.1 |
| Music candidate | `org.deepin.music` 7.0.59.1 |
| Photo Booth candidate | `org.deepin.camera` 6.5.41.1 |
| Calendar candidate | `org.dde.calendar` 6.5.40.1 |
| Mail candidate | `org.deepin.mail` 6.5.75.1 |
| Calculator candidate | `org.deepin.calculator` 6.5.35.1 |
| Browser candidate | `org.deepin.browser` 6.6.5.13 |

The shipped `treeland.desktop` launches `/usr/bin/dde-session` and is marked
`Hidden=true`; the installation/OEM setup handles its availability. This is not
equivalent to writing an arbitrary login `.desktop` file. DDE's session units
also own compositor startup/shutdown and daemon dependencies.

The live Deepin package repository inspected on 2026-11-10 offers Treeland
0.9.1 and LayerShellQt 6.3.4; those are not the ISO versions. `upstream.json`
records the newer source revisions reviewed for architecture, not a claim that
those revisions are installed or compatible with the pinned image.

## Implementation status

`--makos` uses one `ApplicationWindow` per Finder, Settings and suite app. Views
retain their existing styling and page implementations. Native move/resize,
activation, minimize/restore, full screen, close and draft flushing are connected.
Dock thumbnails are image captures: sharing a live `ShaderEffectSource` between
different Qt windows is invalid.

`dde_services.py` implements the actual DDE Audio1 property/method contract,
with asynchronous calls, timeouts, no implicit service activation, availability
tracking and error reporting. Control Center and Sound settings use it when
connected. Plain preview and macOS development do not invoke system services.
Wire-contract tests pass; no Deepin hardware audio test has been performed yet.

Native mode is an integration preview, not a complete Treeland login session.
Dock/topbar layer-shell surfaces, compositor blur, global menus for external
apps, native cross-window file drag/drop, lock/session teardown, multiple monitors
and the compositor Genie animation remain to be integrated and tested. Preview
mode retains its existing in-scene animations. Native mode currently delegates
window transitions to the running window manager/compositor.

## Reusing Deepin applications

| makOS area | Selected direction | Evidence / boundary |
| --- | --- | --- |
| Finder | DFM services for devices and indexing; keep our views | Source includes documented D-Bus DeviceManager, FileNameIndex, TextIndex and mount interfaces. No calls to destructive disk methods have been added. |
| Settings / Control Center | DDE service adapters | Audio1 default sink and SetVolume/SetMute are the first implemented adapter. Network, displays and power still need dedicated adapters. |
| Photos | Evaluate a maintained Album fork or extracted model library | Album's DBManager and import/thumbnail models exist, but its CMake currently builds one executable. It is not a ready-made Python backend. |
| Music / Photo Booth / Calendar / Mail | Audit each app's model and service boundaries before porting | The ISO contains these apps as Linglong bundles. Launching an unmodified bundle does not turn its UI into our Tahoe interface. |
| Browser | Compare maintained engines and complete-app approaches | Our current browser is Qt WebEngine. Pear Pafari/Seafari use different UI/engine stacks; see the separate inspection before choosing. |

Keep package and asset attribution when importing source. Merely renaming an
upstream application is not treated as a completed makOS implementation. Existing
local records remain preserved until a tested data migration is available.

## Qt and session constraints

The Python preview currently bundles Qt, while Deepin DTK/LayerShell plugins are
built against the distribution's Qt. Those must be aligned before loading native
plugins; copying the system QML path into an arbitrary pip environment is unsafe.
`probe.py` makes that distinction visible without attempting an installation.

The development Mac reports `kern.hv_support=0`; hardware-accelerated virtualization
was not available in the inspected environment. The base ISO is ready, but no VM
has been booted, no makOS installer ISO has been produced, and physical login or
GPU animation performance has not been verified.

## Validation

The existing 136 tests plus four DDE adapter tests pass locally. Both preview and
native-window QML checks cover all 19 suite apps, Finder, 32 Settings categories,
menu routing, minimize/restore, full screen, singleton handling and close. Native
checks additionally verify distinct platform windows and context-menu ownership.
These headless checks establish behavior contracts, not visual/animation parity.
