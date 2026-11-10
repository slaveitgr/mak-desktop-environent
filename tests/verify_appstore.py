"""Actual pointer/keyboard App Store browsing using local catalog and tempdata."""
import os
os.environ['QT_QPA_PLATFORM']='offscreen'
os.environ['QT_QUICK_CONTROLS_STYLE']='Basic'
os.environ['QT_QUICK_BACKEND']='software'
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
from PySide6.QtCore import QObject, QPoint, QPointF, QSettings, Qt, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine, QJSValue
from PySide6.QtQuick import QQuickItem
from PySide6.QtTest import QTest
import shiboken6
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from main import Bridge
from filesystem import Workspace

def value(item,name):
    result=item.property(name)
    return result.toVariant() if isinstance(result,QJSValue) else result

def visual(item):
    for child in item.childItems():
        yield child
        yield from visual(child)

app=QGuiApplication([])
app.setOrganizationName('MakOSAppStoreVerification')
app.setApplicationName('TemporaryFixtures')
with TemporaryDirectory() as directory:
    QSettings.setDefaultFormat(QSettings.IniFormat)
    QSettings.setPath(QSettings.IniFormat,QSettings.UserScope,directory)
    bridge=Bridge(Workspace(Path(directory)/'home'))
    engine=QQmlApplicationEngine(); errors=[]
    engine.warnings.connect(lambda rows:errors.extend(str(row) for row in rows))
    for key,data in {'Bridge':bridge,'startFullscreen':False,'comparisonMode':False,'startSettings':False,'startNativeWindows':False}.items():engine.rootContext().setContextProperty(key,data)
    engine.load(QUrl.fromLocalFile(str(ROOT/'qml/Main.qml')))
    assert engine.rootObjects(),errors
    root=engine.rootObjects()[0];root.resize(1400,1000)
    desktop=root.findChild(QObject,'desktop');desktop.setProperty('reduceMotion',True)
    desktop.openApplication('appstore');QTest.qWait(180)
    window=value(desktop,'activeWindow');window.setX(30);window.setY(50);window.setWidth(1100);window.setHeight(800)
    page=value(window,'pageItem');assert page and page.objectName()=='appStoreApp',errors
    root.requestActivate();QTest.qWait(60)
    def click(name, offset=None):
        target=next((x for x in visual(page) if x.objectName()==name),None)
        assert target and target.isVisible(),(name,errors)
        point=target.mapToScene(offset or target.boundingRect().center())
        QTest.mouseClick(root,Qt.LeftButton,Qt.NoModifier,QPoint(round(point.x()),round(point.y())))
        QTest.qWait(50)
    click('storeSection:Work')
    assert page.property('section')=='Work'
    assert {row['id'] for row in value(page,'filteredApps')} >= {'notes','calendar','reminders'}
    if os.environ.get('MAKOS_APPSTORE_SCREENSHOT'):
        assert root.grabWindow().save(os.environ['MAKOS_APPSTORE_SCREENSHOT'])
    search=page.findChild(QQuickItem,'storeSearch');search.forceActiveFocus()
    for letter in 'notes':QTest.keyClick(root,Qt.Key(ord(letter.upper())))
    QTest.qWait(50)
    assert [x['id'] for x in value(page,'filteredApps')]==['notes']
    QTest.keyClick(root,Qt.Key_Return);QTest.qWait(50)
    assert page.property('selectedId')=='notes'
    assert page.findChild(QObject,'storeDetailTitle').property('text')=='Notes'
    click('storeBackButton')
    assert page.property('selectedId')=='' and page.property('searchText')=='notes'
    click('storeSection:Categories')
    assert page.property('categoryPage')
    click('storeCategory:Productivity')
    assert page.property('categoryFilter')=='Productivity'
    assert all(x['category']=='Productivity' for x in value(page,'filteredApps'))
    click('storeAppRow:notes',QPointF(100,40))
    assert page.property('selectedId')=='notes'
    click('storeDetailOpen')
    assert value(desktop,'activeWindow').property('appKind')=='notes'
    desktop.focusWindow(window,True);page.command('back');QTest.qWait(40)
    assert page.property('categoryFilter')=='Productivity' and page.property('selectedId')==''
    page.command('section:Develop');QTest.qWait(40)
    assert [x['id'] for x in value(page,'filteredApps')]==['terminal']
    menu=desktop.menuRows('Store').toVariant()
    assert any(r.get('command')=='app:section:Work' for r in menu)
    assert any(r.get('command')=='app:back' and r['enabled'] for r in menu)
    page.command('section:Updates');QTest.qWait(40)
    assert page.property('specialPage') and not page.property('selectedId')
    assert not errors,'\n'.join(errors)
    root.close();shiboken6.delete(engine);bridge.shutdown();app.processEvents()
print('PASS App Store: search, sections/categories, detail/back restoration, Open and Store menu commands.')
