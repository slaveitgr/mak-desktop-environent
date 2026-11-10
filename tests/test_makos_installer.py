"""Installer protocol tests. Fake transport only; no disks or services touched."""
import copy
from pathlib import Path
import sys
import unittest
from PySide6.QtCore import QCoreApplication,QObject,Signal
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'installer'))
from makos_install import InstallController

DISK={'path':'/dev/testdisk','model':'Injected test disk','size':80_000_000_000,'removable':False}
LAYOUT={'disk':DISK['path'],'size':DISK['size'],'sectorSize':512,'table':'gpt','partitions':[{'number':1,'path':'/dev/testdisk1','start':1048576,'size':79_000_000_000,'fsType':'ext4','label':'Fixture'}]}
PASSWORD='Fixture-only-password'

class FakeInstaller(QObject):
    progress=Signal(str,float);finished=Signal(bool,str);lost=Signal(str)
    def __init__(self):
        super().__init__();self.calls=[];self.disk=copy.deepcopy(DISK);self.layout=copy.deepcopy(LAYOUT);self.running=False;self.failure='';self.install_reply=None
    def call(self,method,arguments,done):
        self.calls.append((method,copy.deepcopy(arguments)))
        if self.failure:done(None,self.failure);return
        if method=='GetDisks':done([copy.deepcopy(self.disk)],'')
        elif method=='GetLayout':done(copy.deepcopy(self.layout),'')
        elif method=='Running':done(self.running,'')
        elif method=='Install':self.install_reply=done
        else:raise AssertionError(method)

class InstallerContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.app=QCoreApplication.instance() or QCoreApplication([])
    def setUp(self):self.transport=FakeInstaller();self.controller=InstallController(live=True,transport=self.transport)
    def to_account(self):
        self.controller.begin();self.controller.selectDisk(DISK['path']);self.controller.account()
        self.assertEqual(self.controller.phase,'account')
    def to_review(self):
        self.to_account()
        self.assertTrue(self.controller.prepare('Fixture User','fixture',PASSWORD,PASSWORD,'fixture-computer','Etc/UTC'))
    def test_discovery_and_selection_are_read_only(self):
        self.to_account()
        self.assertEqual([name for name,_ in self.transport.calls],['GetDisks','Running','GetLayout'])
        self.assertEqual(self.controller.selectedDisk,DISK)
    def test_preview_never_calls_even_injected_transport(self):
        preview=InstallController(live=True,preview=True,transport=self.transport)
        preview.begin();preview.refresh();preview.selectDisk(DISK['path']);preview.commit(DISK['path'],True,PASSWORD)
        self.assertFalse(preview.live);self.assertEqual(self.transport.calls,[])
    def test_unavailable_service_has_no_fallback_launch(self):
        self.transport.failure='Service unavailable';self.controller.begin()
        self.assertFalse(self.controller.available);self.assertIn('unavailable',self.controller.errorText)
        self.assertEqual(self.transport.calls,[('GetDisks',[])])
    def test_account_validation_and_no_password_in_review(self):
        self.to_account()
        self.assertFalse(self.controller.prepare('Fixture User','root:bad',PASSWORD,PASSWORD,'fixture','Etc/UTC'))
        self.assertFalse(self.controller.prepare('Fixture User','fixture',PASSWORD,'wrong','fixture','Etc/UTC'))
        self.assertFalse(self.controller.prepare('Fixture User','fixture',PASSWORD,PASSWORD,'-bad','Etc/UTC'))
        self.assertFalse(self.controller.prepare('Fixture User','fixture',PASSWORD,PASSWORD,'fixture','../../etc/passwd'))
        self.assertTrue(self.controller.prepare('Fixture User','fixture',PASSWORD,PASSWORD,'fixture','Etc/UTC'))
        self.assertNotIn(PASSWORD,repr(self.controller.review));self.assertNotIn('password',self.controller.review)
    def test_confirmation_requires_exact_path_and_checkbox(self):
        self.to_review()
        self.assertFalse(self.controller.commit('/dev/wrong',True,PASSWORD))
        self.assertFalse(self.controller.commit(DISK['path'],False,PASSWORD))
        self.assertNotIn('Install',[name for name,_ in self.transport.calls])
    def test_disk_hotplug_or_layout_change_aborts_before_install(self):
        self.to_review();self.transport.layout['partitions'][0]['size']-=4096
        self.controller.commit(DISK['path'],True,PASSWORD)
        self.assertNotIn('Install',[name for name,_ in self.transport.calls])
        self.assertIn('changed',self.controller.errorText);self.assertFalse(self.controller.available)
    def test_preflight_rechecks_disk_layout_and_running(self):
        self.to_review();self.controller.commit(DISK['path'],True,PASSWORD)
        self.assertEqual([name for name,_ in self.transport.calls][-4:],['GetDisks','GetLayout','Running','Install'])
        options=self.transport.calls[-1][1][0]
        self.assertEqual(options,{'disk':DISK['path'],'fullName':'Fixture User','userName':'fixture','hostName':'fixture-computer','timeZone':'Etc/UTC','password':PASSWORD})
        self.assertEqual(self.controller.phase,'starting');self.assertFalse(self.controller.canClose)
    def test_busy_daemon_blocks_commit(self):
        self.to_review();self.transport.running=True;self.controller.commit(DISK['path'],True,PASSWORD)
        self.assertNotIn('Install',[name for name,_ in self.transport.calls])
        self.assertIn('running',self.controller.errorText)
    def test_progress_is_never_success_without_finished(self):
        self.to_review();self.controller.commit(DISK['path'],True,PASSWORD);self.transport.install_reply(None,'')
        self.transport.progress.emit('finish',1.)
        self.assertEqual(self.controller.phase,'installing');self.assertFalse(self.controller.canClose)
        self.transport.finished.emit(True,'')
        self.assertEqual(self.controller.phase,'complete');self.assertTrue(self.controller.canClose)
    def test_signals_before_acknowledgment_are_buffered(self):
        self.to_review();self.controller.commit(DISK['path'],True,PASSWORD)
        self.transport.progress.emit('copy',0.3);self.transport.finished.emit(True,'')
        self.assertEqual(self.controller.phase,'starting');self.assertEqual(self.controller.progress,0.)
        self.transport.install_reply(None,'');self.assertEqual(self.controller.phase,'complete')
    def test_unrelated_finished_signal_is_ignored(self):
        self.transport.finished.emit(True,'');self.assertEqual(self.controller.phase,'intro')
    def test_error_never_marks_complete_and_timeout_cannot_retry(self):
        self.to_review();self.controller.commit(DISK['path'],True,PASSWORD)
        self.transport.install_reply(None,'org.freedesktop.DBus.Error.NoReply: timeout')
        self.assertEqual(self.controller.phase,'uncertain');self.assertFalse(self.controller.canClose)
        self.assertFalse(self.controller.commit(DISK['path'],True,PASSWORD))
    def test_explicit_denial_is_not_ambiguous(self):
        self.to_review();self.controller.commit(DISK['path'],True,PASSWORD)
        self.transport.install_reply(None,'org.freedesktop.DBus.Error.AccessDenied: denied')
        self.assertEqual(self.controller.phase,'failed');self.assertTrue(self.controller.canClose)
    def test_disconnect_during_install_is_uncertain(self):
        self.to_review();self.controller.commit(DISK['path'],True,PASSWORD);self.transport.install_reply(None,'')
        self.transport.lost.emit('Daemon disappeared')
        self.assertEqual(self.controller.phase,'uncertain');self.assertFalse(self.controller.canClose)
    def test_daemon_failure_keeps_partial_install_explicit(self):
        self.to_review();self.controller.commit(DISK['path'],True,PASSWORD);self.transport.install_reply(None,'')
        self.transport.finished.emit(False,'Copy failed')
        self.assertEqual(self.controller.phase,'failed');self.assertEqual(self.controller.errorText,'Copy failed')

if __name__=='__main__':unittest.main()
