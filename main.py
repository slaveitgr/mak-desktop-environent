#!/usr/bin/env python3
"""Tahoe desktop interaction prototype. Qt Quick frontend, real local files."""
import argparse
import json
import mimetypes
import os
import stat
from pathlib import Path
import sys
from datetime import datetime

from PySide6.QtCore import QObject, Signal, Slot, Property, QUrl, QFileSystemWatcher, QTimer, Qt, QProcess, QEventLoop, QCoreApplication, QEvent
from PySide6.QtGui import QGuiApplication, QFont, QFontDatabase
from PySide6.QtQml import QQmlApplicationEngine, QQmlEngine
from PySide6.QtMultimedia import QImageCapture
from filesystem import Workspace, FileError, seed_workspace
from finder_backend import read_regular_preview
from applications import ApplicationLauncher, NATIVE_APP_IDS, NATIVE_APP_INFO, native_command
from suite import Suite, ChessGame
from terminal_session import TerminalSession
from linux_session import LinuxSession
from dde_services import DdeAudio
from cutefish_services import CutefishShell
from browser_profiles import BrowserProfiles
from linux_settings import LinuxSettings
from spotlight import Spotlight

APP_DIR = Path(__file__).resolve().parent


def human_size(size):
    for unit in ('bytes', 'KB', 'MB', 'GB'):
        if size < 1000 or unit == 'GB':
            return f'{int(size)} {unit}' if unit == 'bytes' else f'{size:.1f} {unit}'
        size /= 1000


class Browser(QObject):
    changed = Signal()
    locationChanged = Signal()

    def __init__(self, bridge, path):
        super().__init__(bridge)
        self.bridge = bridge
        self._path = ''
        self._files = []
        self._history = []
        self._history_index = -1
        self._query = ''
        self._sort = 'name'
        self._reverse = False
        self._hidden = False
        self.watcher = QFileSystemWatcher(self)
        self.watcher.directoryChanged.connect(self.refresh)
        self.navigate(path)

    @Property(str, notify=changed)
    def currentPath(self): return self._path

    @Property(str, notify=changed)
    def title(self):
        if self._path == '@applications': return 'Applications'
        if self._path == '@recents': return 'Recents'
        if self._path.startswith('@tag:'): return self._path[5:]
        if self._path == '.Trash': return 'Trash'
        return Path(self._path).name if self._path else 'Home'

    @Property('QVariantList', notify=changed)
    def files(self): return self._files

    @Property('QVariantList', notify=changed)
    def breadcrumbs(self):
        if self._path == '@applications': return [{'name': 'Applications', 'path': '@applications'}]
        if self._path == '@recents': return [{'name': 'Recents', 'path': '@recents'}]
        if self._path == '.Trash': return [{'name': 'Trash', 'path': '.Trash'}]
        if self._path.startswith('@tag:'): return [{'name': self._path[5:], 'path': self._path}]
        result = [{'name':'Home', 'path':''}]
        path = ''
        for part in Path(self._path).parts:
            path = (path + '/' + part).lstrip('/')
            result.append({'name':part, 'path':path})
        return result

    @Property(bool, notify=changed)
    def canBack(self): return self._history_index > 0

    @Property(bool, notify=changed)
    def canForward(self): return self._history_index < len(self._history) - 1

    @Property(bool, notify=changed)
    def isTrash(self): return self._path == '.Trash'

    @Slot(str)
    def navigate(self, path):
        try:
            if path.startswith('@') and path not in ('@recents', '@applications') and not (path.startswith('@tag:') and path[5:] in Workspace.TAGS):
                raise FileError('This location is not available.')
            if not path.startswith('@') and not self.bridge.workspace.path(path, allow_trash=True).is_dir():
                raise FileError('This folder is no longer available.')
            if self._history_index >= 0 and path == self._path: return
            self._path = path
            self._query = ''
            self._history = self._history[:self._history_index + 1] + [path]
            self._history_index += 1
            self._watch()
            self.refresh()
            self.locationChanged.emit()
        except (OSError, FileError) as exc:
            self.bridge.error.emit(str(exc))

    def _watch(self):
        if self.watcher.directories(): self.watcher.removePaths(self.watcher.directories())
        if not self._path.startswith('@'):
            self.watcher.addPath(str(self.bridge.workspace.path(self._path, allow_trash=True)))

    @Slot()
    def back(self): self._travel(-1)

    @Slot()
    def forward(self): self._travel(1)

    def _travel(self, step):
        idx = self._history_index + step
        if 0 <= idx < len(self._history):
            self._history_index = idx
            self._path = self._history[idx]
            self._query = ''
            self._watch()
            self.refresh()
            self.locationChanged.emit()

    @Slot()
    def up(self):
        if self._path not in ('', '.Trash') and not self._path.startswith('@'):
            parent = str(Path(self._path).parent)
            self.navigate('' if parent == '.' else parent)

    @Slot(str)
    def search(self, query):
        self._query = query
        self.refresh()

    @Slot(str)
    def sortBy(self, key):
        self._reverse = not self._reverse if key == self._sort else False
        self._sort = key
        self.refresh()

    @Slot()
    def toggleHidden(self):
        self._hidden = not self._hidden
        self.refresh()

    @Slot()
    def refresh(self, *args):
        try:
            if self._query.strip() and not self._path.startswith('@') and self._path != '.Trash':
                self._files = self.bridge.search_files(self._path, self._query, self._hidden)
            else:
                self._files = self.bridge.list_files(self._path, self._hidden)
            if self._query and (self._path.startswith('@') or self._path == '.Trash'):
                self._files = [x for x in self._files if self._query.casefold() in x['name'].casefold()]
            key = self._sort
            self._files.sort(key=lambda x: x.get(key, '').casefold() if isinstance(x.get(key), str) else x.get(key, 0), reverse=self._reverse)
            self.changed.emit()
        except (OSError, FileError):
            if self._path not in ('', '@recents'):
                parent = str(Path(self._path).parent)
                self._path = '' if parent == '.' else parent
                self.refresh()


class Bridge(QObject):
    error = Signal(str)
    stateChanged = Signal()
    filesystemChanged = Signal()
    cameraPermissionResult = Signal(bool, str)

    def __init__(self, workspace, session_mode=False, dde_mode=False, cutefish_mode=False, terminal_auto_start=True):
        super().__init__()
        self.workspace = workspace
        self._terminal_auto_start = terminal_auto_start
        self._spotlight = Spotlight(workspace.root, self)
        self.browsers = []
        self.launcher = ApplicationLauncher(native=cutefish_mode)
        self._dde_audio = DdeAudio(dde_mode, self)
        self._dde_audio.error.connect(self.error)
        self._session = LinuxSession(session_mode, self, cutefish_mode=cutefish_mode)
        self._session.error.connect(self.error)
        self._suite = Suite(workspace.root, self)
        self._browser_profiles = BrowserProfiles(self._suite.data_dir, self)
        self._suite.error.connect(self.error)
        if cutefish_mode: self._suite.watchExternalChanges()
        self._cutefish_shell = CutefishShell(cutefish_mode and os.environ.get('XDG_SESSION_DESKTOP') != 'makos', self)
        self._cutefish_shell.error.connect(self.error)
        self._linux_settings = LinuxSettings(cutefish_mode, self)
        self._suite.preferenceChanged.connect(self._cutefish_shell.preferenceChanged)
        self._chess = ChessGame(self._suite, self)
        self.terminals = []
        self._download_decisions = {}
        self._shutting_down = False

    @Property(QObject, constant=True)
    def suite(self): return self._suite

    @Property(QObject, constant=True)
    def browserProfiles(self): return self._browser_profiles

    @Property(QObject, constant=True)
    def session(self): return self._session

    @Property(QObject, constant=True)
    def ddeAudio(self): return self._dde_audio

    @Property(QObject, constant=True)
    def chess(self): return self._chess

    @Property(bool, constant=True)
    def terminalAutoStart(self): return self._terminal_auto_start

    @Property(QObject, constant=True)
    def spotlight(self): return self._spotlight

    @Slot(str, result=bool)
    def openSpotlightFile(self, relative):
        from PySide6.QtGui import QDesktopServices
        try:
            path = self.workspace.path(relative)
            if not stat.S_ISREG(path.lstat().st_mode): return False
            return QDesktopServices.openUrl(QUrl.fromLocalFile(str(path)))
        except (OSError, FileError): return False

    @Slot(result=QObject)
    def createTerminal(self):
        terminal = TerminalSession(self.workspace.root, self)
        self.terminals.append(terminal)
        QQmlEngine.setObjectOwnership(terminal, QQmlEngine.CppOwnership)
        return terminal

    @Slot(QObject)
    def releaseTerminal(self, terminal):
        if terminal in self.terminals:
            terminal.stop()
            if terminal.running:
                self.error.emit('The shell could not be stopped. It remains tracked for cleanup when this desktop exits.')
                return
            self.terminals.remove(terminal)
            terminal.deleteLater()

    @Slot(str, result=bool)
    def launchCutefishApp(self, app_id):
        command = native_command(app_id, APP_DIR, self.workspace.root)
        if not command:
            self.error.emit('This makOS application is not registered.')
            return False
        result = QProcess.startDetached(command[0], command[1:])
        started = result[0] if isinstance(result, tuple) else result
        if not started:
            self.error.emit(NATIVE_APP_INFO[app_id]['name'] + ' could not be opened.')
        return bool(started)

    @Property(QObject, constant=True)
    def cutefishShell(self): return self._cutefish_shell

    def _launch_native_request(self, app_id, option, value):
        if not isinstance(value,str) or len(value)>2048 or '\0' in value:
            return False
        command=native_command(app_id, APP_DIR, self.workspace.root)+[option,value]
        result=QProcess.startDetached(command[0],command[1:])
        started=result[0] if isinstance(result,tuple) else result
        if not started: self.error.emit('The application could not be opened.')
        return bool(started)

    @Slot(str,result=bool)
    def launchFinder(self, path): return self._launch_native_request('finder','--open-folder',path)

    @Slot(str,result=bool)
    def launchSettings(self, page): return self._launch_native_request('settings','--settings-page',page)

    @Slot(result=bool)
    def launchTerminalWindow(self):
        command = native_command('terminal', APP_DIR, self.workspace.root) + ['--new-window']
        result = QProcess.startDetached(command[0], command[1:])
        started = result[0] if isinstance(result, tuple) else result
        if not started: self.error.emit('Terminal could not be opened.')
        return bool(started)

    @Property(QObject, constant=True)
    def linuxSettings(self): return self._linux_settings

    @Slot()
    def shutdown(self):
        if self._shutting_down: return
        self._shutting_down = True
        self._spotlight.stop()
        self._session.stop()
        self._dde_audio.stop()
        self._cutefish_shell.stop()
        self._linux_settings.stop()
        self._suite._external_timer.stop()
        for decision in list(self._download_decisions.values()): decision['loop'].quit()
        self._chess.shutdown()
        try:
            for terminal in self.terminals: terminal.stop()
        finally:
            self._suite._downloads.close()
            self._suite.db.close()

    @Slot(QObject, result=bool)
    def waitForDownloadDecision(self, owner):
        # QtWebEngine deletes an unaccepted request when downloadRequested returns.
        # Keep that callback alive while the ordinary QML confirmation is interactive.
        if self._shutting_down or owner is None or owner in self._download_decisions:
            return False
        loop = QEventLoop(self)
        decision = {'loop': loop, 'accepted': False, 'owner_alive': True}
        self._download_decisions[owner] = decision
        def destroyed(*args):
            decision['owner_alive'] = False
            loop.quit()
        owner.destroyed.connect(destroyed)
        try:
            loop.exec()
            return decision['accepted'] and not self._shutting_down
        finally:
            self._download_decisions.pop(owner, None)
            if decision['owner_alive']:
                try: owner.destroyed.disconnect(destroyed)
                except RuntimeError: pass
            loop.deleteLater()

    @Slot(QObject, bool)
    def resolveDownloadDecision(self, owner, accepted):
        decision = self._download_decisions.get(owner)
        if decision:
            decision['accepted'] = bool(accepted)
            decision['loop'].quit()

    @Property('QVariantMap', constant=True)
    def systemInfo(self):
        from system_info import collect_system_info
        if not hasattr(self, '_system_info'):
            self._system_info = collect_system_info()
        return self._system_info

    @Slot(QObject)
    def pasteToTerminal(self, terminal):
        if terminal in self.terminals:
            paste = getattr(terminal, 'paste', terminal.write)
            paste(QGuiApplication.clipboard().text())

    @Slot(str)
    def copyText(self, text):
        QGuiApplication.clipboard().setText(text)

    @Slot(QObject, result=bool)
    def configurePhotoCapture(self, capture):
        # Qt 6.8.0 accidentally declares these QML properties without WRITE.
        # The public C++/Python setters work on the Deepin base and newer Qt.
        if not isinstance(capture, QImageCapture):
            return False
        capture.setFileFormat(QImageCapture.FileFormat.JPEG)
        capture.setQuality(QImageCapture.Quality.VeryHighQuality)
        return True

    @Slot()
    def requestCameraPermission(self):
        from PySide6.QtCore import QCameraPermission
        if self._suite.preference('camera.allowed', 'true') != 'true':
            self.cameraPermissionResult.emit(False, 'Camera access is disabled in this desktop’s Privacy & Security settings.')
            return
        app = QGuiApplication.instance()
        permission = QCameraPermission()
        status = app.checkPermission(permission)
        if status == Qt.PermissionStatus.Granted:
            self.cameraPermissionResult.emit(True, '')
        elif status == Qt.PermissionStatus.Denied:
            self.cameraPermissionResult.emit(False, 'Camera access was denied. Allow camera access for this application in your system privacy settings.')
        else:
            # macOS requires a usage description in the executable app bundle.
            if sys.platform == 'darwin':
                import plistlib
                executable = Path(app.applicationFilePath()).resolve()
                plist = next((p / 'Info.plist' for p in executable.parents if p.name == 'Contents'), None)
                if plist is None or not plist.exists() or not plistlib.loads(plist.read_bytes()).get('NSCameraUsageDescription'):
                    self.cameraPermissionResult.emit(False, 'This Python launcher has no camera permission declaration. Use the packaged desktop launcher to enable the camera.')
                    return
            app.requestPermission(permission, self, lambda result: self.cameraPermissionResult.emit(result.status() == Qt.PermissionStatus.Granted, '' if result.status() == Qt.PermissionStatus.Granted else 'Camera access was not granted.'))

    @Property('QVariantList', constant=True)
    def settingsCategories(self):
        return json.loads((APP_DIR / 'settings_catalog.json').read_text())

    @Property('QVariantList', constant=True)
    def applicationCatalog(self): return self.launcher.catalog()

    @Property(bool, constant=True)
    def hostSettingsAvailable(self): return bool(self.launcher.command('host-settings'))

    @Slot(str, result=bool)
    def launchApplication(self, app_id):
        command = self.launcher.command(app_id)
        if not command:
            name = self.launcher.apps.get(app_id, {}).get('name', app_id)
            self.error.emit(name + ' is not connected on this system yet. No compatible installed application was found.')
            return False
        result = QProcess.startDetached(command[0], command[1:])
        started = result[0] if isinstance(result, tuple) else result
        if not started:
            self.error.emit('The application could not be opened.')
        return bool(started)

    @Property(str, constant=True)
    def assetRoot(self): return QUrl.fromLocalFile(str(APP_DIR / 'assets') + '/').toString()

    @Property(str, constant=True)
    def rootPath(self): return str(self.workspace.root)

    @Property(str, constant=True)
    def initialFolder(self):
        folder = self.workspace.root / 'Documents'
        return 'Documents' if folder.is_dir() and not folder.is_symlink() else ''

    @Property(str, constant=True)
    def modifier(self): return 'Ctrl'

    @Property(bool, constant=True)
    def isMac(self): return sys.platform == 'darwin'

    @Property(bool, constant=True)
    def nativeWayland(self): return QGuiApplication.platformName() == 'wayland'

    @Property(str, notify=stateChanged)
    def undoTitle(self): return self.workspace.undo_title

    @Property(bool, notify=stateChanged)
    def canPaste(self): return bool(self.workspace.clipboard)

    @Property(int, notify=stateChanged)
    def trashCount(self): return len(self.workspace.trash_index)

    @Slot(result=QObject)
    def createDesktopBrowser(self):
        # A real Desktop location also exists for a user-chosen empty workspace.
        folder = self.workspace.path('Desktop')
        folder.mkdir(exist_ok=True)
        return self.createBrowser('Desktop')

    @Slot(str, result=QObject)
    def createBrowser(self, path):
        browser = Browser(self, path)
        QQmlEngine.setObjectOwnership(browser, QQmlEngine.CppOwnership)
        self.browsers.append(browser)
        return browser

    @Slot(QObject)
    def releaseBrowser(self, browser):
        if browser in self.browsers:
            self.browsers.remove(browser)
            browser.deleteLater()

    def list_files(self, relative, hidden=False, selected_paths=None):
        root = self.workspace.root
        if selected_paths is not None:
            paths = []
            for path in selected_paths:
                try:
                    paths.append(self.workspace.path(path))
                except (OSError, FileError):
                    continue
        elif relative == '@applications':
            apps = [dict(id='finder', name='Finder', image='finder.png'), dict(id='settings', name='System Settings', image='settings.png')] + self.applicationCatalog
            return [dict(name=a['name'], path='@app:'+a['id'], appId=a['id'], isDir=False, kind='Application', size=0, sizeText='—', modified=0, dateText='—', image='', thumbnailText='', tag='', icon=self.assetRoot+a['image']) for a in apps]
        elif relative == '@recents' or relative.startswith('@tag:'):
            paths = []
            for folder, dirs, files in os.walk(root, followlinks=False):
                dirs[:] = [n for n in dirs if not n.startswith('.') and not (Path(folder)/n).is_symlink()]
                paths += [Path(folder) / n for n in (files + (dirs if relative.startswith('@tag:') else []))
                          if not n.startswith('.') and not (Path(folder) / n).is_symlink()]
            if relative.startswith('@tag:'):
                paths = [p for p in paths if self.workspace.tag(self.workspace.rel(p)) == relative[5:]]
            else:
                recent = []
                for path in paths:
                    try:
                        info = path.lstat()
                        if stat.S_ISREG(info.st_mode):
                            recent.append((info.st_mtime, path))
                    except OSError:
                        continue
                paths = [path for _, path in sorted(recent, key=lambda item: item[0], reverse=True)[:100]]
        else:
            paths = list(self.workspace.path(relative, allow_trash=True).iterdir())
        result = []
        for p in paths:
            if p.name == '.desktop-data' or p.is_symlink() or (p.name.startswith('.') and (not hidden or relative == '.Trash')):
                continue
            try:
                st = p.lstat()
                if not (stat.S_ISREG(st.st_mode) or stat.S_ISDIR(st.st_mode)):
                    continue
                directory = stat.S_ISDIR(st.st_mode)
                entry = self.workspace.trash_index.get(p.name) if relative == '.Trash' else None
                name = entry['name'] if entry else p.name
                suffix = Path(name).suffix.lower()
                image = suffix in ('.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp', '.svg')
                kind = 'Folder' if directory else ('Image' if image else ('PDF document' if suffix == '.pdf' else 'Text document' if suffix in ('.txt', '.md', '.json', '.py', '.qml', '.csv') else 'Document'))
                thumbnail_text = ''
                if not directory and suffix in ('.txt', '.md', '.csv', '.json', '.py', '.qml'):
                    try:
                        thumbnail_text = read_regular_preview(p).decode('utf-8', errors='replace')
                    except OSError:
                        pass
                result.append({'thumbnailText': thumbnail_text, 'name':name, 'path':self.workspace.rel(p), 'isDir':directory,
                    'tag': self.workspace.tag(self.workspace.rel(p)),
                    'kind':kind, 'size':st.st_size, 'sizeText':'—' if directory else human_size(st.st_size),
                    'modified':st.st_mtime, 'dateText':datetime.fromtimestamp(st.st_mtime).strftime('%d %b %Y, %H:%M'),
                    'image':QUrl.fromLocalFile(str(p)).toString() if image else '',
                    'icon':self.assetRoot + ('folder.png' if directory else 'document.png')})
            except (OSError, FileError):
                continue
        return sorted(result, key=lambda x: x['name'].casefold())

    def search_files(self, relative, query, hidden=False):
        paths, limited = self.workspace.search(relative, query, hidden)
        result = self.list_files(relative, hidden, selected_paths=paths)
        if limited:
            self.error.emit('Search reached its current limit. Search a smaller folder or use a more specific name.')
        return result

    @Slot(str, result='QVariantList')
    def children(self, relative):
        try: return self.list_files(relative)
        except (OSError, FileError): return []

    def _changed(self):
        for browser in self.browsers: browser.refresh()
        self.stateChanged.emit()
        self.filesystemChanged.emit()

    def _run(self, operation, *args, default=None):
        try:
            result = operation(*args)
            self._changed()
            return result
        except (OSError, FileError) as exc:
            self.error.emit(str(exc))
            self._changed()
            return default

    @Slot(str, str, result=str)
    def newFolder(self, path, name):
        return self._run(self.workspace.mkdir, path, name, default='')

    @Slot(str, str, result=str)
    def rename(self, path, name):
        return self._run(self.workspace.rename, path, name, default='')

    @Slot('QVariantList')
    def copy(self, paths):
        self.workspace.clipboard = list(paths)
        self.stateChanged.emit()

    @Slot(str, bool)
    def paste(self, path, move):
        result = self._run(self.workspace.copy, self.workspace.clipboard, path, move)
        if move and result is not None:
            self.workspace.clipboard = []
            self.stateChanged.emit()

    @Slot('QVariantList')
    def duplicate(self, paths):
        if paths:
            parent = str(Path(paths[0]).parent)
            self._run(self.workspace.copy, paths, '' if parent == '.' else parent, False, True)

    @Slot('QVariantList')
    def trash(self, paths): self._run(self.workspace.remove, paths)

    @Slot('QVariantList')
    def restore(self, paths): self._run(self.workspace.restore, paths)

    @Slot('QVariantList', str, bool, result='QVariantList')
    def dropFiles(self, paths, destination, copy):
        return self._run(self.workspace.copy, paths, destination, not copy, default=[])

    @Slot()
    def undo(self): self._run(self.workspace.undo)

    @Slot('QVariantList', str)
    def setTag(self, paths, tag):
        self._run(self.workspace.set_tag, paths, tag)

    @Slot('QVariantList')
    def copyPathnames(self, paths):
        try:
            text = '\n'.join(str(self.workspace.path(p, allow_trash=True)) for p in paths)
            QGuiApplication.clipboard().setText(text)
        except (OSError, FileError) as exc:
            self.error.emit(str(exc))

    @Slot(str, result=str)
    def fileInfo(self, relative):
        try:
            path = self.workspace.path(relative, allow_trash=True)
            st = path.stat()
            kind = 'Folder' if path.is_dir() else mimetypes.guess_type(path.name)[0] or 'Document'
            return '\n'.join((
                'Name: ' + path.name, 'Kind: ' + kind,
                'Size: ' + human_size(st.st_size), 'Where: ' + str(path.parent),
                'Modified: ' + datetime.fromtimestamp(st.st_mtime).strftime('%d %B %Y at %H:%M:%S'),
                'Tags: ' + (self.workspace.tag(relative) or 'None'),
            ))
        except (OSError, FileError) as exc:
            self.error.emit(str(exc))
            return ''

    @Slot(str, result='QVariantMap')
    def preview(self, relative):
        try:
            p = self.workspace.path(relative, allow_trash=True)
            if p.is_dir():
                return {'name':p.name,'kind':'Folder','text':f'{len(list(p.iterdir()))} items','image':''}
            suffix = p.suffix.lower()
            image = suffix in ('.png','.jpg','.jpeg','.webp','.gif','.bmp','.svg')
            text = ''
            if not image:
                with p.open('rb') as f: content = f.read(120_000)
                if b'\0' not in content:
                    text = content.decode('utf-8', errors='replace')
                else:
                    text = 'Preview is unavailable for this file type.'
            return {'name':p.name,'kind':human_size(p.stat().st_size),'text':text,
                    'image':QUrl.fromLocalFile(str(p)).toString() if image else ''}
        except (OSError, FileError) as exc:
            self.error.emit(str(exc))
            return {}


def finish_session(app, window):
    """A supervisor stop must bypass the interactive window-close confirmation."""
    desktop = window.findChild(QObject, 'desktop')
    if desktop is not None:
        desktop.setProperty('sessionEnding', True)
    window.flushApplications()
    app.quit()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, help='Explicit folder to browse and modify; default: demo-home next to this script')
    parser.add_argument('--fullscreen', action='store_true')
    parser.add_argument('--session', action='store_true', help='Dedicated Linux login session; launched by tahoe-session')
    parser.add_argument('--wayland-shell', action='store_true', help='Experimental makOS layer surfaces; requires a matching LayerShellQt plugin')
    parser.add_argument('--cutefish-app', choices=NATIVE_APP_IDS, help='Native makOS client for the Cutefish shell')
    parser.add_argument('--open-folder', help='Open a folder in the native Finder instance')
    parser.add_argument('--settings-page', help='Open a page in the native Settings instance')
    parser.add_argument('--new-window', action='store_true', help='Open a new native Terminal window')
    parser.add_argument('--cutefish-test', action='store_true', help=argparse.SUPPRESS)
    parser.add_argument('--cutefish-shell', action='store_true', help='Trusted makOS desktop, menu bar and Dock session')
    parser.add_argument('--makos', action='store_true', help='makOS development mode: native windows and opt-in DDE service adapters on Linux')
    parser.add_argument('--native-windows', action='store_true', help='makOS development: a real platform window for each application')
    parser.add_argument('--settings', action='store_true', help='Open System Settings alongside Finder')
    parser.add_argument('--compare-right', action='store_true', help='Position the prototype on the right half for native Finder comparison')
    parser.add_argument('--smoke-test', action='store_true', help='Load QML, render once, and exit without UI interactions')
    args = parser.parse_args()
    if args.open_folder is not None and args.cutefish_app != 'finder': parser.error('--open-folder requires --cutefish-app finder')
    if args.settings_page is not None and args.cutefish_app != 'settings': parser.error('--settings-page requires --cutefish-app settings')
    if args.new_window and args.cutefish_app != 'terminal': parser.error('--new-window requires --cutefish-app terminal')
    if args.cutefish_shell and (sys.platform != 'linux' or not os.environ.get('WAYLAND_SOCKET') or args.cutefish_app or args.session or args.wayland_shell):
        parser.error('--cutefish-shell must be started by the trusted makOS session supervisor')
    if args.cutefish_app and (sys.platform != 'linux' or not os.environ.get('WAYLAND_DISPLAY')):
        parser.error('--cutefish-app requires a Linux Wayland session')
    if args.cutefish_app and (args.session or args.wayland_shell or args.makos):
        parser.error('--cutefish-app cannot be combined with another desktop mode')
    if args.session and (sys.platform != 'linux' or not os.environ.get('TAHOE_SESSION_SOCKET')):
        parser.error('--session must be started by the Linux session launcher')
    if args.wayland_shell and (sys.platform != 'linux' or not os.environ.get('WAYLAND_DISPLAY')):
        parser.error('--wayland-shell requires a running Linux Wayland compositor')
    if args.cutefish_app == 'apps':
        from shell_launcher import request_apps_overlay
        launcher_app = QCoreApplication(sys.argv[:1])
        ok, error = request_apps_overlay()
        if not ok: print('Apps requires the running makOS desktop: ' + error, file=sys.stderr)
        return 0 if ok else 1
    user_data = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share')) / 'tahoe-desktop'
    installed_linux = sys.platform == 'linux' and (args.session or not os.access(APP_DIR, os.W_OK))
    root = args.root or (user_data / 'workspace' if installed_linux else APP_DIR / 'demo-home')
    if not args.root: seed_workspace(root, APP_DIR / 'assets')
    os.environ.setdefault('QT_QUICK_CONTROLS_STYLE', 'Basic')
    from PySide6.QtWebEngineQuick import QtWebEngineQuick
    QtWebEngineQuick.initialize()
    trusted_wayland_fd = int(os.environ['WAYLAND_SOCKET']) if args.cutefish_shell else None
    app = QGuiApplication(sys.argv[:1] + (['-name', 'tahoe-desktop-shell'] if args.session else []))
    app.setApplicationName('makOS' if args.makos else 'Tahoe Desktop')
    app.setOrganizationName('Desktop Prototype')
    if args.cutefish_shell:
        app.setApplicationName('makOS Shell')
        app.setDesktopFileName('org.makos.Shell')
        # Qt already owns the trusted connection. Child apps connect normally.
        try: os.set_inheritable(trusted_wayland_fd, False)
        except OSError: pass  # libwayland may already have consumed the original FD.
        os.environ.pop('WAYLAND_SOCKET', None)
    cutefish_instance = None
    if args.cutefish_app:
        from cutefish_runtime import CutefishInstance
        app.setApplicationName(NATIVE_APP_INFO[args.cutefish_app]['name'])
        app.setDesktopFileName(NATIVE_APP_INFO[args.cutefish_app]['desktop_id'])
        request={'action':'open-folder','argument':args.open_folder} if args.open_folder is not None else {'action':'settings-page','argument':args.settings_page} if args.settings_page is not None else {'action':'terminal-new-window'} if args.new_window else None
        cutefish_instance = CutefishInstance(app, args.cutefish_app, root, request)
        if not cutefish_instance.acquire(): return 0
    if args.session:
        app.setDesktopFileName('tahoe-desktop')
    font = QFont('.AppleSystemUIFont' if sys.platform == 'darwin' else 'Inter', 13)
    font.setStyleStrategy(QFont.PreferAntialias)
    app.setFont(font)
    workspace = Workspace(root)
    bridge = Bridge(workspace, session_mode=args.session or args.cutefish_shell, dde_mode=args.makos or args.wayland_shell,
                    cutefish_mode=bool(args.cutefish_app) or args.cutefish_shell, terminal_auto_start=not args.smoke_test)
    if args.cutefish_shell: bridge.session.refreshApplications()
    else: bridge.session.start()
    bridge.ddeAudio.start()
    engine = QQmlApplicationEngine()
    if args.cutefish_app or args.cutefish_shell:
        engine.addImportPath(str(APP_DIR / 'cutefish/build/qml'))
        engine.rootContext().setContextProperty('cutefishApp', args.cutefish_app or '')
    engine.rootContext().setContextProperty('Bridge', bridge)
    engine.rootContext().setContextProperty('startFullscreen', args.fullscreen)
    engine.rootContext().setContextProperty('comparisonMode', args.compare_right)
    engine.rootContext().setContextProperty('startSettings', args.settings)
    engine.rootContext().setContextProperty('startFolder', args.open_folder)
    engine.rootContext().setContextProperty('settingsStartPage', args.settings_page or '')
    engine.rootContext().setContextProperty('startNativeWindows', args.native_windows or args.makos or args.wayland_shell or bool(args.cutefish_app) or args.cutefish_shell)
    engine.rootContext().setContextProperty('useWaylandShell', args.wayland_shell or args.cutefish_shell)
    engine.rootContext().setContextProperty('useCutefishShell', args.cutefish_shell)
    engine.load(QUrl.fromLocalFile(str(APP_DIR / ('qml/CutefishShell.qml' if args.cutefish_shell else 'qml/WaylandShell.qml' if args.wayland_shell else 'qml/Main.qml'))))
    if not engine.rootObjects(): return 1
    shell_launcher = None
    if args.cutefish_shell:
        from shell_launcher import ShellLauncher
        shell_launcher = ShellLauncher(engine.rootObjects()[0], app)
        app.aboutToQuit.connect(shell_launcher.stop)
    if args.cutefish_shell and os.environ.get('MAKOS_SHELL_TEST_GEOMETRY'):
        def export_shell_geometry():
            result=engine.rootObjects()[0].shellControlGeometry().toVariant()
            destination=Path(os.environ['MAKOS_SHELL_TEST_GEOMETRY'])
            destination.write_text(json.dumps(result)+'\n')
        geometry_timer=QTimer(app)
        geometry_timer.setInterval(150)
        geometry_timer.timeout.connect(export_shell_geometry)
        geometry_timer.start()
    if cutefish_instance:
        cutefish_instance.bind(engine.rootObjects()[0])
        if args.cutefish_test:
            from cutefish_runtime import exercise
            exercise(app, engine.rootObjects()[0], engine)
    app.aboutToQuit.connect(engine.rootObjects()[0].flushApplications)
    app.aboutToQuit.connect(bridge.shutdown)
    if args.session or args.cutefish_shell:
        import signal
        # Permit the supervisor to flush drafts on logout/service failure.
        signal.signal(signal.SIGTERM, lambda *_: finish_session(app, engine.rootObjects()[0]))
        signal.signal(signal.SIGINT, lambda *_: finish_session(app, engine.rootObjects()[0]))
        signal_timer = QTimer(app)
        signal_timer.timeout.connect(lambda: None)
        signal_timer.start(200)
    if args.smoke_test:
        if args.cutefish_app:
            from cutefish_app_smoke import verify_startup
            QTimer.singleShot(1800, lambda: verify_startup(app, engine.rootObjects()[0], engine, args.cutefish_app))
        else:
            QTimer.singleShot(8000 if args.session else 1600,
                              lambda: finish_session(app, engine.rootObjects()[0]) if args.session else app.quit())
    result = app.exec()
    if cutefish_instance:
        # Tear down QML and Wayland protocol objects while their Python context
        # providers and the QGuiApplication still exist.
        cutefish_instance.root = None
        engine.deleteLater()
        QCoreApplication.sendPostedEvents(None, QEvent.Type.DeferredDelete)
    return result


if __name__ == '__main__':
    sys.exit(main())
