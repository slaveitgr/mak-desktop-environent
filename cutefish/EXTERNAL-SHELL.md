# One makOS shell on Cutefish

The pinned compositor has no wlr-layer-shell support. `external-shell.patch`
adds a separate `--external-shell` option and a version 2 extension to its
existing trusted shell protocol. The default compositor mode is unchanged.
External mode creates no native Dock, menu bar, Control Center or launcher;
window management, fallback wallpaper, notifications, authentication prompts
and OSD remain compositor services.

`cutefish-shell-v1.xml` describes the matching client protocol. The client uses
normal xdg_toplevel windows, with trusted desktop/panel/Dock metadata added
before mapping. Panel and Dock focus defaults to `no_focus`; genuine
xdg_popup windows can supply menus and keyboard grabs. The compositor handles
stacking, edge reveal and fullscreen hiding. Its exclusive-zone reservations
are cleared when the client unmaps/destroys the surface or disconnects.

The existing `org.cutefish.WindowDebug1` interface is a prototype bridge for
window state and actions. Added methods expose actual native menu models,
close/fullscreen actions, minimize targets and work areas. `GetWindowMenu`
returns a flat `items` list with item IDs and child IDs; item 0 is the root.
`MenuEvent` accepts `prepare`, `opened`, `closed` and `activate`. Native
cutefish-main-menu clients are supported; the GTK DBus-menu adapter is not
implemented in this branch. A stable production shell API remains future work.

`run-session` launches `session.py` as an ordinary user. The supervisor starts
the compositor, waits for its real ready-fd signal, passes a socketpair endpoint
over SCM_RIGHTS to the trusted shell-control channel, and gives the other
endpoint only to the makOS Qt shell. The stock file-manager daemon is never
started. Native app runtime, settings services and the authentication agent are
started separately. Logout/restart/shutdown ask the compositor to close apps
first and respect cancellation. The session tracks and stops only child process
groups that it started. A shell/compositor failure ends this session; it does
not expose a hidden stock desktop.

For live-image selection, `stage_session.py` requires a successful
`ci-results/external-shell-validation.json` with `result: passed`. It installs
`makos.desktop`, sets the DM's default session, and adds `0087-makos-session`.
The later live hook matters: pinned `0086-cutefish-dm` recreates the DM config
at boot with the live username. The makOS hook preserves that username and the
base's noautologin behavior, while selecting `makos`. No permanent autologin
username is added to the rootfs. Merely installing a desktop entry is not enough.

Pinned source evidence: compositor `0e709136bd7056136e74e981acffc4b88d659e0b`,
core `98b846f`, DM `77e1229`. The ISO runs `cutefish-dm.service`, not greetd or
LightDM. The original session remains available for an explicit login choice.

`session.py --headless --smoke-test` checks three real mapped shell roles on a
software display. It does not prove DRM boot, physical GPU rendering, menu
actions, app overlap, restoration or animation parity. The release gate must
also run those integration checks before changing the ISO's login default.
The supervisor currently starts the known required daemons and live Recovery;
general third-party XDG autostart processing is not implemented.

The external shell observes a physical Left/Right Super tap before Cutefish's
Command-layout modifier remapping. It never consumes a keyboard event. Any
other held/pressed key, pointer button, scroll, touch or gesture cancels the tap;
the lock gate also cancels and blocks delivery. After normal release dispatch,
the compositor emits `org.cutefish.WindowDebug1.LauncherToggleRequested`, which
`CutefishShellState.launcherToggleRequested` forwards to the Apps overlay. Stock
mode never emits this signal. A compiled state-machine test covers repeats,
combinations, release order and locking; the native integration gate drives real
key injection and requires toggling/closing without a new application window.
