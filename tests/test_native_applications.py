"""Native registration and dispatch contract. No applications are launched."""
import configparser
import importlib.util
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from applications import ApplicationLauncher, NATIVE_APPLICATIONS, NATIVE_WINDOW_APPLICATIONS, NATIVE_APP_IDS, NATIVE_APP_INFO, native_command

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('makos_install_preview',ROOT/'cutefish/install_preview.py')
installer=importlib.util.module_from_spec(spec);spec.loader.exec_module(installer)

class NativeApplicationTests(unittest.TestCase):
    def test_all_suite_apps_have_unique_native_identities(self):
        self.assertEqual(len(NATIVE_APPLICATIONS),21)
        self.assertEqual(len(set(NATIVE_APP_IDS)),21)
        self.assertEqual(len({entry['desktop_id'] for entry in NATIVE_APPLICATIONS}),21)
        self.assertEqual(NATIVE_APP_INFO['settings']['desktop_id'],'org.makos.Settings')
        self.assertEqual(NATIVE_APP_INFO['photobooth']['desktop_id'],'org.makos.PhotoBooth')
        self.assertEqual(NATIVE_APP_INFO['facetime']['name'],'FaceTime')
        self.assertEqual(len(NATIVE_WINDOW_APPLICATIONS),20)
        self.assertFalse(NATIVE_APP_INFO['apps']['windowed'])
        self.assertTrue(all(app['id']!='apps' for app in NATIVE_WINDOW_APPLICATIONS))
    def test_installed_entries_and_icons_match_native_identity(self):
        with tempfile.TemporaryDirectory(prefix='makos launchers ') as temporary:
            identities=installer.install(temporary)
            self.assertEqual(len(identities),21)
            for app in NATIVE_APPLICATIONS:
                desktop=Path(temporary)/'applications'/(app['desktop_id']+'.desktop')
                entry=configparser.ConfigParser(interpolation=None);entry.read(desktop)
                values=entry['Desktop Entry']
                self.assertEqual(values['Name'],app['name'])
                self.assertEqual(values['Icon'],app['desktop_id'])
                self.assertEqual(values['Exec'],installer.quoted(ROOT/'cutefish/run-app')+' '+app['id'])
                self.assertEqual(values.getboolean('StartupNotify'),app['windowed'])
                icon=Path(temporary)/'icons/hicolor/128x128/apps'/(app['desktop_id']+'.png')
                self.assertTrue(icon.read_bytes().startswith(b'\x89PNG'))
    def test_commands_are_argv_with_workspace_preserved(self):
        for app_id in NATIVE_APP_IDS:
            self.assertEqual(native_command(app_id,'/tmp/source folder','/tmp/work folder',python='/usr/bin/python'),
                ['/usr/bin/python','/tmp/source folder/main.py','--cutefish-app',app_id,'--root','/tmp/work folder'])
        self.assertEqual(native_command('settings; touch /tmp/no','/tmp/source'),[])
        self.assertEqual(native_command('--settings','/tmp/source'),[])
    def test_bridge_dispatches_all_registered_apps(self):
        from main import Bridge
        errors=[];fake=SimpleNamespace(workspace=SimpleNamespace(root=Path('/isolated/workspace')),error=SimpleNamespace(emit=errors.append))
        with patch('main.QProcess.startDetached',return_value=(True,123)) as launch:
            for app in NATIVE_APPLICATIONS:
                self.assertTrue(Bridge.launchCutefishApp(fake,app['id']))
                self.assertIn('--cutefish-app',launch.call_args.args[1])
                self.assertIn(app['id'],launch.call_args.args[1])
            self.assertFalse(Bridge.launchCutefishApp(fake,'unknown-app'))
            self.assertEqual(launch.call_count,21)
        self.assertEqual(len(errors),1)
    def test_native_catalog_is_explicit(self):
        catalog=ApplicationLauncher(platform='linux',which=lambda _:None,native=True).catalog()
        self.assertTrue(all(row['native'] for row in catalog))
        self.assertTrue(all(row['provider']==('makOS shell launcher' if row['id']=='apps' else 'makOS native application') for row in catalog))
        self.assertTrue(all(row['windowed']==(row['id']!='apps') for row in catalog))
        self.assertTrue(all(row['desktopId']==NATIVE_APP_INFO[row['id']]['desktop_id'] for row in catalog))

if __name__=='__main__':unittest.main()
