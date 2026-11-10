#!/usr/bin/env python3
"""makOS Recovery chooser. Disk changes belong to the explicitly opened utility."""
import argparse
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
from PySide6.QtCore import QObject, Property, Signal, Slot, QProcess, QTimer, QUrl, QCoreApplication, QEvent, QSettings
from PySide6.QtGui import QGuiApplication, QFont
from PySide6.QtQuick import QQuickWindow
from PySide6.QtQml import QQmlApplicationEngine

ROOT = Path(__file__).resolve().parents[1]
TOOLS = {
    'restore': ('deja-dup', ['--restore']),
    'install': ('cutefish-installer', []),
    'browser': ('chromium', []),
    'disks': ('gnome-disks', []),
    'terminal': ('cutefish-terminal', []),
}
CHOICES = [
    {'id':'restore', 'title':'Restore from Backup', 'description':'Restore your files from a compatible backup.', 'icon':'assets/original/time-machine.png'},
    {'id':'install', 'title':'Install makOS', 'description':'Install a new copy of makOS on your computer.', 'icon':'assets/install.svg'},
    {'id':'browser', 'title':'Web Browser', 'description':'Browse the web to get help with your computer.', 'icon':'assets/original/safari.png'},
    {'id':'disks', 'title':'Disk Utility', 'description':'Inspect, repair or erase a disk.', 'icon':'assets/original/disk-utility.png'},
]


def is_live_system():
    return sys.platform == 'linux' and Path('/run/live/medium').is_mount() and Path('/etc/makos/live.json').is_file()


class RecoveryController(QObject):
    openDisks = Signal()
    message = Signal(str, str)
    externalChanged = Signal()
    returning = Signal()
    quitting = Signal()

    def __init__(self, live=False, resolver=shutil.which, process_factory=QProcess):
        super().__init__()
        self._live = bool(live)
        self._resolver = resolver
        self._process_factory = process_factory
        self._process = None
        self._external = False
        self._browser_profile = None

    @Property('QVariantList', constant=True)
    def choices(self): return CHOICES

    @Property(bool, constant=True)
    def live(self): return self._live

    @Property(bool, notify=externalChanged)
    def externalActive(self): return self._external

    @Slot(str)
    def launch(self, kind):
        if kind not in TOOLS or self._process is not None: return
        if kind == 'disks': self.openDisks.emit(); return
        if not self._live:
            details = {
                'install':'Boot the makOS live image to select a destination disk and start installation.',
                'restore':'Boot the makOS live image to restore a Déjà Dup backup. Apple Time Machine backups are not supported.',
                'disks':'Boot the makOS live image to inspect and manage disks.',
                'browser':'The live image opens its web browser here.',
                'terminal':'The live image opens its terminal here.'}
            self.message.emit('Recovery Preview', details[kind]); return
        program, arguments = TOOLS[kind]
        executable = self._resolver(program)
        if not executable:
            self.message.emit('Utility Unavailable', 'This live image is missing ' + program + '.'); return
        arguments = list(arguments)
        if kind == 'browser':
            if self._browser_profile is None: self._browser_profile = tempfile.TemporaryDirectory(prefix='makos-recovery-browser-')
            arguments = ['--new-window', '--user-data-dir=' + self._browser_profile.name,
                         'https://github.com/slaveitgr/mak-desktop-environent']
        process = self._process_factory(self)
        self._process = process
        process.started.connect(self._started)
        process.finished.connect(self._finished)
        process.errorOccurred.connect(self._failed)
        process.start(executable, arguments)

    def _started(self):
        self._external = True; self.externalChanged.emit()

    def _finished(self, code=0, *_):
        process = self._process
        self._process = None; self._external = False; self.externalChanged.emit(); self.returning.emit()
        if process: process.deleteLater()
        if code: self.message.emit('Utility Closed', 'The utility exited with an error. You can try opening it again.')

    def _failed(self, error):
        if error == QProcess.ProcessError.FailedToStart:
            self._finished()
            self.message.emit('Unable to Open Utility', 'The utility could not be started.')

    @Slot(str)
    def command(self, command):
        if command in TOOLS: self.launch(command)
        elif command == 'about': self.message.emit('About makOS Recovery', 'makOS Recovery · Development build\nA recovery environment for makOS on Linux.')
        elif command == 'help': self.message.emit('Recovery Help', 'Select a utility, then choose Continue. Installation and disk changes are confirmed inside their utilities. Restore from Backup supports Déjà Dup backups, not Time Machine.')
        elif command == 'desktop' and not self._external: self.quitting.emit()


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument('--preview', action='store_true')
    parser.add_argument('--autostart', action='store_true')
    parser.add_argument('--smoke-test', action='store_true')
    parser.add_argument('--native-shell', action='store_true')
    parser.add_argument('--disk-utility', action='store_true')
    parser.add_argument('--screenshot', type=Path)
    args = parser.parse_args(argv)
    live = is_live_system() and not args.preview and not args.smoke_test
    if args.autostart and not live: return 0
    os.environ.setdefault('QT_QUICK_CONTROLS_STYLE', 'Basic')
    app = QGuiApplication([])
    app.setApplicationName('makOS Recovery'); app.setOrganizationName('makOS')
    app.setDesktopFileName('org.makos.Recovery')
    app.setFont(QFont('.AppleSystemUIFont' if sys.platform == 'darwin' else 'Inter', 13))
    controller = RecoveryController(live)
    from disks import DiskInventory
    disks = DiskInventory(preview=not live, parent=controller)
    engine = QQmlApplicationEngine()
    native = (live or args.native_shell) and bool(os.environ.get('WAYLAND_DISPLAY')) and (ROOT/'cutefish/build/qml/MakOS/Cutefish/qmldir').is_file()
    if native: engine.addImportPath(str(ROOT/'cutefish/build/qml'))
    engine.rootContext().setContextProperty('RecoveryBackend', controller)
    engine.rootContext().setContextProperty('DiskBackend', disks)
    engine.rootContext().setContextProperty('nativeShell', native)
    engine.load(QUrl.fromLocalFile(str(ROOT/'installer/Recovery.qml')))
    if not engine.rootObjects(): return 1
    window = engine.rootObjects()[0]
    dock = None
    dock_visibility = 0
    if live and native:
        sys.path.insert(0, str(ROOT))
        from cutefish_services import CutefishShell
        dock = CutefishShell(True, controller)
        config = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home()/'.config'))) / 'cutefish/shell.conf'
        dock_visibility = QSettings(str(config), QSettings.Format.IniFormat).value('Dock/Visibility', 0, int)
        QTimer.singleShot(500, lambda: dock.setDockAutoHide(True))
    def quit_recovery():
        if dock:
            dock.setDockVisibility(dock_visibility)
            QTimer.singleShot(150, app.quit)
        else: app.quit()
    controller.quitting.connect(quit_recovery)
    if args.disk_utility: QTimer.singleShot(50, controller.openDisks.emit)
    if args.smoke_test or args.screenshot:
        def capture():
            def visual_names(item):
                return [item.objectName()] + [name for child in item.childItems() for name in visual_names(child)]
            names = visual_names(window.contentItem())
            if not all('recoveryChoice_' + entry['id'] in names for entry in CHOICES):
                print('FAIL: Recovery choices missing', flush=True); app.exit(1); return
            if args.screenshot:
                args.screenshot.parent.mkdir(parents=True, exist_ok=True)
                target = window.findChild(QQuickWindow, 'makOSDiskUtility') if args.disk_utility else window
                if not target or not target.grabWindow().save(str(args.screenshot)): app.exit(1); return
            if native and not args.disk_utility:
                bridge = window.findChild(QObject, 'cutefishRecoveryBridge')
                if not bridge or not bridge.property('active'):
                    print('FAIL: Recovery native menu bridge inactive', flush=True); app.exit(1); return
            if args.disk_utility:
                target = window.findChild(QQuickWindow, 'makOSDiskUtility')
                if not target or not target.isVisible() or len(disks.rows) != 5: app.exit(1); return
                if native:
                    bridge = target.findChild(QObject, 'cutefishDiskBridge')
                    if not bridge or not bridge.property('active'): app.exit(1); return
            print('PASS: makOS Recovery four-option chooser loaded' + ('; Disk Utility loaded' if args.disk_utility else ''), flush=True)
            app.quit()
        QTimer.singleShot(700, capture)
    code = app.exec()
    engine.deleteLater(); QCoreApplication.sendPostedEvents(None, QEvent.Type.DeferredDelete)
    return code


if __name__ == '__main__': sys.exit(main())
