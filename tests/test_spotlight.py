import os
from pathlib import Path
import tempfile
import unittest
from spotlight import discover_files


class SpotlightFilesTests(unittest.TestCase):
    def test_reads_names_without_following_links_or_opening_special_files(self):
        with tempfile.TemporaryDirectory() as folder, tempfile.TemporaryDirectory() as outside:
            root=Path(folder);(root/'Documents').mkdir();(root/'.desktop-data').mkdir()
            (root/'Documents'/'Report.txt').write_text('private content never indexed')
            (root/'.desktop-data'/'secret.txt').write_text('hidden')
            (Path(outside)/'outside.txt').write_text('outside')
            (root/'alias').symlink_to(outside,target_is_directory=True)
            os.mkfifo(root/'pipe')
            rows,limited=discover_files(root,'REPORT')
            self.assertFalse(limited)
            self.assertEqual([row['path'] for row in rows],['Documents/Report.txt'])
            self.assertNotIn('private',str(rows))
            rows,_=discover_files(root)
            self.assertEqual(len(rows),1)

    def test_recent_order_and_bounded_results(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder)
            for index in range(110):
                p=root/('File%03d.txt'%index);p.touch();os.utime(p,(index+1,index+1))
            rows,limited=discover_files(root)
            self.assertFalse(limited);self.assertEqual(len(rows),100)
            self.assertEqual(rows[0]['name'],'File109.txt')
            _,limited=discover_files(root,max_entries=5)
            self.assertTrue(limited)


if __name__=='__main__':unittest.main()
