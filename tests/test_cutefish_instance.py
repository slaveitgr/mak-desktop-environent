import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from PySide6.QtCore import QCoreApplication
from PySide6.QtTest import QTest
from cutefish_runtime import CutefishInstance


class ActivationTarget:
    def __init__(self): self.tokens = []; self.requests = []
    def activateCutefishClient(self): self.tokens.append(os.environ.get('XDG_ACTIVATION_TOKEN'))
    def handleNativeLaunch(self, action, argument): self.requests.append((action,argument))


class CutefishInstanceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls): cls.app = QCoreApplication.instance() or QCoreApplication([])

    def test_second_launch_forwards_activation_to_owner(self):
        with tempfile.TemporaryDirectory(prefix='cf-', dir='/tmp') as directory:
            with patch.dict(os.environ, {'XDG_RUNTIME_DIR':directory}, clear=False):
                owner = CutefishInstance(self.app, 'finder', Path(directory))
                target = ActivationTarget(); owner.bind(target)
                self.assertTrue(owner.acquire())
                second = CutefishInstance(self.app, 'finder', Path(directory))
                with patch.dict(os.environ, {'XDG_ACTIVATION_TOKEN':'launch-token'}):
                    self.assertFalse(second.acquire())
                QTest.qWait(30)
                self.assertEqual(target.tokens, ['launch-token'])
                self.assertNotIn('XDG_ACTIVATION_TOKEN', os.environ)
                second.deleteLater(); owner.server.close(); owner.lock.unlock(); owner.deleteLater()

    def test_invalid_messages_cannot_activate_or_set_environment(self):
        with tempfile.TemporaryDirectory(prefix='cf-', dir='/tmp') as directory:
            with patch.dict(os.environ, {'XDG_RUNTIME_DIR':directory}, clear=False):
                owner = CutefishInstance(self.app, 'finder', Path(directory))
                target = ActivationTarget(); owner.bind(target)
                for message in (None, [], {'action':'execute'}, {'action':'activate','token':3},
                                {'action':'activate','token':'a'*2049}, {'action':'activate','token':'a\0b'}):
                    owner.activate(message)
                self.assertEqual(target.tokens, [])
                owner.deleteLater()

    def test_second_launch_forwards_folder_and_settings_page_to_existing_owner(self):
        with tempfile.TemporaryDirectory(prefix='cf-',dir='/tmp') as directory, patch.dict(os.environ,{'XDG_RUNTIME_DIR':directory}):
            for kind,action,argument in [('finder','open-folder','Downloads'),('settings','settings-page','Wi-Fi'),('terminal','terminal-new-window','')]:
                owner=CutefishInstance(self.app,kind,Path(directory));target=ActivationTarget()
                self.assertTrue(owner.acquire())
                second=CutefishInstance(self.app,kind,Path(directory),{'action':action,'argument':argument})
                self.assertFalse(second.acquire());QTest.qWait(30)
                self.assertEqual(target.requests,[])
                owner.bind(target)
                self.assertEqual(target.requests,[(action,argument)])
                owner.activate({'action':action,'argument':'bad\0path'})
                owner.activate({'action':'settings-page' if kind=='finder' else 'open-folder','argument':'unexpected'})
                self.assertEqual(len(target.requests),1)
                if kind != 'terminal':
                    owner.activate({'action':'terminal-new-window'})
                    self.assertEqual(len(target.requests),1)
                second.deleteLater();owner.server.close();owner.lock.unlock();owner.deleteLater()


if __name__ == '__main__': unittest.main()
