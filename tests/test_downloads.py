"""Download publication and dialog lifecycle, using only temporary local files."""
import errno
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from PySide6.QtCore import QCoreApplication, QObject, QTimer, QUrl
from browser_downloads import BrowserDownloads
from filesystem import Workspace
from main import Bridge


class DownloadTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QCoreApplication.instance() or QCoreApplication([])

    def setUp(self):
        self.temp = TemporaryDirectory()
        self.root = Path(self.temp.name).resolve()
        self.downloads = BrowserDownloads(self.root)

    def tearDown(self):
        self.downloads.close()
        self.temp.cleanup()

    def prepare(self, name='report.txt', data=b'new download'):
        item = self.downloads.destination(name)
        (Path(item['directory']) / item['name']).write_bytes(data)
        return item

    def test_publish_preserves_existing_files_and_cleans_staging(self):
        item = self.prepare()
        existing = self.root / 'Downloads' / 'report.txt'
        existing.write_bytes(b'existing report')
        result = self.downloads.finish(item['token'], True)
        saved = Path(QUrl(result['url']).toLocalFile())
        self.assertEqual(existing.read_bytes(), b'existing report')
        self.assertEqual(saved.name, 'report 2.txt')
        self.assertEqual(saved.read_bytes(), b'new download')
        self.assertFalse(Path(item['directory']).exists())
        with self.assertRaises(ValueError): self.downloads.finish(item['token'], True)

    def test_filename_is_confined_and_bounded_for_unicode(self):
        for name in ('../../outside.txt', '..\\outside.txt', '..', '\0bad\n.txt', 'φ' * 500 + '.png'):
            item = self.prepare(name)
            self.assertNotIn('/', item['name'])
            self.assertNotIn('\\', item['name'])
            self.assertLessEqual(len(item['name'].encode()), 190)
            result = self.downloads.finish(item['token'], True)
            self.assertEqual(Path(QUrl(result['url']).toLocalFile()).parent, self.root / 'Downloads')

    def test_cancel_removes_partial_data_without_public_files(self):
        item = self.prepare()
        (Path(item['directory']) / 'report.txt.crdownload').write_bytes(b'partial')
        self.downloads.cancel(item['token'])
        self.downloads.cancel(item['token'])
        self.assertFalse(Path(item['directory']).exists())
        self.assertEqual(list((self.root / 'Downloads').iterdir()), [])

    def test_rejects_unowned_token_missing_file_and_symlinks(self):
        with self.assertRaises(ValueError): self.downloads.finish('../../outside', True)
        item = self.downloads.destination('missing.txt')
        with self.assertRaises(ValueError): self.downloads.finish(item['token'], True)
        outside = self.root / 'private.txt'
        outside.write_bytes(b'private')
        (Path(item['directory']) / item['name']).symlink_to(outside)
        with self.assertRaises(ValueError): self.downloads.finish(item['token'], True)
        self.assertEqual(outside.read_bytes(), b'private')
        self.downloads.cancel(item['token'])
        (self.root / 'Downloads').rmdir()
        (self.root / 'Downloads').symlink_to(self.root, target_is_directory=True)
        with self.assertRaises(ValueError): self.downloads.destination('no.txt')

    def test_cross_filesystem_copy_is_exclusive_and_keeps_existing(self):
        item = self.prepare()
        (self.root / 'Downloads' / 'report.txt').write_bytes(b'keep')
        with patch('browser_downloads.os.link', side_effect=OSError(errno.EXDEV, 'Cross-device link')):
            result = self.downloads.finish(item['token'], True)
        self.assertEqual(result['name'], 'report 2.txt')
        self.assertEqual((self.root / 'Downloads' / 'report.txt').read_bytes(), b'keep')

    def test_dialog_accept_cancel_owner_destruction_and_shutdown(self):
        bridge = Bridge(Workspace(self.root))
        owner = QObject()
        QTimer.singleShot(0, lambda: bridge.resolveDownloadDecision(owner, True))
        self.assertTrue(bridge.waitForDownloadDecision(owner))
        QTimer.singleShot(0, lambda: bridge.resolveDownloadDecision(owner, False))
        self.assertFalse(bridge.waitForDownloadDecision(owner))
        doomed = QObject()
        QTimer.singleShot(0, doomed.deleteLater)
        self.assertFalse(bridge.waitForDownloadDecision(doomed))
        QTimer.singleShot(0, bridge.shutdown)
        self.assertFalse(bridge.waitForDownloadDecision(owner))
        self.assertEqual(bridge._download_decisions, {})
        bridge.shutdown()


if __name__ == '__main__':
    unittest.main()
