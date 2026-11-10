#!/usr/bin/env python3
"""Headless integration with the compositor shipped in the verified ISO."""
import json
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
    with tempfile.TemporaryDirectory(prefix='makos-cutefish-') as directory:
        runtime = Path(directory); runtime.chmod(0o700)
        env = dict(os.environ, XDG_RUNTIME_DIR=directory, XDG_CURRENT_DESKTOP='Cutefish',
                   LIBGL_ALWAYS_SOFTWARE='1', EGL_PLATFORM='surfaceless')
        env.pop('DISPLAY', None); env.pop('WAYLAND_DISPLAY', None)
        with (results / 'compositor.log').open('w') as log:
            compositor = subprocess.Popen(['cutefish-compositor', '--no-drm', '--no-xwayland',
                                            '--socket', 'makos-test'], env=env, stdout=log,
                                           stderr=log, start_new_session=True)
            try:
                deadline = time.monotonic() + 30
                socket = runtime / 'makos-test'
                while time.monotonic() < deadline and compositor.poll() is None:
                    if socket.exists() and stat.S_ISSOCK(socket.stat().st_mode): break
                    time.sleep(.2)
                else: raise RuntimeError('Cutefish did not start; see compositor.log')
                env.update(WAYLAND_DISPLAY='makos-test', QT_QPA_PLATFORM='wayland',
                           QT_QUICK_BACKEND='software', WAYLAND_DEBUG='client')
                passed = {}
                for kind in ('finder', 'settings'):
                    with (results / (kind + '.log')).open('w') as client_log:
                        result = subprocess.run([sys.executable, str(root / 'main.py'),
                            '--cutefish-app', kind, '--cutefish-test', '--root', str(runtime / 'workspace')],
                            env=env, stdout=client_log, stderr=client_log, timeout=45)
                    trace = (results / (kind + '.log')).read_text()
                    required = ['.get_toplevel(', '.set_main_menu(', '.set_glass(', '.set_fullscreen_bars(',
                                '.set_minimized(', '.set_fullscreen(', '.unset_fullscreen(', '.fullscreen_reveal(', 'MAKOS_CUTEFISH_TEST=']
                    missing = [token for token in required if token not in trace]
                    errors = [token for token in ('TypeError:', 'ReferenceError:', 'failed to load component', 'error in client communication', 'Expected token', 'is not a type', 'FAIL:') if token in trace]
                    if result.returncode or missing or errors:
                        raise RuntimeError(f'{kind}: exit={result.returncode}, missing={missing}, errors={errors}')
                    if compositor.poll() is not None: raise RuntimeError('Compositor exited during client checks')
                    passed[kind] = {'result':'passed', 'protocol_requests':{t:trace.count(t) for t in required[:-1]}}
                for mode in ('recovery', 'disk'):
                    path = results / (mode + '-native.log')
                    args = [sys.executable, str(root / 'installer/recovery.py'), '--native-shell', '--smoke-test']
                    if mode == 'disk': args.append('--disk-utility')
                    with path.open('w') as recovery_log:
                        result = subprocess.run(args, env=env, stdout=recovery_log, stderr=recovery_log, timeout=30)
                    trace = path.read_text()
                    assert result.returncode == 0 and '.set_main_menu(' in trace and 'PASS: makOS Recovery' in trace, trace[-2500:]
                    assert not any(token in trace for token in ('TypeError:', 'ReferenceError:', 'Expected token', 'FAIL:')), trace[-2500:]
                (results / 'integration.json').write_text(json.dumps(passed, indent=2) + '\n')
                print('PASS: Finder and Settings native windows, app menus, glass requests and minimize/fullscreen/restore on Cutefish.')
            finally:
                if compositor.poll() is None:
                    os.killpg(compositor.pid, signal.SIGTERM)
                    try: compositor.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        os.killpg(compositor.pid, signal.SIGKILL); compositor.wait(timeout=5)


if __name__ == '__main__': main()
