#!/usr/bin/env python3
"""Supervise a dedicated X11 login session; never replace an existing WM."""
import argparse
from datetime import datetime
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = ('openbox', 'picom', 'wmctrl', 'dbus-run-session', 'xss-lock', 'i3lock', 'xset', 'gio')


def environment(base, socket_path):
    env = dict(base)
    env.update(XDG_CURRENT_DESKTOP='X-Tahoe', XDG_SESSION_DESKTOP='tahoe',
               DESKTOP_SESSION='tahoe', XDG_SESSION_TYPE='x11',
               QT_QPA_PLATFORM='xcb', QT_QUICK_CONTROLS_STYLE='Basic',
               TAHOE_SESSION_SOCKET=str(socket_path),
               PYTHONPATH=str(ROOT / 'vendor'))
    return env


def terminate_owned(children, grace=5):
    """Each tracked child owns a new process group. No killall/pkill or PID file."""
    for child in reversed(children):
        try:
            os.killpg(child.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
    deadline = time.monotonic() + grace
    for child in reversed(children):
        try:
            child.wait(timeout=max(0.01, deadline - time.monotonic()))
        except subprocess.TimeoutExpired:
            pass
    for child in reversed(children):
        try:
            os.killpg(child.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        child.wait()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true', help='Check installed session dependencies without starting it')
    parser.add_argument('--smoke-test', action='store_true', help='Isolated X server only: load the shell, then exit; no locker or power actions')
    args = parser.parse_args()
    if sys.platform != 'linux' or os.getuid() == 0:
        parser.error('This session runs as an ordinary user on Linux, never as root.')
    missing = [command for command in REQUIRED if not shutil.which(command)]
    if missing:
        parser.error('Missing dependencies: ' + ', '.join(missing))
    probe_env = dict(os.environ, PYTHONPATH=str(ROOT / 'vendor'))
    subprocess.run([sys.executable, '-c', 'import PySide6.QtQuick, PySide6.QtWebEngineQuick, chess, pyte'], env=probe_env, check=True)
    if args.check:
        print('Tahoe session dependencies are available. Select Tahoe Desktop at login.')
        return 0
    if not os.environ.get('DISPLAY'):
        parser.error('An X11 display is required. Choose Tahoe Desktop in your login screen.')
    if subprocess.run(['wmctrl', '-m'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
        parser.error('A window manager is already running. Log out and choose Tahoe Desktop; do not start this inside GNOME/KDE.')
    if not os.environ.get('DBUS_SESSION_BUS_ADDRESS'):
        os.execvp('dbus-run-session', ['dbus-run-session', '--', sys.executable, str(Path(__file__).resolve()), *sys.argv[1:]])
    state = Path(os.environ.get('XDG_STATE_HOME', Path.home() / '.local/state')) / 'tahoe-desktop'
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    log_path = state / ('session-' + datetime.now().strftime('%Y%m%d-%H%M%S') + '.log')
    children = []
    stopping = False
    def stop(*_):
        nonlocal stopping
        stopping = True
    for signum in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        signal.signal(signum, stop)
    runtime = os.environ.get('XDG_RUNTIME_DIR')
    with tempfile.TemporaryDirectory(prefix='tahoe-session-', dir=runtime) as directory, log_path.open('a') as log:
        os.chmod(log_path, 0o600)
        env = environment(os.environ, Path(directory) / 'control.sock')
        def start(command):
            log.write('Starting: ' + command[0] + '\n'); log.flush()
            child = subprocess.Popen(command, env=env, stdout=log, stderr=log, start_new_session=True)
            children.append(child)
            return child
        try:
            wm = start(['openbox', '--config-file', str(ROOT / 'linux/openbox.xml')])
            deadline = time.monotonic() + 10
            while subprocess.run(['wmctrl', '-m'], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode != 0:
                if stopping or wm.poll() is not None or time.monotonic() >= deadline:
                    raise RuntimeError('Openbox could not start. See ' + str(log_path))
                time.sleep(0.1)
            start(['picom', '--config', str(ROOT / 'linux/picom.conf')])
            locker = None
            if not args.smoke_test:
                locker = start(['xss-lock', '--transfer-sleep-lock', '--', 'i3lock', '--nofork', '--color=182331'])
                subprocess.run(['xset', 's', '600', '600'], env=env, check=True)
                # A policy agent can present logind/admin authentication requests.
                for path in ('/usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1',
                             '/usr/libexec/polkit-gnome-authentication-agent-1'):
                    if Path(path).is_file():
                        start([path]); break
            command = [sys.executable, str(ROOT / 'main.py'), '--session']
            if args.smoke_test:
                command.append('--smoke-test')
            shell = start(command)
            while not stopping and shell.poll() is None:
                if wm.poll() is not None or (locker is not None and locker.poll() is not None):
                    raise RuntimeError('A required session service exited. Returning to login; see ' + str(log_path))
                time.sleep(0.1)
            return shell.returncode if shell.returncode is not None else 0
        finally:
            terminate_owned(children)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, RuntimeError, subprocess.SubprocessError) as exc:
        print('Tahoe session failed: ' + str(exc), file=sys.stderr)
        sys.exit(1)
