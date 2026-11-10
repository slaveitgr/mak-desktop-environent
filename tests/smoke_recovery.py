"""Exercise selection and return flows against the real QML, using example disks."""
import os
from pathlib import Path
import sys
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
os.environ.setdefault('QT_QUICK_BACKEND','software')
os.environ.setdefault('QT_QUICK_CONTROLS_STYLE','Basic')
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
from PySide6.QtCore import QUrl,QCoreApplication,QEvent
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine,QQmlExpression
from PySide6.QtQuick import QQuickWindow
from PySide6.QtTest import QTest
from installer.recovery import RecoveryController
from installer.disks import DiskInventory
app=QGuiApplication([]);engine=QQmlApplicationEngine();backend=RecoveryController(False);disks=DiskInventory(True)
ctx=engine.rootContext();ctx.setContextProperty('RecoveryBackend',backend);ctx.setContextProperty('DiskBackend',disks);ctx.setContextProperty('nativeShell',False)
engine.load(QUrl.fromLocalFile(str(ROOT/'installer/Recovery.qml')));assert engine.rootObjects()
root=engine.rootObjects()[0];QTest.qWait(100)
def evaluate(obj,code):
    expr=QQmlExpression(ctx,obj,code);result=expr.evaluate();assert not expr.hasError(),expr.error().toString();return result
for _ in range(2):
    evaluate(root,'selected=3; continueSelection()');QTest.qWait(30)
    disk=root.findChild(QQuickWindow,'makOSDiskUtility');assert disk.isVisible() and not root.isVisible()
    disk.setProperty('selectedPath','/dev/nvme0n1p2');disk.setProperty('allDevices',False)
    assert disk.property('selectedPath')=='/dev/nvme0n1p2'
    assert len(disk.property('visibleRows').toVariant())==3
    evaluate(disk,'requestAction("Erase")');QTest.qWait(20)
    assert backend._process is None
    evaluate(disk,'selectedPath="/dev/nvme0n1"; selectFirst()')
    assert disk.property('selectedPath')=='/dev/nvme0n1p1'
    disk.close();QTest.qWait(30);assert root.isVisible() and not disk.isVisible()
print('PASS: Recovery → Disk Utility → Recovery twice; volume filters preserve valid selection; preview erase sheet has no disk side effects.')
engine.deleteLater();QCoreApplication.sendPostedEvents(None,QEvent.Type.DeferredDelete)
