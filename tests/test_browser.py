from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
try:
    from PySide6.QtCore import QCoreApplication
    from main import Bridge
    from filesystem import Workspace
    HAS_QT = True
except ImportError:
    HAS_QT = False


@unittest.skipUnless(HAS_QT, 'Run with the project Qt environment for browser tests')
class BrowserTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QCoreApplication.instance() or QCoreApplication([])

    def setUp(self):
        self.temp = TemporaryDirectory()
        self.root = Path(self.temp.name)
        (self.root/'Documents').mkdir()
        (self.root/'Downloads').mkdir()
        (self.root/'Documents/Alpha.txt').write_text('alpha contents')
        (self.root/'Documents/Beta.txt').write_text('beta contents')
        self.bridge = Bridge(Workspace(self.root))
        self.browser = self.bridge.createBrowser('Documents')

    def tearDown(self):
        self.bridge.deleteLater()
        self.app.processEvents()
        self.temp.cleanup()

    def test_history_search_and_sort(self):
        self.browser.search('ALP')
        self.assertEqual([x['name'] for x in self.browser.files], ['Alpha.txt'])
        self.browser.navigate('Downloads')
        self.browser.back()
        self.assertEqual(self.browser.currentPath,'Documents')
        self.assertEqual(len(self.browser.files),2)
        self.assertTrue(self.browser.canForward)
        self.browser.sortBy('name')
        self.assertEqual(self.browser.files[0]['name'],'Beta.txt')

    def test_mutations_refresh_all_windows(self):
        other = self.bridge.createBrowser('Documents')
        self.bridge.newFolder('Documents','Test')
        self.assertEqual(len(other.files),3)
        self.bridge.rename('Documents/Test','Renamed')
        self.assertIn('Renamed',[x['name'] for x in other.files])
        self.bridge.undo()
        self.assertIn('Test',[x['name'] for x in self.browser.files])

    def test_preview_and_persistent_trash_names(self):
        data = self.bridge.preview('Documents/Alpha.txt')
        self.assertEqual(data['text'],'alpha contents')
        self.bridge.trash(['Documents/Alpha.txt'])
        self.browser.navigate('.Trash')
        self.assertEqual(self.browser.files[0]['name'],'Alpha.txt')
        self.bridge.restore([self.browser.files[0]['path']])
        self.assertEqual(self.browser.files,[])

    def test_invalid_navigation_preserves_location(self):
        errors=[]
        self.bridge.error.connect(errors.append)
        self.browser.navigate('../outside')
        self.assertEqual(self.browser.currentPath,'Documents')
        self.assertTrue(errors)

    def test_tags_survive_rename_and_undo_and_filter(self):
        self.bridge.setTag(['Documents/Alpha.txt'], 'Red')
        self.assertEqual(self.bridge.workspace.tag('Documents/Alpha.txt'), 'Red')
        self.bridge.rename('Documents/Alpha.txt', 'Renamed.txt')
        self.browser.navigate('@tag:Red')
        self.assertEqual([x['name'] for x in self.browser.files], ['Renamed.txt'])
        self.bridge.undo()
        self.assertEqual([x['name'] for x in self.browser.files], ['Alpha.txt'])
        self.bridge.undo()
        self.assertEqual(self.browser.files, [])
        self.assertEqual(self.bridge.workspace.tag('Documents/Alpha.txt'), '')

    def test_tags_survive_copy_and_folder_copy(self):
        self.bridge.setTag(['Documents/Alpha.txt'], 'Blue')
        self.bridge.copy(['Documents'])
        self.bridge.paste('Downloads', False)
        self.assertEqual(self.bridge.workspace.tag('Downloads/Documents/Alpha.txt'), 'Blue')
        self.bridge.undo()
        self.assertFalse((self.root / 'Downloads/Documents').exists())

    def test_info_and_unknown_virtual_location(self):
        info = self.bridge.fileInfo('Documents/Alpha.txt')
        self.assertIn('Name: Alpha.txt', info)
        self.assertIn('Kind: text/plain', info)
        self.browser.navigate('@unknown')
        self.assertEqual(self.browser.currentPath, 'Documents')

    def test_initial_location_without_documents(self):
        with TemporaryDirectory() as empty:
            bridge = Bridge(Workspace(Path(empty)))
            self.assertEqual(bridge.initialFolder, '')
            browser = bridge.createBrowser(bridge.initialFolder)
            self.assertEqual(browser.title, 'Home')
            bridge.deleteLater()


if __name__=='__main__': unittest.main()
