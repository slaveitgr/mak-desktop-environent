"""Small portable xattr adapter, including Apple's bundled Python without os.xattr."""
import ctypes
import errno
import os
import sys

ATTRIBUTE = 'user.tahoe.tag'

if sys.platform == 'darwin' and not hasattr(os, 'getxattr'):
    _lib = ctypes.CDLL('/usr/lib/libSystem.B.dylib', use_errno=True)
    _lib.getxattr.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_void_p,
                             ctypes.c_size_t, ctypes.c_uint32, ctypes.c_int]
    _lib.getxattr.restype = ctypes.c_ssize_t
    _lib.setxattr.argtypes = _lib.getxattr.argtypes
    _lib.setxattr.restype = ctypes.c_int


def read(path):
    if hasattr(os, 'getxattr'):
        return os.getxattr(path, ATTRIBUTE).decode('utf-8')
    if sys.platform != 'darwin':
        raise OSError(errno.ENOTSUP, 'File tags require extended attributes.')
    buffer = ctypes.create_string_buffer(64)
    count = _lib.getxattr(os.fsencode(path), ATTRIBUTE.encode(), buffer, 64, 0, 0)
    if count < 0:
        raise OSError(ctypes.get_errno(), 'Cannot read file tags.')
    return buffer.raw[:count].decode('utf-8')


def write(path, tag):
    data = tag.encode('utf-8')
    if hasattr(os, 'setxattr'):
        os.setxattr(path, ATTRIBUTE, data)
    elif sys.platform == 'darwin':
        if _lib.setxattr(os.fsencode(path), ATTRIBUTE.encode(), data, len(data), 0, 0) < 0:
            raise OSError(ctypes.get_errno(), 'Cannot save file tags.')
    else:
        raise OSError(errno.ENOTSUP, 'File tags require extended attributes.')
