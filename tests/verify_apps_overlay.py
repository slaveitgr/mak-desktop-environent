"""Real QML launcher gestures; only the isolated preview's apps are launched."""
import os,sys,tempfile
from pathlib import Path
os.environ['QT_QPA_PLATFORM']='offscreen';os.environ['QT_QUICK_BACKEND']='software';os.environ['QT_QUICK_CONTROLS_STYLE']='Basic'
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
from PySide6.QtCore import QObject,QUrl,Qt,QPoint,QPointF,QEvent,QCoreApplication
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickWindow,QQuickItem
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtTest import QTest
from main import Bridge
from filesystem import Workspace
app=QGuiApplication([])
with tempfile.TemporaryDirectory() as folder:
    (Path(folder)/'Documents').mkdir();(Path(folder)/'Documents'/'Launcher Search Test.txt').write_text('isolated fixture')
    bridge=Bridge(Workspace(Path(folder)));engine=QQmlApplicationEngine();warnings=[]
    engine.warnings.connect(lambda items:warnings.extend(str(i) for i in items))
    for key,value in {'Bridge':bridge,'startSettings':False,'startFullscreen':False,'comparisonMode':False,'startNativeWindows':False}.items():engine.rootContext().setContextProperty(key,value)
    engine.load(QUrl.fromLocalFile(str(ROOT/'qml/Main.qml')));assert engine.rootObjects(),warnings
    root=engine.rootObjects()[0];root.setWidth(1360);root.setHeight(850);root.requestActivate()
    desktop=root.findChild(QObject,'desktop');overlay=root.findChild(QObject,'appsOverlay')
    assert len(desktop.property('windows').toVariant())==1
    desktop.openApplication('apps');QTest.qWait(260)
    assert overlay.property('visible') and overlay.property('modal')
    assert not overlay.property('dim')
    assert overlay.property('width')==844 and overlay.property('height')==576
    assert len(desktop.property('windows').toVariant())==1,'Apps must not become a DesktopWindow'
    search=root.findChild(QObject,'appsSearch');assert search.property('activeFocus')
    library=root.findChild(QObject,'applicationsLauncher');grid=root.findChild(QObject,'appsGrid')
    assert grid.property('columns')==7 and grid.property('cellHeight')==102
    assert search.property('placeholderText')=='Applications'
    assert len(library.property('allApps').toVariant())==19
    def visual_items(item):
        yield item
        for child in item.childItems():yield from visual_items(child)
    def click(name):
        item=root.findChild(QObject,name)
        if item is None:
            item=next((i for base in (library,root.findChild(QObject,'spotlightView')) for i in visual_items(base) if i.objectName()==name),None)
        assert item is not None,name
        position=item.mapToScene(QPointF(item.width()/2,item.height()/2))
        QTest.mouseClick(root,Qt.LeftButton,Qt.NoModifier,QPoint(round(position.x()),round(position.y())))
        QTest.qWait(100)
    bridge.suite.setPreference('launcher.view','list');QTest.qWait(30)
    assert root.findChild(QObject,'appsList').property('visible') and not grid.property('visible')
    search.setProperty('text','s');QTest.qWait(20)
    assert grid.property('visible') and not root.findChild(QObject,'appsCategories').property('visible')
    assert grid.property('y')==57
    bridge.suite.setPreference('launcher.view','grid')
    search.setProperty('text','Calculator');QTest.keyClick(root,Qt.Key_Return);QTest.qWait(200)
    assert not overlay.property('visible')
    assert desktop.property('windows').toVariant()[-1].property('appKind')=='calculator'
    desktop.openApplication('apps');QTest.qWait(240);assert overlay.property('visible')
    click('appsToSpotlight')
    assert overlay.property('mode')=='spotlight' and overlay.property('height')==56
    spotlight_search=root.findChild(QObject,'spotlightSearch');assert spotlight_search.property('activeFocus')
    click('spotlightScope_files')
    assert overlay.property('mode')=='files'
    spotlight_search.setProperty('text','Launcher Search')
    for _ in range(100):
        QTest.qWait(20)
        if not bridge.spotlight.busy:break
    assert [row['name'] for row in bridge.spotlight.files]==['Launcher Search Test.txt']
    click('spotlightBack');click('spotlightScope_clipboard')
    assert overlay.property('mode')=='clipboard' and not bridge.spotlight.clipboardEnabled
    app.clipboard().setText('isolated clipboard fixture')
    assert bridge.spotlight.clipboardItems==[]
    click('spotlightAllowClipboard')
    assert bridge.spotlight.clipboardItems==['isolated clipboard fixture']
    bridge.spotlight.setClipboardEnabled(False)
    assert bridge.spotlight.clipboardItems==[]
    click('spotlightBack');click('spotlightScope_apps')
    assert overlay.property('mode')=='apps' and search.property('activeFocus')
    QTest.keyClick(root,Qt.Key_Escape);QTest.qWait(160);assert not overlay.property('visible')
    desktop.openApplication('apps');QTest.qWait(240)
    QTest.mouseClick(root,Qt.LeftButton,Qt.NoModifier,QPoint(12,60));QTest.qWait(160)
    assert not overlay.property('visible'),'Outside click dismisses launcher'
    assert not warnings,warnings
    root.flushApplications();bridge.shutdown();root.setVisible(False);engine.deleteLater();QCoreApplication.sendPostedEvents(None,QEvent.DeferredDelete)
print('Apps/Spotlight passed: 844x576 modal, seven columns, Grid/List and search layout, real file search, opt-in memory-only clipboard, scope/back transitions, Enter launch, Escape/outside dismissal.')
