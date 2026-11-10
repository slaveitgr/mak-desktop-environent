"""Real, reversible file operations confined to an explicitly chosen workspace."""
from pathlib import Path
import json
import os
import shutil
import uuid
import file_tags


class FileError(Exception):
    pass


class Workspace:
    def __init__(self, root):
        self.root = Path(root).expanduser().resolve()
        self.root.mkdir(parents=True, exist_ok=True)
        self.trash = self.root / '.Trash'
        if self.trash.is_symlink():
            raise FileError('The workspace Trash cannot be a symbolic link.')
        self.trash.mkdir(exist_ok=True)
        self.index_file = self.trash / '.index.json'
        if self.index_file.is_symlink():
            raise FileError('The Trash index cannot be a symbolic link.')
        try:
            self.trash_index = json.loads(self.index_file.read_text())
        except (FileNotFoundError, ValueError):
            self.trash_index = {}
        self.undo_stack = []
        self.clipboard = []

    def path(self, relative='', allow_trash=False):
        raw = Path(relative)
        if str(relative) in ('@applications', '@recents') or str(relative).startswith(('@app:', '@tag:')):
            raise FileError('Application and virtual locations are read-only.')
        if raw.parts and raw.parts[0] == '.desktop-data':
            raise FileError('Application data is managed by the desktop apps.')
        if raw.is_absolute() or '..' in raw.parts:
            raise FileError('This path is outside the desktop workspace.')
        target = self.root / raw
        # Do not follow symlinks, including symlinked ancestors.
        cursor = target
        while cursor != self.root:
            if cursor.is_symlink():
                raise FileError('Symbolic links are not followed in this prototype.')
            cursor = cursor.parent
        resolved = target.resolve()
        if resolved != self.root and self.root not in resolved.parents:
            raise FileError('This path is outside the desktop workspace.')
        if raw.parts and raw.parts[0] == '.Trash' and not allow_trash:
            raise FileError('Use Put Back to restore an item from the Trash.')
        return target

    def rel(self, path):
        return str(Path(path).relative_to(self.root)).replace(os.sep, '/')

    @staticmethod
    def name(name):
        name = name.strip()
        if not name or name in ('.', '..', '.Trash') or any(c in name for c in ('/', '\\', '\0')):
            raise FileError('Choose a name without slashes or reserved path components.')
        return name

    def unique(self, parent, name, suffix=' copy'):
        candidate = parent / name
        if not candidate.exists():
            return candidate
        p = Path(name)
        stem, extension = (p.stem, p.suffix) if p.suffix else (name, '')
        i = 1
        while True:
            tail = suffix if i == 1 else suffix + ' ' + str(i)
            candidate = parent / (stem + tail + extension)
            if not candidate.exists():
                return candidate
            i += 1

    def _save_trash(self):
        temp = self.index_file.with_suffix('.tmp')
        temp.write_text(json.dumps(self.trash_index, indent=2))
        temp.replace(self.index_file)

    def _record(self, title, inverse):
        self.undo_stack.append((title, inverse))

    @property
    def undo_title(self):
        return self.undo_stack[-1][0] if self.undo_stack else ''

    def mkdir(self, relative, name='untitled folder'):
        parent = self.path(relative)
        name = self.name(name)
        target = parent / name
        counter = 2
        while target.exists():
            target = parent / f'{name} {counter}'
            counter += 1
        target.mkdir()
        self._record('New Folder', [('trash', self.rel(target))])
        return self.rel(target)

    def rename(self, relative, name):
        source = self.path(relative)
        if source == self.root:
            raise FileError('The workspace itself cannot be renamed.')
        target = source.with_name(self.name(name))
        if target == source:
            return relative
        if target.exists():
            raise FileError('An item with that name already exists.')
        source.rename(target)
        self._record('Rename', [('move', self.rel(target), relative)])
        return self.rel(target)

    def _validate_sources(self, relatives):
        paths = [self.path(r) for r in dict.fromkeys(relatives)]
        for p in paths:
            if p == self.root or not p.exists():
                raise FileError('The selected item is no longer available.')
        # A selection containing a folder and its child needs only the parent.
        return [p for p in paths if not any(q != p and q in p.parents for q in paths)]

    def copy(self, relatives, destination, move=False, duplicate=False):
        sources = self._validate_sources(relatives)
        parent = self.path(destination)
        if not parent.is_dir():
            raise FileError('The destination must be a folder.')
        planned = []
        reserved = set()
        for source in sources:
            if source.is_dir() and (source == parent or source in parent.parents):
                raise FileError('A folder cannot be placed inside itself.')
            target = parent / source.name
            if move and source == target:
                continue
            if target.exists() or target in reserved:
                if move and not duplicate:
                    raise FileError('A destination item has the same name. Nothing was moved.')
                target = self.unique(parent, source.name)
                while target in reserved:
                    target = self.unique(parent, target.stem + ' copy' + target.suffix)
            # Refuse trees containing links before copytree can follow them.
            if source.is_dir() and not move:
                for folder, dirs, files in os.walk(source, followlinks=False):
                    if any((Path(folder) / n).is_symlink() for n in dirs + files):
                        raise FileError('Copying folders containing symbolic links is not supported.')
            reserved.add(target)
            planned.append((source, target))
        completed = []
        try:
            for source, target in planned:
                if move:
                    source.rename(target)
                elif source.is_dir():
                    shutil.copytree(source, target)
                else:
                    shutil.copy2(source, target)
                if not move:
                    self._copy_tags(source, target)
                completed.append((source, target))
        except OSError as exc:
            # Keep successful operations reversible even after a disk error.
            if not move and target.exists() and (source, target) not in completed:
                completed.append((source, target))
            if completed:
                self._record('Partial Move' if move else 'Partial Copy', [
                    ('move', self.rel(t), self.rel(s)) if move else ('trash', self.rel(t))
                    for s, t in reversed(completed)])
            raise FileError(str(exc)) from exc
        if completed:
            self._record('Move' if move else ('Duplicate' if duplicate else 'Copy'), [
                ('move', self.rel(t), self.rel(s)) if move else ('trash', self.rel(t))
                for s, t in reversed(completed)])
        return [self.rel(t) for s, t in completed]

    def _copy_tags(self, source, target):
        # copy2 on Apple's Python does not preserve extended attributes.
        tag = self.tag(self.rel(source))
        if tag:
            file_tags.write(target, tag)
        if source.is_dir():
            for child in source.iterdir():
                self._copy_tags(child, target / child.name)

    def _trash_one(self, source):
        token = uuid.uuid4().hex + '-' + source.name
        original = self.rel(source)
        source.rename(self.trash / token)
        self.trash_index[token] = {'original': original, 'name': source.name}
        try:
            self._save_trash()
        except OSError:
            (self.trash / token).rename(source)
            del self.trash_index[token]
            raise
        return token

    def remove(self, relatives):
        sources = self._validate_sources(relatives)
        inverse = []
        try:
            for source in sources:
                token = self._trash_one(source)
                inverse.insert(0, ('restore', token))
        finally:
            if inverse:
                self._record('Move to Trash', inverse)

    def _restore_one(self, token):
        if '/' in token or token not in self.trash_index:
            raise FileError('This Trash item is not available.')
        entry = self.trash_index[token]
        source = self.trash / token
        destination = self.path(entry['original'])
        destination.parent.mkdir(parents=True, exist_ok=True)
        if destination.exists():
            raise FileError('Put Back would replace an existing item. Rename that item first.')
        source.rename(destination)
        del self.trash_index[token]
        try:
            self._save_trash()
        except OSError:
            destination.rename(source)
            self.trash_index[token] = entry
            raise
        return self.rel(destination)

    def restore(self, relatives):
        inverse = []
        restored = []
        try:
            for rel in relatives:
                token = Path(rel).name
                result = self._restore_one(token)
                restored.append(result)
                inverse.insert(0, ('trash', result))
        finally:
            if inverse:
                self._record('Put Back', inverse)
        return restored

    TAG_ATTRIBUTE = 'user.tahoe.tag'
    TAGS = ('Red', 'Orange', 'Yellow', 'Green', 'Blue', 'Purple', 'Gray')

    def tag(self, relative):
        path = self.path(relative, allow_trash=True)
        try:
            value = file_tags.read(path)
            return value if value in self.TAGS else ''
        except (OSError, AttributeError, UnicodeError):
            return ''

    def set_tag(self, relatives, tag):
        if tag and tag not in self.TAGS:
            raise FileError('Unknown tag color.')
        sources = self._validate_sources(relatives)
        inverse = []
        try:
            for source in sources:
                relative = self.rel(source)
                previous = self.tag(relative)
                file_tags.write(source, tag)
                inverse.insert(0, ('tag', relative, previous))
        finally:
            if inverse:
                self._record('Tags', inverse)

    def undo(self):
        if not self.undo_stack:
            return
        title, actions = self.undo_stack[-1]
        while actions:
            action = actions[0]
            if action[0] == 'tag':
                file_tags.write(self.path(action[1]), action[2])
            elif action[0] == 'trash':
                self._trash_one(self.path(action[1]))
            elif action[0] == 'restore':
                self._restore_one(action[1])
            else:
                source, target = self.path(action[1]), self.path(action[2])
                if target.exists():
                    raise FileError('Undo would replace an existing item.')
                source.rename(target)
            actions.pop(0)
        self.undo_stack.pop()


def seed_workspace(root, asset_dir):
    root = Path(root)
    if root.exists() and any(root.iterdir()):
        return
    for folder in ('Desktop', 'Documents/Projects', 'Documents/Notes', 'Downloads', 'Pictures', 'Music', 'Movies'):
        (root / folder).mkdir(parents=True, exist_ok=True)
    (root / 'Documents/Welcome.txt').write_text(
        'Welcome to your desktop.\n\n'
        'These are real files in an isolated demo workspace.\n'
        'Try opening a folder, switching views, pressing Space for Quick Look,\n'
        'renaming with Return, or creating a folder with Command-Shift-N.\n\n'
        'Command-C copies. Command-V pastes. Command-Option-V moves.\n'
        'Command-Delete moves selected items to the local Trash.\n'
        'Command-Z undoes file operations.\n\n'
        'On Linux use Ctrl instead of Command.\n'
        'The red button closes a Finder window; Finder remains in the Dock.\n', encoding='utf-8')
    (root / 'Documents/Notes/Ideas.md').write_text('# A desktop that feels right\n\n- Consistent controls\n- Fluid window movement\n- Real file operations\n- Thoughtful keyboard navigation\n', encoding='utf-8')
    (root / 'Documents/Projects/Readme.txt').write_text('Your next project starts here.\n', encoding='utf-8')
    (root / 'Downloads/Reading list.txt').write_text('Qt Quick\nWayland\nKWin\n', encoding='utf-8')
    (root / 'Desktop/Start here.txt').write_text('Open Finder from the Dock. Your sample files are in Documents.\n', encoding='utf-8')
    for name, src in [('Tahoe — Day.jpg', 'wallpaper-light.jpg'), ('Tahoe — Night.jpg', 'wallpaper-dark.jpg')]:
        path = Path(asset_dir) / src
        if path.exists():
            shutil.copy2(path, root / 'Pictures' / name)
