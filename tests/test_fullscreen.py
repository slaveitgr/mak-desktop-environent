from pathlib import Path
import unittest
from PySide6.QtCore import QCoreApplication, QUrl
from PySide6.QtQml import QQmlEngine, QQmlComponent
from PySide6.QtTest import QTest

class FullscreenTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QCoreApplication.instance() or QCoreApplication([])
    def setUp(self):
        self.engine = QQmlEngine()
        self.component = QQmlComponent(self.engine, QUrl.fromLocalFile(str(Path(__file__).resolve().parents[1] / 'qml/FullscreenState.qml')))
        self.state = self.component.create()
        self.assertIsNotNone(self.state, str(self.component.errors()))
        self.mock = QQmlComponent(self.engine)
        self.mock.setData(b'''import QtQml
QtObject {
 property real x: 123; property real y: 74; property real width: 940; property real height: 570
 property bool isFullscreen: false
 property rect fullscreenRestoreGeometry
 property size fullscreenViewport
 function animateGeometry(px, py, w, h, duration) { x=px; y=py; width=w; height=h; }
}''', QUrl())
        self.window = self.mock.create()
        self.other = self.mock.create()
    def tearDown(self):
        for obj in (self.state, self.window, self.other, self.component, self.mock, self.engine):
            obj.deleteLater()
        self.app.processEvents()
    def rect(self):
        return tuple(self.window.property(p) for p in ('x','y','width','height'))
    def test_enter_restore_exact_geometry(self):
        original = self.rect()
        self.state.enter(self.window)
        self.assertTrue(self.window.property('isFullscreen'))
        self.assertEqual(self.rect(), (0,0,1360,850))
        self.assertFalse(self.state.property('chromeVisible'))
        self.state.exit()
        self.assertEqual(self.rect(), original)
        self.assertFalse(self.window.property('isFullscreen'))
    def test_external_state_controls_chrome_without_mutating_client_geometry(self):
        original = self.rect()
        self.state.setProperty('externalActive', True)
        self.assertTrue(self.state.property('active'))
        self.assertIsNone(self.state.property('window'))
        self.assertFalse(self.state.property('chromeVisible'))
        self.state.setProperty('pointerAtTop', True)
        self.assertTrue(self.state.property('chromeVisible'))
        self.state.setProperty('pointerAtBottom', True)
        QTest.qWait(220)
        self.assertTrue(self.state.property('dockVisible'))
        self.state.setProperty('externalActive', False)
        QTest.qWait(400)
        self.assertFalse(self.state.property('active'))
        self.assertFalse(self.state.property('chromeVisible'))
        self.assertFalse(self.state.property('dockVisible'))
        self.assertEqual(self.rect(), original)
        self.assertFalse(self.window.property('isFullscreen'))
    def test_external_state_respects_always_visible_menu_preference(self):
        self.state.setProperty('alwaysShowChrome', True)
        self.state.setProperty('externalActive', True)
        self.assertTrue(self.state.property('chromeVisible'))
        self.state.setProperty('externalActive', False)
        self.assertFalse(self.state.property('chromeVisible'))
    def test_resize_and_switch_restore_previous_window(self):
        self.state.enter(self.window)
        self.state.setProperty('viewportWidth', 800)
        self.state.setProperty('viewportHeight', 650)
        self.assertEqual(self.rect(), (0,0,800,650))
        self.state.enter(self.other)
        self.assertFalse(self.window.property('isFullscreen'))
        self.assertLessEqual(self.window.property('x')+self.window.property('width'), 800)
        self.assertTrue(self.other.property('isFullscreen'))
    def test_chrome_requires_top_edge_and_remains_for_menu(self):
        self.state.enter(self.window)
        self.state.setProperty('pointerInChrome', True)
        self.assertFalse(self.state.property('chromeVisible'))
        self.state.setProperty('pointerAtTop', True)
        self.assertTrue(self.state.property('chromeVisible'))
        self.state.setProperty('pointerAtTop', False)
        self.state.setProperty('pointerInChrome', False)
        self.state.setProperty('menuOpen', True)
        QTest.qWait(400)
        self.assertTrue(self.state.property('chromeVisible'))
        self.state.setProperty('menuOpen', False)
        for _ in range(50):
            if not self.state.property('chromeVisible'): break
            QTest.qWait(20)
        self.assertFalse(self.state.property('chromeVisible'))
    def test_dock_reveal_dwell_and_exit_cancels_timers(self):
        self.state.enter(self.window)
        self.state.setProperty('pointerAtBottom', True)
        self.assertFalse(self.state.property('dockVisible'))
        for _ in range(50):
            if self.state.property('dockVisible'): break
            QTest.qWait(20)
        self.assertTrue(self.state.property('dockVisible'))
        self.state.exit()
        QTest.qWait(400)
        self.assertFalse(self.state.property('active'))
        self.assertFalse(self.state.property('dockVisible'))

if __name__ == '__main__': unittest.main()
