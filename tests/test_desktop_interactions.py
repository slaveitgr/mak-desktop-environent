"""Real QTest gestures against Main.qml, isolated from native UI and user files."""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
HAS_QT = importlib.util.find_spec('PySide6') is not None

_HARNESS = r'''
import json, sqlite3, sys, time
from pathlib import Path
from tempfile import TemporaryDirectory
from PySide6.QtCore import QObject, QSettings, QUrl, Qt, QPoint, QPointF, QEvent, QCoreApplication
from PySide6.QtGui import QGuiApplication, QFont, QMouseEvent
from PySide6.QtQml import QQmlApplicationEngine, QJSValue
from PySide6.QtQuick import QQuickItem, QQuickWindow
from PySide6.QtTest import QTest
import shiboken6
ROOT=Path(sys.argv[1]); case=sys.argv[2]; sys.path.insert(0,str(ROOT))
from main import Bridge
from filesystem import Workspace
app=QGuiApplication([]); app.setFont(QFont('.AppleSystemUIFont',13))
app.setOrganizationName('DesktopGestureQA'); app.setApplicationName('Isolated')
def value(item,name):
 result=item.property(name)
 return result.toVariant() if isinstance(result,QJSValue) else result

def visual(item):
 for child in item.childItems():
  yield child
  yield from visual(child)

def wait_for(predicate,description,timeout=3):
 deadline=time.monotonic()+timeout
 while time.monotonic()<deadline:
  QTest.qWait(10)
  if predicate(): return
 raise AssertionError('Timed out: '+description)

with TemporaryDirectory() as folder:
 QSettings.setDefaultFormat(QSettings.IniFormat); QSettings.setPath(QSettings.IniFormat,QSettings.UserScope,folder)
 workspace=Path(folder)/'workspace'; workspace.mkdir()
 if case!='empty':
  (workspace/'Desktop/Folder').mkdir(parents=True)
  (workspace/'Desktop/alpha.txt').write_text('alpha desktop fixture')
  (workspace/'Desktop/beta.txt').write_text('beta desktop fixture')
  (workspace/'Documents/Target').mkdir(parents=True)
  (workspace/'Documents/incoming.txt').write_text('move from Finder')
  (workspace/'Documents/copy.txt').write_text('copy from Finder')
 bridge=Bridge(Workspace(workspace)); engine=QQmlApplicationEngine(); warnings=[]; errors=[]
 engine.warnings.connect(lambda rows:warnings.extend(str(row) for row in rows)); bridge.error.connect(errors.append)
 for key,data in {'Bridge':bridge,'startFullscreen':False,'comparisonMode':False,'startSettings':False}.items():engine.rootContext().setContextProperty(key,data)
 engine.load(QUrl.fromLocalFile(str(ROOT/'qml/Main.qml')))
 assert engine.rootObjects(),warnings
 root=engine.rootObjects()[0]; root.resize(1360,900)
 desktop=root.findChild(QObject,'desktop'); desktop.setProperty('reduceMotion',True)
 surface=root.findChild(QObject,'desktopFiles'); context=root.findChild(QObject,'contextMenu'); top=root.findChild(QObject,'topMenu')
 finder=value(desktop,'windows')[0]
 finder.setX(40);finder.setY(80);finder.setWidth(820);finder.setHeight(610)
 root.requestActivate();QTest.qWait(150)

 def point(item,dx=None,dy=None):
  p=item.mapToScene(QPointF(item.width()/2 if dx is None else dx,item.height()/2 if dy is None else dy))
  return QPoint(round(p.x()),round(p.y()))
 def click(item,button=Qt.LeftButton,modifiers=Qt.NoModifier,dx=None,dy=None):
  QTest.mouseClick(root,button,modifiers,point(item,dx,dy));QTest.qWait(35)
 def click_point(p,button=Qt.LeftButton,modifiers=Qt.NoModifier):
  QTest.mouseClick(root,button,modifiers,p);QTest.qWait(35)
 def drag(start,end,modifiers=Qt.NoModifier):
  if modifiers & Qt.AltModifier:QTest.keyPress(root,Qt.Key_Alt)
  QTest.mouseMove(root,start,10);QTest.mousePress(root,Qt.LeftButton,modifiers,start,10)
  for step in range(1,17):
   p=QPoint(round(start.x()+(end.x()-start.x())*step/16),round(start.y()+(end.y()-start.y())*step/16))
   if modifiers:
    # QTest.mouseMove has no modifier argument; send a real Qt move event
    # carrying held Option between QTest press/release, without calling UI methods.
    event=QMouseEvent(QEvent.MouseMove,QPointF(p),QPointF(root.mapToGlobal(p)),Qt.NoButton,Qt.LeftButton,modifiers)
    QCoreApplication.sendEvent(root,event);QTest.qWait(15)
   else:QTest.mouseMove(root,p,15)
  QTest.mouseRelease(root,Qt.LeftButton,modifiers,end,15)
  if modifiers & Qt.AltModifier:QTest.keyRelease(root,Qt.Key_Alt)
  QTest.qWait(80)
 def close_menu():
  QTest.keyClick(root,Qt.Key_Escape);QTest.qWait(20)
 def rows(menu):return value(menu,'rows')
 def menu_row(menu,command):
  viewport=value(menu,'contentItem')
  candidates=[]
  for item in visual(viewport):
   data=value(item,'modelData') if item.metaObject().indexOfProperty('modelData')>=0 else None
   if isinstance(data,dict) and data.get('command')==command and abs(item.height()-25)<.1:candidates.append(item)
  assert candidates,(command,rows(menu))
  return candidates[0]
 def choose(menu,command):
  row=next(r for r in rows(menu) if r.get('command')==command)
  assert row.get('enabled',True),(command,row)
  click(menu_row(menu,command));wait_for(lambda:not menu.property('visible'),'menu closes after '+command)
 def desktop_tile(path):
  result=next((item for item in visual(surface) if item.objectName()=='desktopFile:'+path),None)
  assert result,path
  return result
 def finder_tile(path):
  found=[]
  for item in visual(finder):
   data=value(item,'modelData') if item.metaObject().indexOfProperty('modelData')>=0 else None
   if isinstance(data,dict) and data.get('path')==path and item.width()>=80 and item.height()>=24 and item.isVisible():found.append(item)
  assert found,('Finder item not found',path,value(value(finder,'browser'),'files'))
  return found[0]
 def title(name):
  chrome=root.findChild(QObject,'topChrome')
  return next(item for item in visual(chrome) if item.metaObject().indexOfProperty('modelData')>=0 and value(item,'modelData')==name and item.height()==30)
 def top_action(name,command):
  click(title(name));wait_for(lambda:top.property('visible'),'top menu '+name);choose(top,command)
 def text_input(text):
  # Prompts select their existing value; use actual key events to replace it.
  QTest.qWait(30)
  for char in text:
   key=Qt.Key_Space if char==' ' else Qt.Key_Period if char=='.' else Qt.Key(ord(char.upper()))
   QTest.keyClick(root,key,Qt.ShiftModifier if char.isupper() else Qt.NoModifier)
  QTest.keyClick(root,Qt.Key_Return);QTest.qWait(60)
 def assert_selected(*paths):assert set(value(surface,'selected'))==set(paths),(value(surface,'selected'),paths)

 try:
  if case=='empty':
   assert (workspace/'Desktop').is_dir()
   assert value(value(surface,'browser'),'files')==[]
   finder.setProperty('appHidden',True)
   click_point(QPoint(1050,350),Qt.RightButton)
   assert context.property('visible')
   assert any(r.get('command')=='newfolder' and r.get('enabled',True) for r in rows(context))
   choose(context,'newfolder');text_input('created folder')
   assert (workspace/'Desktop/created folder').is_dir(),list((workspace/'Desktop').iterdir())
  elif case=='selection':
   finder.setProperty('appHidden',True)
   click_point(QPoint(1050,350),Qt.RightButton)
   commands={r.get('command') for r in rows(context)}
   assert {'newfolder','desktopinfo','paste','settings:Wallpaper','desktopcleanup'}<=commands
   assert not next(r for r in rows(context) if r.get('command')=='paste')['enabled']
   close_menu()
   click(desktop_tile('Desktop/Folder'),Qt.RightButton)
   assert_selected('Desktop/Folder');assert any(r.get('command')=='open' for r in rows(context));close_menu()
   click(desktop_tile('Desktop/alpha.txt'));assert_selected('Desktop/alpha.txt')
   click(desktop_tile('Desktop/beta.txt'),modifiers=Qt.ControlModifier);assert_selected('Desktop/alpha.txt','Desktop/beta.txt')
   click(desktop_tile('Desktop/alpha.txt'),Qt.RightButton)
   assert_selected('Desktop/alpha.txt','Desktop/beta.txt')
   assert not next(r for r in rows(context) if r.get('command')=='rename')['enabled']
   close_menu()
   click(desktop_tile('Desktop/beta.txt'),modifiers=Qt.ControlModifier);assert_selected('Desktop/alpha.txt')
   click(desktop_tile('Desktop/beta.txt'),modifiers=Qt.ShiftModifier)
   assert 'Desktop/beta.txt' in value(surface,'selected')
   click_point(QPoint(1050,350));assert_selected()
   alpha=desktop_tile('Desktop/alpha.txt'); beta=desktop_tile('Desktop/beta.txt')
   start=QPoint(round(min(alpha.x(),beta.x())-8),round(min(alpha.y(),beta.y())-3))
   end=QPoint(round(max(alpha.x()+alpha.width(),beta.x()+beta.width())+3),round(max(alpha.y()+alpha.height(),beta.y()+beta.height())+3))
   drag(start,end);assert_selected('Desktop/alpha.txt','Desktop/beta.txt')
  elif case=='actions':
   finder.setProperty('appHidden',True)
   click(desktop_tile('Desktop/alpha.txt'),Qt.RightButton);choose(context,'rename');text_input('renamed.txt')
   assert (workspace/'Desktop/renamed.txt').read_text()=='alpha desktop fixture'
   assert not (workspace/'Desktop/alpha.txt').exists()
   click(desktop_tile('Desktop/renamed.txt'),Qt.RightButton);choose(context,'copy')
   assert bridge.canPaste
   click_point(QPoint(1050,420),Qt.RightButton);choose(context,'paste')
   assert (workspace/'Desktop/renamed copy.txt').read_text()=='alpha desktop fixture'
   click(desktop_tile('Desktop/renamed copy.txt'),Qt.RightButton);choose(context,'trash')
   assert not (workspace/'Desktop/renamed copy.txt').exists() and bridge.trashCount==1
   top_action('Edit','undo');assert (workspace/'Desktop/renamed copy.txt').exists()
   click_point(QPoint(1050,420),Qt.RightButton);choose(context,'newfolder');text_input('new folder')
   assert (workspace/'Desktop/new folder').is_dir()
   top_action('Edit','undo');assert not (workspace/'Desktop/new folder').exists()
  elif case=='reposition':
   finder.setProperty('appHidden',True)
   alpha=desktop_tile('Desktop/alpha.txt');before=(alpha.x(),alpha.y())
   drag(point(alpha,46,32),QPoint(1080,430))
   positions=json.loads(bridge.suite.preference('desktop.positions','{}'))
   assert 'Desktop/alpha.txt' in positions,positions
   alpha=desktop_tile('Desktop/alpha.txt')
   assert (alpha.x(),alpha.y())!=before,(before,alpha.x(),alpha.y())
   assert abs(alpha.x()-1034)<3 and abs(alpha.y()-398)<3,(alpha.x(),alpha.y())
   assert (workspace/'Desktop/alpha.txt').is_file()
   with sqlite3.connect(workspace/'.desktop-data/applications.sqlite3') as db:
    persisted=json.loads(db.execute("SELECT value FROM preferences WHERE key='desktop.positions'").fetchone()[0])
   assert persisted==positions
   # Multiselection keeps relative spacing when moved as a group.
   click(alpha);click(desktop_tile('Desktop/beta.txt'),modifiers=Qt.ControlModifier)
   before_alpha=(alpha.x(),alpha.y());beta=desktop_tile('Desktop/beta.txt');before_beta=(beta.x(),beta.y())
   drag(point(alpha,46,32),QPoint(980,350))
   alpha=desktop_tile('Desktop/alpha.txt');beta=desktop_tile('Desktop/beta.txt')
   assert abs((alpha.x()-before_alpha[0])-(beta.x()-before_beta[0]))<1
   assert abs((alpha.y()-before_alpha[1])-(beta.y()-before_beta[1]))<1
  elif case in ('transfers','alt-copy','list-transfer','columns-transfer','gallery-transfer'):
   assert value(value(finder,'browser'),'currentPath')=='Documents'
   if case.endswith('-transfer'):finder.setProperty('viewMode',case.removesuffix('-transfer'));QTest.qWait(40)
   if case=='alt-copy':
    tile=finder_tile('Documents/copy.txt')
    drag(point(tile,40,20),QPoint(1090,430),Qt.AltModifier)
    assert (workspace/'Desktop/copy.txt').read_text()=='copy from Finder'
    assert (workspace/'Documents/copy.txt').exists(),'Alt drag moved the source instead of copying'
    # A second copy must position the returned collision-safe name, not overwrite
    # the first icon's saved position by guessing the original basename.
    first=json.loads(bridge.suite.preference('desktop.positions','{}'))['Desktop/copy.txt']
    drag(point(finder_tile('Documents/copy.txt'),40,20),QPoint(1090,590),Qt.AltModifier)
    assert (workspace/'Desktop/copy copy.txt').read_text()=='copy from Finder'
    positions=json.loads(bridge.suite.preference('desktop.positions','{}'))
    assert positions['Desktop/copy.txt']==first
    assert positions['Desktop/copy copy.txt']!=first
    drag(point(desktop_tile('Desktop/alpha.txt'),46,32),QPoint(980,350),Qt.AltModifier)
    assert (workspace/'Desktop/alpha copy.txt').read_text()=='alpha desktop fixture'
    assert (workspace/'Desktop/alpha.txt').exists()
   else:
    tile=finder_tile('Documents/incoming.txt')
    drag(point(tile,40,20),QPoint(1090,430))
    assert (workspace/'Desktop/incoming.txt').read_text()=='move from Finder'
    assert not (workspace/'Documents/incoming.txt').exists()
    assert 'Desktop/incoming.txt' in json.loads(bridge.suite.preference('desktop.positions','{}'))
    source=desktop_tile('Desktop/incoming.txt');target=finder_tile('Documents/Target')
    drag(point(source,46,32),point(target,40,20))
    assert (workspace/'Documents/Target/incoming.txt').read_text()=='move from Finder'
    assert not (workspace/'Desktop/incoming.txt').exists()
    source=desktop_tile('Desktop/beta.txt')
    drag(point(source,46,32),point(finder,550,460))
    assert (workspace/'Documents/beta.txt').read_text()=='beta desktop fixture'
    assert not (workspace/'Desktop/beta.txt').exists()
  elif case=='menu-sweep':
   click(title('Help'));assert top.property('visible') and desktop.property('openMenuName')=='Help'
   for name in ['Window','View','Edit','apple','Finder','File','Go','Help','Window','View','Edit','apple']:
    QTest.mouseMove(root,point(title(name)),20);QTest.qWait(30)
    assert top.property('visible'),('menu closed while hovering',name)
    assert desktop.property('openMenuName')==name,(name,desktop.property('openMenuName'))
   assert rows(top)[0]['label']=='About This Mac'
   assert root.findChild(QObject,'menuBarTracking').property('visible')
   close_menu();assert not top.property('visible')
  else:raise AssertionError(case)
  assert not errors,errors
  assert not warnings,'\n'.join(warnings)
 finally:
  root.close();shiboken6.delete(engine);bridge.shutdown()
print(case+' passed')
'''

@unittest.skipUnless(HAS_QT, 'Run using the project Qt environment')
class DesktopInteractionTests(unittest.TestCase):
    def run_case(self, case):
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_CONTROLS_STYLE='Basic', QT_QUICK_BACKEND='software')
        result = subprocess.run([sys.executable, '-c', _HARNESS, str(ROOT), case], env=env, capture_output=True, text=True, timeout=25)
        self.assertEqual(result.returncode, 0, result.stdout + '\n' + result.stderr)
    def test_empty_workspace_gets_real_desktop_and_new_folder(self): self.run_case('empty')
    def test_context_menus_selection_modifiers_and_marquee(self): self.run_case('selection')
    def test_rename_copy_paste_trash_and_undo_routes(self): self.run_case('actions')
    def test_reposition_and_multiselection_persist(self): self.run_case('reposition')
    def test_finder_desktop_folder_and_background_moves(self): self.run_case('transfers')
    def test_alt_drag_copies_without_moving_source(self): self.run_case('alt-copy')
    def test_finder_list_view_drag_and_drop(self): self.run_case('list-transfer')
    def test_finder_columns_view_drag_and_drop(self): self.run_case('columns-transfer')
    def test_finder_gallery_view_drag_and_drop(self): self.run_case('gallery-transfer')
    def test_top_menus_sweep_with_no_further_clicks(self): self.run_case('menu-sweep')

if __name__ == '__main__': unittest.main()
