import unittest
from installer.clean_image import package_records, removal_plan, validate_simulation, guard

class ImageCleanupTests(unittest.TestCase):
    def test_runtime_packages_are_not_build_tools(self):
        runtime = {'cutefish-core', 'cutefish-framework', 'cutefish-toolkit', 'libgcc-s1',
                   'gcc-14-base', 'libstdc++6', 'qml6-module-qtquick', 'qt6-wayland',
                   'linux-image-amd64', 'network-manager', 'python3-pyside6.qtquick'}
        build = {'qt6-base-dev', 'libwayland-dev', 'g++', 'gcc-14', 'g++-14-x86-64-linux-gnu',
                 'qt6-declarative-dev-tools', 'cmake'}
        self.assertEqual(set(removal_plan(runtime | build)), build)
    def test_simulation_rejects_runtime_cascade_and_installs(self):
        self.assertEqual(validate_simulation('Purg cutefish-settings [1]\nRemv cmake [3]',
                                            ['cutefish-settings','cmake']), ['cmake','cutefish-settings'])
        for plan in ('Remv cmake [3]\nRemv cutefish-core [1]', 'Inst new-package [1]', ''):
            with self.assertRaises(RuntimeError): validate_simulation(plan, ['cmake'])
    def test_only_installed_packages_are_counted(self):
        records = package_records('Package: old\nStatus: deinstall ok config-files\n\n'
                                  'Package: retained\nStatus: install ok installed\nVersion: 1\n')
        self.assertEqual(set(records), {'retained'})
    def test_cleanup_refuses_host(self):
        with self.assertRaises(SystemExit): guard()

if __name__ == '__main__': unittest.main()
