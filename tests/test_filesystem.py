import json
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from filesystem import Workspace, FileError


class FilesystemTests(unittest.TestCase):
    def setUp(self):
        self.temp = TemporaryDirectory()
        self.root = Path(self.temp.name) / 'desktop'
        self.ws = Workspace(self.root)
        (self.root / 'Documents').mkdir()
        (self.root / 'Downloads').mkdir()
        (self.root / 'Documents/report.txt').write_text('keep this content\n')

    def tearDown(self):
        self.temp.cleanup()

    def test_copy_and_undo_preserve_original(self):
        self.ws.copy(['Documents/report.txt'], 'Downloads')
        self.assertEqual((self.root/'Downloads/report.txt').read_text(), 'keep this content\n')
        self.ws.undo()
        self.assertFalse((self.root/'Downloads/report.txt').exists())
        self.assertEqual((self.root/'Documents/report.txt').read_text(), 'keep this content\n')
        self.assertEqual(len(self.ws.trash_index), 1)

    def test_move_and_undo(self):
        self.ws.copy(['Documents/report.txt'], 'Downloads', move=True)
        self.assertFalse((self.root/'Documents/report.txt').exists())
        self.ws.undo()
        self.assertTrue((self.root/'Documents/report.txt').exists())
        self.assertFalse((self.root/'Downloads/report.txt').exists())

    def test_duplicate_does_not_overwrite(self):
        self.ws.copy(['Documents/report.txt'], 'Documents', duplicate=True)
        self.ws.copy(['Documents/report.txt'], 'Documents', duplicate=True)
        self.assertTrue((self.root/'Documents/report copy.txt').exists())
        self.assertTrue((self.root/'Documents/report copy 2.txt').exists())

    def test_trash_survives_restart_and_put_back(self):
        self.ws.remove(['Documents/report.txt'])
        ws = Workspace(self.root)
        token = next(iter(ws.trash_index))
        self.assertFalse((self.root/'Documents/report.txt').exists())
        ws.restore(['.Trash/'+token])
        self.assertEqual((self.root/'Documents/report.txt').read_text(), 'keep this content\n')

    def test_restore_collision_preserves_both(self):
        self.ws.remove(['Documents/report.txt'])
        token = next(iter(self.ws.trash_index))
        (self.root/'Documents/report.txt').write_text('new file')
        with self.assertRaises(FileError): self.ws.restore(['.Trash/'+token])
        self.assertEqual((self.root/'Documents/report.txt').read_text(), 'new file')
        self.assertEqual((self.ws.trash/token).read_text(), 'keep this content\n')

    def test_rename_roundtrip(self):
        self.ws.rename('Documents/report.txt', 'renamed.txt')
        self.assertFalse((self.root/'Documents/report.txt').exists())
        self.ws.undo()
        self.assertEqual((self.root/'Documents/report.txt').read_text(), 'keep this content\n')

    def test_create_unique_and_undo_to_trash(self):
        a = self.ws.mkdir('Documents')
        b = self.ws.mkdir('Documents')
        self.assertEqual(b, 'Documents/untitled folder 2')
        (self.root/b/'added.txt').write_text('new contents')
        self.ws.undo()
        token = next(iter(self.ws.trash_index))
        self.assertEqual((self.ws.trash/token/'added.txt').read_text(), 'new contents')
        self.assertTrue((self.root/a).is_dir())

    def test_traversal_and_absolute_paths_are_rejected(self):
        for path in ('../outside', '/tmp', 'Documents/../../outside'):
            with self.subTest(path=path), self.assertRaises(FileError): self.ws.path(path)
        for name in ('../outside', 'a/b', 'a\\b', '', '..'):
            with self.subTest(name=name), self.assertRaises(FileError): self.ws.rename('Documents/report.txt',name)

    def test_symlink_escape_is_rejected(self):
        outside = Path(self.temp.name)/'outside'
        outside.mkdir()
        (self.root/'Documents/link').symlink_to(outside, target_is_directory=True)
        with self.assertRaises(FileError): self.ws.mkdir('Documents/link','bad')
        with self.assertRaises(FileError): self.ws.copy(['Documents'],'Downloads')
        self.assertEqual(list(outside.iterdir()), [])

    def test_symlink_trash_is_rejected(self):
        other = Path(self.temp.name)/'other'
        other.mkdir()
        (other/'.Trash').symlink_to(self.root/'Documents', target_is_directory=True)
        with self.assertRaises(FileError): Workspace(other)

    def test_no_partial_move_on_destination_collision(self):
        (self.root/'Documents/other.txt').write_text('other')
        (self.root/'Downloads/report.txt').write_text('existing')
        with self.assertRaises(FileError):
            self.ws.copy(['Documents/other.txt','Documents/report.txt'],'Downloads',move=True)
        self.assertTrue((self.root/'Documents/other.txt').exists())
        self.assertFalse((self.root/'Downloads/other.txt').exists())
        self.assertEqual((self.root/'Downloads/report.txt').read_text(),'existing')

    def test_parent_child_selection_and_recursive_move(self):
        with self.assertRaises(FileError): self.ws.copy(['Documents'],'Documents')
        self.ws.remove(['Documents','Documents/report.txt'])
        self.assertEqual(len(self.ws.trash_index),1)
        self.ws.undo()
        self.assertTrue((self.root/'Documents/report.txt').exists())


if __name__ == '__main__': unittest.main()
