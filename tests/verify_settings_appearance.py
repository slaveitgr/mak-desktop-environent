"""Controlled offscreen Settings checks; no native UI, accounts or OS preferences."""
import os
os.environ['QT_QPA_PLATFORM'] = 'offscreen'
os.environ['QT_QUICK_CONTROLS_STYLE'] = 'Basic'
import json
from pathlib import Path
from PySide6.QtCore import QObject, Property, Signal, Slot, QUrl, Qt, QPoint, QPointF
from PySide6.QtGui import QGuiApplication, QFont
from PySide6.QtQuick import QQuickItem, QQuickWindow
from PySide6.QtQml import QQmlApplicationEngine, QJSValue
from PySide6.QtTest import QTest
import shiboken6

ROOT = Path(__file__).resolve().parents[1]
class Store(QObject):
    changed = Signal()
    def __init__(self):
        super().__init__(); self.prefs = {}; self._revision = 0
    @Property(int, notify=changed)
    def revision(self): return self._revision
    @Slot(str, str, result=str)
    def preference(self, key, default): return self.prefs.get(key, default)
    @Slot(str, str)
    def setPreference(self, key, value):
        if self.prefs.get(key) == value: return
        self.prefs[key] = value; self._revision += 1; self.changed.emit()
    @Slot(result='QVariantMap')
    def storage(self): return dict(total=1000000000, free=800000000, photos=0, songs=0, documents=0, path='/isolated-settings-test')
class Bridge(QObject):
    def __init__(self): super().__init__(); self.store = Store()
    @Property(QObject, constant=True)
    def suite(self): return self.store
    @Property(str, constant=True)
    def assetRoot(self): return QUrl.fromLocalFile(str(ROOT / 'assets')).toString() + '/'
    @Property('QVariantList', constant=True)
    def settingsCategories(self): return json.loads((ROOT / 'settings_catalog.json').read_text())
    @Property(str, constant=True)
    def rootPath(self): return '/isolated-settings-test'
    @Property(bool, constant=True)
    def isMac(self): return True
    @Property(bool, constant=True)
    def hostSettingsAvailable(self): return False

app = QGuiApplication([]); app.setFont(QFont('.AppleSystemUIFont', 13))
bridge = Bridge(); engine = QQmlApplicationEngine(); warnings = []
engine.warnings.connect(lambda messages: warnings.extend(str(x) for x in messages))
engine.rootContext().setContextProperty('Bridge', bridge)
engine.loadData(b'''import QtQuick
import QtQuick.Controls
ApplicationWindow {
    width: 1100; height: 1040; visible: true
    Item {
        id: desk; objectName: "desktop"; anchors.fill: parent
        property bool dark: true
        property bool shellActive: true
        property bool reduceMotion: true
        property bool reduceTransparency: false
        property bool glassTinted: false
        property bool wallpaperTint: true
        property bool alwaysShowScrollbars: false
        property bool dockMagnification: true
        property bool dockAutoHide: false
        property bool dockIndicators: true
        property bool dockLaunchAnimation: true
        property bool showDesktopItems: true
        property bool showClock: true
        property bool showSearchIcon: true
        property bool wallpaperIsDark: dark
        property bool menuBarBackground: false
        property string menuBarHideMode: "In Full Screen Only"
        property string wallpaperMode: "appearance"
        property string appearanceMode: "manual"
        property int motionTick: 0
        property int highestZ: 1
        property var windows: [settings]
        readonly property var controls: controlState
        property var activeWindow: settings
        property var presentation: presentationState
        property var baseItem: scene
        property date now: new Date()
        property int revision: Bridge.suite.revision
        property color accentColor: { let r=revision; return Bridge.suite.preference("appearance.accent","multicolor")==="pink" ? "#ec5c9c" : "#1683fa"; }
        property color highlightColor: { let r=revision; return Bridge.suite.preference("appearance.highlight","automatic")==="purple" ? "#c9a1e4" : "#95c2f0"; }
        property string sidebarIconSize: { let r=revision; return Bridge.suite.preference("appearance.sidebarIconSize","medium"); }
        function setAppearance(mode) { appearanceMode = mode === "auto" ? "auto" : "manual"; dark = mode !== "light"; }
        function focusWindow(win) { activeWindow = win; }
        function closeWindow(win) {}
        function minimizeWindow(win) {}
        function destroyWindow(win) {}
        function openApplication(id) {}
        function openControlGallery() {}
        function showInfo(title, detail) {}
        function openFolder(path) {}
        function dispatch(command) {}
        QtObject { id: presentationState; property bool active: false; property bool chromeVisible: true; property var window: null; function exit(){} function toggle(win){} }
        ControlState { id: controlState; desktop: desk }
        Rectangle { id: scene; anchors.fill: parent; color: "#102c48" }
        SettingsWindow { id: settings; objectName: "settings"; x: 20; y: 40; desktop: desk }
    }
}''', QUrl.fromLocalFile(str(ROOT / 'qml/SettingsAppearanceVerification.qml')))
assert engine.rootObjects(), warnings
window = engine.rootObjects()[0]
settings = window.findChild(QObject, 'settings'); desk = window.findChild(QObject, 'desktop')
scroller = window.findChild(QObject, 'settingsContent'); search = window.findChild(QObject, 'settingsSearch')
window.requestActivate(); QTest.qWait(80)

def children(item):
    for child in item.childItems():
        yield child
        yield from children(child)

def buttons():
    return [x for x in children(settings) if x.inherits('QQuickAbstractButton')]

def choice(label, width):
    return next(x for x in buttons() if x.property('modelData') == label and abs(x.width() - width) < 0.1)

def click(item):
    point = item.mapToScene(QPointF(item.width() / 2, item.height() / 2))
    QTest.mouseClick(window, Qt.LeftButton, Qt.NoModifier, QPoint(round(point.x()), round(point.y())))
    QTest.qWait(10)

def value(obj, name):
    item = obj.property(name)
    return item.toVariant() if isinstance(item, QJSValue) else item

appearance = window.findChild(QObject, 'appearanceSettings')
assert appearance, warnings
assert settings.width() == 723 and settings.height() == 861
assert settings.property('sidebarWidth') == 223
assert scroller.x() == 243 and scroller.y() == 52 and scroller.width() == 460
assert search.width() == 195 and search.height() == 28
material = window.findChild(QObject, 'appearanceMaterialCard')
theme = window.findChild(QObject, 'appearanceThemeHeading')
windows = window.findChild(QObject, 'appearanceWindowsHeading')
assert material.height() == 173
assert theme.y() + 39 + scroller.y() == 264
assert windows.y() + 39 + scroller.y() == 559
assert appearance.height() == 771, appearance.height()

click(choice('Light', 68)); assert not desk.property('dark')
click(choice('Dark', 68)); assert desk.property('dark')
click(choice('Auto', 68)); assert desk.property('appearanceMode') == 'auto'
click(choice('Tinted', 68)); assert desk.property('glassTinted')
desk.setProperty('reduceTransparency', True); QTest.qWait(5)
assert not choice('Clear', 68).isEnabled()
click(choice('Clear', 68)); assert desk.property('glassTinted')
desk.setProperty('reduceTransparency', False); click(choice('Clear', 68)); assert not desk.property('glassTinted')
click(choice('Pink', 23)); assert bridge.store.prefs['appearance.accent'] == 'pink'
assert appearance.property('accent').name() == '#ec5c9c'
for name in ('Dark', 'Clear', 'Tinted'):
    assert not choice(name, 48).isEnabled()

# Activate the real ComboBox handlers; they persist preferences and update bound state.
highlight = window.findChild(QObject, 'appearanceHighlight')
highlight.setProperty('currentIndex', 2); highlight.activated.emit(2); QTest.qWait(5)
assert bridge.store.prefs['appearance.highlight'] == 'purple'
assert search.property('selectionColor').name() == '#c9a1e4'
sidebar_size = window.findChild(QObject, 'appearanceSidebarSize')
sidebar_size.setProperty('currentIndex', 2); sidebar_size.activated.emit(2); QTest.qWait(5)
assert bridge.store.prefs['appearance.sidebarIconSize'] == 'large'
assert desk.property('sidebarIconSize') == 'large'
for text, expected in [('Always', True), ('When scrolling', False)]:
    radio = next(x for x in buttons() if x.property('text') == text)
    click(radio); assert desk.property('alwaysShowScrollbars') == expected
for text in ('Automatically based on mouse or trackpad', 'Jump to the next page', 'Jump to the spot that’s clicked'):
    assert not next(x for x in buttons() if x.property('text') == text).isEnabled()

# All original routes and search remain available after splitting Appearance out.
categories = [item['name'] for item in bridge.settingsCategories]
for name in categories + value(settings, 'generalPages'):
    settings.navigate(name); QTest.qWait(2)
    assert settings.property('page') == name
settings.navigate('Appearance'); QTest.qWait(10)
settings.navigate('General'); settings.travel(-1); assert settings.property('page') == 'Appearance'
search.setProperty('text', 'apple'); QTest.qWait(5)
assert any(p['name'] == 'Apple Account' for p in value(settings, 'navigationPages'))
search.setProperty('text', 'time'); QTest.qWait(5)
assert any(p['name'] == 'Date & Time' for p in value(settings, 'navigationPages'))
settings.editSearch('selectAll'); assert search.property('activeFocus')
search.setProperty('text', '')

for dark in (False, True):
    desk.setProperty('dark', dark)
    for width, height in ((723, 861), (640, 680), (600, 520)):
        settings.setWidth(width); settings.setHeight(height); QTest.qWait(10)
        assert scroller.x() + scroller.width() == width - 20
        appearance = window.findChild(QObject, 'appearanceSettings')
        assert appearance.width() == scroller.width()
        assert scroller.property('contentHeight') >= appearance.height()
        for image in children(settings):
            if image.inherits('QQuickImage') and 'settings-reference/' in str(image.property('source')):
                assert image.implicitWidth() > 0 and image.implicitHeight() > 0, image.property('source')
assert not warnings, '\n'.join(warnings)
window.close(); shiboken6.delete(engine)
print('Settings Appearance passed: native geometry/assets, light/dark/auto, glass/accessibility, persisted theme/highlight/sidebar size, scrollbar toggles, disabled unsupported styles, 32 categories + General, search/history, responsive sizing; zero QML warnings.')
