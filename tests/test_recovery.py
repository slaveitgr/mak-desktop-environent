import unittest
from PySide6.QtCore import QObject, Signal, QCoreApplication, QProcess
from installer.recovery import RecoveryController, CHOICES

class FakeProcess(QObject):
    started = Signal()
    finished = Signal(int, int)
    errorOccurred = Signal(object)
    def start(self, executable, arguments): self.command = (executable, arguments)

class RecoveryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls): cls.app = QCoreApplication.instance() or QCoreApplication([])
    def test_preview_never_starts_tools(self):
        calls=[]; messages=[]; opened=[]
        c=RecoveryController(False, process_factory=lambda *_:calls.append(True))
        c.message.connect(lambda *args: messages.append(args))
        c.openDisks.connect(lambda:opened.append(True))
        for row in CHOICES: c.launch(row['id'])
        self.assertEqual(calls,[]); self.assertEqual(len(messages),3)
        self.assertFalse(c.externalActive);self.assertEqual(opened,[True])
    def test_live_dispatch_uses_fixed_program_and_no_shell(self):
        c=RecoveryController(True, resolver=lambda name:'/usr/bin/'+name,process_factory=FakeProcess)
        c.launch('install'); p=c._process
        self.assertEqual(p.command,('/usr/bin/cutefish-installer',[]))
        p.started.emit(); self.assertTrue(c.externalActive)
        c.launch('disks'); self.assertIs(c._process,p)
        p.finished.emit(0,0); self.assertFalse(c.externalActive); self.assertIsNone(c._process)
    def test_unknown_action_and_missing_program_do_not_start(self):
        messages=[];c=RecoveryController(True,resolver=lambda _:None,process_factory=FakeProcess)
        c.message.connect(lambda *args:messages.append(args))
        c.launch('install; reboot'); self.assertEqual(messages,[])
        c.launch('install');self.assertIsNone(c._process);self.assertEqual(len(messages),1)
    def test_failed_start_returns_to_recovery(self):
        c=RecoveryController(True,resolver=lambda n:'/usr/bin/'+n,process_factory=FakeProcess)
        c.launch('restore');self.assertEqual(c._process.command,('/usr/bin/deja-dup',['--restore']))
        c._process.errorOccurred.emit(QProcess.ProcessError.FailedToStart)
        self.assertIsNone(c._process);self.assertFalse(c.externalActive)

if __name__=='__main__':unittest.main()
