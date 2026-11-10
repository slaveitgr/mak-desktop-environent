"""Exercise only an owned temporary PTY; never control the user's Terminal app."""
import os
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
try:
    from PySide6.QtCore import QCoreApplication
    from terminal_session import TerminalSession
    HAS_TERMINAL = True
except ImportError:
    HAS_TERMINAL = False


@unittest.skipUnless(HAS_TERMINAL and os.name == 'posix', 'Requires Qt, pyte and a POSIX PTY')
class TerminalTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QCoreApplication.instance() or QCoreApplication([])

    def setUp(self):
        self.temp = TemporaryDirectory()
        self.terminal = TerminalSession(self.temp.name)

    def tearDown(self):
        self.terminal.stop()
        self.temp.cleanup()

    def wait_until(self, predicate, timeout=3):
        deadline = time.monotonic()+timeout
        while time.monotonic() < deadline:
            self.app.processEvents()
            self.terminal.read()
            if predicate(): return
            time.sleep(0.01)
        self.fail('PTY condition was not reached; display: ' + self.terminal.text[-400:])

    def test_explicit_start_real_command_and_owned_process_cleanup(self):
        self.assertFalse(self.terminal.running)
        self.assertIsNone(self.terminal.process)
        with patch.dict(os.environ, {'SHELL':'/bin/sh', 'ENV':'', 'BASH_ENV':''}):
            self.terminal.start()
        process = self.terminal.process
        self.assertTrue(self.terminal.running)
        # Split marker in the input so seeing it in the display proves execution,
        # rather than merely terminal input echo.
        self.terminal.write("printf 'owned-%s\\n' 'pty-result'; pwd\r")
        self.wait_until(lambda: 'owned-pty-result' in self.terminal.text and self.temp.name in self.terminal.text)
        self.terminal.stop()
        self.assertFalse(self.terminal.running)
        self.assertIsNotNone(process.poll())
        self.assertIsNone(self.terminal.fd)
        self.assertFalse(self.terminal.timer.isActive())

    def test_exit_and_restart_are_supported(self):
        with patch.dict(os.environ, {'SHELL':'/bin/sh', 'ENV':'', 'BASH_ENV':''}):
            self.terminal.start()
            first = self.terminal.process
            self.terminal.write('exit\r')
            self.wait_until(lambda:not self.terminal.running)
            self.terminal.start()
        self.assertTrue(self.terminal.running)
        self.assertNotEqual(self.terminal.process.pid, first.pid)
        self.terminal.write("printf 'second-%s\\n' 'session'\r")
        self.wait_until(lambda:'second-session' in self.terminal.text)


if __name__ == '__main__': unittest.main()
