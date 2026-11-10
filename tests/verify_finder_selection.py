"""Actual Qt pointer/key events against temporary Finder files; no host UI access."""
import os
os.environ['QT_QPA_PLATFORM'] = 'offscreen'
os.environ['QT_QUICK_CONTROLS_STYLE'] = 'Basic'
os.environ['QT_QUICK_BACKEND'] = 'software'
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
from PySide6.QtCore import QObject, QPoint, QPointF, QSettings, Qt, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine, QJSValue
from PySide6.QtQuick import QQuickItem
from PySide6.QtTest import QTest
import shiboken6

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from main import Bridge
from filesystem import Workspace

def value(item, name):
    result = item.property(name)
    return result.toVariant() if isinstance(result, QJSValue) else result

def visual(item):
    for child in item.childItems():
        yield child
        yield from visual(child)

app = QGuiApplication([])
app.setOrganizationName('MakOSFinderGestureVerification')
app.setApplicationName('TemporaryFixtures')
with TemporaryDirectory() as directory:
    QSettings.setDefaultFormat(QSettings.IniFormat)
    QSettings.setPath(QSettings.IniFormat, QSettings.UserScope, directory)
    workspace = Path(directory) / 'workspace'
    (workspace / 'Documents/Nested').mkdir(parents=True)
    for name in ['Alpha.txt', 'Beta.txt', 'Gamma.txt', 'Omega.txt']:
        (workspace / 'Documents/Nested' / name).write_text(name + ' real fixture')
    bridge = Bridge(Workspace(workspace))
    engine = QQmlApplicationEngine()
    warnings, errors = [], []
    engine.warnings.connect(lambda rows: warnings.extend(str(row) for row in rows))
    bridge.error.connect(errors.append)
    for key, data in {'Bridge': bridge, 'startFullscreen': False, 'comparisonMode': False,
                      'startSettings': False, 'startNativeWindows': False}.items():
        engine.rootContext().setContextProperty(key, data)
    engine.load(QUrl.fromLocalFile(str(ROOT / 'qml/Main.qml')))
    assert engine.rootObjects(), warnings
    root = engine.rootObjects()[0]
    root.resize(1360, 900)
    desktop = root.findChild(QObject, 'desktop')
    desktop.setProperty('reduceMotion', True)
    finder = value(desktop, 'windows')[0]
    finder.setX(40); finder.setY(60); finder.setWidth(1000); finder.setHeight(610)
    finder.setProperty('viewMode', 'columns')
    root.requestActivate()
    QTest.qWait(120)

    def click(path, modifier=Qt.NoModifier):
        row = next((item for item in visual(finder) if item.objectName() == 'finderColumnEntry:' + path), None)
        assert row and row.isVisible(), path
        position = row.mapToScene(QPointF(60, row.height() / 2))
        QTest.mouseClick(root, Qt.LeftButton, modifier, QPoint(round(position.x()), round(position.y())))
        QTest.qWait(40)

    click('Documents/Nested')
    click('Documents/Nested/Alpha.txt')
    click('Documents/Nested/Gamma.txt', Qt.ShiftModifier)
    expected = {'Documents/Nested/' + name for name in ['Alpha.txt', 'Beta.txt', 'Gamma.txt']}
    assert set(value(finder, 'selected')) == expected, value(finder, 'selected')
    click('Documents/Nested/Beta.txt', Qt.ControlModifier)
    expected.remove('Documents/Nested/Beta.txt')
    assert set(value(finder, 'selected')) == expected
    bridge.newFolder('Documents/Nested', 'New Folder')
    QTest.qWait(80)
    assert len(value(finder, 'columns')) == 2
    assert set(value(finder, 'selected')) == expected, value(finder, 'selected')
    assert any(item.objectName() == 'finderColumnEntry:Documents/Nested/New Folder' for item in visual(finder))
    search = finder.findChild(QQuickItem, 'finderSearchInput')
    search.parentItem().setVisible(True)
    search.forceActiveFocus()
    for letter in 'omega':
        QTest.keyClick(root, Qt.Key(ord(letter.upper())))
    QTest.qWait(300)
    browser = value(finder, 'browser')
    assert [row['path'] for row in browser.files] == ['Documents/Nested/Omega.txt'], browser.files
    assert not warnings, warnings
    assert not errors, errors
    root.close()
    shiboken6.delete(engine)
    app.processEvents()
    print('PASS: column Shift/Ctrl selection, refresh preservation, recursive search via Qt input')
