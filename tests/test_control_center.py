"""Persistent Control Center state and real offscreen shell gestures.

Each case gets a fresh Qt process and temporary desktop workspace/settings.
"""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
HAS_QT = importlib.util.find_spec('PySide6') is not None

_STATE_HARNESS = r"""
import json,sys,time
from pathlib import Path
from tempfile import TemporaryDirectory
from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine,QQmlComponent
from PySide6.QtQuick import QQuickItem
from PySide6.QtTest import QTest
import shiboken6
ROOT=Path(sys.argv[1]);case=sys.argv[2];sys.path.insert(0,str(ROOT))
from main import Bridge
from filesystem import Workspace
app=QGuiApplication([])
def value(obj,key):
 result=obj.property(key)
 return result.toVariant() if hasattr(result,'toVariant') else result
def wait_for(predicate,description):
 deadline=time.monotonic()+4
 while time.monotonic()<deadline:
  QTest.qWait(20)
  if predicate():return
 raise AssertionError('Timed out: '+description)
class Fixture:
 def __init__(self,folder):
  self.bridge=Bridge(Workspace(folder));self.errors=[];self.engine=QQmlApplicationEngine()
  self.engine.warnings.connect(lambda errors:self.errors.extend(str(e) for e in errors))
  self.engine.rootContext().setContextProperty('Bridge',self.bridge)
  self.desktop_component=QQmlComponent(self.engine)
  self.desktop_component.setData(b'''import QtQml
QtObject {
 id:desk
 property bool dark:false
 property bool showClock:true
 property bool showSearchIcon:true
 property var windows:[]
 property string openedApp:""
 property int infoCount:0
 function openApplication(id) { openedApp=id; }
 function startCountdown(controls,seconds) { controls.startTimer(seconds); }
 function showInfo(title,message) { infoCount++; }
 property QtObject trackPage:QtObject {
  property var playingTrack:null
  property bool playbackPlaying:false
  property string lastCommand:""
  function command(name) {lastCommand=name;}
 }
 property QtObject trackWindow:QtObject {
  property string appKind:"music"
  property bool closing:false
  property var pageItem:desk.trackPage
 }
 function music(available,playing) {
  trackPage.playingTrack=available ? {name:"Local Test Track"} : null;
  trackPage.playbackPlaying=playing;windows=[trackWindow];
 }
}''',QUrl())
  self.desktop=self.desktop_component.create();assert self.desktop,self.desktop_component.errors();self.desktop.setParent(self.engine)
  self.component=QQmlComponent(self.engine,QUrl.fromLocalFile(str(ROOT/'qml/ControlState.qml')))
  self.state=self.component.createWithInitialProperties({'desktop':self.desktop});assert self.state,self.component.errors();self.state.setParent(self.engine)
 def close(self):
  self.state.deleteLater();self.desktop.deleteLater();QTest.qWait(30);shiboken6.delete(self.engine);self.bridge.shutdown()
with TemporaryDirectory() as folder:
 fixture=Fixture(folder)
 try:
  state=fixture.state;desktop=fixture.desktop;suite=fixture.bridge.suite
  if case=='persistence-layout':
   initial=value(state,'layout');assert initial
   state.setInMenu('wifi',False);state.setInMenu('airdrop',True);state.setMode('focus','Always')
   state.removeControl('wifi');state.addControl('timer','small');state.addControl('timer','large')
   assert sum(e['id']=='timer' for e in value(state,'layout'))==1
   state.resizeControl('timer','medium');state.moveControl('timer',0)
   state.moveMenuItem('airdrop','wifi')
   expected=value(state,'layout');expected_order=value(state,'menuOrder')
   assert expected[0]=={'id':'timer','size':'medium'}
   assert not state.inMenu('wifi') and state.inMenu('airdrop') and state.mode('focus')=='Always'
   assert not fixture.errors,fixture.errors
   fixture.close();fixture=Fixture(folder);state=fixture.state
   assert value(state,'layout')==expected
   assert value(state,'menuOrder')==expected_order
   assert not state.inMenu('wifi') and state.inMenu('airdrop') and state.mode('focus')=='Always'
   state.reset()
   assert value(state,'layout')==initial
   assert state.inMenu('wifi') and not state.inMenu('airdrop')
   assert state.mode('focus')=='When Active'
  elif case=='when-active':
   for ident in ('focus','nowplaying','sound','timer','display'):
    state.setInMenu(ident,True);state.setMode(ident,'When Active');assert not state.menuVisible(ident),ident
   suite.setPreference('focus.doNotDisturb','true');assert state.menuVisible('focus')
   suite.setPreference('focus.doNotDisturb','false');assert not state.menuVisible('focus')
   desktop.music(True,False);assert not state.menuVisible('nowplaying')
   desktop.music(True,True);assert state.menuVisible('nowplaying') and state.menuVisible('sound')
   assert value(state,'nowPlaying')['title']=='Local Test Track'
   state.mediaCommand('playPause');assert desktop.property('trackPage').property('lastCommand')=='playPause'
   desktop.music(True,False);assert not state.menuVisible('nowplaying')
   suite.setPreference('display.brightness','0.6');assert state.menuVisible('display')
   suite.setPreference('display.brightness','1');assert not state.menuVisible('display')
   fixture.desktop.startCountdown(state,15);assert state.menuVisible('timer')
   state.pauseTimer();assert state.menuVisible('timer')
   state.resetTimer();assert not state.menuVisible('timer')
   desktop.setProperty('windows',[]);state.mediaCommand('playPause');assert desktop.property('openedApp')=='music'
   for ident in ('wifi','bluetooth','airdrop','mirroring','lowpower'):
    assert not state.isActive(ident),ident
  elif case=='invalid-preferences':
   initial=value(state,'layout')
   suite.setPreference('control.layout','not json');assert value(state,'layout')==initial
   suite.setPreference('control.layout','{}');assert value(state,'layout')==initial
   suite.setPreference('control.layout',json.dumps([None,{},'wrong',{'id':'missing','size':'small'},{'id':'wifi','size':'impossible'},{'id':'wifi','size':'small'}]))
   assert value(state,'layout')==[{'id':'wifi','size':'medium'}]
   suite.setPreference('control.barOrder',json.dumps(['missing','wifi','wifi',None,{},'clock']))
   order=value(state,'menuOrder');assert order[0]=='wifi' and len(order)==len(set(order)) and 'missing' not in order and 'clock' not in order
   suite.setPreference('control.mode.focus','Sometimes');assert state.mode('focus')=='Always'
   previous=value(state,'layout');state.addControl('missing','small');state.resizeControl('wifi','impossible');state.moveControl('missing',0)
   assert value(state,'layout')==previous
   state.setInMenu('missing',True);state.setMode('missing','Always')
   assert not state.menuVisible('missing')
   assert suite.preference('control.bar.missing','untouched')=='untouched'
   assert suite.preference('control.mode.missing','untouched')=='untouched'
  elif case=='timer-pause-restart':
   fixture.desktop.startCountdown(state,8);QTest.qWait(1100);state.pauseTimer()
   remaining=state.property('timerRemaining');assert 1<=remaining<8
   assert not state.property('timerRunning')
   assert not fixture.errors,fixture.errors
   fixture.close();fixture=Fixture(folder);state=fixture.state
   assert state.property('timerRemaining')==remaining and not state.property('timerRunning')
   fixture.desktop.startCountdown(state,0);assert state.property('timerRunning') and state.property('timerRemaining')==remaining
   fixture.desktop.startCountdown(state,20);assert state.property('timerRemaining')==20
   assert not fixture.errors,fixture.errors
   fixture.close();fixture=Fixture(folder);state=fixture.state
   assert state.property('timerRunning') and 18<=state.property('timerRemaining')<=20
   state.resetTimer();assert state.property('timerRemaining')==0 and not state.property('timerRunning')
  elif case=='invalid-timer-preferences':
   suite.setPreference('control.timerDeadline','not a number');suite.setPreference('control.timerPaused','-20')
   fixture.close();fixture=Fixture(folder);state=fixture.state
   assert not state.property('timerRunning') and state.property('timerRemaining')==0
   fixture.bridge.suite.setPreference('control.timerPaused','9999999999')
   fixture.close();fixture=Fixture(folder);state=fixture.state
   assert 0<=state.property('timerRemaining')<=86400,state.property('timerRemaining')
   fixture.bridge.suite.setPreference('control.timerDeadline',str(int(time.time()*1000)+10**12))
   fixture.close();fixture=Fixture(folder);state=fixture.state
   assert state.property('timerRunning') and 0<state.property('timerRemaining')<=86400,state.property('timerRemaining')
  elif case=='timer-bounds-completion':
   fixture.desktop.startCountdown(state,999999);assert state.property('timerRemaining')==86400
   fixture.desktop.startCountdown(state,-100);assert state.property('timerRemaining')==1
   wait_for(lambda:not state.property('timerRunning'),'timer completion')
   assert state.property('timerRemaining')==0 and desktop.property('infoCount')==1
   suite.setPreference('focus.doNotDisturb','true');fixture.desktop.startCountdown(state,1)
   wait_for(lambda:not state.property('timerRunning'),'Focus silenced timer completion')
   assert desktop.property('infoCount')==1
   assert suite.preference('control.timerDeadline','missing')=='0'
  else:raise AssertionError(case)
  assert not fixture.errors,'\n'.join(fixture.errors)
 finally:fixture.close()
print(case+' passed')
"""


_UI_HARNESS = r"""
import json,sys,time
from pathlib import Path
from tempfile import TemporaryDirectory
from PySide6.QtCore import QObject,QSettings,QUrl,Qt,QPoint,QPointF
from PySide6.QtGui import QGuiApplication,QFont
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickItem,QQuickWindow
from PySide6.QtTest import QTest
import shiboken6
ROOT=Path(sys.argv[1]);case=sys.argv[2];sys.path.insert(0,str(ROOT))
from main import Bridge
from filesystem import Workspace
app=QGuiApplication([]);app.setFont(QFont('.AppleSystemUIFont',13));app.setOrganizationName('ControlCenterGestureQA');app.setApplicationName('Isolated')
def value(obj,key):
 result=obj.property(key)
 return result.toVariant() if hasattr(result,'toVariant') else result
def wait_for(predicate,description):
 deadline=time.monotonic()+4
 while time.monotonic()<deadline:
  QTest.qWait(20)
  if predicate():return
 raise AssertionError('Timed out: '+description)
def visual_children(item):
 for child in item.childItems():
  yield child
  yield from visual_children(child)
with TemporaryDirectory() as folder:
 QSettings.setDefaultFormat(QSettings.IniFormat);QSettings.setPath(QSettings.IniFormat,QSettings.UserScope,folder)
 bridge=Bridge(Workspace(Path(folder)/'workspace'));engine=QQmlApplicationEngine();warnings=[]
 engine.warnings.connect(lambda errors:warnings.extend(str(e) for e in errors))
 for key,val in {'Bridge':bridge,'startFullscreen':False,'comparisonMode':False,'startSettings':False}.items():engine.rootContext().setContextProperty(key,val)
 engine.load(QUrl.fromLocalFile(str(ROOT/'qml/Main.qml')));assert engine.rootObjects(),warnings
 root=engine.rootObjects()[0];root.setWidth(1500);root.setHeight(950)
 desktop=root.findChild(QObject,'desktop');desktop.setProperty('reduceMotion',True)
 desktop.setProperty('showClock',True);desktop.setProperty('dockAutoHide',False)
 controls=root.findChild(QObject,'controlState');suite=bridge.suite;root.requestActivate();QTest.qWait(150)
 def named(name):
  for item in visual_children(root.contentItem()):
   if item.objectName()==name:return item
  return root.findChild(QObject,name)
 def require(name):
  obj=named(name);assert obj is not None,'Missing '+name
  return obj
 def show_item(item):
  ancestor=item.parentItem()
  while ancestor:
   if ancestor.metaObject().indexOfProperty('contentY')>=0 and ancestor.property('contentHeight') is not None:
    position=item.mapToItem(ancestor,0,0)
    offset=position.y()-8 if position.y()<8 else position.y()+item.height()-ancestor.height()+8 if position.y()+item.height()>ancestor.height()-8 else 0
    if offset:
     limit=max(0,ancestor.property('contentHeight')-ancestor.height())
     ancestor.setProperty('contentY',max(0,min(limit,ancestor.property('contentY')+offset)))
     QTest.qWait(30)
   ancestor=ancestor.parentItem()
 def point(item,x=None,y=None):
  p=item.mapToScene(QPointF(item.width()/2 if x is None else x,item.height()/2 if y is None else y))
  return QPoint(round(p.x()),round(p.y()))
 def click(name,x=None,y=None,button=Qt.LeftButton):
  item=require(name);show_item(item)
  assert item.isVisible() and item.isEnabled(),('not clickable',name)
  p=point(item,x,y);assert 0<=p.x()<root.width() and 0<=p.y()<root.height(),(name,p,root.size())
  QTest.mouseClick(root,button,Qt.NoModifier,p);QTest.qWait(40)
 def toggle_row(name):
  item=require(name);click(name,item.width()-16)
 def choose(name,index):
  click(name);QTest.keyClick(root,Qt.Key_Home)
  for _ in range(index):QTest.keyClick(root,Qt.Key_Down)
  QTest.keyClick(root,Qt.Key_Return);QTest.qWait(40)
 def type_text(name,text):
  click(name);QTest.keyClick(root,Qt.Key_A,Qt.ControlModifier);
  for char in text:QTest.keyClick(root,ord(char.upper()),Qt.ShiftModifier if char.isupper() else Qt.NoModifier)
  QTest.qWait(40)
 def settings():
  desktop.openSettings('Menu Bar');QTest.qWait(80);assert require('menuBarSettings').isVisible()
 try:
  if case=='status-popups':
   for ident in ('wifi','bluetooth','sound'):controls.setInMenu(ident,True)
   controls.setMode('sound','Always');QTest.qWait(50)
   click('statusButton_wifi');panel=require('systemPanel')
   assert panel.property('visible') and panel.property('section')=='wifi'
   button=require('statusButton_wifi');edge=button.mapToScene(QPointF(button.width(),button.height())).x()
   expected=max(8,min(desktop.width()-panel.property('width')-8,edge-panel.property('width')))
   assert abs(panel.property('x')-expected)<1,(panel.property('x'),expected)
   assert require('controlUnavailableMessage').isVisible()
   assert 'not connected' in require('controlUnavailableMessage').property('text')
   assert not require('controlFocusSwitch').isVisible()
   QTest.mouseMove(root,point(require('statusButton_bluetooth')));QTest.qWait(50)
   assert panel.property('visible') and panel.property('section')=='bluetooth',(panel.property('visible'),panel.property('section'),point(require('statusButton_bluetooth')),require('statusBarTracking').property('origin'),require('statusBarTracking').property('containsMouse'))
   click('statusButton_bluetooth');assert not panel.property('visible')
   click('statusButton_control');assert panel.property('visible') and panel.property('section')=='control'
   QTest.mouseClick(root,Qt.LeftButton,Qt.NoModifier,QPoint(4,120));QTest.qWait(40)
   assert not panel.property('visible')
   click('statusButton_sound');assert panel.property('visible')
   QTest.keyClick(root,Qt.Key_Escape);QTest.qWait(40);assert not panel.property('visible')
  elif case=='menu-reorder-remove':
   for ident in ('wifi','bluetooth'):controls.setInMenu(ident,True)
   QTest.qWait(40);start=point(require('statusButton_wifi'));end=point(require('statusButton_bluetooth'))
   QTest.mousePress(root,Qt.LeftButton,Qt.ControlModifier,start)
   QTest.mouseMove(root,QPoint(end.x()-2,end.y()),20)
   QTest.mouseRelease(root,Qt.LeftButton,Qt.ControlModifier,end);QTest.qWait(60)
   order=value(controls,'menuOrder');assert order.index('wifi')<order.index('bluetooth'),order
   assert json.loads(suite.preference('control.barOrder','[]'))==order
   start=point(require('statusButton_wifi'));end=QPoint(start.x(),110)
   QTest.mousePress(root,Qt.LeftButton,Qt.ControlModifier,start);QTest.mouseMove(root,end,20)
   QTest.mouseRelease(root,Qt.LeftButton,Qt.ControlModifier,end);QTest.qWait(60)
   assert not controls.inMenu('wifi')
   settings();click('moduleToggle_wifi');assert controls.inMenu('wifi')
   assert suite.preference('control.bar.wifi','')=='true'
  elif case=='gallery-layout-reset':
   defaults=value(controls,'layout');settings();click('addControls')
   gallery=require('controlGallery');assert gallery.property('visible')
   type_text('gallerySearch','Timer');click('gallerySize_timer_small');click('galleryAdd_timer')
   assert next(item for item in value(controls,'layout') if item['id']=='timer')['size']=='small'
   click('galleryClose');assert not gallery.property('visible')
   click('statusButton_control');click('controlEdit');assert require('systemPanel').property('editing')
   click('controlResize_timer');assert next(item for item in value(controls,'layout') if item['id']=='timer')['size']=='medium'
   before=next(i for i,item in enumerate(value(controls,'layout')) if item['id']=='timer')
   click('controlTile_timer');click('controlMoveEarlier')
   assert next(i for i,item in enumerate(value(controls,'layout')) if item['id']=='timer')==before-1
   click('controlRemove_timer');assert all(item['id']!='timer' for item in value(controls,'layout'))
   click('controlAddControls');assert gallery.property('visible')
   type_text('gallerySearch','AirDrop');choose('galleryTarget',1);click('galleryAdd_airdrop')
   assert controls.inMenu('airdrop') and suite.preference('control.bar.airdrop','')=='true'
   click('galleryClose');settings();click('resetControlCenter')
   assert require('resetControlCenterPopup').property('visible') and controls.inMenu('airdrop'),('Reset confirmation did not open',point(require('resetControlCenter')))
   click('resetCancel');assert controls.inMenu('airdrop')
   click('resetControlCenter');click('resetConfirm')
   assert value(controls,'layout')==defaults and not controls.inMenu('airdrop')
   assert not require('resetControlCenterPopup').property('visible')
  elif case=='tile-drag':
   controls.saveLayout([{'id':'wifi','size':'small'},{'id':'bluetooth','size':'small'},{'id':'timer','size':'small'},{'id':'darkmode','size':'small'}])
   click('statusButton_control');click('controlEdit')
   start=point(require('controlTile_wifi'));end=point(require('controlTile_darkmode'))
   QTest.mousePress(root,Qt.LeftButton,Qt.NoModifier,start)
   QTest.mouseMove(root,QPoint(start.x()+20,start.y()),20)
   QTest.mouseMove(root,end,20);QTest.mouseRelease(root,Qt.LeftButton,Qt.NoModifier,end);QTest.qWait(70)
   assert [item['id'] for item in value(controls,'layout')]==['bluetooth','timer','darkmode','wifi'],value(controls,'layout')
  elif case=='focus-timer-gestures':
   controls.addControl('timer','small');click('statusButton_control');click('controlTile_focus')
   assert require('systemPanel').property('section')=='focus'
   click('controlFocusSwitch');assert controls.isActive('focus') and suite.preference('focus.doNotDisturb','false')=='true'
   click('controlBack');assert require('systemPanel').property('section')=='control'
   click('controlTile_timer');assert require('systemPanel').property('section')=='timer'
   click('controlTimerStart');assert controls.property('timerRunning') and controls.property('timerRemaining')>0
   click('controlTimerStart');assert not controls.property('timerRunning') and controls.property('timerRemaining')>0
   click('controlTimerReset');assert controls.property('timerRemaining')==0
   click('controlBack');assert require('systemPanel').property('section')=='control'
   click('statusButton_sound');assert require('systemPanel').property('section')=='sound'
  elif case=='slider-continuity':
   click('statusButton_control');slider=require('controlSlider_sound');show_item(slider)
   start=point(slider,slider.width()*0.75);QTest.mousePress(root,Qt.LeftButton,Qt.NoModifier,start)
   observed=[]
   for fraction in (0.5,0.25,0.65,0.9):
    assert shiboken6.isValid(slider),'Volume preference change destroyed the grabbed slider'
    QTest.mouseMove(root,point(slider,slider.width()*fraction),25);QTest.qWait(30)
    observed.append(float(suite.preference('sound.volume','0.75')))
    assert shiboken6.isValid(slider) and require('controlSlider_sound')==slider,'Slider delegate replaced during drag'
   QTest.mouseRelease(root,Qt.LeftButton,Qt.NoModifier,point(slider,slider.width()*0.9));QTest.qWait(40)
   assert observed[1]<observed[0] and observed[2]>observed[1] and observed[3]>observed[2],observed
   assert observed[-1]>0.8,observed
  elif case=='clock-fields':
   settings();click('clockOptions');assert require('clockOptionsPopup').property('visible')
   toggle_row('clockShowDate');toggle_row('clockShowWeekday')
   assert suite.preference('clock.date','Always')=='Never' and suite.preference('clock.weekday','true')=='false'
   assert desktop.property('clockDateText')==''
   toggle_row('clockShowSeconds');assert desktop.property('clockSeconds') and len(desktop.property('clockTimeText').split(':'))==3
   toggle_row('clockFlashSeparators');assert suite.preference('clock.flash','false')=='true'
   click('clockStyleAnalog');assert desktop.property('clockAnalog')
   assert not require('clockShowSeconds').isEnabled() and not require('clockFlashSeparators').isEnabled()
   click('clockStyleDigital');assert not desktop.property('clockAnalog') and require('clockShowSeconds').isEnabled()
   assert not require('clockShowAMPM').isEnabled()
   suite.setPreference('clock.24hour','false');QTest.qWait(30);toggle_row('clockShowAMPM')
   assert suite.preference('clock.ampm','true')=='false'
   for name in ('clockAnnounceTime','clockAnnounceInterval','clockAnnounceVoice','clockCustomizeVoice'):assert not require(name).isEnabled(),name
   click('clockOptionsDone');assert not require('clockOptionsPopup').property('visible')
   click('clockOptions');assert require('clockShowSeconds').property('checked') and not require('clockShowDate').property('checked')
  elif case=='battery-fields':
   settings();click('batteryOptions');assert require('batteryOptionsPopup').property('visible')
   toggle_row('batteryShowPercentage');assert suite.preference('battery.showPercentage','false')=='true'
   choose('batteryEnergyMode',0);assert suite.preference('battery.energyMode','Always')=='When Active'
   click('batteryOptionsDone');assert not require('batteryOptionsPopup').property('visible')
   status=require('statusButton_battery').parentItem()
   labels=[item.property('text') for item in visual_children(status) if item.metaObject().indexOfProperty('text')>=0]
   assert '—%' in labels and '100%' not in labels,labels
   click('statusButton_battery');assert 'not available' in require('controlUnavailableMessage').property('text')
  else:raise AssertionError(case)
  assert not warnings,'\n'.join(warnings)
 finally:
  root.close();shiboken6.delete(engine);bridge.shutdown()
print(case+' passed')
"""


@unittest.skipUnless(HAS_QT, 'Run with the project Qt environment')
class ControlCenterTests(unittest.TestCase):
    def run_case(self, case, harness=_STATE_HARNESS):
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen',
                   QT_QUICK_CONTROLS_STYLE='Basic', QT_QUICK_BACKEND='software')
        result = subprocess.run([sys.executable, '-c', harness, str(ROOT), case],
                                env=env, capture_output=True, text=True, timeout=25)
        self.assertEqual(result.returncode, 0, result.stdout + '\n' + result.stderr)

    def test_status_popups_anchor_toggle_hover_and_dismiss_with_real_gestures(self):
        self.run_case('status-popups', _UI_HARNESS)

    def test_menu_bar_drag_reorder_remove_and_settings_pin(self):
        self.run_case('menu-reorder-remove', _UI_HARNESS)

    def test_settings_gallery_layout_edits_and_confirmed_reset(self):
        self.run_case('gallery-layout-reset', _UI_HARNESS)

    def test_control_tile_drag_reorders_persistent_layout(self):
        self.run_case('tile-drag', _UI_HARNESS)

    def test_focus_timer_and_detail_back_routes_use_real_controls(self):
        self.run_case('focus-timer-gestures', _UI_HARNESS)

    def test_volume_slider_keeps_pointer_grab_through_multiple_preference_updates(self):
        self.run_case('slider-continuity', _UI_HARNESS)

    def test_clock_options_change_menu_bar_and_preserve_unavailable_voice_state(self):
        self.run_case('clock-fields', _UI_HARNESS)

    def test_battery_fields_persist_without_fabricated_telemetry(self):
        self.run_case('battery-fields', _UI_HARNESS)

    def test_menu_choices_and_layout_edits_persist_and_reset(self):
        self.run_case('persistence-layout')

    def test_when_active_tracks_focus_local_music_timer_and_brightness(self):
        self.run_case('when-active')

    def test_invalid_preferences_are_sanitized_and_unknown_controls_ignored(self):
        self.run_case('invalid-preferences')

    def test_timer_pause_resume_restart_and_reopen_preserve_time(self):
        self.run_case('timer-pause-restart')

    def test_invalid_saved_timer_values_cannot_create_negative_or_unbounded_countdowns(self):
        self.run_case('invalid-timer-preferences')

    def test_timer_bounds_completion_and_focus_notification_behavior(self):
        self.run_case('timer-bounds-completion')


if __name__ == '__main__':
    unittest.main()
