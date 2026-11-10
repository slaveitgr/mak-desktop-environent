"""Single-instance native clients and the isolated Cutefish integration exercise."""
import hashlib
import json
import os
from pathlib import Path
import sys
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
            client.write(b'activate\n'); client.waitForBytesWritten(1000)
            client.disconnectFromServer()
            return False
        QLocalServer.removeServer(self.name)  # only after exclusive lock ownership
        if not self.server.listen(self.name):
            raise RuntimeError(self.server.errorString())
        return True

    def bind(self, root):
        self.root = root

    def accept(self):
        while self.server.hasPendingConnections():
            client = self.server.nextPendingConnection()
            client.disconnected.connect(client.deleteLater)
            # The socket carries only activation, never executable commands.
            if self.root:
                self.root.activateCutefishClient()
            client.disconnectFromServer()


def exercise(app, root, engine):
    """Meaningful behavior checks under the actual compositor, without user data."""
    results = []
    shell = engine.rootContext().contextProperty('Bridge').cutefishShell
    applied = []
    shell.applied.connect(applied.append)
    def change_shell():
        shell.setDockSize(48)
        shell.setDockAutoHide(True)
        shell.setDockGlassTint(.6)
        shell.preferenceChanged('battery.showPercentage', 'true')
    QTimer.singleShot(700, change_shell)
    def check(label, expression):
        qml = QQmlExpression(engine.rootContext(), root, expression)
        value = qml.evaluate()
        if isinstance(value, tuple): value = value[0]
        if qml.hasError() or value is not True:
            raise AssertionError(label + ': ' + qml.error().toString())
        results.append(label)
    steps = [
        (1500, 'native client and protocol bridge', '''controller.windows.length === 1 && controller.windows[0].nativeWindow.visible && !visible'''),
        (1800, 'minimize request', '''(controller.minimizeWindow(controller.windows[0]), true)'''),
        (2300, 'minimize retained after compositor deactivation', '''controller.windows[0].minimized && !controller.windows[0].nativeWindow.active'''),
        (2500, 'restore request', '''(controller.focusWindow(controller.windows[0]), true)'''),
        (3000, 'restored native window', '''!controller.windows[0].minimized && controller.windows[0].nativeWindow.visible && controller.windows[0].nativeWindow.active'''),
        (3200, 'fullscreen request', '''(controller.presentation.enter(controller.windows[0]), true)'''),
        (3800, 'fullscreen native window', '''controller.windows[0].nativeWindow.visibility === 5'''),
        (4000, 'fullscreen exit request', '''(controller.presentation.exit(), true)'''),
        (4600, 'normal native window restored', '''controller.windows[0].nativeWindow.visibility === 2'''),
        (4900, 'menu model available', '''JSON.parse(controller.nativeMenuRows(controller.windows[0])).length >= 5'''),
    ]
    failed = [False]
    def run(label, code):
        if failed[0]: return
        try: check(label, code)
        except Exception as e:
            failed[0] = True; print('FAIL:', e, flush=True); app.exit(1)
    for delay, label, code in steps:
        QTimer.singleShot(delay, lambda label=label, code=code: run(label, code))
    def finish():
        if failed[0]: return
        bridges = root.findChildren(QObject, 'makOSCutefishBridge')
        if not bridges or not all(b.property('active') for b in bridges):
            print('FAIL: Cutefish protocol bridge not active', flush=True); app.exit(1); return
        if not {'setIconSize', 'setVisibility', 'setGlassTint', 'setBatteryPercentage'}.issubset(applied):
            print('FAIL: Cutefish shell settings did not acknowledge changes: ' + repr(applied), flush=True)
            app.exit(1); return
        results.append('real Dock and menu-bar D-Bus settings acknowledged')
        print('MAKOS_CUTEFISH_TEST=' + json.dumps(results), flush=True)
        app.quit()
    QTimer.singleShot(5300, finish)
