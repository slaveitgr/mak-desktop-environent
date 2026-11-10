import sys
from pathlib import Path
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from applications import APPLICATIONS, ApplicationLauncher

class ApplicationTests(unittest.TestCase):
    def test_all_requested_apps_present(self):
        self.assertEqual({a['name'] for a in APPLICATIONS}, {'Safari','Messages','Mail','Maps','Photos','FaceTime','Phone','Calendar','Reminders','Notes','Contacts','Music','Games','App Store','Terminal','Apps','Calculator','Chess','Photo Booth'})
    def test_mac_launch_uses_verified_bundle_and_existing_app(self):
        launcher = ApplicationLauncher('darwin', exists=lambda p: p.endswith('/Safari.app'))
        self.assertEqual(launcher.command('safari'), ['/usr/bin/open','-b','com.apple.Safari'])
        self.assertEqual(launcher.command('mail'), [])
        self.assertEqual(launcher.command('safari; touch /tmp/bad'), [])
    def test_linux_detects_installed_provider_and_does_not_fake_apple_services(self):
        launcher = ApplicationLauncher('linux', which=lambda name: '/usr/bin/firefox' if name=='firefox' else None)
        self.assertEqual(launcher.command('safari'), ['/usr/bin/firefox'])
        self.assertEqual(launcher.command('facetime'), [])
        self.assertEqual(launcher.command('phone'), [])
        catalog = {row['id']: row for row in launcher.catalog()}
        self.assertEqual(catalog['safari']['provider'], 'Built-in')
        self.assertTrue(catalog['safari']['hostAvailable'])
        self.assertTrue(catalog['facetime']['available'])
        self.assertFalse(catalog['facetime']['hostAvailable'])

if __name__ == '__main__': unittest.main()
