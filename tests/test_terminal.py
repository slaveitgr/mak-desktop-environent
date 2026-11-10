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
        self.terminal = TerminalSession(self.temp.name, shell_command=['/bin/sh','-i'],
            environment={**os.environ,'ENV':'','BASH_ENV':'','HISTFILE':'/dev/null'})

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

    def test_real_tty_size_resize_and_foreground_interrupt(self):
        self.terminal.resize(120,30);self.terminal.start()
        self.terminal.write('stty size\r')
        self.wait_until(lambda:'30 120' in self.terminal.text)
        self.terminal.resize(92,26);self.terminal.write('stty size\r')
        self.wait_until(lambda:'26 92' in self.terminal.text)
        self.terminal.write("sleep 30; printf 'after-%s\\n' interrupt\r")
        self.wait_until(lambda:os.tcgetpgrp(self.terminal.fd)!=self.terminal.process.pid)
        self.terminal.interrupt()
        self.wait_until(lambda:'after-interrupt' in self.terminal.text)
        self.assertTrue(self.terminal.running)
        self.assertNotIn('no job control',self.terminal.text)

    def test_color_cursor_scrollback_and_alternate_screen(self):
        self.terminal.resize(80,8)
        self.terminal.stream.feed('primary\r\n\x1b[31mred\x1b[0m\r\n')
        self.terminal._render();self.assertIn('color:#c01c28',self.terminal.richText)
        self.terminal.stream.feed('\x1b[?1049hSECONDARY\x1b[?1049l');self.terminal._render()
        self.assertIn('primary',self.terminal.text);self.assertNotIn('SECONDARY',self.terminal.text)
        for index in range(20):self.terminal.stream.feed('line-'+str(index)+'\r\n')
        self.terminal._render();self.assertGreater(self.terminal.historyRows,0)
        self.assertIn('line-0',self.terminal.text)
        self.terminal.clearScrollback();self.assertEqual(self.terminal.historyRows,0)
        self.assertNotIn('line-0',self.terminal.text)
        self.terminal.clearScreen();self.assertFalse(self.terminal.text.strip())

    def test_bracketed_paste_and_utf8(self):
        received=[];self.terminal.write=received.append
        self.terminal.stream.feed('\x1b[?2004h');self.terminal.paste('a\nβ\x1b[201~')
        self.assertEqual(received,['\x1b[200~a\nβ\x1b[201~'])
        data='α😀'.encode();self.terminal.stream.feed(self.terminal.decoder.decode(data[:3]));self.terminal.stream.feed(self.terminal.decoder.decode(data[3:]));self.terminal._render()
        self.assertIn('α😀',self.terminal.text);self.assertEqual(self.terminal.cursorPosition,3)

    def test_banner_uses_inventory_and_escapes_host_fields(self):
        from makos_fetch import render
        output=render({'version':'test','platform':'Fixture Linux','processor':'Fixture CPU\x1b[2J','memory':'8 GiB'},False)
        self.assertIn('Platform: Fixture Linux',output);self.assertIn('CPU: Fixture CPU [2J',output)
        self.assertNotIn('\x1b',output);self.assertFalse(self.terminal.show_banner)

    def test_banner_is_child_output_before_controlled_shell_prompt(self):
        self.terminal.show_banner=True
        self.terminal.environment['PS1']='fixture-banner-prompt$ '
        self.terminal.start()
        self.wait_until(lambda:'makOS:' in self.terminal.text and 'fixture-banner-prompt$' in self.terminal.text)
        self.assertLess(self.terminal.text.index('makOS:'),self.terminal.text.index('fixture-banner-prompt$'))
        self.assertNotIn('makos-fetch.py',self.terminal.text)

    def test_cleanup_signals_captured_foreground_even_if_shell_exits(self):
        # No host process is signalled: assert the bounded ownership checks with
        # an injected process which already exited when cleanup reaches it.
        from unittest.mock import Mock
        process=Mock(pid=123456);process.poll.return_value=0
        self.terminal.process=process
        with patch('terminal_session.os.getsid',return_value=123456),patch('terminal_session.os.killpg') as kill:
            self.terminal.signal_process(9,{123456,123457})
            self.assertEqual(kill.call_args_list, [unittest.mock.call(123456,9),unittest.mock.call(123457,9)])
        self.terminal.process=None


if __name__ == '__main__': unittest.main()
