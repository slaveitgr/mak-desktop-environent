"""Qt front end to the *original* Cutefish Settings service clients.

The helper is Linux-only and unprivileged. Its state messages are observations,
never desired values. A write is complete only after service readback. No local
preference fallback is allowed for hardware settings.
"""
from __future__ import annotations

import json
import math
import os
from pathlib import Path
import sys
from PySide6.QtCore import QObject, Property, QProcess, QTimer, Signal, Slot

ROOT = Path(__file__).resolve().parent
PANELS = ("audio", "network", "bluetooth", "power", "battery", "display")
ACTIONS = {"audio.volume", "audio.muted", "audio.default", "wifi.enabled", "bluetooth.powered", "power.profile"}


class LinuxSettings(QObject):
    changed = Signal()
    operationFinished = Signal(str, bool, str)

    def __init__(self, enabled=False, parent=None, *, helper_path=None, process_factory=QProcess, platform_name=None):
        super().__init__(parent)
        self._enabled = bool(enabled and (platform_name or sys.platform).startswith("linux"))
        self._state = {panel: {"available": False} for panel in PANELS}
        self._ready = False
        self._error = "" if self._enabled else "Linux system settings are available in the makOS Cutefish session."
        self._pending = None
        self._serial = 0
        self._buffer = bytearray()
        self._stopping = False
        self._process = None
        self._timer = QTimer(self)
        self._timer.setSingleShot(True)
        self._timer.setInterval(8000)
        self._timer.timeout.connect(self._timed_out)
        try:
            self._audit = json.loads((ROOT / "reference/settings-linux-audit.json").read_text())["panels"]
        except (OSError, ValueError, KeyError):
            self._audit = {}
        if not self._enabled:
            return
        candidates = [Path(helper_path)] if helper_path else [
            ROOT / "cutefish/build/settings/makos-settings-backend",
            Path("/usr/lib/makos/makos-settings-backend"),
            Path("/usr/local/lib/makos/makos-settings-backend"),
        ]
        executable = next((path for path in candidates if path.is_file() and os.access(path, os.X_OK)), None)
        if executable is None:
            self._error = "The Cutefish Settings backend is not installed. Build the native integration to enable system settings."
            return
        self._process = process_factory(self)
        self._process.setProcessChannelMode(QProcess.ProcessChannelMode.SeparateChannels)
        self._process.readyReadStandardOutput.connect(self._read)
        self._process.readyReadStandardError.connect(self._drain_stderr)
        self._process.errorOccurred.connect(self._process_error)
        self._process.finished.connect(self._exited)
        self._process.start(str(executable), [])
        self._timer.start()

    @Property(bool, constant=True)
    def enabled(self):
        return self._enabled

    @Property(bool, notify=changed)
    def ready(self):
        return self._ready

    @Property("QVariantMap", notify=changed)
    def state(self):
        return self._state

    @Property(bool, notify=changed)
    def busy(self):
        return self._pending is not None

    @Property(str, notify=changed)
    def errorText(self):
        return self._error

    @Slot(str, result=str)
    def scope(self, panel):
        entry = self._audit.get(panel, {})
        return entry.get("ui_notice", "This panel has no Linux system backend yet.")

    def _send(self, command):
        if not self._process or self._process.state() != QProcess.ProcessState.Running:
            return False
        encoded = json.dumps(command, allow_nan=False, separators=(",", ":")).encode() + b"\n"
        return self._process.write(encoded) == len(encoded)

    @Slot()
    def refresh(self):
        if self._ready:
            self._send({"action": "refresh"})

    @Slot(str, "QVariant", str, result=bool)
    def apply(self, action, value, target=""):
        # Validate before crossing the process boundary; the native helper
        # independently validates against current objects and permissions.
        if action not in ACTIONS or not isinstance(target, str) or len(target) > 1024:
            return self._reject("This setting is not implemented.")
        if action == "audio.volume":
            valid = type(value) in (float, int) and math.isfinite(value) and 0 <= value <= 1
        elif action == "power.profile":
            valid = isinstance(value, str) and value in self._state.get("power", {}).get("profiles", [])
        else:
            valid = type(value) is bool and (action != "audio.default" or value)
        if not valid:
            return self._reject("The requested setting value is invalid.")
        if self.busy:
            return self._reject("Wait for the previous setting to be confirmed.")
        if not self._ready:
            return self._reject("The Linux settings service is unavailable.")
        self._serial += 1
        command = {"id": str(self._serial), "action": action, "target": target, "value": value}
        self._pending = command
        self._error = ""
        if not self._send(command):
            self._pending = None
            return self._reject("The Linux settings service could not receive the change.")
        self._timer.start()
        self.changed.emit()
        return True

    def _reject(self, message):
        self._error = message
        self.changed.emit()
        return False

    def _read(self):
        self._buffer.extend(bytes(self._process.readAllStandardOutput()))
        if len(self._buffer) > 1024 * 1024:
            self._fail("The settings backend returned an oversized response.")
            self._process.kill()
            return
        while b"\n" in self._buffer:
            raw, _, self._buffer = self._buffer.partition(b"\n")
            try:
                message = json.loads(raw)
                self._receive(message)
            except (ValueError, TypeError):
                self._fail("The settings backend returned an invalid response.")
                self._process.kill()
                return

    def _receive(self, message):
        if not isinstance(message, dict):
            raise ValueError("not an object")
        if message.get("type") == "state":
            state = message.get("state")
            if message.get("protocol") != 1 or not isinstance(state, dict) or any(
                not isinstance(state.get(panel), dict) or type(state[panel].get("available")) is not bool for panel in PANELS
            ):
                raise ValueError("invalid state")
            was_ready = self._ready
            self._state = state
            self._ready = True
            if not self.busy:
                self._timer.stop()
                if not was_ready:
                    self._error = ""
            self.changed.emit()
        elif message.get("type") == "result":
            if not self._pending or message.get("id") != self._pending["id"]:
                return  # stale or unrelated readback cannot complete a new write
            if type(message.get("ok")) is not bool:
                raise ValueError("invalid result")
            action = self._pending["action"]
            ok = message["ok"]
            self._pending = None
            self._timer.stop()
            self._error = "" if ok else str(message.get("message") or "The service did not confirm this change.")
            self.changed.emit()
            self.operationFinished.emit(action, ok, self._error)
        else:
            raise ValueError("unknown protocol message")

    def _fail(self, message):
        pending = self._pending
        self._pending = None
        self._ready = False
        self._timer.stop()
        self._state = {panel: {"available": False} for panel in PANELS}
        self._error = message
        self.changed.emit()
        if pending:
            self.operationFinished.emit(pending["action"], False, message)

    def _timed_out(self):
        # A disconnected helper must not leave stale controls enabled. A timed
        # out write is never called success even if a daemon later changes it.
        self._fail("The settings backend stopped responding. Reopen Settings to reconnect.")
        if self._process:
            self._process.kill()

    def _drain_stderr(self):
        # PipeWire/DBus diagnostics can be noisy when services are absent. Drain
        # the bounded pipe; capability state is the UI's source of truth.
        self._process.readAllStandardError()

    def _process_error(self, _error):
        if not self._stopping:
            self._fail("The native Cutefish Settings backend could not run.")

    def _exited(self, *_args):
        if not self._stopping:
            self._fail("The native Cutefish Settings backend has stopped.")

    @Slot()
    def stop(self):
        self._stopping = True
        self._timer.stop()
        if self._process:
            self._process.closeWriteChannel()
            if not self._process.waitForFinished(500):
                self._process.kill()
                self._process.waitForFinished(500)
        self._pending = None
        self._ready = False
