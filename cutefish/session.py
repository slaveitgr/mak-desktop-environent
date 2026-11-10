#!/usr/bin/env python3
"""One makOS shell over Cutefish's compositor; launch from the login session."""
import argparse
import array
from datetime import datetime
import json
import os
from pathlib import Path
import re
import selectors
import shutil
import signal
import socket
import stat
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]


def terminate_owned(children):
    for child in reversed(children):
        if child.poll() is None:
            try: os.killpg(child.pid, signal.SIGTERM)
            except ProcessLookupError: pass
    deadline = time.monotonic() + 5
    for child in reversed(children):
        try: child.wait(timeout=max(.01, deadline-time.monotonic()))
        except subprocess.TimeoutExpired:
            try: os.killpg(child.pid, signal.SIGKILL)
            except ProcessLookupError: pass
            child.wait(timeout=2)


def trusted_connection(control_path):
    """Same FD handoff as pinned core/session/shellconnection.cpp."""
    control = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    deadline = time.monotonic() + 4
    while True:
        try: control.connect(str(control_path)); break
        except (FileNotFoundError, ConnectionRefusedError):
            if time.monotonic() >= deadline:
                control.close(); raise RuntimeError('Trusted shell control socket did not appear')
            time.sleep(.05)
    server, client = socket.socketpair()
    try:
        sent = control.sendmsg([b'S'], [(socket.SOL_SOCKET, socket.SCM_RIGHTS, array.array('i', [server.fileno()]))])
        if sent != 1: raise RuntimeError('Trusted shell FD handoff failed')
    except BaseException:
        control.close(); client.close(); raise
    finally: server.close()
    return control, client


def session_environment(base, wayland_display, headless=False):
    env = dict(base)
    for key in ('DISPLAY', 'XAUTHORITY', 'WAYLAND_SOCKET', 'QT_IM_MODULE', 'GTK_IM_MODULE'):
        env.pop(key, None)
    env.update(XDG_CURRENT_DESKTOP='makOS:Cutefish', XDG_SESSION_DESKTOP='makos',
               DESKTOP_SESSION='makos', XDG_SESSION_TYPE='wayland', WAYLAND_DISPLAY=wayland_display,
               QT_QPA_PLATFORM='wayland', GDK_BACKEND='wayland', GSETTINGS_BACKEND='keyfile',
               QT_QUICK_CONTROLS_STYLE='Basic')
    if headless:
        env.update(LIBGL_ALWAYS_SOFTWARE='1', EGL_PLATFORM='surfaceless', QT_QUICK_BACKEND='software')
    return env


def read_xwayland(path):
    if not path.is_file() or path.stat().st_size > 4096: return None
    try:
        data = json.loads(path.read_text()); display = data['DISPLAY']; authority = Path(data['XAUTHORITY'])
        info = authority.lstat()
        if not re.fullmatch(r':[0-9]+', display) or not authority.is_absolute() or not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o600:
            return None
        return {'DISPLAY': display, 'XAUTHORITY': str(authority)}
    except (OSError, ValueError, KeyError, TypeError): return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--headless', action='store_true', help='Isolated development display, no DRM/seat acquisition')
    parser.add_argument('--smoke-test', action='store_true', help='Headless only: require one desktop/bar/Dock, then exit')
    args = parser.parse_args()
    if sys.platform != 'linux' or os.getuid() == 0:
        parser.error('Run as an ordinary Linux user from the makOS login session.')
    if args.smoke_test and not args.headless: parser.error('--smoke-test requires --headless')
    required = ['cutefish-compositor', 'dbus-run-session', 'cutefish-appruntime', 'cutefish-services', 'cutefish-polkit-agent']
    missing = [name for name in required if not shutil.which(name)]
    if missing: parser.error('Missing session programs: '+', '.join(missing))
    if not (ROOT/'qml/CutefishShell.qml').is_file(): parser.error('The makOS shell QML is missing')
    capabilities = subprocess.check_output(['cutefish-compositor', '--help'], text=True, timeout=5)
    if '--external-shell' not in capabilities: parser.error('The compositor lacks the makOS external-shell patch')
    if args.check:
        print('PASS: makOS session programs and external-shell option are present; boot/render untested.'); return 0
    if not args.headless and any(os.environ.get(key) for key in ('WAYLAND_DISPLAY', 'WAYLAND_SOCKET', 'DISPLAY')):
        parser.error('A graphical session is already active. Select makOS at the login screen.')
    if not os.environ.get('DBUS_SESSION_BUS_ADDRESS'):
        os.execvp('dbus-run-session', ['dbus-run-session', '--', sys.executable, str(Path(__file__).resolve()), *sys.argv[1:]])
    from PySide6.QtCore import QCoreApplication, QTimer
    from PySide6.QtDBus import QDBus, QDBusConnection, QDBusMessage, QDBusPendingCallWatcher, QDBusVirtualObject
    app = QCoreApplication([])
    bus = QDBusConnection.sessionBus()
    if not bus.registerService('org.cutefish.Session'):
        raise RuntimeError('Another Cutefish session owns the session bus; refusing to replace it')
    pending = set()
    ending = False
    def call(connection, service, path, interface, method, arguments, callback):
        message = QDBusMessage.createMethodCall(service, path, interface, method)
        message.setArguments(arguments)
        watcher = QDBusPendingCallWatcher(connection.asyncCall(message, 120000), app)
        pending.add(watcher)
        def finished(*_):
            pending.discard(watcher)
            callback(watcher.isError(), watcher.reply().arguments(), watcher.error().message())
            watcher.deleteLater()
        watcher.finished.connect(finished)
    def power(method):
        nonlocal ending
        if args.headless: return
        def done(error, values, detail):
            nonlocal ending
            if error:
                ending = False; print('Session action failed: '+detail, file=sys.stderr)
            elif method != 'suspend': app.quit()
        call(QDBusConnection.systemBus(), 'org.freedesktop.login1', '/org/freedesktop/login1',
             'org.freedesktop.login1.Manager', {'reboot':'Reboot','powerOff':'PowerOff','suspend':'Suspend'}[method], [True], done)
    def request_end(method):
        nonlocal ending
        if ending or args.headless: return
        if method == 'suspend': power(method); return
        ending = True
        def quit_result(error, values, detail):
            nonlocal ending
            if error or not values or values[0] != 'quit':
                ending = False
                if error: print('Applications could not finish: '+detail, file=sys.stderr)
                return
            if method == 'logout': app.quit()
            else: power(method)
        call(bus, 'org.cutefish.Applications1', '/org/cutefish/Applications1',
             'org.cutefish.Applications1', 'QuitAll', [], quit_result)
    class SessionObject(QDBusVirtualObject):
        def introspect(self, path):
            return '<interface name="org.cutefish.Session"><method name="logout"/><method name="reboot"/><method name="powerOff"/><method name="suspend"><arg direction="out" type="b"/></method><method name="startDesktopProcess"/></interface>'
        def handleMessage(self, message, connection):
            if message.interface() != 'org.cutefish.Session' or message.member() not in ('logout','reboot','powerOff','suspend','startDesktopProcess'): return False
            method = message.member()
            if method != 'startDesktopProcess': request_end(method)
            connection.send(message.createReply([not args.headless] if method == 'suspend' else []))
            return True
    service = SessionObject(app)
    if not bus.registerVirtualObject('/Session', service): raise RuntimeError('Cannot export the session object')
    runtime = Path(os.environ.get('XDG_RUNTIME_DIR', ''))
    if not runtime.is_absolute() or not runtime.is_dir() or runtime.stat().st_uid != os.getuid():
        raise RuntimeError('A user-owned XDG_RUNTIME_DIR is required')
    state = Path(os.environ.get('XDG_STATE_HOME', str(Path.home()/'.local/state')))/'makos'
    state.mkdir(parents=True, exist_ok=True)
    log_path = state/('session-'+datetime.now().strftime('%Y%m%d-%H%M%S')+'.log')
    children=[]; critical=[]; control=None; client=None
    with tempfile.TemporaryDirectory(prefix='makos-session-', dir=runtime) as temporary, log_path.open('a') as log:
        log_path.chmod(0o600); directory=Path(temporary)
        display = 'makos-'+str(os.getpid()) if args.headless else 'makos-0'
        env = session_environment(os.environ, display, args.headless)
        def start(command, child_env=None, pass_fds=()):
            process = subprocess.Popen(command, env=child_env or env, stdout=log, stderr=log,
                                       start_new_session=True, pass_fds=pass_fds)
            children.append(process); return process
        try:
            read_fd, write_fd = os.pipe2(os.O_CLOEXEC|os.O_NONBLOCK)
            command = ['cutefish-compositor','--external-shell','--socket',display,
                       '--shell-control-socket',str(directory/'shell.control'),'--ready-fd',str(write_fd)]
            xwayland = directory/'xwayland.json'
            command += ['--no-drm','--no-xwayland'] if args.headless else ['--xwayland-ready-file',str(xwayland)]
            compositor = start(command, pass_fds=(write_fd,)); os.close(write_fd)
            try:
                with selectors.DefaultSelector() as selector:
                    selector.register(read_fd, selectors.EVENT_READ)
                    if not selector.select(20) or os.read(read_fd,1) != b'R':
                        raise RuntimeError('Compositor did not confirm startup; see '+str(log_path))
            finally: os.close(read_fd)
            if not args.headless:
                deadline=time.monotonic()+4
                while time.monotonic()<deadline and compositor.poll() is None:
                    values=read_xwayland(xwayland)
                    if values: env.update(values); break
                    time.sleep(.05)
                subprocess.run(['dbus-update-activation-environment','--systemd',
                                'WAYLAND_DISPLAY','DISPLAY','XAUTHORITY','XDG_CURRENT_DESKTOP',
                                'XDG_SESSION_DESKTOP','XDG_SESSION_TYPE','GSETTINGS_BACKEND'],
                               env=env, stdout=log, stderr=log, timeout=5, check=False)
                for program in ('cutefish-appruntime','cutefish-services','cutefish-polkit-agent'): critical.append(start([program]))
                if shutil.which('xdg-user-dirs-update'):
                    subprocess.run(['xdg-user-dirs-update'],env=env,stdout=log,stderr=log,timeout=5,check=False)
            control, client = trusted_connection(directory/'shell.control')
            shell_env=dict(env, WAYLAND_SOCKET=str(client.fileno()))
            shell = start([sys.executable,str(ROOT/'main.py'),'--cutefish-shell','--root',str(Path.home())],
                          shell_env, (client.fileno(),))
            client.close(); client=None
            for signum in (signal.SIGTERM,signal.SIGINT,signal.SIGHUP): signal.signal(signum,lambda *_: app.quit())
            started=time.monotonic(); recovery_started=False
            def monitor():
                nonlocal recovery_started
                if compositor.poll() is not None or shell.poll() is not None:
                    app.exit(1 if compositor.returncode or shell.returncode else 0); return
                if any(process.poll() is not None for process in critical):
                    print('A required session service exited; see '+str(log_path),file=sys.stderr);app.exit(1);return
                if args.smoke_test:
                    message=QDBusMessage.createMethodCall('org.cutefish.WindowDebug1','/org/cutefish/WindowDebug1','org.cutefish.WindowDebug1','ListWindows')
                    reply=bus.call(message, QDBus.CallMode.Block, 1000)
                    if reply.arguments():
                        try: windows=json.loads(reply.arguments()[0])
                        except (ValueError,TypeError): windows=[]
                        roles={role:[w for w in windows if w.get('role')==role] for role in ('desktop','panel','dock')}
                        if all(len(value)==1 for value in roles.values()):
                            result={'mode':'headless native external shell','windows':windows,'limits':['Not a DRM, hardware boot, or screenshot parity test.']}
                            (state/'external-shell-smoke.json').write_text(json.dumps(result,indent=2)+'\n')
                            print('PASS: one native makOS desktop, menu bar and Dock; no stock shell counterparts.');app.quit();return
                    if time.monotonic()-started>30:
                        print('External shell surfaces did not become ready; see '+str(log_path),file=sys.stderr);app.exit(1)
                elif not recovery_started and time.monotonic()-started>2:
                    recovery_started=True
                    if (Path('/etc/makos/live.json').is_file() and (ROOT/'installer/run').is_file()):
                        start([str(ROOT/'installer/run'),'--autostart'])
            timer=QTimer(app); timer.timeout.connect(monitor);timer.start(250)
            return app.exec()
        finally:
            if client: client.close()
            if control: control.close()
            terminate_owned(children)


if __name__ == '__main__':
    try: sys.exit(main())
    except (OSError,RuntimeError,subprocess.SubprocessError) as error:
        print('makOS session failed: '+str(error),file=sys.stderr);sys.exit(1)
