"""About window layout with controlled hardware fixtures, no OS mutations."""
import os
os.environ['QT_QPA_PLATFORM'] = 'offscreen'
os.environ['QT_QUICK_CONTROLS_STYLE'] = 'Basic'
os.environ['QT_QUICK_BACKEND'] = 'software'
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
from PySide6.QtCore import QObject, Property, QSettings, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine, QJSValue
from PySide6.QtQuick import QQuickItem
from PySide6.QtTest import QTest
import shiboken6

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from main import Bridge
from filesystem import Workspace

FIXTURE = {'name':'HP EliteBook 840 G8 Notebook PC', 'processor':'Intel Core i7-1165G7 @ 2.80GHz',
           'graphics':'Intel Iris Xe Graphics\nNVIDIA GeForce MX150', 'memory':'15.5 GiB',
           'version':'0.1 Development', 'platform':'makOS Development (Cutefish)',
           'user':'Fixture User', 'isPreview':False}


class FixtureBridge(Bridge):
    @Property('QVariantMap', constant=True)
    def systemInfo(self):
        return FIXTURE


def visual(item):
    for child in item.childItems():
        yield child
        yield from visual(child)


app = QGuiApplication([])
app.setOrganizationName('MakOSAboutVerification')
app.setApplicationName('TemporaryFixtures')
with TemporaryDirectory() as directory:
    QSettings.setDefaultFormat(QSettings.IniFormat)
    QSettings.setPath(QSettings.IniFormat, QSettings.UserScope, directory)
    bridge = FixtureBridge(Workspace(Path(directory) / 'home'))
    engine = QQmlApplicationEngine()
    errors = []
    engine.warnings.connect(lambda rows: errors.extend(str(row) for row in rows))
    for key, value in {'Bridge':bridge, 'startFullscreen':False, 'comparisonMode':False,
                       'startSettings':False, 'startNativeWindows':False}.items():
        engine.rootContext().setContextProperty(key, value)
    engine.load(QUrl.fromLocalFile(str(ROOT / 'qml/Main.qml')))
    assert engine.rootObjects(), errors
    root = engine.rootObjects()[0]
    root.resize(1200, 900)
    desktop = root.findChild(QObject, 'desktop')
    desktop.setProperty('reduceMotion', True)
    desktop.openAbout()
    QTest.qWait(160)
    about = desktop.property('activeWindow')
    if isinstance(about, QJSValue):
        about = about.toQObject()
    assert about.property('windowTitle') == 'About This Mak'
    title = about.findChild(QObject, 'aboutComputerModel')
    assert title.property('text') == FIXTURE['name']
    rows = [item for item in visual(about) if item.objectName().startswith('aboutRow:')]
    assert [row.objectName() for row in rows] == ['aboutRow:Processor', 'aboutRow:Graphics', 'aboutRow:Memory', 'aboutRow:makOS']
    assert [row.y() for row in rows] == sorted(row.y() for row in rows)
    for index, (row, key) in enumerate(zip(rows, ('processor', 'graphics', 'memory', 'version'))):
        labels = [child.property('text') for child in row.childItems() if child.property('text') is not None]
        assert labels[-1] == FIXTURE[key], labels
        if index:
            assert row.y() >= rows[index-1].y() + rows[index-1].height()
    assert not about.findChild(QObject, 'aboutPreviewHost').property('visible')
    preview = {**FIXTURE, 'name':'MacBookPro16,1', 'version':'Development preview',
               'platform':'macOS 26.7.2', 'isPreview':True}
    about.setProperty('information', preview)
    QTest.qWait(40)
    assert title.property('text') == 'MacBookPro16,1'
    footer = about.findChild(QObject, 'aboutPreviewHost')
    assert footer.property('visible') and footer.property('text') == 'Preview running on macOS 26.7.2'
    desktop.openSettings('About')
    QTest.qWait(100)
    settings = desktop.property('activeWindow')
    if isinstance(settings, QJSValue):
        settings = settings.toQObject()
    assert settings.findChild(QObject, 'settingsComputerModel').property('text') == FIXTURE['name']
    settings_rows = [item for item in visual(settings) if item.objectName().startswith('settingsAboutRow:')]
    assert [row.objectName() for row in settings_rows] == ['settingsAboutRow:Processor', 'settingsAboutRow:Graphics', 'settingsAboutRow:Memory', 'settingsAboutRow:makOS']
    for row, key in zip(settings_rows, ('processor', 'graphics', 'memory', 'version')):
        labels = [child.property('text') for child in row.childItems() if child.property('text') is not None]
        assert labels[-1] == FIXTURE[key], labels
    assert not errors, '\n'.join(errors)
    root.close()
    shiboken6.delete(engine)
    bridge.shutdown()
    app.processEvents()
print('PASS About: actual model, CPU/GPU/memory/makOS order, wrapped GPUs and explicit preview host.')
