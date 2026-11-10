#!/usr/bin/env python3
"""Exercise installed X11 session under Xvfb, without touching the login manager."""
import os
from pathlib import Path
import select
import socket
import subprocess
import tempfile
import time


def main():
    with tempfile.TemporaryDirectory(prefix='tahoe-login-test-') as folder:
        base = Path(folder)
        runtime = base / 'runtime'; runtime.mkdir(mode=0o700)
        home = base / 'home'; home.mkdir()
        rfd, wfd = os.pipe()
        xvfb = subprocess.Popen(['Xvfb', '-displayfd', str(wfd), '-screen', '0', '1440x900x24', '-nolisten', 'tcp'], pass_fds=(wfd,))
        os.close(wfd)
        session = None
        try:
            assert select.select([rfd], [], [], 10)[0], 'Xvfb failed to allocate a display'
            display = ':' + os.read(rfd, 128).decode().strip()
            env = dict(os.environ, DISPLAY=display, HOME=str(home), XDG_RUNTIME_DIR=str(runtime),
                       XDG_DATA_HOME=str(home / '.local/share'), XDG_CONFIG_HOME=str(home / '.config'),
                       XDG_STATE_HOME=str(home / '.local/state'), QTWEBENGINE_DISABLE_SANDBOX='1')
            env.pop('DBUS_SESSION_BUS_ADDRESS', None)
            env.pop('WAYLAND_DISPLAY', None)
            session = subprocess.Popen(['/usr/bin/tahoe-session', '--smoke-test'], env=env)
            deadline = time.monotonic() + 40
            socket_path = None
            while time.monotonic() < deadline and session.poll() is None:
                paths = list(runtime.glob('tahoe-session-*/control.sock'))
                if paths:
                    socket_path = paths[0]
                    break
                time.sleep(0.05)
            assert socket_path, 'Installed shell never created its control socket'
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                listing = subprocess.run(['wmctrl', '-l'], env=env, capture_output=True, text=True)
                if 'Tahoe Desktop' in listing.stdout:
                    break
                time.sleep(0.05)
            assert 'Tahoe Desktop' in listing.stdout, listing.stdout + listing.stderr
            assert subprocess.run(['wmctrl', '-m'], env=env, capture_output=True).returncode == 0
            # An active window manager must never be replaced by a second login.
            duplicate = subprocess.run(['/usr/bin/tahoe-session', '--smoke-test'], env=env, capture_output=True, text=True, timeout=15)
            assert duplicate.returncode != 0 and 'already running' in duplicate.stderr, duplicate.stderr
            for command in ('show', 'apps', 'terminal'):
                with socket.socket(socket.AF_UNIX) as client:
                    client.settimeout(3); client.connect(str(socket_path)); client.sendall((command + '\n').encode())
                    assert client.recv(128) == b'OK\n', command
            assert session.wait(timeout=30) == 0, 'Session did not exit cleanly'
            assert not socket_path.exists(), 'Control socket leaked after logout'
            assert subprocess.run(['wmctrl', '-m'], env=env, capture_output=True).returncode != 0, 'Window manager survived session'
            logs = list((home / '.local/state/tahoe-desktop').glob('session-*.log'))
            assert logs
            for log in logs:
                text = log.read_text()
                print(text)
                assert not any(message in text for message in ('QQmlApplicationEngine failed', 'Traceback (most recent call last)', 'Binding loop detected', 'TypeError:', 'ReferenceError:')), text
            print('PASS: installed session, Openbox, native shell window, hotkeys, duplicate-session guard and cleanup')
        finally:
            for log in (home / '.local/state/tahoe-desktop').glob('session-*.log'):
                print('Session diagnostics:', log.read_text(), flush=True)
            os.close(rfd)
            if session and session.poll() is None:
                session.terminate()
                try: session.wait(timeout=10)
                except subprocess.TimeoutExpired: session.kill(); session.wait()
            xvfb.terminate(); xvfb.wait(timeout=5)


if __name__ == '__main__':
    main()
