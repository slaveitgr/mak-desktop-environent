"""DDE service adapters. System access is explicitly enabled in makOS mode."""
import math
import sys
from PySide6.QtCore import QObject, Property, QTimer, Signal, Slot


class DdeAudio(QObject):
    """org.deepin.dde.Audio1, verified against the pinned dde-daemon source.

    Calls are asynchronous, have deadlines, and never activate missing services.
    A disconnected service is exposed as unavailable, not a simulated device.
    """
    changed = Signal()
    error = Signal(str)
    SERVICE = 'org.deepin.dde.Audio1'
    ROOT = '/org/deepin/dde/Audio1'
    PROPERTIES = 'org.freedesktop.DBus.Properties'

    def __init__(self, enabled=False, parent=None, transport=None):
        super().__init__(parent)
        self._enabled = bool(enabled and sys.platform.startswith('linux'))
        self._transport = transport
        self._available = False
        self._sink = ''
        self._volume = 0.0
        self._muted = False
        self._pending = set()
        self._refreshing = False
        self._generation = 0
        self._poll = QTimer(self)
        self._poll.setInterval(3000)
        self._poll.timeout.connect(self.refresh)

    @Property(bool, notify=changed)
    def available(self): return self._available

    @Property(float, notify=changed)
    def volume(self): return self._volume

    @Property(bool, notify=changed)
    def muted(self): return self._muted

    def start(self):
        if self._enabled:
            self.refresh()
            self._poll.start()

    def stop(self):
        self._generation += 1
        self._poll.stop()
        self._enabled = False

    @staticmethod
    def unwrap(value):
        # QtDBus may wrap a property variant or object path.
        if hasattr(value, 'variant'): value = value.variant()
        if hasattr(value, 'path'): value = value.path()
        return value

    def _call(self, path, interface, method, arguments, callback):
        if not self._enabled:
            return
        if self._transport:
            self._transport(path, interface, method, arguments, callback)
            return
        from PySide6.QtDBus import QDBusConnection, QDBusMessage, QDBusPendingCallWatcher
        message = QDBusMessage.createMethodCall(self.SERVICE, path, interface, method)
        message.setArguments(arguments)
        message.setAutoStartService(False)
        generation = self._generation
        watcher = QDBusPendingCallWatcher(QDBusConnection.sessionBus().asyncCall(message, 1200), self)
        self._pending.add(watcher)

        def finished(*_):
            self._pending.discard(watcher)
            if self._enabled and generation == self._generation:
                reply = watcher.reply()
                callback(None if watcher.isError() else [self.unwrap(x) for x in reply.arguments()],
                         watcher.error().message() if watcher.isError() else '')
            watcher.deleteLater()
        watcher.finished.connect(finished)

    def _get(self, path, interface, name, callback):
        self._call(path, self.PROPERTIES, 'Get', [interface, name], callback)

    def _unavailable(self):
        self._refreshing = False
        self._sink = ''
        if self._available:
            self._available = False
            self.changed.emit()

    @Slot()
    def refresh(self):
        if not self._enabled or self._refreshing:
            return
        self._refreshing = True

        def sink_reply(values, error):
            path = values[0] if values else ''
            if not isinstance(path, str) or not path.startswith(self.ROOT + '/Sink'):
                self._unavailable()
                return

            def volume_reply(levels, error):
                value = levels[0] if levels else None
                if isinstance(value, bool) or not isinstance(value, (float, int)) or not math.isfinite(value):
                    self._unavailable()
                    return

                def mute_reply(mutes, error):
                    if not mutes or not isinstance(mutes[0], bool):
                        self._unavailable()
                        return
                    self._sink = path
                    self._volume = max(0.0, min(1.0, float(value)))
                    self._muted = mutes[0]
                    self._available = True
                    self._refreshing = False
                    self.changed.emit()
                self._get(path, self.SERVICE + '.Sink', 'Mute', mute_reply)
            self._get(path, self.SERVICE + '.Sink', 'Volume', volume_reply)
        self._get(self.ROOT, self.SERVICE, 'DefaultSink', sink_reply)

    def _written(self, values, error):
        if error:
            self.error.emit('DDE audio: ' + error)
            self._unavailable()
        else:
            self.refresh()

    @Slot(float)
    def setVolume(self, value):
        if not self._enabled or not self._available:
            return
        if not math.isfinite(value) or not 0 <= value <= 1:
            self.error.emit('Volume must be between 0 and 1.')
            return
        self._call(self._sink, self.SERVICE + '.Sink', 'SetVolume', [float(value), False], self._written)

    @Slot(bool)
    def setMuted(self, value):
        if self._enabled and self._available:
            self._call(self._sink, self.SERVICE + '.Sink', 'SetMute', [bool(value)], self._written)
