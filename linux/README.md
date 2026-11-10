# Ubuntu login session

The 0.7 package adds **Tahoe Desktop (Experimental)** to the login screen. Its own Qt Quick shell runs in a dedicated X11 session, with Openbox managing windows and picom handling X11 composition. GNOME/KDE is not started inside this session. Existing desktop choices and the display manager configuration are preserved.

Target: **Ubuntu 26.10 (primary target), plus 22.04, 24.04 and 26.04, Intel/AMD 64-bit**, an installed graphical login manager, and a working Xorg graphics driver. The pinned Qt release needs Python 3.10–3.15. Ubuntu 26.10 ships Python 3.14, so Linux uses PySide6 6.12.0 while the existing macOS build stays on 6.8.3. This is an experimental session, not a finished macOS clone or a Treeland/Wayland compositor.

## Install

From an ordinary user account in your current Ubuntu desktop:

```sh
sudo apt update
sudo apt install git
git clone https://github.com/slaveitgr/mak-desktop-environent.git
cd mak-desktop-environent
./linux/install.sh
```

The script installs build prerequisites, downloads the pinned Python/Qt wheels, builds `dist/tahoe-desktop_0.7.0_amd64.deb` as your user, and installs the package and its Ubuntu dependencies through apt. The Qt runtime is bundled under `/opt/tahoe-desktop/vendor`; no pip installation runs as root. Building needs network access and roughly 1–2 GB of free disk space. Enable Ubuntu's **universe** repository if apt cannot find Openbox or picom.

Log out. At the login screen, select your user, open the gear/session menu, select **Tahoe Desktop (Experimental)** and enter your password. With GDM the session chooser normally appears after selecting the account. No reboot or display-manager restart is required by the installer. If the entry does not appear, verify `/usr/share/xsessions/tahoe.desktop` and `/usr/bin/tahoe-session --check`; your login manager must support X11 sessions.

To preview the installed shell inside your existing desktop, run `tahoe-desktop`. Do not run `tahoe-session` inside GNOME/KDE: it deliberately refuses to replace an active window manager.

## Use and return to Ubuntu

| Action | Control |
| --- | --- |
| Return to the shell, Dock and menu bar | **Super+Space** |
| Open Apps, including installed Linux launchers | **Super+A** |
| Switch between the shell and external Linux windows | **Alt+Tab** |
| Open the built-in Terminal | **Ctrl+Alt+T** |
| Lock the session | **Super+L** or Apple menu → Lock Screen |
| Log out | Apple menu → Log Out, or **Ctrl+Alt+Delete**, then confirm |
| Move/resize an external window | **Alt+left drag / Alt+right drag** |

The locker is i3lock, supervised by xss-lock, with a ten-minute inactivity timeout and logind sleep-lock integration. The first lock screen is i3lock's own UI. Restart/shutdown ask for confirmation, flush internal drafts, and use logind through `systemctl`; polkit may request authentication. Lock, sleep, reboot and poweroff have not been physically exercised on the user's Ubuntu hardware.

After logout choose **Ubuntu** (or your previous desktop) in the same session menu. To remove the package from that desktop:

```sh
sudo apt remove tahoe-desktop
```

Removing it deletes the shell and login entry. User files and preferences remain. No existing GNOME session, login-manager configuration or user home files are replaced. Update with `git pull` and `./linux/install.sh`.

## Data, logs and current limits

The installed shell uses `${XDG_DATA_HOME:-~/.local/share}/tahoe-desktop/workspace`. Finder's Home/Desktop/Documents refer to this workspace, **not the whole Ubuntu home directory**. The data directory is created per user at first launch. `tahoe-desktop --root /absolute/folder` selects another folder explicitly in preview mode.

Session logs: `${XDG_STATE_HOME:-~/.local/state}/tahoe-desktop/session-*.log`. If a required session service or shell fails, the supervisor stops its own process groups and returns control to the display manager; it never uses `killall` or changes the default session. Each login creates a private control socket for its own hotkeys. No downloads occur at login.

- The 21 internal app entries still share one Qt shell window. Linux apps launch as independent Openbox windows. External windows are switched with Alt+Tab; they do not yet have Dock thumbnails or exported global menus. They can cover the shell's Dock and bar; Super+Space brings the shell back.
- Primary-monitor layout only; no integrated multi-monitor arrangement, portal service, generic XDG autostart, freedesktop notification server or native window decoration matching.
- Control Center's Wi-Fi, Bluetooth, battery, hardware brightness/audio and other device services remain unconnected. Internal media/appearance settings work. Installed Linux apps use their own settings and can be opened through Apps.
- X11 session scaffolding is separate from the proposed future Treeland compositor. A login option is not evidence of compositor completeness or Tahoe 1:1 visual/animation parity.

## Validation

`python3 -m unittest discover -s tests` includes session environment/cleanup, disabled-preview safety, desktop-entry discovery and package-content checks. `linux/ci_session.py` exercises the **installed package** under a fresh Xvfb server, checking Openbox startup, the shell's X11 window, control-socket commands, socket routing and owned-process cleanup; separate Qt tests verify external-launch routing and logout cancellation/confirmation. GitHub Actions runs in an Ubuntu 26.10 container on an Ubuntu runner. Xvfb does not validate GDM's physical login screen, hardware acceleration, suspend, lock authentication or multiple monitors.

Reference interfaces: [GNOME session configuration](https://help.gnome.org/system-admin-guide/session-user.html), [Desktop Entry specification](https://specifications.freedesktop.org/desktop-entry/latest-single/), [Ubuntu Openbox](https://packages.ubuntu.com/noble/openbox), [i3lock / xss-lock](https://manpages.ubuntu.com/manpages/noble/man1/i3lock.1.html).

Ubuntu 26.10 references: [release notes / Python 3.14](https://documentation.ubuntu.com/release-notes/26.10/), [GDM package still includes gdm-x-session](https://packages.ubuntu.com/stonking/amd64/gdm3/filelist), [PySide6 6.12.0](https://pypi.org/project/PySide6/6.12.0/). The removal of Ubuntu’s GNOME-on-Xorg session does not itself remove third-party X11 sessions.
