"""Animation regressions against real desktop QML in isolated offscreen processes."""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
HAS_QT = importlib.util.find_spec('PySide6') is not None

_HARNESS = r'''
import sys,time
from pathlib import Path
from tempfile import TemporaryDirectory
from PySide6.QtCore import QObject,QSettings,QUrl,QRectF
from PySide6.QtGui import QGuiApplication,QFont
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickItem,QQuickWindow
from PySide6.QtTest import QTest
import shiboken6
ROOT=Path(sys.argv[1]);case=sys.argv[2];sys.path.insert(0,str(ROOT))
from main import Bridge
from filesystem import Workspace
app=QGuiApplication([]);app.setFont(QFont('.AppleSystemUIFont',13))
app.setOrganizationName('AnimationInterruptionQA');app.setApplicationName('Isolated')
def rect(item):return tuple(float(item.property(k)) for k in ('x','y','width','height'))
def rect_value(value):return tuple(float(getattr(value,k)()) for k in ('x','y','width','height'))
def near(left,right):return all(abs(a-b)<0.05 for a,b in zip(left,right))
def wait_for(predicate,description):
 deadline=time.monotonic()+5
 while time.monotonic()<deadline:
  QTest.qWait(10)
  if predicate():return
 raise AssertionError('Timed out: '+description)
with TemporaryDirectory() as folder:
 QSettings.setDefaultFormat(QSettings.IniFormat);QSettings.setPath(QSettings.IniFormat,QSettings.UserScope,folder)
 bridge=Bridge(Workspace(Path(folder)/'workspace'));engine=QQmlApplicationEngine();warnings=[]
 engine.warnings.connect(lambda items:warnings.extend(str(e) for e in items))
 for key,value in {'Bridge':bridge,'startFullscreen':False,'comparisonMode':False,'startSettings':False}.items():engine.rootContext().setContextProperty(key,value)
 engine.load(QUrl.fromLocalFile(str(ROOT/'qml/Main.qml')))
 assert engine.rootObjects(),warnings
 root=engine.rootObjects()[0];desktop=root.findChild(QObject,'desktop');state=root.findChild(QObject,'fullscreenState')
 finder=desktop.property('windows').toVariant()[0]
 desktop.setProperty('reduceMotion',False);QTest.qWait(250)
 def fullscreen_rect():return (0.,0.,float(desktop.property('width')),float(desktop.property('height')))
 def pending():return state.property('pendingRestores').toVariant()
 def get_dock():return next(item for item in root.findChildren(QObject) if 'DesktopDock_QMLTYPE' in item.metaObject().className())
 def visual_children(item):
  for child in item.childItems():
   yield child
   yield from visual_children(child)
 def dock_entry(window):
  for item in visual_children(get_dock()):
   if item.metaObject().indexOfProperty('isWindow')<0 or not item.property('isWindow'):continue
   data=item.property('modelData');data=data.toVariant() if hasattr(data,'toVariant') else data
   if data.get('window')==window:return item
  raise AssertionError('No minimized window thumbnail')
 def thumbnail_rect(window):
  visual=dock_entry(window).property('visualItem')
  return rect_value(visual.mapRectToItem(desktop,QRectF(0,visual.height()*0.145,visual.width(),visual.height()*0.71)))
 def start_exit(target,normal):
  full=rect(target);state.exit()
  wait_for(lambda:not near(rect(target),full) and not near(rect(target),normal),'actual intermediate exit geometry')
  assert target.property('geometryAnimating')
 try:
  if case=='reenter':
   original=rect(finder)
   state.enter(finder);wait_for(lambda:near(rect(finder),fullscreen_rect()),'fullscreen geometry')
   start_exit(finder,original)
   state.enter(finder)
   assert near(rect_value(finder.property('fullscreenRestoreGeometry')),original)
   wait_for(lambda:near(rect(finder),fullscreen_rect()),'reentered fullscreen')
   state.exit();wait_for(lambda:near(rect(finder),original),'original normal bounds')
   wait_for(lambda:not pending(),'completed transition cache cleanup')
  elif case=='switch':
   desktop.openApplication('notes');QTest.qWait(50)
   notes=desktop.property('activeWindow');original_finder=rect(finder);original_notes=rect(notes)
   state.enter(finder);wait_for(lambda:near(rect(finder),fullscreen_rect()),'Finder fullscreen')
   state.enter(notes)
   wait_for(lambda:not near(rect(finder),fullscreen_rect()) and not near(rect(finder),original_finder),'Finder exit while Notes enters')
   state.enter(finder)
   assert near(rect_value(finder.property('fullscreenRestoreGeometry')),original_finder)
   wait_for(lambda:near(rect(finder),fullscreen_rect()),'Finder reentry')
   wait_for(lambda:near(rect(notes),original_notes),'Notes bounds after interrupted entry')
   state.exit();wait_for(lambda:near(rect(finder),original_finder),'Finder bounds after switching')
   wait_for(lambda:not pending(),'switch cache cleanup')
  elif case=='resize':
   desktop.setProperty('reduceMotion',True);root.setWidth(1460);root.setHeight(900)
   finder.animateGeometry(400,180,970,590,0);original=rect(finder)
   desktop.setProperty('reduceMotion',False)
   state.enter(finder);wait_for(lambda:near(rect(finder),fullscreen_rect()),'fullscreen before resize')
   start_exit(finder,original)
   root.setWidth(1000);root.setHeight(650);state.enter(finder)
   wait_for(lambda:near(rect(finder),fullscreen_rect()),'resized fullscreen')
   state.exit()
   width=min(original[2],desktop.property('width')-24)
   height=min(original[3],desktop.property('height')-100)
   expected=(max(0,min(original[0],desktop.property('width')-width)),max(30,min(original[1],desktop.property('height')-height-80)),width,height)
   wait_for(lambda:near(rect(finder),expected),'clamped logical bounds after viewport resize')
  elif case=='close-and-reduced-motion':
   original=rect(finder);state.enter(finder)
   wait_for(lambda:near(rect(finder),fullscreen_rect()),'fullscreen before close')
   start_exit(finder,original);assert pending()
   desktop.closeWindow(finder)
   wait_for(lambda:not pending(),'closed target removed from transition cache')
   wait_for(lambda:not shiboken6.isValid(finder),'closed window destroyed')
   desktop.openApplication('notes');notes=desktop.property('activeWindow')
   desktop.setProperty('reduceMotion',True);normal=rect(notes)
   state.enter(notes);assert near(rect(notes),fullscreen_rect())
   state.exit();assert near(rect(notes),normal);assert not pending()
  elif case=='dock-minimize-immediate':
   desktop.setProperty('dockMagnification',False)
   desktop.minimizeWindow(finder)
   captured=rect_value(finder.property('minimizeTarget'))
   assert captured[0]>desktop.width()/2,('destination must be on right of application icons',captured)
   QTest.qWait(40)
   expected=thumbnail_rect(finder)
   assert near(captured,expected),('first-frame target versus settled thumbnail',captured,expected)
  elif case=='dock-multiple':
   desktop.setProperty('dockMagnification',False)
   desktop.newWindow('');second=desktop.property('activeWindow');QTest.qWait(40)
   desktop.minimizeWindow(finder);first_target=rect_value(finder.property('minimizeTarget'))
   QTest.qWait(40);assert near(first_target,thumbnail_rect(finder))
   desktop.minimizeWindow(second);second_target=rect_value(second.property('minimizeTarget'))
   QTest.qWait(40)
   assert near(second_target,thumbnail_rect(second)),(second_target,thumbnail_rect(second))
   assert thumbnail_rect(second)[0]>thumbnail_rect(finder)[0]+thumbnail_rect(finder)[2]
   expected=thumbnail_rect(finder);desktop.focusWindow(finder,False)
   assert near(rect_value(finder.property('minimizeTarget')),expected)
   QTest.qWait(40)
   expected=thumbnail_rect(second);desktop.focusWindow(second,False)
   assert near(rect_value(second.property('minimizeTarget')),expected)
  elif case=='dock-magnified-restore':
   desktop.setProperty('dockMagnification',False)
   desktop.minimizeWindow(finder);QTest.qWait(40)
   entry=dock_entry(finder)
   # Exercise real delegate geometry and its animations without moving the
   # user's pointer. The bump property is what the hover calculation drives.
   entry.setProperty('bump',1.0);QTest.qWait(150)
   root.setWidth(root.width()+240);QTest.qWait(40)
   visual=entry.property('visualItem');visual.setScale(0.94);QTest.qWait(120)
   expected=thumbnail_rect(finder)
   assert expected[2]>get_dock().property('baseIconSize')+15
   desktop.focusWindow(finder,False)
   assert near(rect_value(finder.property('minimizeTarget')),expected),(rect_value(finder.property('minimizeTarget')),expected)
  elif case=='dock-restore':
   desktop.setProperty('reduceMotion',True)
   dock=next(item for item in root.findChildren(QObject) if 'DesktopDock_QMLTYPE' in item.metaObject().className())
   desktop.minimizeWindow(finder);QTest.qWait(25)
   previous=rect_value(finder.property('minimizeTarget'))
   root.setWidth(root.width()+300);QTest.qWait(25)
   expected=rect_value(dock.targetFor(finder))
   assert not near(previous,expected),'Fixture must change the Dock destination'
   desktop.focusWindow(finder,False)
   assert near(rect_value(finder.property('minimizeTarget')),expected),(previous,expected,rect_value(finder.property('minimizeTarget')))
   assert not finder.property('minimized') and finder.property('minimizeProgress')==0
  else:raise AssertionError(case)
  assert not warnings,'\n'.join(warnings)
 finally:
  root.close();shiboken6.delete(engine);bridge.shutdown()
print(case+' passed')
'''


@unittest.skipUnless(HAS_QT, 'Run using the project Qt environment')
class AnimationInterruptionTests(unittest.TestCase):
    def run_case(self, case):
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen',
                   QT_QUICK_CONTROLS_STYLE='Basic', QT_QUICK_BACKEND='software')
        result = subprocess.run([sys.executable, '-c', _HARNESS, str(ROOT), case],
                                env=env, capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stdout + '\n' + result.stderr)

    def test_reentering_during_exit_preserves_original_geometry(self):
        self.run_case('reenter')

    def test_switching_windows_preserves_each_logical_restore_geometry(self):
        self.run_case('switch')

    def test_viewport_resize_during_exit_keeps_clamped_restore_geometry(self):
        self.run_case('resize')

    def test_closed_targets_are_released_and_reduced_motion_is_immediate(self):
        self.run_case('close-and-reduced-motion')

    def test_first_minimize_targets_right_thumbnail_before_next_frame(self):
        self.run_case('dock-minimize-immediate')

    def test_multiple_minimized_windows_have_distinct_right_side_targets(self):
        self.run_case('dock-multiple')

    def test_restore_targets_actual_magnified_and_pressed_thumbnail(self):
        self.run_case('dock-magnified-restore')

    def test_restore_uses_current_dock_target_after_viewport_resize(self):
        self.run_case('dock-restore')


if __name__ == '__main__':
    unittest.main()
