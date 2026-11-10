"""Hardware metadata fixtures only; never probe or mutate test host hardware."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import system_info


class SystemInfoTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.addCleanup(self.temp.cleanup)
        self.command = Mock(return_value='')
        self.which = Mock(return_value=None)
        hostname = patch('system_info.socket.gethostname', return_value='actual-computer')
        hostname.start()
        self.addCleanup(hostname.stop)

    def put(self, path, text):
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(text)

    def collect(self, **kwargs):
        return system_info.collect_system_info(self.root, platform_name=kwargs.pop('platform_name', 'linux'),
                                               command=self.command, which=self.which, **kwargs)

    def test_hp_model_cpu_dual_gpu_ram_and_actual_makos_release(self):
        self.put('sys/class/dmi/id/sys_vendor', 'HP\n')
        self.put('sys/class/dmi/id/product_name', 'HP EliteBook 840 G8 Notebook PC\n')
        self.put('proc/cpuinfo', 'processor : 0\nmodel name : Intel(R) Core(TM) i7-1165G7 @ 2.80GHz\n')
        self.put('proc/meminfo', 'MemTotal: 16252928 kB\nMemFree: 100 kB\n')
        self.put('etc/os-release', 'ID=makos\nVERSION="0.1 Development"\nPRETTY_NAME="makOS Development (Cutefish)"\n')
        self.which.return_value = '/usr/bin/lspci'
        self.command.return_value = '\n'.join([
            '0000:00:02.0 "VGA compatible controller [0300]" "Intel Corporation [8086]" "TigerLake-LP GT2 [Iris Xe Graphics] [9a49]" -r01',
            '0000:01:00.0 "3D controller [0302]" "NVIDIA Corporation [10de]" "GP108M [GeForce MX150] [1d10]"',
            '0000:00:1f.3 "Audio device [0403]" "Intel Corporation [8086]" "HD Audio [1234]"'])
        result = self.collect()
        self.assertEqual(result['name'], 'HP EliteBook 840 G8 Notebook PC')
        self.assertEqual(result['processor'], 'Intel(R) Core(TM) i7-1165G7 @ 2.80GHz')
        self.assertEqual(result['graphics'], 'Intel Corporation TigerLake-LP GT2 [Iris Xe Graphics]\nNVIDIA Corporation GP108M [GeForce MX150]')
        self.assertEqual(result['memory'], '15.5 GiB')
        self.assertEqual(result['memoryBytes'], 16252928 * 1024)
        self.assertEqual(result['version'], '0.1 Development')
        self.assertFalse(result['isPreview'])
        self.command.assert_called_once_with(['/usr/bin/lspci', '-D', '-mm', '-nn'])

    def test_no_hardware_does_not_fabricate_cpu_gpu_ram_or_pc_model(self):
        result = self.collect()
        self.assertEqual(result['name'], 'actual-computer')
        for key in ('model', 'processor', 'graphics', 'memory'):
            self.assertEqual(result[key], 'Not available')
        self.assertEqual(result['version'], 'Development preview')
        self.assertTrue(result['isPreview'])
        self.command.assert_not_called()

    def test_placeholder_dmi_uses_device_tree_and_arm_cpu(self):
        self.put('sys/class/dmi/id/product_name', 'To Be Filled By O.E.M.')
        self.put('sys/class/dmi/id/sys_vendor', 'Default string')
        self.put('sys/firmware/devicetree/base/model', 'PINE64 ROCKPro64 v2.1\0')
        self.put('proc/cpuinfo', 'Processor : AArch64 Processor rev 4 (aarch64)\n')
        result = self.collect()
        self.assertEqual(result['name'], 'PINE64 ROCKPro64 v2.1')
        self.assertEqual(result['processor'], 'AArch64 Processor rev 4 (aarch64)')

    def test_sysfs_gpu_ids_when_pci_database_unavailable_ignores_connectors(self):
        self.put('sys/class/drm/card0/device/vendor', '0x1002\n')
        self.put('sys/class/drm/card0/device/device', '0x1638\n')
        self.put('sys/class/drm/card0-HDMI-A-1/device/vendor', '0xffff')
        self.put('sys/class/drm/card0-HDMI-A-1/device/device', '0xffff')
        self.assertEqual(self.collect()['graphics'], 'PCI 1002:1638 (model unavailable)')

    def test_other_linux_release_is_host_not_makos_version(self):
        self.put('usr/lib/os-release', 'ID=debian\nVERSION_ID="13"\nPRETTY_NAME="Debian GNU/Linux 13 (trixie)"\n')
        result = self.collect()
        self.assertEqual(result['platform'], 'Debian GNU/Linux 13 (trixie)')
        self.assertEqual(result['version'], 'Development preview')
        self.assertTrue(result['isPreview'])

    def test_release_is_parsed_without_shell_evaluation(self):
        self.put('etc/os-release', 'ID=makos\nVERSION="$(touch NEVER_EXECUTE)"\nINVALID="unterminated\n')
        self.assertEqual(self.collect()['version'], '$(touch NEVER_EXECUTE)')
        self.assertFalse((self.root / 'NEVER_EXECUTE').exists())
        self.command.assert_not_called()

    def test_mac_preview_is_identified_with_specific_metadata_queries_no_serial(self):
        values = {'hw.model':'MacBookPro16,1\n', 'machdep.cpu.brand_string':'Intel Core i9\n',
                  'hw.memsize':str(32 * 1024**3), '-productVersion':'26.7.2\n'}
        self.command.side_effect = lambda args: values[args[-1]]
        result = self.collect(platform_name='darwin')
        self.assertEqual(result['name'], 'MacBookPro16,1')
        self.assertEqual(result['memory'], '32 GiB')
        self.assertEqual(result['platform'], 'macOS 26.7.2')
        self.assertTrue(result['isPreview'])
        self.assertEqual(result['version'], 'Development preview')
        self.assertEqual(result['manufacturer'], 'Not available')
        self.assertEqual(result['modelSource'], 'macOS-reported model identifier')
        self.assertFalse(any('serial' in str(call).lower() for call in self.command.call_args_list))
        self.which.assert_not_called()

    def test_probe_timeout_returns_unavailable_and_is_bounded(self):
        with patch('system_info.subprocess.run', side_effect=subprocess.TimeoutExpired('lspci', 2)) as run:
            self.assertEqual(system_info._command(['/usr/bin/lspci', '-D', '-mm', '-nn']), '')
            self.assertEqual(run.call_args.kwargs['timeout'], 2)
            self.assertFalse(run.call_args.kwargs.get('shell', False))


if __name__ == '__main__':
    unittest.main()
