# makOS / Cutefish experimental clients

This branch connects the existing Finder and System Settings views to the
Cutefish desktop. The compositor's Dock, menu bar and window transitions own
presentation. The hidden Qt controller does not map a second desktop, Dock or
menu bar over them. The original Deepin experiment is preserved on `makos-deepin`.

## Running on the pinned Cutefish live/install environment

Use `cutefish-1.0-nightly-20261108-2229-amd64.iso`, verified by `base.json`.
Inside its Linux environment, with this branch checked out:

```sh
bash cutefish/setup.sh
./cutefish/run-app finder
./cutefish/run-app settings
```

Setup installs distribution build/runtime packages, builds the bridge in this
checkout and registers two user desktop entries/icons. It does not replace the
display manager, compositor, stock Cutefish applications or system files with
makOS versions. Keep the checkout in place: the launchers refer to it. Each app
is a separate process with a stable desktop ID; launching it again activates
the existing instance for the same workspace. Both use the shared workspace's
records/files. An explicit `--root /path` selects a different workspace.

The ordinary `run.sh` remains the independent Qt preview. Its pip Qt runtime is
not used for this integration: the native plugin and Python Qt bindings must
come from the same distribution Qt. The setup environment inherits Debian's
PySide6/Qt and installs only the chess dependency in its own venv.

## Connected behavior

- Finder and Settings export their app identity and native Wayland windows for
  Dock grouping, activation, thumbnails and compositor minimize/restore.
- The native main-menu protocol exports each window's menu tree, nested items,
  labels, enabled/check states, themed symbols and shortcuts. Actions route to
  the existing handlers. A menu refreshes before opening and while its state
  changes, without replacing the menu answering the compositor's open event.
- The glass protocol requests a rounded, refracting sidebar backdrop. Active
  windows expose the real background there; inactive windows and Reduce
  Transparency keep an opaque sidebar. The previous wallpaper approximation
  is not drawn over an active compositor glass region.
- The fullscreen reveal event supplies the offset and transition duration for
  application chrome. Traffic lights follow that event in Cutefish mode.
- Window open/close/minimize transitions belong to Cutefish; the Qt preview's
  corresponding scale/fade/Genie animation is not layered over them.
- Settings forwards Dock size, auto-hide and glass tint, plus menu-bar battery
  percentage, to the actual Cutefish session D-Bus services. Missing services
  report an error and are not implicitly started. The shipped compositor does
  not export these services in headless mode; live-session settings success
  still needs a graphical-session test. Unsupported Dock switches
  are disabled in this mode.

The imported XML definitions are pinned to the compositor snapshot named by the
ISO package, with hashes and its BSD license in `protocols/`. The adapter does
not load or reproduce Reef.

## Validation and current limits

Local regression: 144 tests pass, including four shell-adapter wire-contract
checks. The existing native-window smoke test loads all 19 suite app pages,
Finder and 32 Settings categories. This branch's Cutefish entry points are
specifically Finder and Settings.

The CI workflow extracts the verified ISO into an isolated Linux rootfs,
installs matching Debian build dependencies, builds the real native bridge and
exercises the shipped compositor with a headless output. Protocol and behavior
validation is in progress; a successful result must be recorded separately.

Headless protocol acceptance cannot establish visual quality or GPU frame
timings. No Cutefish session has been booted on the development Mac. The
compositor's stock system menu, desktop icons and Control Center still use
Cutefish's implementation. Most Settings fields remain local prototype
preferences; appearance changes are not yet synchronized across the two app
processes or with Cutefish's appearance service. No physical login, multi-monitor
test, complete external drag/drop integration or macOS animation parity is
claimed. Cutefish's current minimize transition is not evidence of Apple's
Genie deformation or timings.
