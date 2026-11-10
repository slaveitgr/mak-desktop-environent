import unittest
from unittest.mock import patch
from PySide6.QtCore import QCoreApplication
from installer.disks import inventory, DiskInventory, DEMO

class DiskInventoryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.app=QCoreApplication.instance() or QCoreApplication([])
    def test_partition_tree_inherits_transport_and_scheme(self):
        rows=inventory(DEMO)
        self.assertEqual(len(rows),5)
        self.assertEqual(rows[2]['depth'],1)
        self.assertEqual(rows[2]['scheme'],'GUID Partition Table')
        self.assertEqual(rows[-1]['category'],'External')
        self.assertEqual(rows[-1]['transport'],'USB')
    def test_unavailable_usage_is_not_reported_as_empty(self):
        rows=inventory(DEMO)
        self.assertFalse(rows[0]['usageKnown'])
        self.assertEqual(rows[0]['available'],'Not available')
        self.assertTrue(rows[2]['usageKnown'])
        self.assertAlmostEqual(rows[2]['fraction'],32000000000/489000000000)
    def test_empty_and_unsafe_device_paths_are_ignored(self):
        self.assertEqual(inventory({'blockdevices':[{'path':'/tmp/device'},{'path':'/dev/../tmp/disk'}]}),[])
        self.assertEqual(inventory({}),[])
    def test_preview_never_starts_system_disk_tools(self):
        disks=DiskInventory(True);disks.refresh()
        with patch('installer.disks.QProcess.startDetached') as start:
            disks.openDiskTools('/dev/sdb');start.assert_not_called()
    def test_unknown_or_disappeared_device_does_not_launch(self):
        with patch('installer.disks.sys.platform','linux'):disks=DiskInventory(False)
        disks._rows=inventory(DEMO)
        with patch('installer.disks.QProcess.startDetached') as start, patch('installer.disks.Path.stat',side_effect=FileNotFoundError):
            disks.openDiskTools('/dev/unknown');disks.openDiskTools('/dev/sdb');start.assert_not_called()
    def test_explicit_handoff_only_selects_existing_block_device(self):
        import stat
        from types import SimpleNamespace
        with patch('installer.disks.sys.platform','linux'):disks=DiskInventory(False)
        disks._rows=inventory(DEMO)
        with patch('installer.disks.Path.stat',return_value=SimpleNamespace(st_mode=stat.S_IFBLK)), patch('installer.disks.shutil.which',return_value='/usr/bin/gnome-disks'), patch('installer.disks.QProcess.startDetached',return_value=(True,123)) as start:
            disks.openDiskTools('/dev/sdb')
            start.assert_called_once_with('/usr/bin/gnome-disks',['--block-device','/dev/sdb'])

if __name__=='__main__':unittest.main()
