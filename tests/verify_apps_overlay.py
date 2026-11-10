"""Real QML launcher gestures; only the isolated preview's apps are launched."""
import os,sys,tempfile
from pathlib import Path
os.environ['QT_QPA_PLATFORM']='offscreen';os.environ['QT_QUICK_BACKEND']='software';os.environ['QT_QUICK_CONTROLS_STYLE']='Basic'
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
from PySide6.QtCore import QObject,QUrl,Qt,QPoint,QEvent,QCoreApplication
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickWindow,QQuickItem
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtTest import QTest
from main import Bridge
from filesystem import Workspace
app=QGuiApplication([])
with tempfile.TemporaryDirectory() as folder:
    bridge=Bridge(Workspace(Path(folder)));engine=QQmlApplicationEngine();warnings=[]
    engine.warnings.connect(lambda items:warnings.extend(str(i) for i in items))
    for key,value in {'Bridge':bridge,'startSettings':False,'startFullscreen':False,'comparisonMode':False,'startNativeWindows':False}.items():engine.rootContext().setContextProperty(key,value)
    engine.load(QUrl.fromLocalFile(str(ROOT/'qml/Main.qml')));assert engine.rootObjects(),warnings
    root=engine.rootObjects()[0];root.setWidth(1360);root.setHeight(850);root.requestActivate()
    desktop=root.findChild(QObject,'desktop');overlay=root.findChild(QObject,'appsOverlay')
    assert len(desktop.property('windows').toVariant())==1
    desktop.openApplication('apps');QTest.qWait(260)
    assert overlay.property('visible') and overlay.property('modal')
    assert len(desktop.property('windows').toVariant())==1,'Apps must not become a DesktopWindow'
    search=root.findChild(QObject,'appsSearch');assert search.property('activeFocus')
    search.setProperty('text','Calculator');QTest.keyClick(root,Qt.Key_Return);QTest.qWait(200)
    assert not overlay.property('visible')
    assert desktop.property('windows').toVariant()[-1].property('appKind')=='calculator'
    desktop.openApplication('apps');QTest.qWait(240);assert overlay.property('visible')
    QTest.keyClick(root,Qt.Key_Escape);QTest.qWait(160);assert not overlay.property('visible')
    desktop.openApplication('apps');QTest.qWait(240)
    QTest.mouseClick(root,Qt.LeftButton,Qt.NoModifier,QPoint(12,60));QTest.qWait(160)
    assert not overlay.property('visible'),'Outside click dismisses launcher'
    assert not warnings,warnings
    root.flushApplications();bridge.shutdown();root.setVisible(False);engine.deleteLater();QCoreApplication.sendPostedEvents(None,QEvent.DeferredDelete)
print('Apps overlay passed: modal without app window, search+Enter launch, Escape and outside dismissal.')
