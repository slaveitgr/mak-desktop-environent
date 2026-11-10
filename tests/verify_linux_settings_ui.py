"""Render native Settings UI with injected observations; no hardware test."""
import os
os.environ['QT_QPA_PLATFORM']='offscreen'
os.environ['QT_QUICK_CONTROLS_STYLE']='Basic'
from pathlib import Path
from PySide6.QtCore import QObject, Property, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtTest import QTest
from linux_settings import LinuxSettings, PANELS
ROOT=Path(__file__).resolve().parents[1]
app=QGuiApplication([])
class Bridge(QObject):
    def __init__(self):
        super().__init__(); self.backend=LinuxSettings(False,self)
    @Property(QObject,constant=True)
    def linuxSettings(self): return self.backend
bridge=Bridge();engine=QQmlApplicationEngine();warnings=[]
engine.warnings.connect(lambda values:warnings.extend(str(value) for value in values))
engine.rootContext().setContextProperty('Bridge',bridge)
engine.loadData(b'''import QtQuick
import QtQuick.Controls
ApplicationWindow {
    width: 500; height: 900; visible: true
    QtObject {
        id: settingsHost; objectName: "host"
        property string page: "Sound"
        property bool dark: true
        property color ink: "#eeeeee"
        property color muted: "#b0b2b5"
        property QtObject desktop: QtObject { property color accentColor: "#1683fa" }
    }
    Flickable {
        anchors.fill: parent; contentHeight: panel.height
        LinuxSystemSettings { id: panel; width: parent.width; host: settingsHost }
    }
}''', QUrl.fromLocalFile(str(ROOT/'qml/SettingsLinuxVerification.qml')))
assert engine.rootObjects(), warnings
window=engine.rootObjects()[0];host=window.findChild(QObject,'host')
state={panel:{'available':False} for panel in PANELS}
state['audio']={'available':True,'outputs':[{'id':'1','name':'Test audio output','type':'USB','volume':0.5,'muted':False,'writable':True,'default':True}],'inputs':[]}
state['network']={'available':True,'wifiEnabled':True,'wifiPresent':True,'wifiHardwareEnabled':True,'wifiWritable':True,'interfaces':[{'id':'test','name':'test0','type':'Wi-Fi','state':100,'connection':'Injected network'}]}
state['bluetooth']={'available':True,'hardwareBlocked':False,'adapters':[{'id':'test','name':'Injected adapter','powered':True,'writable':True}],'devices':[{'name':'Injected device','connected':False,'paired':True}]}
state['power']={'available':True,'profiles':['balanced','power-saver'],'active':'balanced','degraded':''}
state['battery']={'available':True,'percent':80,'onBattery':True,'status':'Injected discharge state'}
state['display']={'available':True,'monitors':[{'name':'Test output','width':1920,'height':1080,'scale':1,'primary':True}]}
bridge.backend._receive({'type':'state','protocol':1,'state':state})
for page in ['Sound','Wi-Fi','Network','Bluetooth','Battery','Displays']:
    host.setProperty('page',page);QTest.qWait(40)
    assert not warnings,(page,warnings)
bridge.backend._receive({'type':'state','protocol':1,'state':{panel:{'available':False} for panel in PANELS}})
QTest.qWait(40)
assert not warnings,warnings
print('Six Settings panels and missing-service state rendered without QML warnings. Fixtures only; hardware not tested.')
window.close();engine.deleteLater();QTest.qWait(5)
