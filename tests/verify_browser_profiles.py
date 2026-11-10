"""Real local HTTP cookie isolation/persistence and tab-overview interaction.

Run with the project's Qt Python. All browser data and downloads use a tempdir;
the write/read phases are distinct processes to prove disk persistence.
"""
import html
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

os.environ['QT_QPA_PLATFORM'] = 'offscreen'
os.environ['QT_QUICK_CONTROLS_STYLE'] = 'Basic'
os.environ['QT_QUICK_BACKEND'] = 'software'
os.environ['QTWEBENGINE_CHROMIUM_FLAGS'] = '--disable-gpu'
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))


def phase(folder, writing):
    from PySide6.QtCore import QObject, QUrl, QPoint, Qt, QTimer
    from PySide6.QtGui import QGuiApplication
    from PySide6.QtQml import QQmlApplicationEngine, QQmlComponent
    from PySide6.QtQuick import QQuickItem, QQuickWindow
    from PySide6.QtTest import QTest
    from PySide6.QtWebEngineQuick import QtWebEngineQuick
    import shiboken6
    from main import Bridge
    from filesystem import Workspace

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if urlparse(self.path).path == '/download':
                data = b'Only the originating browser window saves this file.\n'
                self.send_response(200)
                self.send_header('Content-Type', 'application/octet-stream')
                self.send_header('Content-Disposition', 'attachment; filename="window.txt"')
                self.send_header('Content-Length', str(len(data)))
                self.end_headers()
                self.wfile.write(data)
                return
            query = parse_qs(urlparse(self.path).query)
            title = query.get('title', ['echo'])[0] + ':' + self.headers.get('Cookie', 'empty')
            data = ('<html><head><title>' + html.escape(title) + '</title></head><body>Local fixture</body></html>').encode()
            self.send_response(200)
            if 'set' in query:
                self.send_header('Set-Cookie', 'session=' + query['set'][0] + '; Max-Age=3600; SameSite=Lax; Path=/')
            self.send_header('Cache-Control', 'no-store')
            self.send_header('Content-Type', 'text/html')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            try:
                self.wfile.write(data)
            except (BrokenPipeError, ConnectionResetError):
                pass  # Closing a tab can cancel its favicon request.
        def log_message(self, *_):
            pass

    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    origin = 'http://127.0.0.1:' + str(server.server_port)
    QtWebEngineQuick.initialize()
    app = QGuiApplication([])
    bridge = Bridge(Workspace(folder))
    assert hasattr(bridge, 'browserProfiles'), 'Production Bridge.browserProfiles wiring missing'
    engine = QQmlApplicationEngine()
    errors = []
    engine.warnings.connect(lambda rows: errors.extend(str(row) for row in rows))
    engine.rootContext().setContextProperty('Bridge', bridge)
    engine.loadData(b'''import QtQuick
import QtQuick.Controls
ApplicationWindow { width:1020;height:720;visible:true
 QtObject { id:desk;property bool reduceMotion:true;function showInfo(title,message) {} }
 Item { id:host;objectName:"host";width:1020;height:720;property string appKind:"safari";property string windowTitle:"Safari";property bool privateBrowsing:false;property bool dark:false;property color ink:"#222";property color muted:"#888";property var desktop:desk }
}''', QUrl.fromLocalFile(str(ROOT / 'qml/ProfileVerification.qml')))
    assert engine.rootObjects(), errors
    window = engine.rootObjects()[0]
    host = window.findChild(QObject, 'host')
    component = QQmlComponent(engine, QUrl.fromLocalFile(str(ROOT / 'qml/WebApp.qml')))
    pages = []
    host_component = QQmlComponent(engine)
    host_component.setData(b'''import QtQuick
Item { width:1020;height:660;property string appKind:"safari";property string windowTitle:"Safari";property bool privateBrowsing:false;property bool dark:false;property color ink:"#222";property color muted:"#888";property var desktop }
''', QUrl.fromLocalFile(str(ROOT / 'qml/ProfileHost.qml')))

    def wait(test, label):
        deadline = time.monotonic() + 12
        while time.monotonic() < deadline:
            QTest.qWait(25)
            if test():
                return
        raise AssertionError(label + '\n' + '\n'.join(errors))

    def new_page(private=False):
        owner = host_component.createWithInitialProperties({'privateBrowsing': private, 'desktop': host.property('desktop')})
        assert owner, host_component.errors()
        owner.setParentItem(host)
        page = component.createWithInitialProperties({'host': owner})
        assert page, component.errors()
        page.setParentItem(owner)
        page.setWidth(1020)
        page.setHeight(660)
        page.ensureSession()
        assert page.property('browsingProfile'), errors
        pages.append((page, owner))
        return page

    def navigate(page, path, expected):
        page.openUrl(origin + path, False)
        wait(lambda: page.property('currentPage') and page.property('currentPage').property('pageTitle') == expected, expected)

    def close_page(page):
        owner = next(owner for p, owner in pages if p is page)
        page.flush()
        page.setParentItem(None)
        page.deleteLater()
        owner.deleteLater()
        pages.remove((page, owner))
        QTest.qWait(150)

    def item_named(parent, name):
        for child in parent.childItems():
            if child.objectName() == name:
                return child
            found = item_named(child, name)
            if found:
                return found
        return None

    def entries(manager):
        value = manager.property('entries')
        return value.toVariant() if hasattr(value, 'toVariant') else value

    try:
        normal = new_page()
        if writing:
            navigate(normal, '/?set=regular&title=set', 'set:empty')
            navigate(normal, '/?title=normal', 'normal:session=regular')
            private = new_page(True)
            navigate(private, '/?title=private', 'private:empty')
            navigate(private, '/?set=private&title=set-private', 'set-private:empty')
            navigate(private, '/?title=private-check', 'private-check:session=private')
            navigate(normal, '/?title=normal-check', 'normal-check:session=regular')
            second = new_page()
            assert normal.property('browsingProfile') == second.property('browsingProfile')
            navigate(second, '/?title=shared', 'shared:session=regular')
            manager = normal.property('downloadManager')
            other_manager = second.property('downloadManager')
            decision_timer = QTimer()
            decision_timer.setInterval(20)
            def accept_download():
                if manager.property('awaitingConfirmation'):
                    decision_timer.stop()
                    manager.decide(True)
            decision_timer.timeout.connect(accept_download)
            decision_timer.start()
            normal.openUrl(origin + '/download', False)
            wait(lambda: entries(manager) and entries(manager)[0].property('finalized'), 'shared-profile download')
            decision_timer.stop()
            entry = entries(manager)[0]
            assert entry.property('status') == 'complete', entry.property('message')
            assert not entries(other_manager), 'An unrelated normal window received a download prompt'
            assert Path(QUrl(entry.property('savedUrl')).toLocalFile()).read_bytes() == b'Only the originating browser window saves this file.\n'
            print('PASS shared-profile download is owned by its originating window', flush=True)
            close_page(private)
            private = new_page(True)
            navigate(private, '/?title=reopened-private', 'reopened-private:empty')
            close_page(private)
            close_page(second)
            print('PASS regular windows share cookies; private window is isolated and cleared on close', flush=True)

            normal.newTab()
            navigate(normal, '/?title=Second', 'Second:session=regular')
            normal.command('tabOverview')
            assert normal.property('overviewVisible')
            normal.setProperty('overviewQuery', 'normal-check')
            overlay = normal.findChild(QObject, 'browserTabOverview')
            wait(lambda: overlay.property('matchingCount') == 1, 'filtered overview')
            card = item_named(overlay, 'browserTabCard_0')
            assert card and card.isVisible(), errors
            point = card.mapToScene(card.boundingRect().center())
            QTest.mouseClick(window, Qt.LeftButton, Qt.NoModifier, QPoint(int(point.x()), int(point.y())))
            wait(lambda: not normal.property('overviewVisible') and normal.property('currentTab') == 0, 'overview selection')
            normal.command('tabOverview')
            normal.setProperty('overviewQuery', '')
            close_button = item_named(overlay, 'browserTabCardClose_1')
            point = close_button.mapToScene(close_button.boundingRect().center())
            QTest.mouseClick(window, Qt.LeftButton, Qt.NoModifier, QPoint(int(point.x()), int(point.y())))
            wait(lambda: normal.property('tabCount') == 1, 'overview close tab')
            button = normal.findChild(QObject, 'browserOverviewNewTab')
            point = button.mapToScene(button.boundingRect().center())
            QTest.mouseClick(window, Qt.LeftButton, Qt.NoModifier, QPoint(int(point.x()), int(point.y())))
            wait(lambda: normal.property('tabCount') == 2 and not normal.property('overviewVisible'), 'overview new tab')
            print('PASS overview search, pointer selection, close and new-tab operations', flush=True)
        else:
            navigate(normal, '/?title=after-restart', 'after-restart:session=regular')
            private = new_page(True)
            navigate(private, '/?title=private-after-restart', 'private-after-restart:empty')
            print('PASS regular cookie persists across a real process restart; private cookie does not', flush=True)
        assert not errors, '\n'.join(errors)
    finally:
        for page, owner in list(pages):
            close_page(page)
        bridge.shutdown()
        shiboken6.delete(engine)
        shiboken6.delete(bridge)
        QTest.qWait(200)
        server.shutdown()


if __name__ == '__main__':
    if len(sys.argv) == 3:
        phase(sys.argv[2], sys.argv[1] == 'write')
    else:
        with tempfile.TemporaryDirectory(prefix='makos-browser-profiles-') as folder:
            for mode in ('write', 'read'):
                subprocess.run([sys.executable, __file__, mode, folder], check=True, timeout=70)
        print('Browser profile and tab overview integration checks passed.')
