#!/usr/bin/env python3
"""Exercise the actual Deepin Treeland compositor, with isolated owned processes."""
import os
from pathlib import Path
import signal
import stat
import subprocess
import sys
import tempfile
import time


def main():
    root = Path(__file__).resolve().parents[1]
    results = Path('/tmp/makos/results')
    with tempfile.TemporaryDirectory(prefix='makos-wayland-') as folder:
        runtime = Path(folder)
        runtime.chmod(0o700)
        env = dict(os.environ, XDG_RUNTIME_DIR=folder, WLR_BACKENDS='headless',
                   WLR_HEADLESS_OUTPUTS='1', WLR_RENDERER='pixman',
                   LIBGL_ALWAYS_SOFTWARE='1', DSG_APP_ID='org.deepin.dde.treeland')
        for key in ('DISPLAY', 'WAYLAND_DISPLAY', 'QT_QUICK_BACKEND', 'QT_QPA_PLATFORM'):
            env.pop(key, None)
        with (results / 'compositor.log').open('w') as log:
            compositor = subprocess.Popen(['treeland'], env=env, stdout=log, stderr=log, start_new_session=True)
            try:
                deadline = time.monotonic() + 30
                socket = None
                while time.monotonic() < deadline and compositor.poll() is None:
                    socket = next((p for p in runtime.glob('*wayland*') if stat.S_ISSOCK(p.stat().st_mode)), None)
                    if socket: break
                    time.sleep(0.2)
                if socket is None:
                    raise RuntimeError('Treeland did not expose a Wayland socket; see compositor.log')
                client_env = dict(env, WAYLAND_DISPLAY=str(socket), QT_QPA_PLATFORM='wayland',
                                  QT_QUICK_BACKEND='software', WAYLAND_DEBUG='client',
                                  DSG_APP_ID='org.makos.Desktop')
                with (results / 'wayland-client.log').open('w') as client_log:
                    client = subprocess.run([sys.executable, str(root / 'main.py'), '--makos',
                                             '--wayland-shell', '--settings', '--smoke-test',
                                             '--root', str(runtime / 'workspace')], env=client_env,
                                            stdout=client_log, stderr=client_log, timeout=35)
                trace = (results / 'wayland-client.log').read_text()
                if client.returncode != 0 or 'failed to load component' in trace or 'TypeError:' in trace:
                    raise RuntimeError('makOS failed under Treeland; see wayland-client.log')
                if trace.count('.get_layer_surface(') < 3 or trace.count('.get_toplevel(') < 2:
                    raise RuntimeError('Expected three layer surfaces and two native app windows in the protocol trace')
                print('PASS: Treeland accepted desktop/menu/Dock layer surfaces and Finder/Settings native toplevels.')
            finally:
                if compositor.poll() is None:
                    os.killpg(compositor.pid, signal.SIGTERM)
                    try: compositor.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        os.killpg(compositor.pid, signal.SIGKILL)
                        compositor.wait(timeout=5)


if __name__ == '__main__': main()
