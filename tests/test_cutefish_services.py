import sys
import unittest
from unittest.mock import patch
from PySide6.QtCore import QCoreApplication
from cutefish_services import CutefishShell


class CutefishContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls): cls.app = QCoreApplication.instance() or QCoreApplication([])

    def setUp(self):
        self.calls = []
        with patch.object(sys, 'platform', 'linux'):
            self.shell = CutefishShell(True, transport=lambda *args: self.calls.append(args))

    def test_dock_wire_types(self):
        self.shell.setDockSize(54); self.shell.setDockAutoHide(True); self.shell.setDockGlassTint(.5)
        self.assertEqual(self.calls, [
            ('org.cutefish.Dock','/Dock','org.cutefish.Dock','setIconSize',[54]),
            ('org.cutefish.Dock','/Dock','org.cutefish.Dock','setVisibility',[1]),
            ('org.cutefish.Dock','/Dock','org.cutefish.Dock','setGlassTint',[.5])])

    def test_invalid_values_are_not_sent(self):
        for size in (-1, 0, 65, 100000): self.shell.setDockSize(size)
        for tint in (-1, 2, float('nan'), float('inf')): self.shell.setDockGlassTint(tint)
        self.shell.preferenceChanged('dock.size', 'not a number')
        self.assertEqual(self.calls, [])

    def test_only_supported_preferences_are_forwarded(self):
        self.shell.preferenceChanged('control.bar.wifi', 'true')
        self.shell.preferenceChanged('battery.showPercentage', 'true')
        self.assertEqual(self.calls, [('org.cutefish.Statusbar','/Statusbar','org.cutefish.Statusbar','setBatteryPercentage',[True])])

    def test_preview_and_stopped_clients_do_not_call_shell(self):
        shell = CutefishShell(False, transport=lambda *args: self.calls.append(args))
        shell.setDockSize(40)
        self.shell.stop(); self.shell.setDockAutoHide(False)
        self.assertEqual(self.calls, [])


if __name__ == '__main__': unittest.main()
