"""Isolated QtWebEngine download lifecycle QA; uses localhost and temporary files only.

Run in a fresh process so QtWebEngineQuick can initialize before QGuiApplication.
"""
import os
os.environ['QT_QPA_PLATFORM'] = 'offscreen'
os.environ['QT_QUICK_CONTROLS_STYLE'] = 'Basic'
os.environ['QT_QUICK_BACKEND'] = 'software'
os.environ['QTWEBENGINE_CHROMIUM_FLAGS'] = '--disable-gpu'

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import sys
import tempfile
import threading
import time
from urllib.parse import urlsplit

from PySide6.QtCore import QObject, QTimer, QUrl, qVersion
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine, QQmlComponent
from PySide6.QtQuick import QQuickItem, QQuickWindow
from PySide6.QtTest import QTest
from PySide6.QtWebEngineQuick import QtWebEngineQuick
from PySide6.QtWebEngineCore import qWebEngineVersion, qWebEngineChromiumVersion
import shiboken6

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from main import Bridge
from filesystem import Workspace

DATA = 'Local browser download · δοκιμή\n'.encode('utf-8') * 128
SLOW_DATA = bytes(range(256)) * 4096
COOKIES = []


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = urlsplit(self.path).path
        if path.startswith('/download'):
            if path.endswith('-broken'):
                print('FIXTURE: serving truncated response', flush=True)
            slow = path.endswith('-slow')
            data = SLOW_DATA if slow else DATA
            name = 'slow.bin' if slow else 'sample.txt'
            self.send_response(200)
            self.send_header('Content-Type', 'application/octet-stream')
            self.send_header('Content-Disposition', 'attachment; filename="' + name + '"')
            self.send_header('Content-Length', str(len(data) + 4096 if path.endswith('-broken') else len(data)))
            self.end_headers()
            try:
                for offset in range(0, len(data), 16384):
                    self.wfile.write(data[offset:offset + 16384])
                    self.wfile.flush()
                    if slow:
                        time.sleep(0.04)
            except (BrokenPipeError, ConnectionResetError):
                pass
            return
        COOKIES.append((path, self.headers.get('Cookie', '')))
        data = b'<html><head><title>Local fixture</title></head><body>Browser fixture</body></html>'
        self.send_response(200)
        self.send_header('Content-Type', 'text/html')
        self.send_header('Content-Length', str(len(data)))
        if path == '/set-cookie':
            self.send_header('Set-Cookie', 'private_fixture=shared; Path=/; SameSite=Lax')
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *args):
        pass


def entries(manager):
    value = manager.property('entries')
    return value.toVariant() if hasattr(value, 'toVariant') else value


def wait_for(predicate, description, seconds=10):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        QTest.qWait(25)
        if predicate():
            return
    raise AssertionError('Timed out: ' + description)


class BrowserHarness:
    def __init__(self, folder, origin):
        self.root = Path(folder).resolve()
        self.origin = origin
        self.bridge = Bridge(Workspace(folder))
        self.errors = []
        self.engine = QQmlApplicationEngine()
        self.engine.warnings.connect(lambda warnings: self.errors.extend(str(w) for w in warnings))
        self.engine.rootContext().setContextProperty('Bridge', self.bridge)
        self.engine.loadData(b'''import QtQuick
import QtQuick.Controls
ApplicationWindow { width:1020;height:720;visible:false
 QtObject { id:desk;property bool reduceMotion:true;function showInfo(title,message) {} function openFolder(path) {} }
 Item { objectName:"host";width:1020;height:720;property string appKind:"safari";property string windowTitle:"Safari";property bool privateBrowsing:true;property bool dark:false;property color ink:"#222222";property color muted:"#888888";property var desktop:desk;property bool active:true;property bool closing:false;property bool minimized:false }
}''', QUrl.fromLocalFile(str(ROOT / 'qml/DownloadVerification.qml')))
        assert self.engine.rootObjects(), self.errors
        self.window = self.engine.rootObjects()[0]
        self.host = self.window.findChild(QObject, 'host')
        self.page = None
        self.new_browser()

    def new_browser(self):
        self.component = QQmlComponent(self.engine, QUrl.fromLocalFile(str(ROOT / 'qml/WebApp.qml')))
        self.page = self.component.createWithInitialProperties({'host': self.host})
        assert self.page, self.component.errors()
        self.page.setParentItem(self.host)
        self.page.setSize(self.host.size())
        self.page.ensureSession()
        self.manager = self.page.property('downloadManager')
        assert self.manager
        self.manager.setProperty('traceLifecycle', os.environ.get('MAKOS_DOWNLOAD_TRACE') == '1')

    def close_browser(self):
        if self.page is None:
            return
        self.page.flush()
        self.page.setParentItem(None)
        self.page.deleteLater()
        QTest.qWait(100)
        self.page = None
        self.manager = None

    def navigate(self, path, new_tab=False):
        self.page.openUrl(self.origin + path, new_tab)
        wait_for(lambda: self.page.property('currentPage') and
                 self.page.property('currentPage').property('loadProgress') == 100,
                 'local page ' + path)

    def start_download(self, accept, path='/download', rename=None, on_prompt=None):
        before = len(entries(self.manager))
        decisions = []
        callback_errors = []
        timer = QTimer()
        timer.setInterval(20)
        started = time.monotonic()

        def confirm():
            if not self.manager.property('awaitingConfirmation'):
                if time.monotonic() - started > 10:
                    callback_errors.append(AssertionError('Download confirmation did not appear'))
                    timer.stop()
                return
            timer.stop()
            try:
                # A request has not been accepted and no staging reservation exists yet.
                assert not self.bridge.suite._downloads._pending
                assert not self.stage_files()
                if rename:
                    self.manager.setProperty('proposedName', rename)
                if on_prompt:
                    on_prompt()
                else:
                    self.manager.decide(accept)
                decisions.append(True)
            except BaseException as exc:
                callback_errors.append(exc)
                self.manager.decide(False)

        timer.timeout.connect(confirm)
        timer.start()
        self.page.openUrl(self.origin + path, False)
        wait_for(lambda: bool(decisions or callback_errors), 'download confirmation')
        timer.stop()
        if callback_errors:
            raise callback_errors[0]
        assert len(entries(self.manager)) == before + 1
        return entries(self.manager)[0]

    def stage_files(self):
        stage = self.root / '.desktop-data/downloads'
        return list(stage.iterdir()) if stage.exists() else []

    def verify_signal_order(self):
        # Qt6.8.2 QWebEngineDownloadRequestPrivate::update emits stateChanged
        # before byte counts and isFinished. Drive that exact ordering through
        # the real QML manager, including a resumable interrupt's cancel path.
        component = QQmlComponent(self.engine)
        component.setData(b'''import QtQuick
QtObject {
 id:request
 required property var owner
 property var view:owner.currentPage.webView
 property int id:9000
 property int state:0
 property bool isFinished:false
 property bool isSavePageDownload:false
 property int interruptReason:0
 property string interruptReasonString:""
 property int receivedBytes:0
 property int totalBytes:-1
 property url url:"http://127.0.0.1/signal-order-fixture"
 property string suggestedFileName:"sequenced.bin"
 property string downloadDirectory:""
 property string downloadFileName:""
 property bool updating:false
 property bool cancelDuringUpdate:false
 function accept() { state=1; }
 function cancel() { if(updating)cancelDuringUpdate=true;state=3;isFinished=true; }
 function completeUpdate() { updating=true;state=2;receivedBytes=7;totalBytes=7;isFinished=true;updating=false; }
 function interruptUpdate() { updating=true;interruptReason=20;interruptReasonString="Fixture network error";state=4;receivedBytes=3;totalBytes=7;updating=false; }
}''', QUrl.fromLocalFile(str(ROOT / 'qml/DownloadUpdateFixture.qml')))
        for scenario in ('complete', 'interrupt', 'duplicate'):
            request_id = 9000 + ('complete', 'interrupt', 'duplicate').index(scenario)
            request = component.createWithInitialProperties({'owner':self.page, 'id':request_id})
            assert request, component.errors()
            timer = QTimer()
            timer.setInterval(10)
            timer.timeout.connect(lambda: self.manager.decide(True) if self.manager.property('awaitingConfirmation') else None)
            timer.start()
            self.manager.requested(request)
            timer.stop()
            entry = entries(self.manager)[0]
            stage = Path(request.property('downloadDirectory')) / request.property('downloadFileName')
            stage.write_bytes(b'partial' if scenario == 'complete' else b'par')
            duplicate = None
            if scenario == 'duplicate':
                count = len(entries(self.manager))
                duplicate = component.createWithInitialProperties({'owner':self.page, 'id':request_id})
                assert duplicate, component.errors()
                # The same native item can retry after its source tab closes;
                # ID ownership must win even when that new wrapper has no view.
                duplicate.setProperty('view', None)
                self.manager.requested(duplicate)
                assert not self.manager.property('awaitingConfirmation')
                assert len(entries(self.manager)) == count
                assert duplicate.property('state') == 3
            elif scenario == 'interrupt':
                request.interruptUpdate()
            else:
                request.completeUpdate()
            assert not entry.property('finalized'), 'Finalized inside Qt state notification before the remaining fields'
            wait_for(lambda: entry.property('finalized'), 'deferred terminal update')
            assert not request.property('cancelDuringUpdate'), 'Cancellation reentered the native update frame'
            if scenario != 'duplicate':
                assert entry.property('received') == (3 if scenario == 'interrupt' else 7)
                assert entry.property('total') == 7
            assert entry.property('status') == ('complete' if scenario == 'complete' else 'failed')
            if scenario == 'complete':
                assert Path(QUrl(entry.property('savedUrl')).toLocalFile()).read_bytes() == b'partial'
            else:
                assert not stage.exists()
            if duplicate:
                assert request.property('state') == 3
                assert not entry.property('savedUrl')
                assert entry.property('message')
                duplicate.deleteLater()
            self.assert_clean()
            request.deleteLater()
            QTest.qWait(20)
        print('PASS: terminal state waits for complete fields; same-ID retry fails once without a second Save sheet', flush=True)

    def assert_clean(self):
        assert not self.bridge.suite._downloads._pending
        assert not self.stage_files(), self.stage_files()
        assert not self.errors, '\n'.join(self.errors)

    def close(self):
        self.close_browser()
        self.bridge.shutdown()
        shiboken6.delete(self.engine)


def main():
    print('Browser runtime: Qt=' + qVersion() + ' WebEngine=' + qWebEngineVersion() + ' Chromium=' + qWebEngineChromiumVersion(), flush=True)
    server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    QtWebEngineQuick.initialize()
    app = QGuiApplication([])
    # Escape an unexpected nested confirmation loop so failures cannot hang CI.
    watchdog = QTimer()
    watchdog.setSingleShot(True)
    watchdog.timeout.connect(lambda: os._exit(124))
    watchdog.start(60000)
    with tempfile.TemporaryDirectory() as folder:
        harness = BrowserHarness(folder, 'http://127.0.0.1:' + str(server.server_port))
        try:
            harness.navigate('/page')
            entry = harness.start_download(False)
            wait_for(lambda: entry.property('finalized'), 'cancel before save')
            assert entry.property('status') == 'cancelled'
            assert not list((harness.root / 'Downloads').glob('*'))
            harness.assert_clean()
            print('PASS: cancel before Save writes no file', flush=True)

            def filename_menu():
                field = harness.manager.findChild(QObject, 'browserDownloadName')
                harness.page.command('selectAll')
                assert field.property('selectedText') == 'sample.txt'
                url = harness.page.property('activeUrl')
                harness.page.command('home')
                assert harness.page.property('activeUrl') == url
                harness.manager.decide(False)

            harness.start_download(False, on_prompt=filename_menu)
            harness.assert_clean()
            print('PASS: menu editing targets filename and underlying navigation is blocked', flush=True)

            downloads = harness.root / 'Downloads'
            downloads.mkdir(exist_ok=True)
            (downloads / 'sample.txt').write_bytes(b'keep existing')
            entry = harness.start_download(True)
            wait_for(lambda: entry.property('finalized'), 'saved download')
            assert entry.property('status') == 'complete', entry.property('message')
            saved = Path(QUrl(entry.property('savedUrl')).toLocalFile())
            assert saved.parent == downloads and saved.name != 'sample.txt'
            assert saved.read_bytes() == DATA
            assert (downloads / 'sample.txt').read_bytes() == b'keep existing'
            harness.assert_clean()
            print('PASS: accepted Content-Disposition download preserves existing file', flush=True)

            entry = harness.start_download(True, rename='δοκιμή.txt')
            wait_for(lambda: entry.property('finalized'), 'renamed UTF-8 download')
            assert (downloads / 'δοκιμή.txt').read_bytes() == DATA
            assert entry.property('status') == 'complete'
            harness.assert_clean()
            print('PASS: chosen UTF-8 file name survives publication', flush=True)

            entry = harness.start_download(True, '/download-slow')
            wait_for(lambda: entry.property('received') > 0, 'progress update')
            assert entry.property('total') == len(SLOW_DATA)
            assert harness.manager.property('activeCount') == 1
            harness.manager.cancelEntry(entry)
            wait_for(lambda: entry.property('finalized'), 'active cancellation')
            assert entry.property('status') == 'cancelled'
            assert not (downloads / 'slow.bin').exists()
            harness.assert_clean()
            print('PASS: progress and cancellation remove owned partial files', flush=True)

            harness.navigate('/signal-order-page')
            harness.verify_signal_order()

            print('CASE: truncated response before or during Save confirmation', flush=True)
            entry = harness.start_download(True, '/download-broken', rename='broken.bin')
            print('CASE: truncated response accepted; waiting for terminal state', flush=True)
            wait_for(lambda: entry.property('finalized'), 'interrupted download', seconds=15)
            assert entry.property('status') == 'failed'
            assert entry.property('message')
            assert not (downloads / 'broken.bin').exists()
            harness.assert_clean()
            print('PASS: interrupted transfer reports failure and removes staging', flush=True)

            harness.page.newTab()
            entry = harness.start_download(True, '/download-slow', rename='survived.bin')
            wait_for(lambda: entry.property('received') > 0, 'tab-close progress')
            profile = harness.page.property('browsingProfile')
            harness.page.closeTab(harness.page.property('currentTab'))
            assert harness.page.property('browsingProfile') is profile
            wait_for(lambda: entry.property('finalized'), 'download after source tab closes')
            assert entry.property('status') == 'complete', entry.property('message')
            assert (downloads / 'survived.bin').read_bytes() == SLOW_DATA
            harness.assert_clean()
            print('PASS: shared profile preserves download after source tab closes', flush=True)

            harness.navigate('/set-cookie')
            harness.navigate('/echo-cookie', True)
            assert any(path == '/echo-cookie' and 'private_fixture=shared' in cookie
                       for path, cookie in COOKIES)
            harness.close_browser()
            harness.new_browser()
            harness.navigate('/fresh-cookie')
            assert all('private_fixture=' not in cookie for path, cookie in COOKIES
                       if path == '/fresh-cookie')
            print('PASS: private cookies shared across tabs and cleared with window', flush=True)

            entry = harness.start_download(True, '/download-slow', rename='closing.bin')
            wait_for(lambda: entry.property('received') > 0, 'window-close progress')
            harness.page.flush()
            assert entry.property('status') == 'cancelled'
            assert not (downloads / 'closing.bin').exists()
            harness.assert_clean()
            harness.close_browser()
            harness.new_browser()
            print('PASS: window close cancels active download and removes staging', flush=True)

            entry = harness.start_download(False, on_prompt=lambda: harness.page.flush())
            wait_for(lambda: entry.property('finalized'), 'close during confirmation')
            assert entry.property('status') == 'cancelled'
            harness.assert_clean()
            print('PASS: window close dismisses pending Save without writing', flush=True)

            # Clear removes only the display history, preserving published files.
            harness.manager.clearFinished()
            assert entries(harness.manager) == []
            assert saved.read_bytes() == DATA
            harness.assert_clean()
        finally:
            harness.close()
    watchdog.stop()
    server.shutdown()
    print('Browser download integration checks passed.', flush=True)


if __name__ == '__main__':
    main()
