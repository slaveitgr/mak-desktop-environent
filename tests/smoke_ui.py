"""Isolated headless QML integration check; no interaction with the user's UI."""
import os
os.environ['QT_QPA_PLATFORM'] = 'offscreen'
os.environ['QT_QUICK_CONTROLS_STYLE'] = 'Basic'
from pathlib import Path
from tempfile import TemporaryDirectory
import sys
from PySide6.QtCore import QObject, QSettings, QUrl
from PySide6.QtGui import QGuiApplication, QFont
import shiboken6
from PySide6.QtQml import QQmlApplicationEngine, QQmlEngine, QQmlExpression
from PySide6.QtQuick import QQuickItem, QQuickWindow
from PySide6.QtTest import QTest
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from main import Bridge
from filesystem import Workspace

app = QGuiApplication([])
app.setFont(QFont('.AppleSystemUIFont', 13))
app.setOrganizationName('TahoePrototypeUIVerification')
app.setApplicationName('IsolatedUI')
with TemporaryDirectory() as folder:
    QSettings.setDefaultFormat(QSettings.IniFormat)
    QSettings.setPath(QSettings.IniFormat, QSettings.UserScope, folder)
    workspace = Path(folder) / 'workspace'
    (workspace / 'Documents').mkdir(parents=True)
    (workspace / 'Documents/example.txt').write_text('Example')
    bridge = Bridge(Workspace(workspace), terminal_auto_start=False)
    engine = QQmlApplicationEngine()
    warnings = []
    engine.warnings.connect(lambda errors: warnings.extend(str(e) for e in errors))
    for key, value in {'Bridge':bridge, 'startFullscreen':False, 'comparisonMode':False, 'startSettings':True, 'startNativeWindows':'--native-windows' in sys.argv}.items():
        engine.rootContext().setContextProperty(key, value)
    engine.load(QUrl.fromLocalFile(str(ROOT / 'qml/Main.qml')))
    assert engine.rootObjects(), warnings
    root = engine.rootObjects()[0]
    desktop = root.findChild(QObject, 'desktop')
    windows = desktop.property('windows').toVariant()
    assert len(windows) == 2
    finder, settings = windows
    assert settings.property('appKind') == 'settings'
    def qml_boolean(expression):
        evaluator = QQmlExpression(QQmlEngine.contextForObject(desktop), desktop, expression)
        value, undefined = evaluator.evaluate()
        assert not evaluator.hasError(), evaluator.error().toString()
        return not undefined and bool(value)

    # Export the requested window's menu, even while another app is active.
    assert qml_boolean("JSON.parse(nativeMenuRows(windows[0]))[0].label === 'Finder'")
    assert qml_boolean("JSON.parse(nativeMenuRows(windows[1]))[0].label === 'System Settings'")
    assert qml_boolean("JSON.parse(nativeMenuRows(windows[0])).find(m => m.label === 'File').submenu.some(r => r.command === 'newwindow' && r.enabled && r.icon.length > 0)")
    assert qml_boolean("JSON.parse(nativeMenuRows(windows[1])).find(m => m.label === 'View').submenu.some(r => r.command === 'settings:Appearance' && r.checked)")

    if '--native-windows' in sys.argv:
        assert qml_boolean("windows[0].nativeWindow && windows[1].nativeWindow && windows[0].nativeWindow !== windows[1].nativeWindow")
        assert qml_boolean("windows[0].nativeWindow.objectName === 'makOSNativeWindow' && windows[0].x === 0 && windows[0].y === 0")
        desktop.openContext(100, 100, finder)
        QTest.qWait(30)
        assert qml_boolean("contextMenu.parent === windows[0].nativeWindow.contentItem")
        root.findChild(QObject, 'contextMenu').close()
        desktop.openSettings('Appearance')

    for page in [row['name'] for row in bridge.settingsCategories] + ['About', 'Storage', 'Date & Time', 'Sharing']:
        settings.navigate(page)
        QTest.qWait(20)
    desktop.setAppearance('dark')
    assert desktop.property('dark')
    desktop.setAppearance('light')
    assert not desktop.property('dark')
    desktop.setProperty('reduceMotion', True)
    presentation = desktop.findChild(QObject, 'fullscreenState')
    presentation.enter(settings)
    assert settings.property('isFullscreen')
    desktop.activateFinder()
    if '--native-windows' not in sys.argv:
        assert not settings.property('isFullscreen')
    else:
        presentation.exit()
    assert desktop.property('activeWindow') == finder
    desktop.openSettings('Appearance')
    assert len(desktop.property('windows').toVariant()) == 2
    desktop.openFolder('Documents')
    assert desktop.property('activeWindow') == finder
    desktop.openSettings('Desktop & Dock')
    desktop.minimizeWindow(settings)
    assert settings.property('minimized')
    desktop.openSettings('')
    assert not settings.property('minimized')
    desktop.closeWindow(settings)
    for _ in range(25):
        if len(desktop.property('windows').toVariant()) == 1:
            break
        QTest.qWait(20)
    assert len(desktop.property('windows').toVariant()) == 1
    for entry in bridge.applicationCatalog:
        desktop.openApplication(entry['id'])
        QTest.qWait(60)
        if entry['id'] == 'apps':
            assert desktop.property('appsOverlayVisible')
            assert len(desktop.property('windows').toVariant()) == 1
            desktop.toggleApps()
            QTest.qWait(150)
            assert not desktop.property('appsOverlayVisible')
            continue
        windows = desktop.property('windows').toVariant()
        target = windows[-1]
        assert target.property('appKind') == entry['id'], entry
        assert target.property('pageItem') is not None, entry
        assert qml_boolean("JSON.parse(nativeMenuRows(windows[windows.length-1]))[0].label === windows[windows.length-1].windowTitle"), entry
        if entry['id']=='appstore': assert qml_boolean("JSON.parse(nativeMenuRows(windows[windows.length-1])).some(menu=>menu.label==='Store')")
        if entry['id']=='safari': assert qml_boolean("JSON.parse(nativeMenuRows(windows[windows.length-1])).some(menu=>menu.label==='Bookmarks')")
        if '--native-windows' in sys.argv:
            assert qml_boolean("windows[windows.length-1].nativeWindow !== windows[0].nativeWindow"), entry
            assert qml_boolean("windows[windows.length-1].nativeWindow.title === windows[windows.length-1].windowTitle"), entry
            if entry['id'] == 'calculator': assert qml_boolean("windows[windows.length-1].nativeWindow.width < 600")

        desktop.openApplication(entry['id'])
        assert len(desktop.property('windows').toVariant()) == len(windows)
        desktop.minimizeWindow(target)
        desktop.openApplication(entry['id'])
        assert not target.property('minimized')
        for menu_name in (target.property('windowTitle'), 'File', 'Edit', 'View', 'Window', 'Help', 'apple'):
            desktop.menuRows(menu_name)
        desktop.closeWindow(target)
        for _ in range(25):
            if len(desktop.property('windows').toVariant()) == 1: break
            QTest.qWait(20)
        assert len(desktop.property('windows').toVariant()) == 1, entry
    assert not warnings, '\n'.join(warnings)
    root.close()
    shiboken6.delete(engine)
print('QML integration passed: 18 suite windows (load, menus, singleton, minimize/restore and close), Apps overlay, 32 settings categories and General routes, appearance, app routing, fullscreen, minimize/restore, close.')
