"""Filesystem primitives for Finder; never replace a destination implicitly."""
import ctypes
import errno
import os
from pathlib import Path
import shutil
import stat
import sys
import tempfile


def occupied(path):
    """Broken links occupy directory entries too."""
    return os.path.lexists(path)


def read_regular_preview(path, maximum=700):
    """Read a regular file only, without following a link or blocking on a pipe."""
    descriptor = os.open(path, os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW)
    with os.fdopen(descriptor, 'rb') as stream:
        if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
            raise OSError(errno.EINVAL, 'Preview requires a regular file.', str(path))
        return stream.read(maximum)


def rename_exclusive(source, destination):
    """Atomic no-replace rename on the supported Linux/macOS hosts.

    A check followed by Path.rename is insufficient: another file (or link)
    can arrive between them. Fail closed on hosts/filesystems lacking this
    operation instead of silently falling back to an overwriting rename.
    """
    library = ctypes.CDLL(None, use_errno=True)
    old, new = os.fsencode(source), os.fsencode(destination)
    if sys.platform == 'darwin' and hasattr(library, 'renamex_np'):
        function = library.renamex_np
        function.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint]
        function.restype = ctypes.c_int
        result = function(old, new, 0x4)  # RENAME_EXCL
    elif sys.platform.startswith('linux') and hasattr(library, 'renameat2'):
        function = library.renameat2
        function.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int,
                             ctypes.c_char_p, ctypes.c_uint]
        function.restype = ctypes.c_int
        result = function(-100, old, -100, new, 1)  # AT_FDCWD, RENAME_NOREPLACE
    else:
        raise OSError(errno.ENOTSUP, 'This system cannot safely rename without replacing files.')
    if result != 0:
        code = ctypes.get_errno()
        raise OSError(code, os.strerror(code), str(destination))


def copy_exclusive(source, destination, metadata=None):
    """Publish a complete copy atomically; failed copies leave no target.

    Staging is private and on the destination filesystem. Links introduced
    into a source tree during a copy are copied as links, never followed.
    Workspace performs its own policy checks before calling this primitive.
    """
    source, destination = Path(source), Path(destination)
    with tempfile.TemporaryDirectory(prefix='.finder-transfer-', dir=destination.parent) as staging:
        staged = Path(staging) / 'item'
        if source.is_dir() and not source.is_symlink():
            shutil.copytree(source, staged, symlinks=True)
        else:
            shutil.copy2(source, staged, follow_symlinks=False)
        if metadata:
            metadata(source, staged)
        rename_exclusive(staged, destination)


def search_names(directory, query, hidden=False, max_entries=50000, max_results=5000):
    """Return bounded recursive filename matches without following links.

    Internal app data, Trash and transfer staging are never searched. The
    caller can present the explicit truncation flag and select a narrower
    directory; this is filename search, not an indexed content search.
    """
    needle = query.casefold().strip()
    if not needle:
        return [], False
    matches, pending, examined = [], [Path(directory)], 0
    while pending:
        folder = pending.pop()
        try:
            with os.scandir(folder) as entries:
                for entry in entries:
                    examined += 1
                    if examined > max_entries:
                        return matches, True
                    name = entry.name
                    if (name in ('.Trash', '.desktop-data') or name.startswith('.finder-transfer-')
                            or (name.startswith('.') and not hidden) or entry.is_symlink()):
                        continue
                    try:
                        mode = entry.stat(follow_symlinks=False).st_mode
                    except OSError:
                        continue
                    if not (stat.S_ISREG(mode) or stat.S_ISDIR(mode)):
                        continue
                    path = Path(entry.path)
                    if needle in name.casefold():
                        matches.append(path)
                        if len(matches) >= max_results:
                            return matches, True
                    if stat.S_ISDIR(mode):
                        pending.append(path)
        except OSError:
            # One inaccessible/deleted nested directory must not hide other matches.
            continue
    return matches, False
