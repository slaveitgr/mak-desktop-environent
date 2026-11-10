"""Render all installer stages with an injected fake daemon. No disk operations."""
import os
os.environ['QT_QPA_PLATFORM']='offscreen';os.environ['QT_QUICK_CONTROLS_STYLE']='Basic'
from pathlib import Path
import sys
from PySide6.QtCore import QObject,QUrl,QPointF,QPoint,Qt
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow
from PySide6.QtTest import QTest
import shiboken6
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'installer'))
from makos_install import InstallController
from test_makos_installer import FakeInstaller,DISK,PASSWORD
app=QGuiApplication([]);transport=FakeInstaller();controller=InstallController(live=True,transport=transport)
engine=QQmlApplicationEngine();warnings=[];engine.warnings.connect(lambda items:warnings.extend(str(item) for item in items))
engine.rootContext().setContextProperty('InstallBackend',controller);engine.rootContext().setContextProperty('nativeShell',False)
engine.load(QUrl.fromLocalFile(str(ROOT/'installer/InstallWindow.qml')))
assert engine.rootObjects(),warnings
window=engine.rootObjects()[0];window.show();window.requestActivate();QTest.qWait(30)
def click(item):
    point=item.mapToScene(QPointF(item.width()/2,item.height()/2))
    QTest.mouseClick(window,Qt.LeftButton,Qt.NoModifier,QPoint(round(point.x()),round(point.y())))
    QTest.qWait(20)
def visual(name, item=None):
    item=item or window.contentItem()
    if item.objectName()==name:return item
    for child in item.childItems():
        found=visual(name,child)
        if found is not None:return found
    return None
next_button=window.findChild(QObject,'installerContinue')
click(next_button);assert controller.phase=='disk'
assert not next_button.property('enabled')
assert [name for name,_ in transport.calls]==['GetDisks','Running']
click(visual('installerDisk_'+DISK['path']))
assert next_button.property('enabled')
window.grabWindow().save('/tmp/makos-installer-disk-fixture.png')
click(next_button);assert controller.phase=='account'
for name,value in [('installerFullName','Fixture User'),('installerUserName','fixture'),('installerPassword',PASSWORD),('installerPasswordRepeat',PASSWORD),('installerHostName','fixture-computer')]:
    field=window.findChild(QObject,name);assert field,name;field.setProperty('text',value)
window.findChild(QObject,'installerTimeZone').setProperty('editText','Etc/UTC')
click(next_button);assert controller.phase=='review',controller.errorText
assert not next_button.property('enabled')
window.grabWindow().save('/tmp/makos-installer-review-fixture.png')
window.findChild(QObject,'installerDiskConfirmation').setProperty('text','/dev/wrong')
click(window.findChild(QObject,'installerEraseConsent'))
assert not next_button.property('enabled')
assert 'Install' not in [name for name,_ in transport.calls]
window.findChild(QObject,'installerDiskConfirmation').setProperty('text',DISK['path']);QTest.qWait(10)
assert next_button.property('enabled')
click(next_button);assert controller.phase=='starting'
assert window.findChild(QObject,'installerPassword').property('text')==''
transport.install_reply(None,'');transport.progress.emit('copy',0.4);QTest.qWait(20)
assert controller.phase=='installing'
transport.finished.emit(True,'');QTest.qWait(20);assert controller.phase=='complete'
assert not warnings,warnings
shiboken6.delete(engine)
print('PASS: makOS installer disk/account/review/starting/progress/completion UI; injected daemon only; zero QML warnings.')
