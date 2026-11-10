"""Shell/app integration in isolated offscreen subprocesses, plus virtual-path guards."""
import json
import os
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
try:
    from PySide6.QtCore import QCoreApplication, Qt
    import main
    from main import Bridge
    from filesystem import Workspace, FileError
    HAS_QT = True
except ImportError:
    HAS_QT = False


_UI_HARNESS = r'''
import json, os, sqlite3, sys
from pathlib import Path
from datetime import date
from tempfile import TemporaryDirectory
from unittest.mock import patch
from PySide6.QtCore import QObject, QSettings, QUrl, QTimer, Qt, Property, Slot, QMetaObject
from PySide6.QtGui import QGuiApplication, QFont, QKeySequence
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickItem
from PySide6.QtTest import QTest
import shiboken6
ROOT=Path(sys.argv[1]);case=sys.argv[2];sys.path.insert(0,str(ROOT))
from main import Bridge
from filesystem import Workspace
app=QGuiApplication([]);app.setFont(QFont('.AppleSystemUIFont',13));app.setOrganizationName('ShellSuiteQA');app.setApplicationName('Isolated')
with TemporaryDirectory() as folder:
 QSettings.setDefaultFormat(QSettings.IniFormat);QSettings.setPath(QSettings.IniFormat,QSettings.UserScope,folder)
 workspace=Path(folder)/'workspace';(workspace/'Documents').mkdir(parents=True);(workspace/'Documents/safe.txt').write_text('do not change')
 bridge=Bridge(Workspace(workspace),terminal_auto_start=False);engine=QQmlApplicationEngine();warnings=[]
 engine.warnings.connect(lambda errors:warnings.extend(str(e) for e in errors))
 for name,value in {'Bridge':bridge,'startFullscreen':False,'comparisonMode':False,'startSettings':False}.items():engine.rootContext().setContextProperty(name,value)
 engine.load(QUrl.fromLocalFile(str(ROOT/'qml/Main.qml')));assert engine.rootObjects(),warnings
 root=engine.rootObjects()[0];desktop=root.findChild(QObject,'desktop');desktop.setProperty('reduceMotion',True)
 app.aboutToQuit.connect(root.flushApplications);app.aboutToQuit.connect(bridge.shutdown)
 def windows():return desktop.property('windows').toVariant()
 def open_app(name):
  desktop.openApplication(name);QTest.qWait(25)
  return next(w for w in windows() if w.property('appKind')==name and not w.property('closing'))
 try:
  if case=='close-flush':
   window=open_app('notes');page=window.property('pageItem');page.newRecord('');page.setField('body','Last keystroke before closing')
   assert page.property('dirty')
   desktop.closeWindow(window)
   assert bridge.suite.records('notes')[0]['body']=='Last keystroke before closing'
   QTest.qWait(50);reopened=open_app('notes');assert reopened.property('pageItem').property('draft').toVariant()['body']=='Last keystroke before closing'
  elif case=='quit-flush':
   window=open_app('notes');page=window.property('pageItem');page.newRecord('')
   assert bridge.suite.records('notes')[0]['body']==''
   desktop.minimizeWindow(window)
   terminal=open_app('terminal').property('pageItem').property('session')
   with patch.dict(os.environ,{'SHELL':'/bin/sh','ENV':'','BASH_ENV':''}):terminal.start()
   process=terminal.process;assert terminal.running
   page.setField('body','Last keystroke before quitting');assert page.property('dirty')
   assert bridge.suite.records('notes')[0]['body']==''
   QTimer.singleShot(0,app.quit);app.exec()
   with sqlite3.connect(workspace/'.desktop-data/applications.sqlite3') as db:
    payload=json.loads(db.execute("SELECT payload FROM records WHERE kind='notes'").fetchone()[0])
   assert payload['body']=='Last keystroke before quitting'
   assert process.poll() is not None and not bridge.terminals
  elif case=='menus-fullscreen':
   window=open_app('notes');page=window.property('pageItem');page.newRecord('');page.setField('body','A working draft')
   finder_count=sum(w.property('appKind')=='finder' for w in windows())
   desktop.dispatch('newwindow');assert sum(w.property('appKind')=='finder' for w in windows())==finder_count
   assert len(bridge.suite.records('notes'))==2
   state=desktop.findChild(QObject,'fullscreenState');state.enter(window)
   assert window.property('isFullscreen')
   rows=desktop.menuRows('Window').toVariant();assert next(r for r in rows if r.get('command')=='minimize')['enabled'] is False
   shortcuts=[obj for obj in root.findChildren(QObject) if obj.metaObject().className()=='QQuickShortcut']
   sequence=QKeySequence('Ctrl+Meta+F' if sys.platform=='darwin' else 'F11')
   fullscreen=[obj for obj in shortcuts if obj.property('sequence')==sequence]
   assert fullscreen and fullscreen[0].property('enabled'), 'Full-screen shortcut must work inside suite applications'
   desktop.dispatch('fullscreen');assert not window.property('isFullscreen')
   desktop.minimizeWindow(window);assert window.property('minimized')
   desktop.openApplication('notes');assert not window.property('minimized') and desktop.property('activeWindow')==window
   desktop.dispatch('trash');assert (workspace/'Documents/safe.txt').read_text()=='do not change'
  elif case=='records-menus':
   notes=open_app('notes').property('pageItem');notes.newRecord('');desktop.dispatch('app:pin')
   assert bridge.suite.records('notes')[0]['pinned']
   desktop.dispatch('app:category:pinned');assert notes.property('category')=='pinned'
   notes.command('category:invalid');assert notes.property('category')=='pinned'
   reminders=open_app('reminders').property('pageItem');reminders.newRecord('');desktop.dispatch('app:complete')
   assert bridge.suite.records('reminders')[0]['done']
   desktop.dispatch('app:toggleCompleted');assert reminders.property('category')=='completed' and len(reminders.property('filtered').toVariant())==1
   contacts=open_app('contacts').property('pageItem');contacts.newRecord('');desktop.dispatch('app:favorite')
   assert bridge.suite.records('contacts')[0]['favorite']
   events=open_app('calendar').property('pageItem');events.newRecord('2026-12-25')
   calendar=events.findChild(QObject,'recordsCalendar');desktop.dispatch('app:new')
   assert bridge.suite.records('calendar')[0]['date']=='2026-12-25'
   desktop.dispatch('app:next')
   assert calendar.property('month').date().year()==2027 and calendar.property('month').date().month()==1
   desktop.dispatch('app:previous');assert calendar.property('month').date().month()==12
   desktop.dispatch('app:today');assert calendar.property('day') == date.today().isoformat()
   mail=open_app('mail').property('pageItem');mail.newRecord('');mail.setField('recipient','reader@example.test');mail.setField('body','Exported through File menu');desktop.dispatch('app:export')
   assert len(list((workspace/'Documents'/'Mail Drafts').glob('*.eml')))==1
  elif case=='terminal-keys':
   from terminal_session import TerminalSession
   class FakeTerminal(TerminalSession):
    def __init__(self):
     super().__init__(workspace,shell_command=['/bin/sh','-i']);self.writes=[];self.interrupts=0;self._text='Terminal selection';self._html=self._text
    @Property(bool,constant=True)
    def running(self):return True
    @Slot(int,int)
    def resize(self,columns,rows):pass
    @Slot(str)
    def write(self,text):self.writes.append(text)
    @Slot()
    def interrupt(self):self.interrupts+=1
    @Slot()
    def stop(self):pass
   window=open_app('terminal');page=window.property('pageItem');original=page.property('session');fake=FakeTerminal();bridge.terminals.append(fake);page.setProperty('tabs',[{'id':1,'session':fake}]);bridge.releaseTerminal(original)
   output=page.findChild(QObject,'terminalOutput');assert 'Terminal selection' in output.property('text')
   QMetaObject.invokeMethod(output,'forceActiveFocus');QTest.qWait(20)
   QTest.keyClick(root,Qt.Key_Return);QTest.keyClick(root,Qt.Key_Up)
   assert fake.writes==['\r','\x1b[A'], repr(fake.writes)
   QTest.keyClick(root,Qt.Key_C,Qt.MetaModifier if sys.platform=='darwin' else Qt.ControlModifier)
   assert fake.interrupts==1, 'Physical Control+C must interrupt the shell'
   if sys.platform=='darwin':
    QTest.keyClick(root,Qt.Key_C,Qt.ControlModifier)
    assert fake.interrupts==1, 'Command+C must not interrupt the shell'
   app.clipboard().setText('a pasted command')
   page.command('paste')
   assert fake.writes[-1]=='a pasted command', 'Terminal Paste must reach its PTY'
  elif case=='applications-readonly':
   desktop.openFolder('@applications');finder=desktop.property('activeWindow');browser=finder.property('browser')
   assert browser.property('currentPath')=='@applications'
   assert any(row['appId']=='notes' for row in browser.property('files'))
   finder.setProperty('selected',['@app:notes'])
   rows=desktop.menuRows('File').toVariant()+desktop.menuRows('Edit').toVariant()
   for action in ('rename','duplicate','trash','copy','paste','move'):
    matching=[r for r in rows if r.get('command')==action]
    assert matching and matching[0]['enabled'] is False, (action,matching)
   before=len(windows());desktop.dispatch('open')
   assert desktop.property('activeWindow').property('appKind')=='notes' and len(windows())==before+1
  elif case=='shell-chrome':
   from PySide6.QtCore import QDateTime, QDate, QTime
   apple=desktop.menuRows('apple').toVariant()
   assert apple[0]['label']=='About This Mak'
   labels=[row.get('label') for row in apple]
   for label in ('System Settings…','App Store…','Recent Items','Force Quit…','Sleep','Restart…','Shut Down…','Lock Screen'):assert label in labels,label
   desktop.dispatch('aboutmac');about=desktop.property('activeWindow')
   assert about.property('appKind')=='aboutmac' and bridge.systemInfo['processor']
   desktop.closeWindow(about);QTest.qWait(30)
   notes=open_app('notes');finder=next(w for w in windows() if w.property('appKind')=='finder')
   desktop.dispatch('hide');assert notes.property('appHidden') and not notes.property('minimized')
   assert not finder.property('appHidden') and desktop.property('activeWindow')==finder
   desktop.openApplication('notes');assert not notes.property('appHidden')
   desktop.dispatch('hideothers');assert finder.property('appHidden') and not notes.property('appHidden')
   desktop.dispatch('unhideall');assert not finder.property('appHidden')
   desktop.activateFinder();root.requestActivate();QTest.qWait(20)
   was_sidebar=finder.property('sidebarVisible')
   QTest.keyClick(root,Qt.Key_S,Qt.ControlModifier|Qt.AltModifier)
   assert finder.property('sidebarVisible')!=was_sidebar
   QTest.keyClick(root,Qt.Key_A,Qt.ControlModifier|Qt.ShiftModifier)
   assert finder.property('browser').property('currentPath')=='@applications'
   desktop.openTopMenu('apple',10);QTest.qWait(20)
   menu=root.findChild(QObject,'topMenu');sub=root.findChild(QObject,'subMenu')
   recent=next(i for i,row in enumerate(menu.property('rows').toVariant()) if row.get('label')=='Recent Items')
   menu.setProperty('currentIndex',recent);menu.openSubmenu(recent);QTest.qWait(20)
   assert sub.property('opened') and sub.property('parent')==menu.property('contentItem')
   assert sub.property('backdropOrigin').x()>menu.property('x')
   QTest.keyClick(root,Qt.Key_Down);assert sub.property('currentIndex')>=0
   QTest.keyClick(root,Qt.Key_Left);QTest.qWait(10);assert not sub.property('opened')
   menu.openSubmenu(recent);QTest.qWait(10);assert sub.property('opened')
   menu.setProperty('currentIndex',0);QTest.qWait(20);assert not sub.property('opened')
   menu.setProperty('rows',[{'label':'Item '+str(i),'command':'noop'} for i in range(100)])
   menu.setProperty('currentIndex',99)
   # Repeater/Flickable layout is asynchronous; assert the settled scroll state
   # rather than depending on one 10 ms tick under concurrent test/render load.
   for _ in range(100):
    if menu.property('height')<desktop.property('height') and menu.property('contentItem').property('contentY')>0:break
    QTest.qWait(10)
   assert menu.property('height')<desktop.property('height') and menu.property('contentItem').property('contentY')>0
   menu.close()
   for section in ('control','wifi','bluetooth','sound','battery','clock'):
    desktop.openStatusPanel(section);QTest.qWait(15)
    panel=root.findChild(QObject,'systemPanel');assert panel.property('opened') and panel.property('height')<=desktop.property('height')
    panel.close()
   desktop.dispatch('forcequit');QTest.qWait(15);force=root.findChild(QObject,'forceQuitPanel');assert force.property('opened');force.close()
   suite=bridge.suite
   suite.setPreference('clock.24hour','false');suite.setPreference('clock.ampm','false');suite.setPreference('clock.seconds','true')
   suite.setPreference('clock.weekday','false');suite.setPreference('clock.date','Never')
   desktop.setProperty('now',QDateTime(QDate(2026,11,10),QTime(13,5,9)))
   assert desktop.property('clockTimeText')=='1:05:09' and desktop.property('clockDateText')==''
   suite.setPreference('clock.style','Analog');assert desktop.property('clockAnalog')
   suite.setPreference('menubar.background','true');assert root.findChild(QObject,'menuBarBackground').property('color').alpha()>0
   suite.setPreference('menubar.hide','Always');desktop.setProperty('menuBarRevealed',False);QTest.qWait(10)
   assert root.findChild(QObject,'topChrome').property('y')==-30
   state=desktop.findChild(QObject,'fullscreenState');state.enter(notes);assert not state.property('chromeVisible')
   state.setProperty('pointerAtTop',True);assert state.property('chromeVisible')
   suite.setPreference('menubar.hide','Never');state.setProperty('pointerAtTop',False);QTest.qWait(400);assert state.property('chromeVisible')
   state.exit();assert root.findChild(QObject,'topChrome').property('y')==0
   desktop.openSettings('Menu Bar');QTest.qWait(30)
   assert not warnings,'\n'.join(warnings)
  else:raise AssertionError(case)
  assert not warnings,'\n'.join(warnings)
 finally:
  root.flushApplications();root.close();shiboken6.delete(engine);bridge.shutdown()
 print(case,'passed')
'''


@unittest.skipUnless(HAS_QT, 'Run with the project Qt environment')
class ShellSuiteUiTests(unittest.TestCase):
    def run_case(self, name):
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_CONTROLS_STYLE='Basic')
        result = subprocess.run([sys.executable, '-c', _UI_HARNESS, str(ROOT), name], env=env, capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout+'\n'+result.stderr)

    def test_close_flushes_last_edit_before_window_destruction(self): self.run_case('close-flush')
    def test_quit_flushes_minimized_apps_and_stops_terminal(self): self.run_case('quit-flush')
    def test_app_menus_new_window_and_fullscreen_shortcuts_route_to_app(self): self.run_case('menus-fullscreen')
    def test_finder_application_rows_launch_but_are_read_only(self): self.run_case('applications-readonly')
    def test_terminal_control_keys_escapes_and_paste(self): self.run_case('terminal-keys')
    def test_records_menu_actions_are_routed_and_persisted(self): self.run_case('records-menus')
    def test_shell_menus_hide_scope_clock_and_menu_bar_settings(self): self.run_case('shell-chrome')


@unittest.skipUnless(HAS_QT, 'Run with the project Qt environment')
class VirtualAndCameraGuards(unittest.TestCase):
    @classmethod
    def setUpClass(cls): cls.app = QCoreApplication.instance() or QCoreApplication([])

    def setUp(self):
        self.temp = TemporaryDirectory()
        self.root = Path(self.temp.name).resolve()
        self.bridge = Bridge(Workspace(self.root))

    def tearDown(self):
        self.bridge.shutdown()
        self.temp.cleanup()

    def test_virtual_application_paths_cannot_mutate_real_filename_collisions(self):
        collision = self.root/'@app:notes'
        collision.write_text('An unrelated local file')
        errors=[];self.bridge.error.connect(errors.append)
        self.bridge.trash(['@app:notes'])
        self.assertTrue(collision.exists(), 'A virtual app icon must not delete a same-named root file')
        self.assertEqual(collision.read_text(), 'An unrelated local file')
        self.assertTrue(errors)
        for path in ('@app:notes','@recents','@applications','@tag:Red'):
            with self.subTest(path=path):
                with self.assertRaises(FileError): self.bridge.workspace.path(path)

    def test_privacy_disabled_camera_never_calls_os_permission_api(self):
        self.bridge.suite.setPreference('camera.allowed','false')
        calls=[];self.bridge.cameraPermissionResult.connect(lambda ok,message:calls.append((ok,message)))
        fake=SimpleNamespace(instance=lambda: (_ for _ in ()).throw(AssertionError('OS permission API should not be called')))
        with patch.object(main,'QGuiApplication',fake):self.bridge.requestCameraPermission()
        self.assertEqual(len(calls),1);self.assertFalse(calls[0][0]);self.assertIn('disabled',calls[0][1])

    def test_plain_python_without_usage_description_does_not_request_camera(self):
        requests=[];results=[]
        fake_app=SimpleNamespace(applicationFilePath=lambda:str(self.root/'python'),checkPermission=lambda p:Qt.PermissionStatus.Undetermined,requestPermission=lambda *args:requests.append(args))
        self.bridge.cameraPermissionResult.connect(lambda ok,message:results.append((ok,message)))
        with patch.object(main,'QGuiApplication',SimpleNamespace(instance=lambda:fake_app)), patch.object(main,'sys',SimpleNamespace(platform='darwin',executable=str(self.root/'python'))):
            self.bridge.requestCameraPermission()
        self.assertEqual(requests,[]);self.assertEqual(len(results),1);self.assertFalse(results[0][0]);self.assertIn('declaration',results[0][1])


if __name__ == '__main__': unittest.main()
