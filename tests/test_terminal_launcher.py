import unittest
from pathlib import Path
from terminal_launcher import command

class TerminalLauncherTests(unittest.TestCase):
    def test_direct_argv_is_preserved(self):
        values=['/usr/bin/example','with spaces','$(literal); `text`','--flag']
        result=command(['-e',*values],Path('/opt/makos'),Path('/home/live'))
        self.assertEqual(result, ['/opt/makos/main.py','--root','/home/live','--cutefish-app',
                                  'terminal','--terminal-execute',*values])
    def test_plain_launch_requests_new_shell_window(self):
        self.assertEqual(command([],Path('/opt/makos'),Path('/home/live'))[-1], '--new-window')
    def test_invalid_options_do_not_execute(self):
        for args in (['-e'],['--unsupported'],['program']):
            with self.assertRaises(ValueError):command(args,Path('/opt/makos'),Path('/home/live'))
