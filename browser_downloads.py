"""Owned browser downloads: stage privately and publish without overwriting files."""
import errno
import os
from pathlib import Path
import shutil
import stat
import uuid
from PySide6.QtCore import QUrl


class BrowserDownloads:
    def __init__(self, root):
        self.root = Path(root).resolve()
        self._pending = {}

    def _folder(self, parts):
        path = self.root
        for part in parts:
            path /= part
            if path.is_symlink():
                raise ValueError('Download folders cannot be symbolic links')
            path.mkdir(exist_ok=True)
            if not path.is_dir():
                raise ValueError('Downloads need a directory')
        return path

    @staticmethod
    def _filename(value):
        name = str(value).replace('\\', '/').rsplit('/', 1)[-1]
        name = ''.join(c for c in name if ord(c) >= 32 and ord(c) != 127).strip()
        if not name or not name.strip('.'):
            name = 'download'
        # Leave room for collision suffixes on common Linux/macOS file systems.
        suffix = Path(name).suffix
        if len(suffix.encode('utf-8')) > 32:
            suffix = ''
        stem = name[:-len(suffix)] if suffix else name
        while len((stem + suffix).encode('utf-8')) > 190:
            stem = stem[:-1]
        return stem + suffix

    def destination(self, filename):
        # Called only after the user chooses Save in the browser prompt.
        self._folder(('Downloads',))
        base = self._folder(('.desktop-data', 'downloads'))
        token = uuid.uuid4().hex
        stage = base / token
        stage.mkdir()
        name = self._filename(filename)
        self._pending[token] = (stage, name)
        return {'token': token, 'directory': str(stage), 'name': name,
                'url': QUrl.fromLocalFile(str(self.root / 'Downloads' / name)).toString()}

    def _stage(self, token):
        if token not in self._pending:
            raise ValueError('This download is no longer active')
        stage, name = self._pending[token]
        base = self._folder(('.desktop-data', 'downloads'))
        if stage.parent != base or stage.is_symlink() or not stage.is_dir():
            raise ValueError('The download staging folder changed')
        return stage, name

    def cancel(self, token):
        if token not in self._pending:
            return
        stage, _ = self._stage(token)
        shutil.rmtree(stage)
        self._pending.pop(token, None)

    def finish(self, token, completed):
        stage, name = self._stage(token)
        if not completed:
            self.cancel(token)
            return {'url': '', 'name': name, 'error': 'Download cancelled'}
        source = stage / name
        if source.is_symlink() or not source.exists() or not stat.S_ISREG(source.stat().st_mode):
            raise ValueError('The downloaded file is missing or invalid')
        destination = self._folder(('Downloads',))
        index = 1
        while True:
            candidate = destination / (name if index == 1 else f'{Path(name).stem} {index}{Path(name).suffix}')
            try:
                # Atomic, exclusive publication on the usual same-filesystem path.
                os.link(source, candidate, follow_symlinks=False)
                break
            except FileExistsError:
                index += 1
            except OSError as exc:
                if exc.errno != errno.EXDEV:
                    raise
                try:
                    target = candidate.open('xb')
                except FileExistsError:
                    index += 1
                    continue
                try:
                    with target, source.open('rb') as data:
                        shutil.copyfileobj(data, target)
                except BaseException:
                    candidate.unlink(missing_ok=True)
                    raise
                break
        self.cancel(token)
        return {'url': QUrl.fromLocalFile(str(candidate)).toString(), 'name': candidate.name, 'error': ''}

    def close(self):
        for token in list(self._pending):
            try:
                self.cancel(token)
            except (OSError, ValueError):
                # A replaced folder must never be followed during shutdown cleanup.
                pass
