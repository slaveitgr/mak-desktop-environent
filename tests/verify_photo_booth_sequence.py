"""Use synthetic captures to test Photo Booth sequence state; never load a Camera."""
import os,sys,tempfile
os.environ['QT_QPA_PLATFORM']='offscreen';os.environ['QT_QUICK_CONTROLS_STYLE']='Basic'
from pathlib import Path
from PySide6.QtCore import QObject,Property,Slot,Signal,QUrl
from PySide6.QtGui import QGuiApplication,QFont,QImage,QColor
from PySide6.QtQuick import QQuickItem
from PySide6.QtQml import QQmlApplicationEngine,QQmlComponent
from PySide6.QtTest import QTest
import shiboken6
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root))
from suite import Suite
class Bridge(QObject):
 cameraPermissionResult=Signal(bool,str)
 def __init__(self,path):super().__init__();self.store=Suite(path);self.requests=0
 @Property(QObject,constant=True)
 def suite(self):return self.store
 @Property(str,constant=True)
 def assetRoot(self):return QUrl.fromLocalFile(str(root/'assets')).toString()+'/'
 @Slot()
 def requestCameraPermission(self):self.requests+=1;raise AssertionError('Test must not request camera permission')
app=QGuiApplication([]);app.setFont(QFont('.AppleSystemUIFont',13))
with tempfile.TemporaryDirectory() as temp:
 bridge=Bridge(Path(temp).resolve());engine=QQmlApplicationEngine();errors=[]
 bridge.store.error.connect(errors.append)
 engine.warnings.connect(lambda items:errors.extend(str(e) for e in items));engine.rootContext().setContextProperty('Bridge',bridge)
 engine.loadData(b'''import QtQuick
import QtQuick.Controls
ApplicationWindow { width:1020;height:720;visible:false
 QtObject { id:desk; property bool reduceMotion:true; function openApplication(id){} }
 Item { id:holder;objectName:"host";width:1020;height:660;property bool active:true;property bool closing:false;property bool minimized:false;property bool dark:true;property color ink:"white";property color muted:"gray";property var desktop:desk
 PhotoBoothApp {id:booth;objectName:"booth";anchors.fill:parent;host:holder} }
}''',QUrl.fromLocalFile(str(root/'qml/PhotoBoothVerification.qml')))
 assert engine.rootObjects(),errors
 window=engine.rootObjects()[0];page=window.findChild(QObject,'booth');host=window.findChild(QObject,'host');QTest.qWait(10)
 assert not page.property('cameraStarted')
 page.setEffect('sepia');assert page.property('effect')=='sepia';assert bridge.store.preference('photobooth.effect','')=='sepia'
 page.setCaptureMode('four');assert page.property('captureMode')=='four'
 page.setProperty('totalFrames',4);page.setProperty('framesRemaining',4);page.setProperty('shotEffect','sepia');page.setProperty('shotMirror',True)
 page.setEffect('mono');assert page.property('effect')=='sepia'
 for color in ('red','green','blue','yellow'):
  path=bridge.store.photoPath();image=QImage(24,16,QImage.Format_RGB32);image.fill(QColor(color));assert image.save(path,'PNG')
  page.setProperty('capturePending',True);page.savedCapture(path)
 assert page.property('framesRemaining')==0 and not page.property('busy')
 photos=bridge.store.media('photos')
 assert len(photos)==5 and len(list((Path(temp)/'Pictures/Photo Booth/.originals').glob('*')))==4
 assert all((Path(temp)/r['path']).exists() for r in photos)
 assert all('.originals' not in r['path'] for r in photos)
 assert not page.findChild(QObject,'photoSequenceTimer').property('running')
 page.setProperty('framesRemaining',4);page.setProperty('countdown',3);page.setProperty('capturePending',True)
 page.findChild(QObject,'photoCountdownTimer').start()
 host.setProperty('minimized',True)
 assert not page.property('busy') and not page.property('cameraStarted')
 assert not page.findChild(QObject,'photoCountdownTimer').property('running')
 assert not page.findChild(QObject,'photoSequenceTimer').property('running')
 assert bridge.requests==0
 assert not errors,'\n'.join(errors)
 page.flush();window.close();shiboken6.delete(engine)
 bridge.store._downloads.close();bridge.store.db.close()
print('Photo Booth real Suite/QML integration passed: synthetic four-shot saves, hidden originals, SQLite preferences, Photos visibility, capture locking and minimize cancellation. Camera/permission never activated.')
