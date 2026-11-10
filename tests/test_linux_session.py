"""Session/package contracts, installed launcher discovery and safe preview behavior."""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch, Mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from xdg_applications import discover_applications


def load_file(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class DesktopEntryTests(unittest.TestCase):
    def test_composite_desktop_honors_environment_and_base_app_exclusions(self):
        with tempfile.TemporaryDirectory() as folder:
            base=Path(folder);applications=base/'applications';applications.mkdir()
            for name,extra in [('base-files','NotShowIn=makOS;'),('integration','OnlyShowIn=Cutefish;'),('finder','OnlyShowIn=makOS;')]:
                (applications/(name+'.desktop')).write_text('[Desktop Entry]\nType=Application\nName='+name+'\nExec=example\n'+extra+'\n')
            with patch.dict(os.environ,{'XDG_CURRENT_DESKTOP':'makOS:Cutefish'}):
                self.assertEqual([a['name'] for a in discover_applications([base])],['finder','integration'])
                self.assertEqual([a['name'] for a in discover_applications([base],desktop='Cutefish')],['base-files','integration'])

    def test_user_hidden_masks_system_and_filter_rules(self):
        with tempfile.TemporaryDirectory() as folder:
            user, system = Path(folder) / 'user', Path(folder) / 'system'
            def entry(base, name, extra=''):
                path = base / 'applications' / (name + '.desktop')
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('[Desktop Entry]\nType=Application\nName=' + name + '\nExec=example %U\n' + extra)
            entry(system, 'masked'); entry(user, 'masked', 'Hidden=true\n')
            entry(system, 'invisible', 'NoDisplay=true\n')
            entry(system, 'gnome', 'OnlyShowIn=GNOME;\n')
            entry(system, 'excluded', 'NotShowIn=X-Tahoe;\n')
            entry(system, 'missing', 'TryExec=missing-program\n')
            entry(system, 'good', 'OnlyShowIn=X-Tahoe;GNOME;\nComment=100% local\n')
            result = discover_applications([user, system], which=lambda _: None)
            self.assertEqual([a['id'] for a in result], ['xdg:good.desktop'])
            self.assertEqual(result[0]['description'], '100% local')

    def test_nested_ids_overrides_invalid_and_no_execution(self):
        with tempfile.TemporaryDirectory() as folder:
            base = Path(folder)
            (base / 'applications/vendor').mkdir(parents=True)
            (base / 'applications/vendor/app.desktop').write_text('[Desktop Entry]\nType=Application\nName=An App\nExec=sh -c "touch NEVER"\n')
            (base / 'applications/broken.desktop').write_text('invalid')
            (base / 'applications/badbool.desktop').write_text('[Desktop Entry]\nHidden=invalid\nType=Application\nName=Bad\nExec=no\n')
            with patch('subprocess.Popen') as spawn:
                result = discover_applications([base])
                spawn.assert_not_called()
            self.assertEqual([a['id'] for a in result], ['xdg:vendor-app.desktop'])


class SessionTests(unittest.TestCase):
    def test_environment_is_explicit_and_does_not_mutate_caller(self):
        supervisor = load_file('session_supervisor', ROOT / 'linux/session.py')
        before = {'DISPLAY': ':99', 'HOME': '/home/example', 'QT_QPA_PLATFORM': 'wayland'}
        env = supervisor.environment(before, '/tmp/private/control.sock')
        self.assertEqual(before['QT_QPA_PLATFORM'], 'wayland')
        self.assertEqual(env['QT_QPA_PLATFORM'], 'xcb')
        self.assertEqual(env['XDG_CURRENT_DESKTOP'], 'X-Tahoe')
        self.assertEqual(env['HOME'], before['HOME'])

    def test_cleanup_terminates_only_owned_process_group(self):
        supervisor = load_file('session_supervisor', ROOT / 'linux/session.py')
        owned = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)'], start_new_session=True)
        other = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)'], start_new_session=True)
        try:
            supervisor.terminate_owned([owned], grace=1)
            self.assertIsNotNone(owned.poll())
            self.assertIsNone(other.poll())
        finally:
            if owned.poll() is None: owned.kill()
            other.terminate(); other.wait(timeout=3)

    def test_preview_cannot_launch_or_change_host_session(self):
        from linux_session import LinuxSession
        session = LinuxSession(False)
        with patch.object(session, '_run') as run:
            for action in ('logout', 'lock', 'sleep', 'restart', 'shutdown'):
                session.perform(action)
            self.assertFalse(session.launch('xdg:test.desktop'))
            run.assert_not_called()

    def native_session(self, enabled=True):
        from linux_session import LinuxSession
        calls = []
        with patch.object(sys, 'platform', 'linux'):
            session = LinuxSession(enabled, cutefish_mode=True,
                                   transport=lambda *args: calls.append(args))
        return session, calls

    def test_cutefish_actions_use_supervisor_and_real_lock_service(self):
        session, calls = self.native_session()
        with patch.object(session, '_run') as run, patch('linux_session.QGuiApplication.quit') as quit_app:
            for action in ('logout', 'sleep', 'restart', 'shutdown', 'lock', 'unknown'):
                session.perform(action)
            run.assert_not_called()
            quit_app.assert_not_called()
        self.assertEqual([call[:-1] for call in calls], [
            ('org.cutefish.Session', '/Session', 'org.cutefish.Session', method, [])
            for method in ('logout', 'suspend', 'reboot', 'powerOff')
        ] + [('org.freedesktop.ScreenSaver', '/ScreenSaver', 'org.freedesktop.ScreenSaver', 'Lock', [])])

    def test_cutefish_failure_is_visible_without_unsafe_fallback(self):
        session, calls = self.native_session()
        errors = []
        session.error.connect(errors.append)
        with patch.object(session, '_run') as run:
            session.perform('lock')
            calls[-1][-1]('Session is not available for locking', [])
            session.perform('sleep')
            calls[-1][-1]('', [False])
            run.assert_not_called()
        self.assertIn('Session is not available for locking', errors[0])
        self.assertIn('Sleep is not available', errors[1])
        session.stop()
        calls[-1][-1]('late reply', [])
        self.assertEqual(len(errors), 2)

    def test_native_flag_does_not_enable_preview_or_stopped_session(self):
        session, calls = self.native_session(enabled=False)
        for action in ('logout', 'sleep', 'restart', 'shutdown', 'lock'):
            session.perform(action)
        self.assertEqual(calls, [])
        session, calls = self.native_session()
        session.stop()
        session.perform('logout')
        self.assertEqual(calls, [])

    def test_cutefish_start_needs_no_legacy_control_socket(self):
        session, calls = self.native_session()
        with patch.dict(os.environ, {}, clear=True), patch.object(session, 'refreshApplications') as refresh:
            session.start()
            refresh.assert_called_once()
        self.assertIsNone(session._server)
        self.assertEqual(calls, [])

    def test_legacy_actions_keep_x11_session_behavior(self):
        from linux_session import LinuxSession
        with patch.object(sys, 'platform', 'linux'):
            session = LinuxSession(True)
        with patch.object(session, '_run') as run, patch('linux_session.QGuiApplication.quit') as quit_app:
            session.perform('lock')
            run.assert_called_once_with(['xset', 's', 'activate'])
            session.perform('logout')
            quit_app.assert_called_once()

    def test_external_launch_only_known_entry_and_no_shell_interpolation(self):
        from linux_session import LinuxSession
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'example;not-a-command.desktop'
            path.write_text('[Desktop Entry]\nType=Application\nName=Example\nExec=example %U\n')
            session = LinuxSession(False)
            session._enabled = True
            session._applications = [{'id': 'xdg:example.desktop', 'path': str(path)}]
            with patch.object(session, '_run') as run:
                self.assertFalse(session.launch(str(path)))
                self.assertTrue(session.launch('xdg:example.desktop'))
                run.assert_called_once_with(['gio', 'launch', str(path)])

    def test_package_excludes_personal_state_and_owns_login_files(self):
        builder = load_file('deb_builder', ROOT / 'linux/build_deb.py')
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            app = builder.stage_source(root)
            files = [str(p.relative_to(root)) for p in root.rglob('*') if p.is_file()]
            for forbidden in ('demo-home', '.desktop-data', 'Tahoe Desktop.app', '.venv', '__pycache__'):
                self.assertFalse(any(forbidden in name.split('/') for name in files), forbidden)
            self.assertIn('usr/share/xsessions/tahoe.desktop', files)
            self.assertIn('usr/bin/tahoe-session', files)
            self.assertTrue((app / 'qml/Main.qml').is_file())
            self.assertNotIn('gnome-session', (root / 'usr/bin/tahoe-session').read_text())
            self.assertFalse((root / 'etc/gdm3/custom.conf').exists())

    def test_session_ui_cancel_and_confirm_flush(self):
        script = r'''
import sys,tempfile
from pathlib import Path
from unittest.mock import patch, Mock
from PySide6.QtCore import QObject,QSettings,QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtTest import QTest
import shiboken6
sys.path.insert(0,sys.argv[1])
from main import Bridge,finish_session
from filesystem import Workspace
app=QGuiApplication([]);app.setOrganizationName('SessionQA');app.setApplicationName('Isolated')
with tempfile.TemporaryDirectory() as folder:
 QSettings.setDefaultFormat(QSettings.IniFormat);QSettings.setPath(QSettings.IniFormat,QSettings.UserScope,folder)
 bridge=Bridge(Workspace(folder));bridge.session._enabled=True
 bridge.session.refreshApplications=lambda:None
 engine=QQmlApplicationEngine();warnings=[]
 engine.warnings.connect(lambda errors:warnings.extend(str(e) for e in errors))
 for key,value in {'Bridge':bridge,'startFullscreen':False,'startSettings':False,'comparisonMode':False}.items():engine.rootContext().setContextProperty(key,value)
 engine.load(QUrl.fromLocalFile(str(Path(sys.argv[1])/'qml/Main.qml')));assert engine.rootObjects(),warnings
 root=engine.rootObjects()[0];desktop=root.findChild(QObject,'desktop');dialog=root.findChild(QObject,'sessionConfirm')
 desktop.openApplication('notes');QTest.qWait(30)
 notes=next(w for w in desktop.property('windows').toVariant() if w.property('appKind')=='notes')
 page=notes.property('pageItem');page.newRecord('');page.setField('body','Save before session exit')
 with patch.object(bridge.session,'perform') as perform:
  desktop.requestSessionAction('logout');QTest.qWait(30);assert dialog.property('visible')
  dialog.reject();QTest.qWait(30);perform.assert_not_called();assert not desktop.property('sessionEnding')
  fake_app=Mock();finish_session(fake_app,root);fake_app.quit.assert_called_once()
  assert desktop.property('sessionEnding');desktop.setProperty('sessionEnding',False)
  desktop.requestSessionAction('logout');QTest.qWait(30);dialog.accept();QTest.qWait(30)
  perform.assert_called_once_with('logout');assert desktop.property('sessionEnding')
  assert bridge.suite.records('notes')[0]['body']=='Save before session exit'
 assert not warnings,warnings
 root.close();shiboken6.delete(engine);bridge.shutdown()
'''
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_CONTROLS_STYLE='Basic')
        result = subprocess.run([sys.executable, '-c', script, str(ROOT)], env=env, capture_output=True, text=True, timeout=45)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
