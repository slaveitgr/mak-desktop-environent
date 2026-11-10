"""Isolated Apps/App Store/Games QML checks; no host apps or desktop actions."""
import os
import sys
from pathlib import Path

os.environ['QT_QPA_PLATFORM'] = 'offscreen'
os.environ['QT_QUICK_CONTROLS_STYLE'] = 'Basic'
from PySide6.QtCore import QObject, Property, QUrl, Qt, QPoint, QPointF
from PySide6.QtGui import QGuiApplication, QFont
from PySide6.QtQuick import QQuickItem, QQuickWindow
from PySide6.QtQml import QQmlApplicationEngine, QJSValue
from PySide6.QtTest import QTest
import shiboken6

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from applications import APPLICATIONS

class Bridge(QObject):
    @Property('QVariantList', constant=True)
    def applicationCatalog(self):
        return [dict(id=a['id'], name=a['name'], image=a['id'] + '.png') for a in APPLICATIONS]

    @Property(str, constant=True)
    def assetRoot(self):
        return QUrl.fromLocalFile(str(ROOT / 'assets')).toString() + '/'

app = QGuiApplication([])
app.setFont(QFont('.AppleSystemUIFont', 13))
bridge = Bridge()
engine = QQmlApplicationEngine()
warnings = []
engine.warnings.connect(lambda items: warnings.extend(str(item) for item in items))
engine.rootContext().setContextProperty('Bridge', bridge)
engine.loadData(b'''import QtQuick
import QtQuick.Controls
ApplicationWindow {
    width: 1020; height: 628; visible: true
    QtObject {
        id: desk; objectName: "desktop"
        property bool reduceMotion: true
        property bool alwaysShowScrollbars: true
        property var actions: []
        function openApplication(id) { actions = actions.concat("open:" + id); }
        function closeWindow(target) {
            if (target !== holder) throw new Error("Incorrect close target");
            actions = actions.concat("close:" + target.appKind);
        }
    }
    Item {
        id: holder; objectName: "host"; anchors.fill: parent
        property string appKind: "apps"
        property bool dark: true
        property color ink: dark ? "white" : "#292d34"
        property color muted: dark ? "#a2acb8" : "#667080"
        property var desktop: desk
        AppsLibrary { objectName: "library"; anchors.fill: parent; host: holder }
    }
}''', QUrl.fromLocalFile(str(ROOT / 'qml/AppsLibraryVerification.qml')))
assert engine.rootObjects(), warnings
window = engine.rootObjects()[0]
page = window.findChild(QObject, 'library')
host = window.findChild(QObject, 'host')
desk = window.findChild(QObject, 'desktop')
search = window.findChild(QObject, 'appsSearch')
grid = window.findChild(QObject, 'appsGrid')
sort = window.findChild(QObject, 'appsSort')
window.requestActivate()
QTest.qWait(40)

def value(obj, name):
    result = obj.property(name)
    return result.toVariant() if isinstance(result, QJSValue) else result

def ids():
    return [item['id'] for item in value(page, 'filteredApps')]

def key(code):
    QTest.keyClick(window, code)
    QTest.qWait(1)

def children(item):
    for child in item.childItems():
        yield child
        yield from children(child)

def click(item):
    point = item.mapToScene(QPointF(item.width() / 2, item.height() / 2))
    QTest.mouseClick(window, Qt.LeftButton, Qt.NoModifier, QPoint(round(point.x()), round(point.y())))
    QTest.qWait(5)

# The launcher contains every built-in application except itself, plus Finder and Settings.
expected = {a['id'] for a in APPLICATIONS if a['id'] != 'apps'} | {'finder', 'settings'}
assert set(ids()) == expected
assert len(ids()) == len(expected) == 20
assert ids()[0] == 'appstore'
assert search.property('activeFocus')

# Actual category button and sorting button interactions, not just model assignment.
productivity = next(item for item in children(page) if item.inherits('QQuickAbstractButton') and item.property('text') == 'Productivity' and item.isVisible())
click(productivity)
assert set(ids()) == {'calendar', 'contacts', 'notes', 'reminders'}, ids()
page.chooseSection('All Apps')
click(sort)
assert not page.property('alphabetical')
assert ids()[0] == 'facetime', ids()
click(sort)
assert page.property('alphabetical') and ids()[0] == 'appstore'

for category, expected_ids in [
    ('Communication', {'safari', 'messages', 'mail', 'facetime', 'phone'}),
    ('Creativity', {'photos', 'music', 'photobooth'}),
    ('Utilities', {'finder', 'settings', 'calculator', 'maps', 'terminal', 'appstore'}),
    ('Games', {'chess', 'games'}),
]:
    page.chooseSection(category)
    assert set(ids()) == expected_ids, (category, ids())
page.chooseSection('All Apps')
page.setProperty('searchText', ' photo ')
assert set(ids()) == {'photobooth', 'photos'}
page.setProperty('searchText', 'no-such-application')
assert not ids() and page.property('selectedIndex') == -1
page.activateSelection()
assert value(desk, 'actions') == []

# Search Escape clears and focuses search; arrows enter and navigate the grid.
page.command('find')
key(Qt.Key_Escape)
assert page.property('searchText') == '' and search.property('activeFocus')
key(Qt.Key_Down)
assert grid.property('activeFocus') and page.property('selectedIndex') == 0
key(Qt.Key_Right)
assert page.property('selectedIndex') == 1
columns = grid.property('columns')
key(Qt.Key_Down)
assert page.property('selectedIndex') == columns + 1
key(Qt.Key_Left)
assert page.property('selectedIndex') == columns
key(Qt.Key_Up)
assert page.property('selectedIndex') == 0
key(Qt.Key_Up)
assert search.property('activeFocus')
key(Qt.Key_Down)
key(Qt.Key_End)
assert page.property('selectedIndex') == len(ids()) - 1
key(Qt.Key_Home)
assert page.property('selectedIndex') == 0
key(Qt.Key_Right)
chosen = page.property('selectedApp')
key(Qt.Key_Return)
assert value(desk, 'actions') == ['open:' + chosen, 'close:apps']

# Typing while navigating starts a new search. Enter launches and closes only Apps.
key(Qt.Key_P)
assert page.property('searchText') == 'p' and search.property('activeFocus')
page.setProperty('searchText', 'Calculator')
key(Qt.Key_Return)
assert value(desk, 'actions')[-2:] == ['open:calculator', 'close:apps']
key(Qt.Key_Escape)

# At supported widths the grid stays within its content region, with full final-row access.
for kind in ('apps', 'appstore', 'games'):
    host.setProperty('appKind', kind)
    page.chooseSection('All Apps')
    page.setProperty('searchText', '')
    for dark in (False, True):
        host.setProperty('dark', dark)
        for width, height in ((1020, 628), (760, 628), (640, 408)):
            window.resize(width, height)
            QTest.qWait(10)
            assert grid.x() >= (0 if kind == 'apps' else 222)
            assert grid.x() + grid.width() <= width
            assert 0 < grid.property('cellWidth') <= grid.width()
            assert grid.y() + grid.height() < height
            assert abs(grid.property('cellWidth') * grid.property('columns') - grid.width()) < .01
            page.moveSelection(1000)
            QTest.qWait(10)
            bottom = ((len(ids()) - 1) // grid.property('columns') + 1) * grid.property('cellHeight')
            assert bottom + grid.property('originY') - grid.property('contentY') <= grid.height() + 1, (kind, width, bottom, grid.property('contentY'), grid.height())
            assert grid.property('contentX') == 0
    before = list(value(desk, 'actions'))
    page.launch('chess')
    delta = value(desk, 'actions')[len(before):]
    assert delta == (['open:chess', 'close:apps'] if kind == 'apps' else ['open:chess'])
    if kind == 'games':
        assert ids() == ['chess']

assert not warnings, '\n'.join(warnings)
window.close()
shiboken6.delete(engine)
print('Apps library passed: all 20 apps, categories, actual sort/filter buttons, search, arrows/Enter/Escape, launcher close ordering, persistent App Store/Games, 640/760/1020 layouts, light/dark, final-row scrolling; no QML warnings.')
