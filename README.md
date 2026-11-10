# makOS · Cutefish experiment

This branch connects our Tahoe-style Finder and System Settings to the Cutefish
compositor, Dock and menu bar. The desktop remains an experimental integration;
visual and animation parity with macOS Tahoe has not been established.

The client bridge exports native app menus, requests compositor glass behind
translucent sidebars, follows fullscreen chrome reveal events, and delegates
window transitions to Cutefish. Finder and Settings have separate desktop IDs
and processes. The existing Deepin/Treeland experiment remains on `makos-deepin`.

## Run in Cutefish

Inside the pinned Cutefish Debian 13 live/install environment:

```sh
bash cutefish/setup.sh
./cutefish/run-app finder
./cutefish/run-app settings
```

See [Cutefish setup, integration details and limits](cutefish/README.md).
The setup uses distribution Qt/PySide6 and builds the native plugin locally.
The commands below refer to the shared standalone Qt preview and its earlier
verification history, not a makOS installer or completed Cutefish desktop.

## Shared Qt preview

On this Mac, open `Tahoe Desktop.app`, double-click `Launch.command`, or run `./run.sh`. The local `.app` contains the camera usage declaration for Photo Booth. It embeds the prepared Python environment and references this checkout; rebuild it with `python build_macos_launcher.py` after moving the project or environment. The source ZIP excludes this machine-specific launcher.

On Linux, use Python 3.10–3.15 with `venv`, then run:

```sh
./run.sh
```

The launcher uses an existing environment or creates `.venv` and installs `requirements.txt`. Qt needs the platform's Wayland/X11 libraries and a working graphics driver. The historical 0.7 Ubuntu package passed its X11 session checks; current Deepin validation is described below. Physical login and hardware behavior remain unverified. Optional arguments:

```sh
./run.sh --fullscreen
./run.sh --settings
./run.sh --compare-right --settings
./run.sh --root /absolute/path/to/a/test-folder
```

The default workspace is `demo-home/`, seeded once with sample files. An explicit `--root` allows file operations in that folder. Existing workspace contents are preserved. Application records and preferences use `.desktop-data/applications.sqlite3`; Finder hides this internal directory. Appearance preferences also use Qt Settings. Notes and editors save after a short delay and flush before selection changes, closing or quitting.

## Applications

The Dock launches our own application windows (native in `--makos` mode). Apps sits immediately after Finder, with search, categories, sorting and keyboard navigation. Its launcher includes 20 applications; Apps itself is the 21st Dock application. Running indicators, hiding, closing, full screen and minimizing track our registered application windows.

| Application | Working functionality | Remaining limits |
| --- | --- | --- |
| Finder | Real workspace browsing; icon/list/column/gallery views; search; folder creation; rename/copy/move/duplicate; reversible Trash; tags; Quick Look; virtual Applications folder | No network volumes, native sharing, tabs, rich PDF previews or whole-computer indexing |
| System Settings | All 32 top-level categories and General routes; persistent appearance, Dock, menu-bar/clock, camera-access and internal audio preferences; real storage counts | Hardware, accounts, networking, security and most OS services are not connected; session operations are connected only in Linux login mode |
| Safari | Qt WebEngine browsing, tabs, bookmarks, one shared private profile per window, Save/Cancel download confirmation, progress and cancellation | Chromium, not Apple's Safari/WebKit; no extensions, sync, download restart recovery or webpage archives |
| Messages / Mail | Local editable records, search, autosave, deletion/restore; Mail exports EML drafts | No messaging, mail account, sending or receiving service |
| Notes / Reminders | Local notes, pinning, search; reminders with completion, priority and date; reversible deletion | Plain-text notes; no notifications or cloud sync |
| Calendar / Contacts | Month navigation and local events; contact editing, favorites and search | No recurrence, notifications or account sync |
| Maps | OpenStreetMap browsing and place search after explicit navigation | No Apple Maps or native route planning |
| Photos | Explicit image import, local library, favorites and image viewing | No cloud library or full editor |
| Music | Explicit file import, playback, seeking, previous/next, volume and mute | Local media only; codecs depend on the Qt backend |
| FaceTime / Phone | Shared local contacts, contact selection, keypad and copying a number | No call provider or Apple-service connection |
| Games / App Store | Local built-in catalog and app launching; Games opens Chess | No Apple storefront, purchases or Linux package installation |
| Terminal | Real interactive PTY shell, input, output, resize, interruption and copy/paste | A shell can affect files outside the demo workspace; it starts only when chosen |
| Calculator | Basic/scientific modes, decimal arithmetic, contextual percent, repeated equals, Deg/Rad, memory and persistent history | No Programmer or Math Notes mode; transcendental results use floating-point precision |
| Chess | Legal moves, castling/en passant, promotion choice, draw claims, history, undo, saved games and bounded computer opponent | Modest-strength local engine, 2D board; no SharePlay or native 3D renderer |
| Photo Booth | Explicit camera start/permission, countdown, single/four-photo capture, filmstrip, Normal/B&W/Sepia/Mirror, flip and contact sheets | Camera capture/live preview not yet tested on hardware; no video recording |

Safari and Maps access the network when navigated. Private cookies are shared across tabs and discarded when the browser window closes. Download history is session-only; accepted files persist in the workspace Downloads folder. Completed downloads use exclusive publication, preserving existing names with a suffix. Cancelling clears only the download's owned staging directory.

Photo Booth starts with the camera off. On macOS, use the generated `.app` so the OS can present a proper permission prompt. A plain Python process without a camera usage declaration reports an explanation instead. Camera capture stops on minimize, hide or close. Original captures remain in `Pictures/Photo Booth/.originals`; processed PNGs and contact sheets appear in Photos. Opening the app alone never starts the camera.

## Desktop behavior

These interaction descriptions refer to preview mode unless explicitly stated.
Native mode delegates window movement, resize, minimize and full screen to the
platform compositor; the remaining integration boundaries are listed above.

- The Desktop shows real files from the workspace `Desktop/` folder. It supports selection, a selection rectangle, contextual menus, persistent icon positions, folder creation, rename, copy/paste, reversible Trash and Undo. Drag files between Finder and Desktop, onto folders, or between desktop positions; Option-drag copies. These are internal workspace drags; host-app drag/import and external volumes are not connected.
- Minimized windows travel to their separate thumbnail on the right of the Dock. The destination is laid out before animation starts and recalculated before restore after a viewport change.
- Transparent normal menu bar by default; optional background and four automatic-hide modes. A hidden bar reveals at the top edge. Full-screen chrome is black.
- Apple menu begins with **About This Mac**, followed by System Settings, App Store, Recent Items, Force Quit and session entries. About shows actual host information and identifies this prototype. The installed Linux login session connects lock, logout and power actions; preview mode cannot invoke them.
- Contextual application menus and Finder menus use inspected native labels and native symbol artwork. Finder archive image assignments are distinguished from semantic fallback choices in the menu-symbol provenance. Once a top-bar menu is open, moving across adjacent titles switches menus without another click. Menu backgrounds sample a blurred, tinted live scene. Unsupported actions are visibly disabled. Force Quit manages this prototype's windows and flushes pending edits.
- Per-app Hide and Hide Others preserve windows without creating minimized Dock thumbnails. Show All unhides apps. Bring All to Front is scoped to the active app.
- The green button enters internal full screen; rapid exit/re-entry preserves the logical original window geometry; default settings hide the menu bar, traffic lights and Dock until the relevant edge is reached. Exiting restores the previous geometry. This does not create native macOS Spaces.
- Inactive Finder windows use an opaque sidebar, dimmed title/traffic lights and reduced toolbar framing. Focus follows both the selected internal window and host-app activation.
- Liquid Glass uses independent Qt shaders, live scene sampling, refraction, blur and tinting. Reduce Motion and Reduce Transparency remain available. See [rendering notes](RENDERING.md).

## Control Center and menu-bar controls

The right-side status items now toggle an anchored panel, switch between open status panels on hover, dismiss on Escape/outside click, and expose contextual pin/remove actions. Command-drag (Ctrl on Linux) reorders items; dragging away from the bar removes the item. Overflow controls remain reachable from the More menu. Sound artwork changes for mute and volume level.

System Settings → Menu Bar contains the observed Tahoe control list, visibility checks, Always/When Active modes, recent-item count, Clock Options, Battery Options, Fast User Switching style, registered-app visibility and a confirmed Reset Control Center action. Clock/date choices update the bar immediately. Reset restores control layout and menu visibility; it does not reset unrelated preferences.

Add Controls opens a searchable category gallery. Controls can be added to either the menu bar or Control Center. Edit mode supports removal, size changes and drag/keyboard/contextual reordering, with persistence across launches. The model retains its delegates during unrelated preference changes, so dragging a volume slider does not lose its pointer grab.

Working local controls include light/dark appearance, Reduce Motion/Transparency, internal scene brightness, Music volume/mute and playback, Focus suppression of this desktop's timer alert, and a persisted countdown timer. Music playback state drives Now Playing visibility. The recent-item count limits local app/document entries; network servers are not supported.

Host Wi-Fi/Bluetooth, AirDrop, mirroring, keyboard lighting, power modes, user switching, backup, weather, music recognition and voice announcements are not connected. Their related settings/details state that limitation. Battery percentage is shown as unavailable rather than inventing telemetry. Scene brightness affects the prototype, not the physical display. No third-party app controls have registered with this prototype yet.

The native Menu Bar, Clock Options and Battery Options were inspected live. The native Add Controls editor could not be captured through the available UI automation, so its gallery geometry is independently reconstructed rather than claimed as 1:1. See `reference/control-center-0.6.json`.

## Keyboard controls

Use Command on macOS and Ctrl on Linux unless stated otherwise.

| Shortcut | Action |
| --- | --- |
| Command-N / W / M | Active-app new action / close / minimize |
| Command-H / Option-Command-H | Hide app / Hide Others |
| Command-Q | Close the active built-in app; Finder stays available |
| Control-Command-F; Linux F11 | Internal window full screen |
| Command-Shift-N | Finder: new folder |
| Command-1 / 2 / 3 / 4 | Finder: icons / list / columns / gallery |
| Command-O or Command-Down | Open selected item |
| Command-Y or Space | Quick Look |
| Command-I / Return | Get Info / rename |
| Command-Up / Command-[ / ] | Enclosing folder / back / forward |
| Command-C / V / Option-Command-V | Copy / paste / move copied files |
| Option-Command-C | Copy pathnames |
| Command-D / Backspace / Z | Duplicate / move to workspace Trash / undo |
| Option-Command-S / P | Toggle sidebar / path bar |
| Command-Shift-A / F | Applications / Recents |
| Command-Shift-. | Show hidden files |
| Control-Option-Q | Quit the complete prototype |

Terminal uses physical Control-C to interrupt the shell. On macOS Command-C/V copy/paste; on Linux Control-Shift-C/V copy/paste. Application editors retain their own text shortcuts. Apps supports arrows, Home/End, Enter, Escape and typing to search.

Trash metadata persists across launches; the filesystem undo stack is per session. Undoing a copied or newly created item also moves it to Trash, preserving subsequent edits. Finder mutations reject symlink escapes and virtual application paths. The Applications folder opens apps and cannot be used to rename/delete files with colliding names.

## REA reference coverage

REA 6.8.0 is connected to the coding agent, with 229 tools. It is a development analysis tool, not a runtime dependency embedded in each app.

[reference/coverage.json](reference/coverage.json) maps all 25 inspected app/shell targets, four modern Settings extensions, and the desktop/topbar composites. It links 115 evidence records to bundle paths, hashes, decoded resources and explicit gaps. The full evidence bundles remain in this workspace's `work/rea-reference/` and are not copied into the release ZIP.

Observed evidence includes application icons, SF symbols, plist identity, localized labels, Interface Builder connections and some asset colors. Desktop/menu-bar references span Finder, Dock, SystemUIServer, ControlCenter and Settings extensions. Static resources do not prove final geometry, visibility, behavior or animation curves. Modern SwiftUI interfaces can contain no decodable Interface Builder layout; legacy/debug menu items are not treated as visible runtime controls. No original Apple source or private Liquid Glass renderer was recovered.

Appearance Settings now uses the measured native sidebar/content geometry, native appearance and Liquid Glass previews, and native category artwork. Theme color, highlight color and Finder sidebar size are connected to local preferences. Icon-style variants, custom folder colors and unconnected OS behavior remain disabled.

Native reference assets came from the local Tahoe 26.7.2 installation. Provenance is recorded in `assets/sources.json`, `assets/symbols/sources.json` and `assets/settings-reference/provenance.json`. Rendering uses the host system font on macOS and available fallback fonts on Linux.

## Verification

Run checks using the same Python environment as the application:

```sh
python -m unittest discover -s tests -v
python tests/smoke_ui.py
python tests/verify_calculator.py
python tests/verify_appslibrary.py
python tests/verify_media_pages.py
python tests/verify_photo_booth_sequence.py
python tests/verify_web_page.py
python tests/verify_web_downloads.py
python tests/verify_settings_appearance.py
python tests/verify_menu_symbols.py
```

**Deepin development verification:** 140 tests pass locally. The [Deepin run](https://github.com/slaveitgr/mak-desktop-environent/actions/runs/42806639307) passes native-window QML checks for all 19 suite apps, Finder and 32 Settings categories using system Qt 6.8.0. A separate headless Treeland 0.8.13 test confirms three shell layer surfaces and two native Finder/Settings windows. See [the exact evidence and limits](reference/verification-deepin-2026-11-10.json). This is not an installer or physical-login validation.

**Historical 0.7 verification:** 136 tests passed on macOS and Ubuntu 26.10; all built-in apps and Settings loaded; the installed X11 session started and stopped cleanly under Xvfb. [Successful Ubuntu run](https://github.com/slaveitgr/mak-desktop-environent/actions/runs/42788148488); [legacy Ubuntu package ZIP](https://github.com/slaveitgr/mak-desktop-environent/actions/runs/42788148488/artifacts/13750056972). See `reference/verification-0.7.json` for scope and limitations.

Previous verification for 0.5 on 10 November 2026: **114 unit/integration tests passed**, including ten desktop mouse-gesture scenarios and eight animation/layout regressions. The complete QML app/Settings smoke check, Appearance controls and menu-symbol/material checks also passed without QML warnings. The rebuilt macOS launcher was reopened and the updated Apple/File menus were visually checked. The seven application verification scripts from 0.4 remain the previous application baseline.

The suite covers persistent records and final-edit flushing, legal chess and asynchronous cancellation, safe calculator evaluation, reversible file operations, download publication, shell lifecycle, virtual-folder guards, menus, clock settings and full-screen transitions. QML checks load every built-in app and Settings category. Browser tests use localhost only. Photo Booth tests use synthetic images and never request a camera; media tests use a silent local WAV.

After the Mac was unlocked, live native Finder and Appearance Settings were inspected. Finder grid/sidebar/toolbar spacing and Settings geometry/previews were revised from those observations. Live prototype checks also confirmed the real Desktop file and its context menu. Native menu capture did not expose every composited layer, and native Dock timings were not measured. Physical Linux graphics/login, real camera permissions/capture, frame-time measurements and synchronized native animation comparison remain unverified. Functional checks do not establish 1:1 visual equivalence.

## Implementation and next platform boundary

`main.py` bridges Qt to the confined file workspace. `suite.py` provides SQLite records/preferences and Chess integration. `browser_downloads.py`, `photo_effects.py`, `calculator_engine.py`, `chess_engine.py` and `terminal_session.py` implement the corresponding local services. `qml/` contains the shell and application views; `shaders/` includes source and precompiled Qt packages. `build_shaders.py` rebuilds every shader with the pinned Qt compiler.

The previous `makos-deepin` branch uses Deepin, Treeland/Waylib and selected DDE services.
Our shell and application views remain project code, with native client windows
in development mode. The earlier 0.7 Openbox/picom session is a historical
prototype. No makOS VM has been booted or makOS installer ISO produced yet.

To create a source package without user data or local runtimes, run `python package_release.py`. The ZIP contains a SHA-256 manifest and seeds a fresh workspace on first launch. Existing release archives are never overwritten by this command.

## Previous Deepin integration reference

The [base and integration notes](distro/README.md) record the pinned Deepin ISO,
shipped component versions, app reuse decisions and runtime constraints.
`dde_services.py` implements the first DDE Audio1 adapter. File Manager, Album
and other Deepin application backends still need bounded integration work;
launching their existing interfaces does not implement our Tahoe views.

[Cutefish](reference/cutefish-2026-11.md) and [PearOS](reference/pearos-2026-11.md)
were inspected as additional references. Cutefish supplies its own toolkit and
compositor; PearOS uses Plasma/KWin. Neither is a drop-in Treeland component.
No Reef runtime was identified in the inspected Cutefish nightly ISO, and no
Mac application compatibility is claimed. Exact source revisions and licensing
boundaries are recorded in the corresponding `reference/*-sources.json` files.
