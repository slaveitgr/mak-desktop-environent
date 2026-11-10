"""Protocol and UI state tests with an injected process. No hardware is touched."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from PySide6.QtCore import QCoreApplication, QObject, QProcess, Signal
from linux_settings import LinuxSettings, PANELS

class FakeProcess(QObject):
    readyReadStandardOutput = Signal()
    readyReadStandardError = Signal()
    errorOccurred = Signal(object)
    finished = Signal(int, object)
    def __init__(self, parent=None):
        super().__init__(parent); self.writes=[]; self.buffer=b''; self.running=False
    def setProcessChannelMode(self, mode): pass
    def start(self, *args): self.running=True
    def state(self): return QProcess.Running if self.running else QProcess.NotRunning
    def write(self, data): self.writes.append(json.loads(data)); return len(data)
    def readAllStandardOutput(self):
        data=self.buffer; self.buffer=b''; return data
    def readAllStandardError(self): return b''
    def send(self, message):
        self.buffer=json.dumps(message).encode()+b'\n'; self.readyReadStandardOutput.emit()
    def kill(self): self.running=False
    def closeWriteChannel(self): self.running=False
    def waitForFinished(self, timeout): return True

class SettingsContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls): cls.app=QCoreApplication.instance() or QCoreApplication([])
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(); path=Path(self.tmp.name)/'helper'; path.write_text('fixture'); path.chmod(0o755)
        self.settings=LinuxSettings(True, helper_path=path, process_factory=FakeProcess, platform_name='linux')
        self.process=self.settings._process
        self.state={panel:{'available':False} for panel in PANELS}
        self.state['audio']={'available':True,'outputs':[{'id':'17','name':'Injected test sink','volume':0.4,'muted':False,'default':True,'writable':True}],'inputs':[]}
        self.state['power']={'available':True,'active':'balanced','profiles':['balanced','power-saver']}
        self.publish()
    def tearDown(self): self.settings.stop(); self.tmp.cleanup()
    def publish(self): self.process.send({'type':'state','protocol':1,'state':self.state})
    def test_write_keeps_observed_state_until_readback(self):
        self.assertTrue(self.settings.apply('audio.volume',0.8,'17'))
        self.assertTrue(self.settings.busy)
        self.assertEqual(self.settings.state['audio']['outputs'][0]['volume'],0.4)
        command=self.process.writes[-1]
        self.state['audio']['outputs'][0]['volume']=0.8; self.publish()
        self.assertTrue(self.settings.busy)
        self.process.send({'type':'result','id':command['id'],'ok':True})
        self.assertFalse(self.settings.busy)
        self.assertEqual(self.settings.state['audio']['outputs'][0]['volume'],0.8)
    def test_permission_failure_preserves_actual_state(self):
        self.settings.apply('power.profile','power-saver','')
        self.process.send({'type':'result','id':self.process.writes[-1]['id'],'ok':False,'message':'Permission denied'})
        self.assertEqual(self.settings.state['power']['active'],'balanced')
        self.assertEqual(self.settings.errorText,'Permission denied')
    def test_invalid_values_and_unsupported_actions_never_cross_boundary(self):
        for action,value in [('audio.volume',float('nan')),('audio.volume',2),('audio.volume',True),('audio.muted','true'),('audio.default',False),('power.profile','fake'),('display.apply',True)]:
            self.assertFalse(self.settings.apply(action,value,'17'))
        self.assertEqual(self.process.writes,[])
    def test_stale_reply_cannot_complete_new_request(self):
        self.settings.apply('audio.muted',True,'17')
        self.process.send({'type':'result','id':'stale','ok':True})
        self.assertTrue(self.settings.busy)
        self.assertFalse(self.settings.apply('audio.volume',0.5,'17'))
        self.assertEqual(len(self.process.writes),1)
    def test_timeout_clears_availability_instead_of_showing_success(self):
        self.settings.apply('audio.muted',True,'17'); self.settings._timed_out()
        self.assertFalse(self.settings.ready); self.assertFalse(self.settings.busy)
        self.assertFalse(self.settings.state['audio']['available']); self.assertFalse(self.process.running)
    def test_malformed_state_disables_backend(self):
        self.process.send({'type':'state','protocol':1,'state':{'audio':{'available':True}}})
        self.assertFalse(self.settings.ready); self.assertFalse(self.process.running)
    def test_host_guard_never_starts_native_helper(self):
        settings=LinuxSettings(True,platform_name='darwin',process_factory=lambda _:self.fail('host helper started'))
        self.assertFalse(settings.enabled); self.assertFalse(settings.ready)
        self.assertFalse(settings.apply('wifi.enabled',True,''))
    def test_missing_executable_is_explicit(self):
        settings=LinuxSettings(True,platform_name='linux',helper_path=Path(self.tmp.name)/'missing')
        self.assertIn('not installed',settings.errorText)
    def test_service_absence_is_honest_state(self):
        self.process.send({'type':'state','protocol':1,'state':{panel:{'available':False} for panel in PANELS}})
        self.assertTrue(self.settings.ready)
        self.assertTrue(all(not panel['available'] for panel in self.settings.state.values()))

if __name__=='__main__': unittest.main()
