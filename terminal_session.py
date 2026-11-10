"""A real local PTY. Started only by the Terminal app; stopped when its window closes."""
import codecs
import fcntl
import os
import pty
import signal
import struct
import subprocess
import termios
import pyte
from PySide6.QtCore import QObject, Property, Signal, Slot, QTimer

class TerminalSession(QObject):
    changed = Signal()
    def __init__(self, root, parent=None):
        super().__init__(parent)
        self.root = str(root)
        self.process = None
        self.fd = None
        self.screen = pyte.Screen(100, 30)
        self.stream = pyte.Stream(self.screen)
        self.decoder = codecs.getincrementaldecoder('utf-8')('replace')
        self._text = 'Press Start Shell to open a local terminal.'
        self.timer = QTimer(self); self.timer.setInterval(30); self.timer.timeout.connect(self.read)
    @Property(str, notify=changed)
    def text(self): return self._text
    @Property(bool, notify=changed)
    def running(self): return self.process is not None and self.process.poll() is None
    @Slot()
    def start(self):
        if self.running: return
        self.stop()
        self.screen.reset()
        self.fd, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH',30,100,0,0))
        env = dict(os.environ, TERM='xterm-256color', COLORTERM='truecolor')
        shell = env.get('SHELL','/bin/sh')
        if not os.path.isfile(shell): shell='/bin/sh'
        try:
            self.process = subprocess.Popen([shell,'-i'], stdin=slave, stdout=slave, stderr=slave, cwd=self.root, env=env, start_new_session=True)
            os.set_blocking(self.fd, False)
            self.timer.start()
        except OSError as exc:
            self._text=str(exc)
            self.stop()
        finally: os.close(slave)
        self.changed.emit()
    @Slot(str)
    def write(self, value):
        if self.fd is not None and self.running:
            try: os.write(self.fd, value.encode('utf-8'))
            except OSError: pass
    def signal_process(self, sig):
        process = self.process
        if not process or process.poll() is not None: return
        try:
            if os.getpgid(process.pid) == process.pid:
                os.killpg(process.pid, sig)
                return
        except OSError:
            pass
        try: process.send_signal(sig)
        except ProcessLookupError: pass

    @Slot()
    def interrupt(self):
        try: self.signal_process(signal.SIGINT)
        except OSError as exc:
            self._text += '\nUnable to interrupt this process: ' + str(exc)
            self.changed.emit()
    def read(self):
        changed=False
        if self.fd is None: return
        for _ in range(16):
            try:
                data=os.read(self.fd,65536)
                if not data: break
                self.stream.feed(self.decoder.decode(data)); changed=True
            except BlockingIOError: break
            except OSError: break
        if changed:
            self._text='\n'.join(self.screen.display).rstrip(); self.changed.emit()
        if self.process and self.process.poll() is not None:
            self.timer.stop(); self.changed.emit()
    @Slot()
    def stop(self):
        self.timer.stop()
        process = self.process
        failure = None
        try:
            if process and process.poll() is None:
                try: self.signal_process(signal.SIGHUP)
                except OSError as exc: failure = exc
                try: process.wait(timeout=0.2)
                except subprocess.TimeoutExpired:
                    try: self.signal_process(signal.SIGKILL)
                    except OSError as exc: failure = exc
                    try: process.wait(timeout=1)
                    except subprocess.TimeoutExpired: failure = RuntimeError('The shell did not exit after its termination request.')
        finally:
            if self.fd is not None:
                try: os.close(self.fd)
                except OSError: pass
                self.fd = None
            if process is None or process.poll() is not None:
                self.process = None
            elif failure:
                self._text += '\nUnable to stop this shell: ' + str(failure)
            self.changed.emit()
