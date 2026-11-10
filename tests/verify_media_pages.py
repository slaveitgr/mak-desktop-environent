import os,sys,tempfile,shutil,wave,json
os.environ['QT_QPA_PLATFORM']='offscreen'
os.environ['QT_QUICK_CONTROLS_STYLE']='Basic'
from pathlib import Path
from PySide6.QtCore import QUrl,QObject
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine,QQmlComponent
from PySide6.QtQuick import QQuickItem,QQuickWindow
from PySide6.QtTest import QTest
import shiboken6
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root))
from main import Bridge
from filesystem import Workspace
app=QGuiApplication([])
with tempfile.TemporaryDirectory() as folder:
 bridge=Bridge(Workspace(folder)); engine=QQmlApplicationEngine(); errors=[]
 pic=Path(folder)/'Pictures';pic.mkdir();shutil.copy2(root/'assets/photos.png',pic/'Fixture.png')
 music=Path(folder)/'Music';music.mkdir()
 with wave.open(str(music/'Silent fixture.wav'),'wb') as audio:
  audio.setnchannels(1);audio.setsampwidth(2);audio.setframerate(8000);audio.writeframes(b'\0\0'*800)
 bridge.suite.setPreference('sound.muted','true')
 engine.warnings.connect(lambda items:errors.extend(str(e) for e in items))
 engine.rootContext().setContextProperty('Bridge',bridge)
 engine.loadData(b'''import QtQuick
import QtQuick.Controls
ApplicationWindow { id:win; width:1020;height:720;visible:false
 QtObject { id:desk; property bool reduceMotion:true; function showInfo(title,message) { console.log(title,message); } function openApplication(id) {} }
 Item { id:host;objectName:"host";width:1020;height:720;property string appKind:"safari";property string windowTitle:"Safari";property bool dark:false;property color ink:"#222222";property color muted:"#888888";property var desktop:desk;property bool active:true;property bool closing:false;property bool minimized:false }
}''',QUrl.fromLocalFile(str(root/'qml/Verification.qml')))
 assert engine.rootObjects(), errors
 window=engine.rootObjects()[0]; host=window.findChild(QObject,'host')
 for appid,filename in [('safari','WebApp.qml'),('maps','WebApp.qml'),('photos','MediaApp.qml'),('music','MediaApp.qml'),('photobooth','PhotoBoothApp.qml'),('phone','CallsApp.qml'),('facetime','CallsApp.qml')]:
  host.setProperty('appKind',appid)
  component=QQmlComponent(engine,QUrl.fromLocalFile(str(root/'qml'/filename)))
  if component.isError(): raise AssertionError('\n'.join(str(e) for e in component.errors()))
  page=component.createWithInitialProperties({'host':host}); assert page, str(component.errors())
  page.setParentItem(host);page.setWidth(1020);page.setHeight(660);QTest.qWait(40)
  if appid=='photos':
   items=bridge.suite.media('photos');assert len(items)==1
   page.toggleFavorite(items[0]);assert json.loads(bridge.suite.preference('photos.favorites','[]'))==['Pictures/Fixture.png']
   page.setProperty('section','Favorites');QTest.qWait(10)
   page.nextPhoto(1);assert page.property('selection').toVariant()['name']=='Fixture.png'
  if appid=='music':
   items=bridge.suite.media('music');assert len(items)==1
   page.playTrack(items[0]);QTest.qWait(80)
   assert page.property('playingTrack').toVariant()['name']=='Silent fixture.wav'
  if appid=='photobooth':
   assert not page.property('cameraStarted') and not page.property('awaitingPermission')
  page.flush();page.setParentItem(None);page.deleteLater();QTest.qWait(30)
  print('Loaded',appid)
 if errors:raise AssertionError('\n'.join(errors))
 shiboken6.delete(engine)
print('All media/web/call pages loaded with no QML diagnostics; no camera, microphone or network started.')
