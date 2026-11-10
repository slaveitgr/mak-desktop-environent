"""Single-instance native clients and the isolated Cutefish integration exercise."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
from PySide6.QtCore import QObject, QLockFile, QTimer
from PySide6.QtNetwork import QLocalServer, QLocalSocket
from PySide6.QtQml import QQmlExpression


class CutefishInstance(QObject):
    def __init__(self, app, kind, root):
        super().__init__(app)
        identity = hashlib.sha256(str(root.resolve()).encode()).hexdigest()[:16]
        runtime = Path(os.environ['XDG_RUNTIME_DIR'])
        self.name = str(runtime / ('makos-' + kind + '-' + identity))
        self.lock = QLockFile(self.name + '.lock')
        self.server = QLocalServer(self)
        self.server.setSocketOptions(QLocalServer.UserAccessOption)
        self.root = None
        self.server.newConnection.connect(self.accept)

    def acquire(self):
        if not self.lock.tryLock(0):
            client = QLocalSocket()
            client.connectToServer(self.name)
            if not client.waitForConnected(2000):
                raise RuntimeError('The existing makOS client is not accepting activation requests.')
            payload = {'action':'activate', 'token':os.environ.get('XDG_ACTIVATION_TOKEN', '')[:2048]}
            client.write(json.dumps(payload).encode() + b'\n')
            if not client.waitForBytesWritten(1000):
                raise RuntimeError('Could not deliver the activation request.')
            client.disconnectFromServer()
            return False
        QLocalServer.removeServer(self.name)  # only after exclusive lock ownership
        if not self.server.listen(self.name):
            raise RuntimeError(self.server.errorString())
        return True

    def bind(self, root):
        self.root = root

    def activate(self, payload):
        if not isinstance(payload, dict) or payload.get('action') != 'activate': return
        token = payload.get('token', '')
        if not isinstance(token, str) or len(token) > 2048 or '\0' in token: return
        if self.root:
            # Qt 6.8 consumes XDG_ACTIVATION_TOKEN synchronously from
            # requestActivate(). Forward the launcher's token to the owner.
            if token: os.environ['XDG_ACTIVATION_TOKEN'] = token
            try: self.root.activateCutefishClient()
            finally:
                if token: os.environ.pop('XDG_ACTIVATION_TOKEN', None)

    def accept(self):
        while self.server.hasPendingConnections():
            client = self.server.nextPendingConnection()
            client.setReadBufferSize(4097)
            client.disconnected.connect(client.deleteLater)
            deadline = QTimer(client); deadline.setSingleShot(True)
            deadline.timeout.connect(lambda client=client: client.disconnectFromServer())
            deadline.start(1500)
            def receive(client=client, deadline=deadline):
                if client.bytesAvailable() > 4096:
                    client.disconnectFromServer(); return
                if not client.canReadLine(): return
                deadline.stop()
                try: self.activate(json.loads(bytes(client.readLine()).decode()))
                except (ValueError, UnicodeError): pass
                client.disconnectFromServer()
            client.readyRead.connect(receive)
            receive()


def exercise(app, root, engine):
    """Checks under the shipped headless compositor, in a private CI session."""
    from PySide6.QtDBus import QDBusConnection, QDBusMessage, QDBus
    results, snapshots, applied, errors = [], [], [], []
    shell = engine.rootContext().contextProperty('Bridge').cutefishShell
    shell.applied.connect(applied.append)
    shell.error.connect(errors.append)
    bus = QDBusConnection.sessionBus()
    failed = [False]

    def guard(callback):
        if failed[0]: return
        try: callback()
        except Exception as error:
            failed[0] = True
            print('FAIL:', error, flush=True)
            app.exit(1)

    def server_state(expected, active):
        request = QDBusMessage.createMethodCall('org.cutefish.WindowDebug1',
            '/org/cutefish/WindowDebug1', 'org.cutefish.WindowDebug1', 'ListWindows')
        reply = bus.call(request, QDBus.CallMode.Block, 1200)
        if reply.type() == QDBusMessage.MessageType.ErrorMessage:
            raise AssertionError(reply.errorMessage())
        windows = json.loads(reply.arguments()[0])
        clients = [w for w in windows if w['appId'] == app.desktopFileName()]
        assert len(clients) == 1, 'Expected exactly one native app surface: ' + repr(clients)
        window = clients[0]
        assert window['state'] == expected and window['active'] == active, repr(window)
        snapshots.append(window)

    def restore_from_shell():
        # A minimized client cannot mint its own focus token. Exercise the
        # compositor activation path used by its Dock/window switcher.
        for method in ('RestoreWindow', 'ActivateWindow'):
            result = subprocess.run(['dbus-send', '--session', '--print-reply',
                '--dest=org.cutefish.WindowDebug1', '/org/cutefish/WindowDebug1',
                'org.cutefish.WindowDebug1.' + method, 'uint64:' + snapshots[-1]['id']],
                capture_output=True, text=True, timeout=3)
            assert result.returncode == 0 and 'boolean true' in result.stdout, result.stderr

    def pointer_motion(x, y):
        result = subprocess.run(['dbus-send', '--session', '--print-reply',
            '--dest=org.cutefish.WindowDebug1', '/org/cutefish/WindowDebug1',
            'org.cutefish.WindowDebug1.PointerMotion', 'double:' + str(x), 'double:' + str(y)],
            capture_output=True, text=True, timeout=3)
        assert result.returncode == 0 and 'boolean true' in result.stdout, result.stderr

    def check(label, expression, state=None, active=True):
        if callable(expression):
            expression(); results.append(label); return
        qml = QQmlExpression(engine.rootContext(), root, expression)
        value = qml.evaluate()
        if isinstance(value, tuple): value = value[0]
        if qml.hasError() or value is not True:
            raise AssertionError(label + ': ' + qml.error().toString())
        if state: server_state(state, active)
        results.append(label)

    steps = [
        (1500, 'native client and protocol bridge', 'controller.windows.length === 1 && controller.windows[0].nativeWindow.visible && controller.windows[0].nativeWindow.compositorGlass && !visible', 'normal', True),
        (1800, 'minimize request', '(controller.minimizeWindow(controller.windows[0]), true)', None, False),
        # xdg-shell has no minimized configure state. Check the actual window
        # manager plus the retained client request and loss of focus instead.
        (2300, 'compositor confirms minimized window', 'controller.windows[0].minimized && !controller.windows[0].nativeWindow.active', 'minimized', False),
        (2500, 'restore through compositor activation', restore_from_shell, None, True),
        (3000, 'compositor confirms restored window', '!controller.windows[0].minimized && controller.windows[0].nativeWindow.visible && controller.windows[0].nativeWindow.active', 'normal', True),
        (3200, 'fullscreen request', '(controller.presentation.enter(controller.windows[0]), true)', None, True),
        (3800, 'compositor confirms fullscreen window', 'controller.windows[0].nativeWindow.visibility === 5', 'fullscreen', True),
        (4000, 'pointer reaches fullscreen top edge', lambda: pointer_motion(800, 0), None, True),
        (4500, 'fullscreen chrome follows compositor reveal', 'controller.windows[0].nativeWindow.compositorReveal > 0 && controller.windows[0].chromeRevealed && controller.windows[0].chromeOffset > 0', None, True),
        (4700, 'pointer leaves fullscreen chrome', lambda: pointer_motion(800, 600), None, True),
        (5500, 'fullscreen chrome follows compositor hide', 'controller.windows[0].nativeWindow.compositorReveal === 0 && !controller.windows[0].chromeRevealed && controller.windows[0].chromeOffset === 0', None, True),
        (5700, 'fullscreen exit request', '(controller.presentation.exit(), true)', None, True),
        (6300, 'compositor confirms windowed restore', 'controller.windows[0].nativeWindow.visibility === 2', 'normal', True),
        (6600, 'menu model available', 'JSON.parse(controller.nativeMenuRows(controller.windows[0])).length >= 5', None, True),
    ]
    # Schedule each transition after its predecessor has actually run. Portal
    # startup can block the event loop; independent absolute timers then become
    # overdue together and may request fullscreen before the restore assertion.
    def run_step(index):
        if failed[0]: return
        delay, label, code, state, active = steps[index]
        guard(lambda: check(label, code, state, active))
        if failed[0]: return
        if index + 1 < len(steps):
            QTimer.singleShot(steps[index + 1][0] - delay, lambda: run_step(index + 1))
        else:
            QTimer.singleShot(300, lambda: guard(check_services))
    QTimer.singleShot(steps[0][0], lambda: run_step(0))

    def absent_services():
        # Upstream deliberately does not export Dock/Statusbar services with
        # --no-drm (compositor_shell.cpp). Exercise the real missing-service
        # path, without substituting mocks or claiming successful settings.
        for service in ('org.cutefish.Dock', 'org.cutefish.Statusbar'):
            registered = bus.interface().isServiceRegistered(service)
            assert registered.isValid() and not registered.value(), service
        shell.setDockSize(48)
        shell.setDockAutoHide(True)
        shell.setDockGlassTint(.6)
        shell.preferenceChanged('battery.showPercentage', 'true')
    def check_services():
        absent_services()
        QTimer.singleShot(1700, lambda: guard(finish))

    def finish():
        bridges = root.findChildren(QObject, 'makOSCutefishBridge')
        assert bridges and all(b.property('active') for b in bridges), 'Cutefish protocol bridge not active'
        assert len(errors) == 4 and not applied, 'Unavailable shell settings must report failure: ' + repr((errors, applied))
        results.append('headless shell service absence reported without false success')
        print('MAKOS_CUTEFISH_TEST=' + json.dumps({'checks':results, 'windows':snapshots,
            'shell_settings':'missing-service handling verified; live-session success unverified'}), flush=True)
        app.quit()
