"""Finder Bridge integration using actual temporary files, never host user data."""
import os
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
try:
    from PySide6.QtCore import QCoreApplication
    HAS_QT = True
except ImportError:
    HAS_QT = False
if HAS_QT:
    from main import Bridge
    from filesystem import Workspace


@unittest.skipUnless(HAS_QT, 'PySide6 is not installed')
class FinderSearchTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QCoreApplication.instance() or QCoreApplication([])

    def setUp(self):
        self.temp = TemporaryDirectory()
        self.root = Path(self.temp.name) / 'workspace'
        (self.root / 'Documents/Nested').mkdir(parents=True)
        (self.root / 'Downloads').mkdir()
        (self.root / 'Documents/Nested/report.txt').write_text('nested contents')
        (self.root / 'Documents/report-local.txt').write_text('local contents')
        self.bridge = Bridge(Workspace(self.root))
        self.errors = []
        self.bridge.error.connect(self.errors.append)
        self.browser = self.bridge.createBrowser('Documents')

    def tearDown(self):
        self.bridge.deleteLater()
        self.app.processEvents()
        self.temp.cleanup()

    def paths(self, browser=None):
        return {row['path'] for row in (browser or self.browser).files}

    def test_recursive_search_is_scoped_and_restores_normal_listing(self):
        (self.root / 'Downloads/report-other.txt').write_text('other folder')
        self.browser.search('REPORT')
        self.assertEqual(self.paths(), {'Documents/Nested/report.txt', 'Documents/report-local.txt'})
        nested = next(row for row in self.browser.files if row['name'] == 'report.txt')
        self.assertEqual(nested['thumbnailText'], 'nested contents')
        self.browser.search('')
        self.assertEqual(self.paths(), {'Documents/Nested', 'Documents/report-local.txt'})
        self.assertEqual(self.errors, [])

    def test_multiselection_drop_from_search_moves_real_files_and_refreshes_windows(self):
        destination = self.bridge.createBrowser('Downloads')
        self.browser.search('report')
        result = self.bridge.dropFiles(sorted(self.paths()), 'Downloads', False)
        self.assertEqual(set(result), {'Downloads/report.txt', 'Downloads/report-local.txt'})
        self.assertEqual(self.paths(), set())
        self.assertEqual(self.paths(destination), set(result))
        self.assertEqual((self.root / 'Downloads/report.txt').read_text(), 'nested contents')
        self.bridge.undo()
        self.assertEqual(self.paths(), {'Documents/Nested/report.txt', 'Documents/report-local.txt'})
        self.assertEqual(self.paths(destination), set())

    def test_copy_drop_retains_source_and_rename_searches_by_new_name(self):
        result = self.bridge.dropFiles(['Documents/Nested/report.txt'], 'Downloads', True)
        self.assertEqual(result, ['Downloads/report.txt'])
        self.assertTrue((self.root / 'Documents/Nested/report.txt').exists())
        self.browser.search('renamed')
        self.bridge.rename('Documents/Nested/report.txt', 'renamed.txt')
        self.assertEqual(self.paths(), {'Documents/Nested/renamed.txt'})
        self.bridge.trash(list(self.paths()))
        self.assertEqual(self.paths(), set())
        item = '.Trash/' + next(iter(self.bridge.workspace.trash_index))
        self.bridge.restore([item])
        self.assertEqual(self.paths(), {'Documents/Nested/renamed.txt'})

    @unittest.skipUnless(hasattr(os, 'mkfifo'), 'Requires POSIX fixture')
    def test_listing_search_and_recents_skip_fifo_and_dangling_link(self):
        os.mkfifo(self.root / 'Documents/report-pipe.txt')
        (self.root / 'Documents/report-link.txt').symlink_to(Path(self.temp.name) / 'missing')
        self.browser.refresh()
        self.assertNotIn('Documents/report-pipe.txt', self.paths())
        self.browser.search('report')
        self.assertEqual(self.paths(), {'Documents/Nested/report.txt', 'Documents/report-local.txt'})
        self.browser.navigate('@recents')
        self.assertNotIn('Documents/report-link.txt', self.paths())
        self.assertNotIn('Documents/report-pipe.txt', self.paths())
        self.assertEqual(self.errors, [])

    def test_hidden_recursive_search_requires_show_hidden(self):
        (self.root / 'Documents/Nested/.report-hidden.txt').write_text('hidden')
        self.browser.search('report')
        self.assertNotIn('Documents/Nested/.report-hidden.txt', self.paths())
        self.browser.toggleHidden()
        self.assertIn('Documents/Nested/.report-hidden.txt', self.paths())
        self.browser.navigate('Downloads')
        self.browser.back()
        self.assertEqual(self.browser.currentPath, 'Documents')
        self.assertNotIn('Documents/Nested/report.txt', self.paths())


if __name__ == '__main__':
    unittest.main()
