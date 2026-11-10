"""Two app connections share appearance without echoing remote writes."""
import os,sys,tempfile
from pathlib import Path
os.environ['QT_QPA_PLATFORM']='offscreen';os.environ['QT_QUICK_BACKEND']='software';os.environ['QT_QUICK_CONTROLS_STYLE']='Basic'
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
from PySide6.QtCore import QObject,QUrl,QCoreApplication,QEvent
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickWindow,QQuickItem
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtTest import QTest
from main import Bridge
from filesystem import Workspace
app=QGuiApplication([])
with tempfile.TemporaryDirectory() as folder:
    instances=[];warnings=[]
    for _ in range(2):
        bridge=Bridge(Workspace(Path(folder)));bridge.suite.watchExternalChanges()
        engine=QQmlApplicationEngine();engine.warnings.connect(lambda items:warnings.extend(str(i) for i in items))
        for key,value in {'Bridge':bridge,'startSettings':False,'startFullscreen':False,'comparisonMode':False,'startNativeWindows':False}.items():engine.rootContext().setContextProperty(key,value)
        engine.load(QUrl.fromLocalFile(str(ROOT/'qml/Main.qml')));assert engine.rootObjects(),warnings
        root=engine.rootObjects()[0];instances.append((bridge,engine,root,root.findChild(QObject,'desktop')))
    a,b=instances;before=b[0].suite.db.total_changes
    a[3].setAppearance('dark');a[3].setProperty('glassTinted',True)
    QTest.qWait(750)
    assert b[3].property('dark') and b[3].property('appearanceMode')=='manual' and b[3].property('glassTinted'), [(x[3].property('dark'),x[3].property('appearanceMode'),x[3].property('glassTinted'),x[0].suite.preference('shell.appearance','missing')) for x in instances]
    assert b[0].suite.db.total_changes==before,'Remote appearance must not be written back'
    before=a[0].suite.db.total_changes
    b[3].setAppearance('light');b[3].setProperty('dockMagnification',False)
    QTest.qWait(750)
    assert not a[3].property('dark') and a[3].property('appearanceMode')=='manual' and not a[3].property('dockMagnification')
    assert a[0].suite.db.total_changes==before
    assert not warnings,warnings
    for bridge,engine,root,desktop in instances:
        root.flushApplications();bridge.shutdown();root.setVisible(False);engine.deleteLater()
    QCoreApplication.sendPostedEvents(None,QEvent.DeferredDelete)
print('Appearance sync passed: two independent SQLite connections, both directions, no echo writes.')
