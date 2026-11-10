"""Bounded background file discovery and opt-in, memory-only clipboard results."""
import os
from pathlib import Path
import stat
import time
from concurrent.futures import ThreadPoolExecutor
from PySide6.QtCore import QObject, Property, Signal, Slot, QTimer, QUrl


def discover_files(root, query='', max_entries=20000, time_budget=1.0):
    root = Path(root).resolve()
    query = query.casefold().strip()
    stack, rows, visited = [root], [], 0
    deadline = time.monotonic() + time_budget
    limited = False
    while stack:
        folder = stack.pop()
        try:
            with os.scandir(folder) as entries:
                for entry in entries:
                    visited += 1
                    if visited > max_entries or time.monotonic() > deadline:
                        limited = True
                        break
                    if entry.name.startswith('.') or entry.is_symlink():
                        continue
                    try:
                        info = entry.stat(follow_symlinks=False)
                        if stat.S_ISDIR(info.st_mode):
                            stack.append(Path(entry.path))
                            continue
                        if not stat.S_ISREG(info.st_mode) or query not in entry.name.casefold():
                            continue
                        path = Path(entry.path)
                        suffix = path.suffix.lower()
                        kind = 'Images' if suffix in ('.png','.jpg','.jpeg','.webp','.gif','.bmp') else 'PDF' if suffix=='.pdf' else 'Text' if suffix in ('.txt','.md','.csv','.json') else 'Archives' if suffix in ('.zip','.tar','.gz','.xz','.7z') else 'Other'
                        rows.append({'name':entry.name,'path':str(path.relative_to(root)), 'modified':info.st_mtime,
                                     'kind':kind, 'image':QUrl.fromLocalFile(str(path)).toString() if kind=='Images' else ''})
                    except OSError:
                        continue
        except OSError:
            continue
        if limited:
            break
    rows.sort(key=lambda item: (-item['modified'],item['name'].casefold()))
    return rows[:100], limited


class Spotlight(QObject):
    changed = Signal()
    clipboardChanged = Signal()
    _completed = Signal(int, object, bool)

    def __init__(self, root, parent=None):
        super().__init__(parent)
        self.root = Path(root)
        self._files, self._clipboard = [], []
        self._enabled = False
        self._busy, self._limited, self._stopped = False, False, False
        self._generation = 0
        self._query = ''
        self._pool = ThreadPoolExecutor(max_workers=1,thread_name_prefix='makos-spotlight')
        self._future = None
        self._completed.connect(self._accept)
        self._timer = QTimer(self)
        self._timer.setSingleShot(True)
        self._timer.setInterval(140)
        self._timer.timeout.connect(self._scan)

    @Property('QVariantList', notify=changed)
    def files(self): return self._files
    @Property(bool, notify=changed)
    def busy(self): return self._busy
    @Property(bool, notify=changed)
    def limited(self): return self._limited
    @Property(bool, notify=clipboardChanged)
    def clipboardEnabled(self): return self._enabled
    @Property('QVariantList', notify=clipboardChanged)
    def clipboardItems(self): return self._clipboard

    @Slot(str)
    def search(self, query):
        if self._stopped: return
        self._query = query[:256]
        self._generation += 1
        self._busy = True
        self.changed.emit()
        self._timer.start()

    def _scan(self):
        if self._future: self._future.cancel()
        generation = self._generation
        self._future = self._pool.submit(discover_files,self.root,self._query)
        def done(future):
            if self._stopped or future.cancelled(): return
            try: rows,limited = future.result()
            except Exception: rows,limited = [],True
            try: self._completed.emit(generation,rows,limited)
            except RuntimeError: pass  # The owning UI has already been destroyed.
        self._future.add_done_callback(done)

    @Slot(int,object,bool)
    def _accept(self,generation,rows,limited):
        if self._stopped or generation != self._generation: return
        self._files,self._limited,self._busy = rows,limited,False
        self.changed.emit()

    @Slot(bool)
    def setClipboardEnabled(self, enabled):
        from PySide6.QtGui import QGuiApplication
        if self._enabled == enabled: return
        self._enabled = enabled
        clipboard = QGuiApplication.clipboard()
        if enabled:
            clipboard.dataChanged.connect(self._capture_clipboard)
            self._capture_clipboard()
        else:
            clipboard.dataChanged.disconnect(self._capture_clipboard)
            self._clipboard = []
        self.clipboardChanged.emit()

    @Slot()
    def _capture_clipboard(self):
        if not self._enabled: return
        from PySide6.QtGui import QGuiApplication
        text = QGuiApplication.clipboard().text()
        if not text or len(text)>65536: return
        self._clipboard = [text]+[entry for entry in self._clipboard if entry!=text][:19]
        self.clipboardChanged.emit()

    @Slot()
    def stop(self):
        self._stopped = True
        self._timer.stop()
        if self._enabled: self.setClipboardEnabled(False)
        self._pool.shutdown(wait=False,cancel_futures=True)
