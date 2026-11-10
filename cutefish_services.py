"""Explicit, bounded calls to the Cutefish shell; no service auto-activation."""
import math
import sys
from PySide6.QtCore import QObject, Property, Signal, Slot


class CutefishShell(QObject):
    error = Signal(str)
    applied = Signal(str)

    def __init__(self, enabled=False, parent=None, transport=None):
        super().__init__(parent)
        self._enabled = bool(enabled and sys.platform == 'linux')
        self._transport = transport
        self._pending = set()

    @Property(bool, constant=True)
    def enabled(self): return self._enabled

    def stop(self): self._enabled = False

    def _call(self, service, path, method, args):
        if not self._enabled: return
        if self._transport:
            self._transport(service, path, service, method, args)
            return
        from PySide6.QtDBus import QDBusConnection, QDBusMessage, QDBusPendingCallWatcher
        message = QDBusMessage.createMethodCall(service, path, service, method)
        message.setArguments(args); message.setAutoStartService(False)
        watcher = QDBusPendingCallWatcher(QDBusConnection.sessionBus().asyncCall(message, 1200), self)
        self._pending.add(watcher)
        def finished(*_):
            self._pending.discard(watcher)
            if self._enabled:
                if watcher.isError(): self.error.emit('Cutefish: ' + watcher.error().message())
                else: self.applied.emit(method)
            watcher.deleteLater()
        watcher.finished.connect(finished)

    @Slot(int)
    def setDockSize(self, size):
        if 24 <= size <= 64:
            self._call('org.cutefish.Dock', '/Dock', 'setIconSize', [int(size)])

    @Slot(bool)
    def setDockAutoHide(self, enabled):
        self.setDockVisibility(1 if enabled else 0)

    @Slot(int)
    def setDockVisibility(self, mode):
        if mode in (0, 1, 2):
            self._call('org.cutefish.Dock', '/Dock', 'setVisibility', [int(mode)])

    @Slot(float)
    def setDockGlassTint(self, amount):
        if math.isfinite(amount) and 0 <= amount <= 1:
            self._call('org.cutefish.Dock', '/Dock', 'setGlassTint', [float(amount)])

    @Slot(str, str)
    def preferenceChanged(self, key, value):
        if key == 'dock.size':
            try: self.setDockSize(int(value))
            except ValueError: return
        elif key == 'battery.showPercentage' and value in ('true', 'false'):
            self._call('org.cutefish.Statusbar', '/Statusbar', 'setBatteryPercentage', [value == 'true'])
