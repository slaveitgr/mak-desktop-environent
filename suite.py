"""Local application services. No Apple accounts or host libraries are imported."""
import json
import os
from pathlib import Path
import shutil
import sqlite3
from concurrent.futures import ThreadPoolExecutor
import uuid
from datetime import datetime
from urllib.parse import quote

import chess
import chess.pgn
from calculator_engine import evaluate as calculator_evaluate
from chess_engine import choose_move
from photo_effects import PhotoEffects
from browser_downloads import BrowserDownloads
from PySide6.QtCore import QObject, Property, Signal, Slot, QUrl, QTimer

KINDS = {'notes', 'reminders', 'contacts', 'calendar', 'mail', 'messages', 'bookmarks'}
IMAGE_EXT = {'.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp'}
AUDIO_EXT = {'.mp3', '.m4a', '.aac', '.wav', '.ogg', '.flac', '.opus'}


def calculate(expression):
    """Compatibility entry point for the bounded decimal/scientific parser."""
    return calculator_evaluate(expression)


class Suite(QObject):
    changed = Signal()
    preferenceChanged = Signal(str, str)
    error = Signal(str)
    def __init__(self, root, parent=None):
        super().__init__(parent)
        self.root = Path(root).resolve()
        self.data_dir = self.root / '.desktop-data'
        if self.data_dir.is_symlink():
            raise ValueError('Application data directory cannot be a symbolic link')
        self.data_dir.mkdir(exist_ok=True)
        dbpath = self.data_dir / 'applications.sqlite3'
        if dbpath.is_symlink():
            raise ValueError('Application database cannot be a symbolic link')
        self.db = sqlite3.connect(dbpath)
        self.db.row_factory = sqlite3.Row
        self.db.execute('PRAGMA journal_mode=WAL')
        self.db.executescript('''CREATE TABLE IF NOT EXISTS records
            (id TEXT PRIMARY KEY, kind TEXT NOT NULL, payload TEXT NOT NULL, modified TEXT NOT NULL, deleted INTEGER NOT NULL DEFAULT 0);
            CREATE TABLE IF NOT EXISTS preferences (key TEXT PRIMARY KEY, value TEXT NOT NULL);''')
        self.db.commit()
        self._revision = 0
        self._photo_effects = PhotoEffects(self.root)
        self._downloads = BrowserDownloads(self.root)

    @Property(int, notify=changed)
    def revision(self): return self._revision

    def notify(self):
        self._revision += 1
        self.changed.emit()

    @Slot(str, bool, result='QVariantList')
    def records(self, kind, deleted=False):
        if kind not in KINDS:
            return []
        rows = self.db.execute('SELECT * FROM records WHERE kind=? AND deleted=? ORDER BY modified DESC, rowid DESC', (kind, int(deleted)))
        return [dict(json.loads(row['payload']), id=row['id'], modified=row['modified']) for row in rows]

    @Slot(str, str, 'QVariantMap', result=str)
    def save(self, kind, record_id, fields):
        try:
            if kind not in KINDS: raise ValueError('Unknown application collection')
            clean = {str(k): v for k, v in fields.items() if k not in ('id', 'modified', 'deleted') and isinstance(v, (str, int, float, bool, type(None)))}
            payload = json.dumps(clean, ensure_ascii=False, allow_nan=False)
            if len(payload.encode()) > 2_000_000: raise ValueError('Document is too large')
            if kind == 'calendar':
                datetime.strptime(clean.get('date', ''), '%Y-%m-%d')
                datetime.strptime(clean.get('time') or '09:00', '%H:%M')
            if record_id:
                existing = self.db.execute('SELECT kind FROM records WHERE id=?', (record_id,)).fetchone()
                if not existing or existing['kind'] != kind: raise ValueError('Document no longer exists')
            else:
                record_id = uuid.uuid4().hex
            with self.db:
                self.db.execute('INSERT INTO records(id,kind,payload,modified) VALUES(?,?,?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload,modified=excluded.modified', (record_id, kind, payload, datetime.now().isoformat(timespec='microseconds')))
            self.notify()
            return record_id
        except (ValueError, TypeError, sqlite3.Error) as exc:
            self.error.emit(str(exc)); return ''

    @Slot(str, bool)
    def setDeleted(self, record_id, deleted):
        with self.db: self.db.execute('UPDATE records SET deleted=? WHERE id=?', (int(deleted), record_id))
        self.notify()

    @Slot(str, str, result=str)
    def preference(self, key, default=''):
        row = self.db.execute('SELECT value FROM preferences WHERE key=?', (key,)).fetchone()
        return row['value'] if row else default

    @Slot(str, str)
    def setPreference(self, key, value):
        if len(value) > 100000 or self.preference(key, '\0') == value: return
        with self.db: self.db.execute('INSERT INTO preferences VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value', (key, value))
        self.notify()
        self.preferenceChanged.emit(key, value)

    @Slot(str, result='QVariantMap')
    def evaluate(self, expression):
        try: return {'ok': True, 'value': calculate(expression)}
        except (ValueError, ArithmeticError, SyntaxError, RecursionError): return {'ok': False, 'value': 'Error'}

    @Slot(str, str, result='QVariantMap')
    def evaluateScientific(self, expression, angle_mode):
        try: return {'ok': True, 'value': calculator_evaluate(expression, angle_mode)}
        except (ValueError, ArithmeticError, SyntaxError, RecursionError): return {'ok': False, 'value': 'Error'}

    @Slot(str, result=str)
    def webAddress(self, value):
        value = value.strip()
        if not value: return 'about:blank'
        url = QUrl(value)
        if url.scheme() in ('https', 'http') and url.host(): return url.toString()
        if not url.scheme() and '.' in value and ' ' not in value: return 'https://' + value
        return 'https://duckduckgo.com/?q=' + quote(value)

    def safe_folder(self, relative):
        folder = self.root
        for part in Path(relative).parts:
            if part in ('..', '/') or not part: raise ValueError('Invalid folder')
            folder = folder / part
            if folder.is_symlink(): raise ValueError('Media folders cannot be symbolic links')
            folder.mkdir(exist_ok=True)
        return folder

    @Slot(str, result='QVariantList')
    def media(self, kind):
        suffixes = IMAGE_EXT if kind == 'photos' else AUDIO_EXT
        directory = self.root / ('Pictures' if kind == 'photos' else 'Music')
        result = []
        if directory.is_symlink() or not directory.exists(): return result
        for base, dirs, files in os.walk(directory, followlinks=False):
            dirs[:] = [d for d in dirs if not (Path(base)/d).is_symlink() and not d.startswith('.')]
            for name in files:
                path = Path(base)/name
                if path.is_symlink() or path.suffix.lower() not in suffixes: continue
                try:
                    st = path.stat()
                    result.append({'name':name,'url':QUrl.fromLocalFile(str(path)).toString(), 'path':str(path.relative_to(self.root)), 'modified':st.st_mtime})
                except OSError: continue
                if len(result) >= 5000: break
        return sorted(result, key=lambda row:row['modified'], reverse=True)

    @Slot('QVariantList', str, result=int)
    def importMedia(self, urls, kind):
        count = 0
        try:
            folder = self.safe_folder('Pictures' if kind == 'photos' else 'Music')
            extensions = IMAGE_EXT if kind == 'photos' else AUDIO_EXT
            for value in urls:
                path = Path(QUrl(str(value)).toLocalFile())
                if not path.is_file() or path.suffix.lower() not in extensions: continue
                dest = folder / path.name
                if path.resolve() == dest.resolve(): continue
                index = 2
                while dest.exists():
                    dest = folder / f'{path.stem} {index}{path.suffix}'; index += 1
                # Exclusive destination creation prevents overwriting an existing photo.
                with path.open('rb') as source, dest.open('xb') as target: shutil.copyfileobj(source, target)
                count += 1
            self.notify()
        except (OSError, ValueError) as exc: self.error.emit(str(exc))
        return count

    @Slot(result=str)
    def photoPath(self):
        try: return self._photo_effects.capture_path()
        except (OSError, ValueError) as exc: self.error.emit(str(exc)); return ''

    @Slot(str, str, bool, result='QVariantMap')
    def finishPhoto(self, source, effect, flip):
        try:
            result = self._photo_effects.finish(source, effect, flip)
            self.notify()
            return result
        except (OSError, ValueError) as exc:
            self.error.emit(str(exc)); return {'error': str(exc)}

    @Slot('QVariantList', str, bool, result='QVariantMap')
    def photoStrip(self, sources, effect, flip):
        try:
            result = self._photo_effects.contact_sheet(sources, effect, flip)
            self.notify()
            return result
        except (OSError, ValueError) as exc:
            self.error.emit(str(exc)); return {'error': str(exc)}

    @Slot(str, result='QVariantMap')
    def downloadDestination(self, filename):
        try: return self._downloads.destination(filename)
        except (OSError, ValueError) as exc:
            self.error.emit(str(exc)); return {'error': str(exc)}

    @Slot(str, bool, result='QVariantMap')
    def finishDownload(self, token, completed):
        try:
            result = self._downloads.finish(token, completed)
            if completed: self.notify()
            return result
        except (OSError, ValueError) as exc:
            self.error.emit(str(exc)); return {'error': str(exc), 'url': '', 'name': ''}

    @Slot(str)
    def cancelDownload(self, token):
        try: self._downloads.cancel(token)
        except (OSError, ValueError) as exc: self.error.emit(str(exc))

    @Slot()
    def refresh(self): self.notify()

    @Slot(result='QVariantMap')
    def storage(self):
        disk = shutil.disk_usage(self.root)
        return {'total':disk.total, 'free':disk.free, 'photos':len(self.media('photos')), 'songs':len(self.media('music')), 'documents':self.db.execute('SELECT COUNT(*) FROM records WHERE deleted=0').fetchone()[0], 'path':str(self.root)}

    @Slot(str, result=str)
    def exportMail(self, record_id):
        from email.message import EmailMessage
        row = next((r for r in self.records('mail') if r['id'] == record_id), None)
        if not row: return ''
        try:
            message = EmailMessage()
            message['To'] = row.get('recipient', '')
            message['Subject'] = row.get('title', '')
            message.set_content(row.get('body',''))
            path = self.safe_folder('Documents/Mail Drafts') / ('Draft-' + uuid.uuid4().hex[:8] + '.eml')
            with path.open('xb') as f: f.write(bytes(message))
            return str(path)
        except (OSError, ValueError) as exc: self.error.emit(str(exc)); return ''


class ChessGame(QObject):
    changed = Signal()
    def __init__(self, suite, parent=None):
        super().__init__(parent)
        self.suite = suite
        self.board = chess.Board()
        self._selected = -1
        self._promotion = ''
        self._draw_claimed = suite.preference('chess.drawClaimed', 'false') == 'true'
        self._computer = suite.preference('chess.computer', 'false') == 'true'
        self._future = None
        self._search_position = None
        self._engine_error = ''
        self._executor = None
        self._stopping = False
        self._poll = QTimer(self)
        self._poll.setInterval(30)
        self._poll.timeout.connect(self._finish_search)
        try:
            for move in json.loads(suite.preference('chess.moves', '[]')):
                self.board.push_uci(move)
        except (ValueError, TypeError): self.board.reset()
        self._start_search()

    @Property('QVariantList', notify=changed)
    def squares(self):
        destinations = {move.to_square for move in self.board.legal_moves if move.from_square == self._selected}
        result = []
        for row in range(8):
            for col in range(8):
                square = chess.square(col, 7-row); piece = self.board.piece_at(square)
                result.append({'square':square,'name':chess.square_name(square), 'piece':piece.unicode_symbol() if piece else '', 'white':bool(piece and piece.color), 'selected':square == self._selected, 'legal':square in destinations, 'light':(row+col)%2==0})
        return result

    @Property(str, notify=changed)
    def status(self):
        if self._draw_claimed: return 'Draw · claimed by agreement with the rules'
        outcome = self.board.outcome()
        if outcome:
            return ('Draw' if outcome.winner is None else ('White' if outcome.winner else 'Black') + ' wins') + ' · ' + outcome.termination.name.replace('_',' ').lower()
        if self._engine_error: return self._engine_error
        if self.thinking: return 'Black is thinking…'
        return ('White' if self.board.turn else 'Black') + ' to move' + (' · Check' if self.board.is_check() else '')

    @Property(bool, notify=changed)
    def versusComputer(self): return self._computer
    @Property(bool, notify=changed)
    def thinking(self): return self._future is not None

    @Slot(bool)
    def setComputer(self, enabled):
        self._cancel_search()
        self._computer = enabled
        self._selected = -1
        self.suite.setPreference('chess.computer', 'true' if enabled else 'false')
        self._start_search()
        self.changed.emit()

    def _cancel_search(self):
        self._poll.stop()
        if self._future: self._future.cancel()
        self._future = None
        self._search_position = None
        self._engine_error = ''

    def _start_search(self):
        if self._stopping or self._future or not self._computer or self.board.turn != chess.BLACK or self._draw_claimed or self.board.is_game_over(): return
        if self._executor is None: self._executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix='Chess')
        self._search_position = self.board.fen()
        self._future = self._executor.submit(choose_move, self.board.copy(stack=True), 3000)
        self._poll.start()
        self.changed.emit()

    def _finish_search(self):
        if not self._future or not self._future.done(): return
        future, position = self._future, self._search_position
        self._future = None
        self._poll.stop()
        try: move = future.result()
        except Exception:
            self._engine_error = 'Computer could not complete its move. Switch to Two Players to continue.'
            self.changed.emit(); return
        if not self._stopping and not self._draw_claimed and self._computer and position == self.board.fen() and move in self.board.legal_moves:
            self.board.push(move)
            self.persist()
        else: self.changed.emit()

    def shutdown(self):
        self._stopping = True
        self._cancel_search()
        if self._executor: self._executor.shutdown(wait=False, cancel_futures=True)

    @Property(str, notify=changed)
    def moves(self): return str(chess.pgn.Game.from_board(self.board).mainline())
    @Property(bool, notify=changed)
    def promotionPending(self): return bool(self._promotion)
    @Property(bool, notify=changed)
    def canClaimDraw(self): return not self._draw_claimed and self.board.can_claim_draw()

    @Slot()
    def claimDraw(self):
        if self.canClaimDraw:
            self._cancel_search()
            self._draw_claimed = True
            self.persist()

    @Property(bool, notify=changed)
    def canUndo(self): return bool(self.board.move_stack)

    def persist(self):
        self.suite.setPreference('chess.drawClaimed', 'true' if self._draw_claimed else 'false')
        self.suite.setPreference('chess.moves', json.dumps([m.uci() for m in self.board.move_stack]))
        self.changed.emit()
        self._start_search()

    @Slot(int)
    def select(self, square):
        if not 0 <= square < 64 or self._draw_claimed or self.board.is_game_over() or (self._computer and self.board.turn == chess.BLACK): return
        if self._selected >= 0:
            prefix = chess.square_name(self._selected) + chess.square_name(square)
            options = [move for move in self.board.legal_moves if move.uci().startswith(prefix)]
            if options:
                if options[0].promotion:
                    self._promotion = prefix; self.changed.emit(); return
                self.board.push(options[0]); self._selected = -1; self.persist(); return
        piece = self.board.piece_at(square)
        self._selected = square if piece and piece.color == self.board.turn else -1
        self.changed.emit()

    @Slot(str)
    def promote(self, piece):
        if self._promotion and piece in ('q','r','b','n'):
            move = chess.Move.from_uci(self._promotion + piece)
            if move in self.board.legal_moves: self.board.push(move)
            self._promotion = ''; self._selected = -1; self.persist()

    @Slot()
    def undo(self):
        self._cancel_search()
        self._draw_claimed = False
        steps = 2 if self._computer and self.board.turn == chess.WHITE and len(self.board.move_stack) >= 2 else 1
        for _ in range(steps):
            if self.board.move_stack: self.board.pop()
        self._selected = -1; self._promotion = ''; self.persist()

    @Slot()
    def newGame(self):
        self._cancel_search()
        self._draw_claimed = False
        if self.board.move_stack:
            archive = json.loads(self.suite.preference('chess.archive', '[]'))
            archive.insert(0, {'date': datetime.now().isoformat(), 'pgn': str(chess.pgn.Game.from_board(self.board))})
            self.suite.setPreference('chess.archive', json.dumps(archive[:50]))
        self.board.reset(); self._selected = -1; self._promotion = ''; self.persist()
