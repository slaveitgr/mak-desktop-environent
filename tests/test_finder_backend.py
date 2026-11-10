"""Real temporary-file regressions for Finder mutations and recursive search."""
import errno
import json
import os
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import finder_backend
from filesystem import Workspace, FileError


class FinderFileOperationTests(unittest.TestCase):
    def setUp(self):
        self.temp = TemporaryDirectory()
        self.root = Path(self.temp.name) / 'workspace'
        self.ws = Workspace(self.root)
        (self.root / 'Source').mkdir()
        (self.root / 'Target').mkdir()
        (self.root / 'Source/report.txt').write_text('original report')
        self.outside = Path(self.temp.name) / 'outside'
        self.outside.mkdir()

    def tearDown(self):
        self.temp.cleanup()

    def test_copy_collision_with_dangling_link_never_writes_through_it(self):
        link = self.root / 'Target/report.txt'
        link.symlink_to(self.outside / 'not-created.txt')
        result = self.ws.copy(['Source/report.txt'], 'Target')
        self.assertEqual(result, ['Target/report copy.txt'])
        self.assertTrue(link.is_symlink())
        self.assertFalse((self.outside / 'not-created.txt').exists())
        self.assertEqual((self.root / result[0]).read_text(), 'original report')

    def test_move_and_rename_refuse_dangling_destinations(self):
        (self.root / 'Target/report.txt').symlink_to(self.outside / 'missing')
        (self.root / 'Source/new.txt').symlink_to(self.outside / 'missing')
        with self.assertRaises(FileError):
            self.ws.copy(['Source/report.txt'], 'Target', move=True)
        with self.assertRaises(FileError):
            self.ws.rename('Source/report.txt', 'new.txt')
        self.assertEqual((self.root / 'Source/report.txt').read_text(), 'original report')
        self.assertTrue((self.root / 'Source/new.txt').is_symlink())
        self.assertEqual(list(self.outside.iterdir()), [])

    def test_copy_publication_collision_does_not_replace_the_new_arrival(self):
        rename = finder_backend.rename_exclusive

        def collide(source, target):
            Path(target).write_text('arrived after copy planning')
            rename(source, target)

        with patch.object(finder_backend, 'rename_exclusive', side_effect=collide):
            with self.assertRaises(FileError):
                self.ws.copy(['Source/report.txt'], 'Target')
        self.assertEqual((self.root / 'Target/report.txt').read_text(), 'arrived after copy planning')
        self.assertEqual((self.root / 'Source/report.txt').read_text(), 'original report')
        self.assertEqual(self.ws.undo_stack, [])
        self.assertEqual(list((self.root / 'Target').glob('.finder-transfer-*')), [])

    def test_failed_copy_removes_only_its_private_staging_data(self):
        def disk_full(source, target, **kwargs):
            Path(target).write_text('incomplete data')
            raise OSError(errno.ENOSPC, 'Simulated full temporary disk')

        with patch.object(finder_backend.shutil, 'copy2', side_effect=disk_full):
            with self.assertRaises(FileError):
                self.ws.copy(['Source/report.txt'], 'Target')
        self.assertEqual(list((self.root / 'Target').iterdir()), [])
        self.assertEqual((self.root / 'Source/report.txt').read_text(), 'original report')
        self.assertEqual(self.ws.undo_stack, [])

    def test_completed_part_of_failed_batch_remains_undoable(self):
        (self.root / 'Source/second.txt').write_text('second original')
        copy = finder_backend.copy_exclusive

        def second_fails(source, target, metadata):
            if Path(source).name == 'second.txt':
                raise OSError(errno.ENOSPC, 'Simulated disk full')
            return copy(source, target, metadata)

        with patch('filesystem.copy_exclusive', side_effect=second_fails):
            with self.assertRaises(FileError):
                self.ws.copy(['Source/report.txt', 'Source/second.txt'], 'Target')
        self.assertEqual((self.root / 'Target/report.txt').read_text(), 'original report')
        self.assertFalse((self.root / 'Target/second.txt').exists())
        self.assertEqual(self.ws.undo_title, 'Partial Copy')
        self.ws.undo()
        self.assertEqual(list((self.root / 'Target').iterdir()), [])
        self.assertEqual((self.root / 'Source/second.txt').read_text(), 'second original')

    def test_same_names_in_multiselection_preserve_every_contents(self):
        (self.root / 'Another').mkdir()
        (self.root / 'Another/report.txt').write_text('another report')
        result = self.ws.copy(['Source/report.txt', 'Another/report.txt'], 'Target')
        self.assertEqual(len(set(result)), 2)
        self.assertEqual({(self.root / p).read_text() for p in result}, {'original report', 'another report'})
        self.ws.undo()
        self.assertEqual(list((self.root / 'Target').iterdir()), [])

    def test_trash_index_write_failure_leaves_source_in_place(self):
        with patch.object(self.ws, '_save_trash', side_effect=OSError(errno.ENOSPC, 'Full disk')):
            with self.assertRaises(OSError):
                self.ws.remove(['Source/report.txt'])
        self.assertEqual((self.root / 'Source/report.txt').read_text(), 'original report')
        self.assertEqual(self.ws.trash_index, {})
        self.assertEqual(list(self.ws.trash.iterdir()), [])

    def test_trash_index_temporary_name_cannot_write_through_a_planted_link(self):
        marker = self.outside / 'marker'
        marker.write_text('do not touch')
        (self.ws.trash / '.index.tmp').symlink_to(marker)
        self.ws.remove(['Source/report.txt'])
        self.assertEqual(marker.read_text(), 'do not touch')
        restarted = Workspace(self.root)
        token = next(iter(restarted.trash_index))
        restarted.restore(['.Trash/' + token])
        self.assertEqual((self.root / 'Source/report.txt').read_text(), 'original report')

    def test_replaced_trash_directory_is_rejected_after_initialization(self):
        self.ws.trash.rename(self.root / 'old-trash')
        self.ws.trash.symlink_to(self.outside, target_is_directory=True)
        with self.assertRaises(FileError):
            self.ws.remove(['Source/report.txt'])
        self.assertTrue((self.root / 'Source/report.txt').is_file())
        self.assertEqual(list(self.outside.iterdir()), [])

    def test_restore_collision_preflights_the_entire_selection(self):
        (self.root / 'Source/second.txt').write_text('second original')
        self.ws.remove(['Source/report.txt', 'Source/second.txt'])
        items = ['.Trash/' + token for token in self.ws.trash_index]
        (self.root / 'Source/second.txt').write_text('new arrival')
        with self.assertRaises(FileError):
            self.ws.restore(items)
        self.assertFalse((self.root / 'Source/report.txt').exists())
        self.assertEqual(len(self.ws.trash_index), 2)
        self.assertEqual((self.root / 'Source/second.txt').read_text(), 'new arrival')

    def test_restart_and_restore_refuse_a_dangling_original_location(self):
        self.ws.remove(['Source/report.txt'])
        token = next(iter(self.ws.trash_index))
        (self.root / 'Source/report.txt').symlink_to(self.outside / 'missing')
        restarted = Workspace(self.root)
        with self.assertRaises(FileError):
            restarted.restore(['.Trash/' + token])
        self.assertEqual((restarted.trash / token).read_text(), 'original report')
        self.assertEqual(list(self.outside.iterdir()), [])

    def test_put_back_undo_and_duplicate_selection(self):
        self.ws.remove(['Source/report.txt'])
        item = '.Trash/' + next(iter(self.ws.trash_index))
        self.assertEqual(self.ws.restore([item, item]), ['Source/report.txt'])
        self.ws.undo()
        self.assertFalse((self.root / 'Source/report.txt').exists())
        self.assertEqual(len(self.ws.trash_index), 1)

    def test_trash_preserves_long_original_names_across_restart(self):
        name = 'a' * 247 + '.txt'
        (self.root / 'Source' / name).write_text('long-name contents')
        self.ws.remove(['Source/' + name])
        restarted = Workspace(self.root)
        token = next(iter(restarted.trash_index))
        self.assertEqual(restarted.trash_index[token]['name'], name)
        restarted.restore(['.Trash/' + token])
        self.assertEqual((self.root / 'Source' / name).read_text(), 'long-name contents')

    def test_corrupt_trash_metadata_cannot_restore_outside_workspace(self):
        (self.ws.trash / '.index.json').write_text(json.dumps({
            'token': {'original': str(self.outside / 'escape'), 'name': 'escape'}}))
        with self.assertRaises(FileError):
            Workspace(self.root)
        self.assertEqual(list(self.outside.iterdir()), [])

    def test_reserved_appdata_name_cannot_be_created_or_renamed(self):
        with self.assertRaises(FileError):
            self.ws.mkdir('', '.desktop-data')
        with self.assertRaises(FileError):
            self.ws.rename('Source', '.desktop-data')
        self.assertTrue((self.root / 'Source/report.txt').exists())

    def test_search_descends_without_reading_outside_or_internal_data(self):
        (self.root / 'Source/Deep').mkdir()
        (self.root / 'Source/Deep/REPORT Two.txt').write_text('nested result')
        (self.root / 'Source/.hidden-report.txt').write_text('hidden')
        (self.root / '.desktop-data').mkdir()
        (self.root / '.desktop-data/report.db').write_text('private data')
        (self.outside / 'report-outside.txt').write_text('outside')
        (self.root / 'Source/escape').symlink_to(self.outside, target_is_directory=True)
        (self.root / 'Source/loop').symlink_to(self.root, target_is_directory=True)
        results, limited = self.ws.search('', 'REPORT')
        self.assertFalse(limited)
        self.assertEqual(set(results), {'Source/report.txt', 'Source/Deep/REPORT Two.txt'})
        visible, _ = self.ws.search('Source', 'report', hidden=True)
        self.assertIn('Source/.hidden-report.txt', visible)
        self.assertFalse(any('outside' in path or 'loop' in path for path in visible))

    def test_search_respects_starting_directory_and_reports_limits(self):
        (self.root / 'Target/report-target.txt').write_text('outside search scope')
        results, limited = self.ws.search('Source', 'report')
        self.assertEqual(results, ['Source/report.txt'])
        self.assertFalse(limited)
        for number in range(5):
            (self.root / 'Source' / f'report{number}').write_text('fixture')
        results, limited = finder_backend.search_names(self.root / 'Source', 'report', max_results=2)
        self.assertEqual(len(results), 2)
        self.assertTrue(limited)

    @unittest.skipUnless(hasattr(os, 'mkfifo'), 'FIFO fixture requires POSIX')
    def test_search_excludes_special_files_without_opening_them(self):
        os.mkfifo(self.root / 'Source/report-pipe.txt')
        results, _ = self.ws.search('Source', 'report')
        self.assertEqual(results, ['Source/report.txt'])
        with self.assertRaises(OSError):
            finder_backend.read_regular_preview(self.root / 'Source/report-pipe.txt')

    def test_preview_refuses_links_and_caps_the_read(self):
        (self.outside / 'private.txt').write_text('outside contents')
        (self.root / 'Source/link.txt').symlink_to(self.outside / 'private.txt')
        with self.assertRaises(OSError):
            finder_backend.read_regular_preview(self.root / 'Source/link.txt')
        self.assertEqual(finder_backend.read_regular_preview(self.root / 'Source/report.txt', 8), b'original')


if __name__ == '__main__':
    unittest.main()
