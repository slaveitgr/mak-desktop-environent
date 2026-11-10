"""Control Center consumes confirmed Settings state; no system service is used."""
import copy
import os
from pathlib import Path
import sys
import tempfile
os.environ['QT_QPA_PLATFORM']='offscreen'
os.environ['QT_QUICK_BACKEND']='software'
os.environ['QT_QUICK_CONTROLS_STYLE']='Basic'
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from PySide6.QtCore import QObject,QUrl,QEvent,QCoreApplication
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickWindow,QQuickItem
from PySide6.QtQml import QQmlApplicationEngine,QQmlExpression,QQmlEngine
from PySide6.QtTest import QTest
from main import Bridge
from filesystem import Workspace
from linux_settings import PANELS
app=QGuiApplication([])
with tempfile.TemporaryDirectory() as temporary:
    bridge=Bridge(Workspace(Path(temporary)))
    backend=bridge.linuxSettings;writes=[]
    backend._send=lambda command:(writes.append(copy.deepcopy(command)) or True)
    state={panel:{'available':False} for panel in PANELS}
    state['audio']={'available':True,'outputs':[{'id':'sink-17','name':'Test output','volume':0.4,'muted':False,'default':True,'writable':True}]}
    state['network']={'available':True,'wifiEnabled':True,'wifiWritable':True,'wifiHardwareEnabled':True,'wifiPresent':True,'interfaces':[]}
    state['bluetooth']={'available':True,'adapters':[],'devices':[]}
    state['battery']={'available':True,'percent':72,'onBattery':True}
    state['power']={'available':True,'active':'balanced','profiles':['balanced','power-saver']}
    def publish():backend._receive({'type':'state','protocol':1,'state':copy.deepcopy(state)})
    publish()
    engine=QQmlApplicationEngine();warnings=[]
    engine.warnings.connect(lambda items:warnings.extend(str(i) for i in items))
    for key,value in {'Bridge':bridge,'startSettings':False,'startFullscreen':False,'comparisonMode':False,'startNativeWindows':False,'useCutefishShell':True}.items():engine.rootContext().setContextProperty(key,value)
    engine.load(QUrl.fromLocalFile(str(ROOT/'qml/Main.qml')))
    assert engine.rootObjects(),warnings
    root=engine.rootObjects()[0];desktop=root.findChild(QObject,'desktop')
    def check(code):
        e=QQmlExpression(QQmlEngine.contextForObject(desktop),desktop,code);value,undefined=e.evaluate()
        assert not e.hasError(),e.error().toString()
        assert value and not undefined,code
    check('controls.nativeSystem && controls.soundAvailable && controls.preference("sound.volume", "0") === "0.4"')
    check('(controls.requestVolume(0.8), true)');QTest.qWait(120)
    assert writes[-1]['action']=='audio.volume' and writes[-1]['target']=='sink-17' and writes[-1]['value']==0.8
    check('controls.preference("sound.volume", "0") === "0.4"')
    check('(controls.requestVolume(0.2), controls.requestVolume(0.6), true)');QTest.qWait(100)
    assert len(writes)==1,'Do not race settings writes while awaiting readback'
    state['audio']['outputs'][0]['volume']=0.8;publish()
    backend._receive({'type':'result','id':writes[-1]['id'],'ok':True});QTest.qWait(120)
    assert len(writes)==2 and writes[-1]['value']==0.6,'Latest queued slider value should be applied'
    backend._receive({'type':'result','id':writes[-1]['id'],'ok':False,'message':'Permission denied'})
    check('controls.preference("sound.volume", "0") === "0.8"')
    for section in ['control','sound','wifi','bluetooth','battery','lowpower']:
        desktop.openStatusPanel(section);QTest.qWait(30)
    backend._fail('Disconnected')
    check('!controls.soundAvailable && controls.preference("sound.volume", "1") === "0"')
    check('(controls.setPreference("sound.volume",0.1),true)');QTest.qWait(100)
    assert len(writes)==2
    assert bridge.suite.preference('sound.volume','not-written')=='not-written'
    assert not warnings,warnings
    bridge.shutdown();root.setVisible(False);engine.deleteLater();QCoreApplication.sendPostedEvents(None,QEvent.DeferredDelete)
print('Control Center: confirmed audio readback, coalesced writes, denied writes, disconnected state and native panels passed.')
