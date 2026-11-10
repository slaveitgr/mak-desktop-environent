"""Tahoe control structure and real pointer routing with injected Linux state.

No hardware service, pairing, network connection, or actual native app starts.
Optional screenshots contain fixture device names only and use opaque materials
because the software Qt renderer cannot validate shader-based Liquid Glass.
"""
import copy
import os
from pathlib import Path
import sys
import tempfile
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
os.environ.setdefault('QT_QUICK_BACKEND','software')
os.environ['QT_QUICK_CONTROLS_STYLE']='Basic'
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
from PySide6.QtCore import QObject,QUrl,Qt,QPoint,QPointF,Slot,Signal,Property
from PySide6.QtGui import QGuiApplication,QFont
from PySide6.QtQml import QQmlApplicationEngine,QQmlComponent
from PySide6.QtQuick import QQuickWindow
from PySide6.QtTest import QTest
import shiboken6
from main import Bridge
from filesystem import Workspace
from linux_settings import PANELS

class FixtureShell(QObject):
    changed=Signal()
    launcherToggleRequested=Signal()
    hardwareLevelChanged=Signal(str,float,bool,str,bool)
    @Property("QVariantList",notify=changed)
    def windows(self):return []
    @Property("QVariantList",notify=changed)
    def menus(self):return []
    @Property(str,notify=changed)
    def activeId(self):return ""

class FixtureBridge(Bridge):
    launches=[]
    @Slot(str,result=bool)
    def launchCutefishApp(self,app_id):
        self.launches.append(app_id);return True
    @Slot(str,result=bool)
    def launchSettings(self,page):
        self.launches.append('settings:'+page);return True

class FixtureNativeOSD(QObject):
    showing=False
    last=None
    @Slot(str,float,bool,str,bool,result=bool)
    def present(self,kind,value,muted,label,available):
        self.last=(kind,value,muted,label,available);self.showing=available;return available
    @Slot()
    def dismiss(self):self.showing=False

app=QGuiApplication([]);app.setFont(QFont('.AppleSystemUIFont' if sys.platform=='darwin' else 'Inter',13))
with tempfile.TemporaryDirectory() as temporary:
    bridge=FixtureBridge(Workspace(Path(temporary)))
    backend=bridge.linuxSettings;writes=[]
    backend._send=lambda command:(writes.append(copy.deepcopy(command)) or True)
    state={panel:{'available':False} for panel in PANELS}
    state['audio']={'available':True,'outputs':[{'id':'fixture-output','name':'Fixture Speakers','volume':0.4,'muted':False,'default':True,'writable':True}]}
    state['network']={'available':True,'wifiEnabled':True,'wifiWritable':True,'wifiHardwareEnabled':True,'wifiPresent':True,'interfaces':[{'id':'fixture-wifi','type':'Wi-Fi','state':100,'connection':'Fixture Network'}]}
    state['bluetooth']={'available':True,'hardwareBlocked':False,'adapters':[{'id':'fixture-adapter','name':'Fixture Bluetooth','powered':True,'writable':True}],'devices':[{'id':'fixture-headphones','name':'Fixture Headphones','connected':True,'battery':64}]}
    state['battery']={'available':True,'percent':72,'onBattery':False,'status':'Charging'}
    state['power']={'available':True,'active':'balanced','profiles':['balanced','power-saver']}
    def publish():backend._receive({'type':'state','protocol':1,'state':copy.deepcopy(state)})
    publish()
    engine=QQmlApplicationEngine();warnings=[]
    engine.warnings.connect(lambda items:warnings.extend(str(i) for i in items))
    for key,value in {'Bridge':bridge,'startSettings':False,'startFullscreen':False,'comparisonMode':False,'startNativeWindows':False,'useCutefishShell':True}.items():engine.rootContext().setContextProperty(key,value)
    engine.load(QUrl.fromLocalFile(str(ROOT/'qml/Main.qml')));assert engine.rootObjects(),warnings
    root=engine.rootObjects()[0];root.setWidth(1360);root.setHeight(900);root.show();root.requestActivate()
    desktop=root.findChild(QObject,'desktop');desktop.setProperty('reduceMotion',True);desktop.setProperty('reduceTransparency',True)
    panel=root.findChild(QObject,'systemPanel');controls=root.findChild(QObject,'controlState')
    shell=FixtureShell();root.setProperty('nativeShellState',shell)
    def children(item):
        for child in item.childItems():yield child;yield from children(child)
    def get(name):
        item=next((i for i in children(root.contentItem()) if i.objectName()==name),None)
        item=item if item is not None else root.findChild(QObject,name)
        assert item is not None,name
        return item
    def click(item):
        assert item.isVisible() and item.isEnabled(),item.objectName()
        p=item.mapToScene(QPointF(item.width()/2,item.height()/2))
        QTest.mouseClick(root,Qt.LeftButton,Qt.NoModifier,QPoint(round(p.x()),round(p.y())));QTest.qWait(30)
    def show(section):desktop.openStatusPanel(section);QTest.qWait(35)
    def screenshot(name):
        if '--screenshots' not in sys.argv:return
        image=root.grabWindow();scale=image.width()/root.width()
        image.copy(round(panel.property('x')*scale),round(panel.property('y')*scale),round(panel.property('width')*scale),round(panel.property('height')*scale)).save('/tmp/makos-controls-'+name+'.png')
    controls.reset();show('control')
    positions={'wifi':(0,0,138,62),'nowplaying':(152,0,138,138),'bluetooth':(0,76,138,62),'airdrop':(0,152,138,62),'stagemanager':(152,152,62,62),'mirroring':(228,152,62,62),'darkmode':(0,228,62,62),'capture':(76,228,62,62),'focus':(152,228,138,62),'display':(0,304,290,62),'sound':(0,380,290,62)}
    for name,wanted in positions.items():
        tile=get('controlTile_'+name);actual=(tile.x(),tile.y(),tile.width(),tile.height())
        assert all(abs(a-b)<1 for a,b in zip(actual,wanted)),(name,actual,wanted)
    assert not get('controlCenterMaterial').isVisible()
    assert not get('controlBack').isVisible() and not get('controlClose').isVisible()
    assert get('controlEdit').property('text')=='Edit Controls'
    screenshot('center')
    # The icon toggles the real radio; the tile label still opens its detail.
    click(get('controlToggle_wifi'));assert writes[-1]['action']=='wifi.enabled' and writes[-1]['value'] is False
    assert controls.isActive('wifi'),'Unconfirmed desired value must not replace observed state'
    backend._receive({'type':'result','id':writes[-1]['id'],'ok':False,'message':'Fixture permission denied'})
    show('wifi');assert panel.property('width')==306
    assert not get('controlBack').isVisible() and not get('controlClose').isVisible() and not get('controlPinSwitch').isVisible()
    switch=get('controlWifiSwitch');assert switch.property('checked')
    before=len(writes);click(get('controlOtherNetworks'));assert len(writes)==before
    screenshot('wifi')
    click(switch);assert writes[-1]['action']=='wifi.enabled' and switch.property('checked')
    state['network']['wifiEnabled']=False;publish();backend._receive({'type':'result','id':writes[-1]['id'],'ok':True})
    assert not switch.property('checked')
    show('bluetooth');screenshot('bluetooth');click(get('controlBluetoothSwitch'))
    assert writes[-1]['action']=='bluetooth.powered' and writes[-1]['target']=='fixture-adapter'
    state['bluetooth']['adapters'][0]['powered']=False;publish();backend._receive({'type':'result','id':writes[-1]['id'],'ok':True})
    assert not get('controlBluetoothSwitch').property('checked')
    controls.setPreference('battery.showPercentage','true');show('battery');screenshot('battery')
    assert get('controlBatteryPercentage').property('text')=='72%'
    assert get('statusLabel_battery').property('text')=='72%'
    assert get('controlBatterySource').property('text')=='Power Source: Power Adapter'
    click(get('controlPower_power-saver'));assert writes[-1]['action']=='power.profile' and writes[-1]['value']=='power-saver'
    assert backend.state['power']['active']=='balanced'
    state['power']['active']='power-saver';publish();backend._receive({'type':'result','id':writes[-1]['id'],'ok':True})
    click(get('controlSettings'));assert bridge.launches==['settings:Battery'] and not panel.property('visible')
    # Exercise the actual Main.qml signal routing, not only helper functions.
    osd=get('hardwareLevelOSD');osd.setProperty('dismissalInterval',60)
    show('control');shell.hardwareLevelChanged.emit('volume',0.61,False,'Fixture Speakers',True)
    assert abs(panel.property('volume')-0.61)<0.001 and not osd.property('visible')
    shell.hardwareLevelChanged.emit('brightness',0.35,False,'Display',True)
    assert abs(panel.property('brightness')-0.35)<0.001 and not osd.property('visible')
    assert not get('controlSlider_display').isEnabled(),'No native brightness setter is available'
    before=len(writes);panel.changeLevel('display',0.8);assert len(writes)==before
    panel.close();shell.hardwareLevelChanged.emit('volume',0.7,False,'Fixture Speakers',True);QTest.qWait(15)
    assert osd.property('visible') and osd.property('label')=='Fixture Speakers'
    assert osd.property('width')==290 and osd.property('height')==62 and osd.property('y')==41
    assert abs(osd.property('x')-(root.width()-318))<1
    if '--screenshots' in sys.argv:
        image=root.grabWindow();scale=image.width()/root.width()
        image.copy(round(osd.property('x')*scale),round(osd.property('y')*scale),round(290*scale),round(62*scale)).save('/tmp/makos-controls-osd.png')
    show('control');assert not osd.property('visible'),'Opening CC must dismiss a separate OSD'
    panel.close();shell.hardwareLevelChanged.emit('brightness',0.35,False,'Display',True)
    assert osd.property('visible') and osd.property('kind')=='brightness'
    QTest.qWait(90);assert not osd.property('visible')
    shell.hardwareLevelChanged.emit('brightness',1.2,False,'Display',True);assert not osd.property('visible')
    shell.hardwareLevelChanged.emit('brightness',0.5,False,'Display',False);assert not osd.property('visible')
    native_osd=FixtureNativeOSD();root.setProperty('nativeOsd',native_osd)
    shell.hardwareLevelChanged.emit('volume',0.3,True,'Fixture Speakers',True)
    assert native_osd.showing and native_osd.last==('volume',0.3,True,'Fixture Speakers',True)
    assert not osd.property('visible'),'Native sessions must never open the preview popup'
    show('control');assert not native_osd.showing
    shell.hardwareLevelChanged.emit('volume',0.4,False,'Fixture Speakers',True)
    assert not native_osd.showing and abs(panel.property('volume')-0.4)<0.001
    state['battery']={'available':False};state['bluetooth']={'available':False};state['network']={'available':False};publish()
    show('wifi');assert not get('controlWifiSwitch').isEnabled()
    show('bluetooth');assert not get('controlBluetoothSwitch').isEnabled()
    show('battery');assert get('controlBatteryPercentage').property('text')=='—' and get('statusLabel_battery').property('text')=='—'
    assert not warnings,warnings
    bridge.shutdown();shiboken6.delete(engine)
print('PASS: Tahoe grid geometry, dedicated popovers, actual radio/profile pointer requests, confirmed readback, battery telemetry and hardware OSD routing; injected state only.')
