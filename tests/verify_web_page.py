import os,sys,tempfile,threading
os.environ['QT_QPA_PLATFORM']='offscreen'
os.environ['QT_QUICK_CONTROLS_STYLE']='Basic'
os.environ['QT_QUICK_BACKEND']='software'
os.environ['QTWEBENGINE_CHROMIUM_FLAGS']='--disable-gpu'
from pathlib import Path
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from PySide6.QtCore import QUrl,QObject
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine,QQmlComponent
from PySide6.QtQuick import QQuickItem,QQuickWindow
from PySide6.QtWebEngineQuick import QtWebEngineQuick
from PySide6.QtTest import QTest
import shiboken6
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root))
from main import Bridge
from filesystem import Workspace
class Handler(BaseHTTPRequestHandler):
 def do_GET(self):
  data=b'<html><head><title>Prototype local browser test</title></head><body><h1>Local content</h1></body></html>'
  self.send_response(200);self.send_header('Content-Type','text/html');self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
 def log_message(self,*args):pass
server=ThreadingHTTPServer(('127.0.0.1',0),Handler);threading.Thread(target=server.serve_forever,daemon=True).start()
QtWebEngineQuick.initialize();app=QGuiApplication([])
with tempfile.TemporaryDirectory() as folder:
 bridge=Bridge(Workspace(folder));engine=QQmlApplicationEngine();errors=[]
 engine.warnings.connect(lambda items:errors.extend(str(e) for e in items))
 engine.rootContext().setContextProperty('Bridge',bridge)
 engine.loadData(b'''import QtQuick
import QtQuick.Controls
ApplicationWindow { id:win; width:1020;height:720;visible:false
 QtObject { id:desk; property bool reduceMotion:true; function showInfo(title,message) {} function openApplication(id) {} }
 Item { id:host;objectName:"host";width:1020;height:720;property string appKind:"safari";property string windowTitle:"Safari";property bool dark:false;property color ink:"#222222";property color muted:"#888888";property var desktop:desk;property bool active:true;property bool closing:false;property bool minimized:false }
}''',QUrl.fromLocalFile(str(root/'qml/Verification.qml')))
 window=engine.rootObjects()[0];host=window.findChild(QObject,'host')
 component=QQmlComponent(engine,QUrl.fromLocalFile(str(root/'qml/WebApp.qml')))
 page=component.createWithInitialProperties({'host':host});assert page,component.errors();page.setParentItem(host);page.setWidth(1020);page.setHeight(660)
 page.openUrl('http://127.0.0.1:'+str(server.server_port),False)
 for _ in range(120):
  QTest.qWait(50)
  current=page.property('currentPage')
  if current and not current.property('loading') and current.property('loadProgress')==100:break
 print('Current URL:',page.property('activeUrl'))
 assert current and current.property('loadProgress')==100,errors
 page.toggleBookmark();assert len(bridge.suite.records('bookmarks',False))==1
 page.newTab();assert page.property('currentTab')==1
 page.closeTab(1);assert page.property('currentTab')==0
 page.flush();page.setParentItem(None);page.deleteLater();QTest.qWait(100)
 assert not errors,'\n'.join(errors)
 shiboken6.delete(engine)
server.shutdown()
print('Browser local navigation, completed load, bookmark persistence, tabs and cleanup passed.')
