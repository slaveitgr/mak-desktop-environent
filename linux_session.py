"""Opt-in Linux session bridge. Preview mode never invokes session services."""
import os
from pathlib import Path
import sys
from PySide6.QtCore import QObject, Signal, Slot, Property, QProcess, QBuffer, QIODevice
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtNetwork import QLocalServer
from xdg_applications import discover_applications


class LinuxSession(QObject):
    commandRequested = Signal(str)
    error = Signal(str)
    applicationsChanged = Signal()

    def __init__(self, enabled=False, parent=None, *, cutefish_mode=False, transport=None):
        super().__init__(parent)
        self._enabled = bool(enabled and sys.platform.startswith('linux'))
        self._cutefish_mode = bool(cutefish_mode)
        self._transport = transport
        self._pending = set()
        self._stopped = False
        self._applications = []
        self._server = None
        self._clients = set()
        self._processes = set()

    @Property(bool, constant=True)
    def enabled(self): return self._enabled

    @Property('QVariantList', notify=applicationsChanged)
    def applications(self): return self._applications

    def start(self):
        if not self.enabled or self._stopped:
            return
        if self._cutefish_mode:
            self.refreshApplications()
            return
        socket = os.environ.get('TAHOE_SESSION_SOCKET', '')
        if not socket or not Path(socket).parent.is_dir():
            raise RuntimeError('Start this desktop through tahoe-session, not main.py --session.')
        self._server = QLocalServer(self)
        self._server.setSocketOptions(QLocalServer.UserAccessOption)
        self._server.newConnection.connect(self._accept)
        if not self._server.listen(socket):
            raise RuntimeError('Cannot create session control socket: ' + self._server.errorString())
        self.refreshApplications()

    def _accept(self):
        while self._server.hasPendingConnections():
            client = self._server.nextPendingConnection()
            self._clients.add(client)
            client.readyRead.connect(lambda c=client: self._read(c))
            client.disconnected.connect(lambda c=client: self._discard(c))

    def _discard(self, client):
        self._clients.discard(client)
        client.deleteLater()

    def _read(self, client):
        if client.bytesAvailable() > 128:
            client.abort()
            return
        if not client.canReadLine():
            return
        command = bytes(client.readLine(128)).decode('ascii', errors='replace').strip()
        if command in ('show', 'apps', 'terminal', 'logout', 'lock'):
            self.commandRequested.emit(command)
            client.write(b'OK\n')
        else:
            client.write(b'ERROR\n')
        client.disconnectFromServer()

    @Slot()
    def refreshApplications(self):
        if not self.enabled:
            return
        apps = discover_applications()
        for entry in apps:
            icon = QIcon(entry['icon']) if entry['icon'].startswith('/') else QIcon.fromTheme(entry['icon'])
            if not icon.isNull():
                buffer = QBuffer()
                buffer.open(QIODevice.WriteOnly)
                icon.pixmap(64, 64).save(buffer, 'PNG')
                entry['iconUrl'] = 'data:image/png;base64,' + bytes(buffer.data().toBase64()).decode('ascii')
        self._applications = apps
        self.applicationsChanged.emit()

    @Slot(str, result=bool)
    def launch(self, identity):
        if not self.enabled or self._stopped:
            return False
        entry = next((a for a in self._applications if a['id'] == identity), None)
        if not entry or not Path(entry['path']).is_file():
            self.error.emit('This installed application is no longer available. Refresh Apps.')
            return False
        self._run(['gio', 'launch', entry['path']])
        return True

    def _run(self, command):
        process = QProcess(self)
        self._processes.add(process)
        def finish(code=0, *_):
            if process not in self._processes:
                return
            if code:
                message = bytes(process.readAllStandardError()).decode(errors='replace').strip()
                self.error.emit(message or 'The requested system operation failed.')
            self._processes.discard(process)
            process.deleteLater()
        process.finished.connect(finish)
        process.errorOccurred.connect(lambda _: finish(1))
        process.start(command[0], command[1:])

    def _call_session(self, service, path, interface, method):
        """The login-session owner handles app quit/cancel and power authorization."""
        def complete(detail, values):
            if self._stopped:
                return
            if detail:
                self.error.emit('The session operation failed: ' + detail)
            elif method == 'suspend' and values == [False]:
                self.error.emit('Sleep is not available in this session.')
        if self._transport:
            self._transport(service, path, interface, method, [], complete)
            return
        from PySide6.QtDBus import QDBusConnection, QDBusMessage, QDBusPendingCallWatcher
        message = QDBusMessage.createMethodCall(service, path, interface, method)
        message.setAutoStartService(False)
        # Lock replies only once the compositor has securely covered its outputs.
        watcher = QDBusPendingCallWatcher(QDBusConnection.sessionBus().asyncCall(message, 15000), self)
        self._pending.add(watcher)
        def finished(*_):
            self._pending.discard(watcher)
            complete(watcher.error().message() if watcher.isError() else '', watcher.reply().arguments())
            watcher.deleteLater()
        watcher.finished.connect(finished)

    @Slot(str)
    def perform(self, action):
        if not self.enabled or self._stopped:
            self.error.emit('System session operations are only available in the Linux login session.')
            return
        if self._cutefish_mode:
            if action == 'lock':
                self._call_session('org.freedesktop.ScreenSaver', '/ScreenSaver',
                                   'org.freedesktop.ScreenSaver', 'Lock')
            elif action in ('logout', 'sleep', 'restart', 'shutdown'):
                method = {'logout': 'logout', 'sleep': 'suspend',
                          'restart': 'reboot', 'shutdown': 'powerOff'}[action]
                self._call_session('org.cutefish.Session', '/Session', 'org.cutefish.Session', method)
            return
        if action == 'logout':
            QGuiApplication.quit()
            return
        commands = {'lock': ['xset', 's', 'activate'],
                    'sleep': ['systemctl', 'suspend'],
                    'restart': ['systemctl', 'reboot'],
                    'shutdown': ['systemctl', 'poweroff']}
        if action in commands:
            self._run(commands[action])

    def stop(self):
        self._stopped = True
        if self._server:
            self._server.close()
        for client in list(self._clients):
            client.abort()
        # Detached application lifetimes belong to the display-manager session.
        # GIO helpers that already exited are removed by the finished callback.
