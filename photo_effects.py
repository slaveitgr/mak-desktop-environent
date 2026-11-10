"""Photo Booth capture processing, using Qt's image operations only.

Only paths allocated by this instance may be processed. Camera originals are
kept in .originals; visible results are new, exclusively-created PNG files.
No image is uploaded or overwritten. Grayscale uses Qt's sRGB luminance
conversion; the preview shader uses the same transfer function and weights.
"""
from datetime import datetime
from pathlib import Path
import uuid
from PySide6.QtCore import QFile, QIODevice, QRect, QSize, Qt, QUrl
from PySide6.QtGui import QColor, QColorSpace, QImage, QImageReader, QPainter, qRgb

EFFECTS = {'normal': 'Photo', 'mono': 'Black & White', 'sepia': 'Sepia', 'mirror': 'Mirror'}
MAX_PIXELS = 20_000_000
MAX_FILE_BYTES = 100_000_000


def apply_effect(image, effect='normal', flip=False):
    """Transform an owned image in memory. Input is left unchanged."""
    if effect not in EFFECTS:
        raise ValueError('Unknown photo effect')
    if image.isNull() or image.width() * image.height() > MAX_PIXELS:
        raise ValueError('The captured image is empty or too large')
    result = image.copy()
    if result.colorSpace().isValid() and result.colorSpace() != QColorSpace(QColorSpace.SRgb):
        result.convertToColorSpace(QColorSpace(QColorSpace.SRgb))
    else:
        result.setColorSpace(QColorSpace(QColorSpace.SRgb))
    if flip:
        result = result.mirrored(True, False)
    if effect in ('mono', 'sepia'):
        gray = result.convertToFormat(QImage.Format_Grayscale8)
        if effect == 'mono':
            result = gray.convertToFormat(QImage.Format_RGB32)
        else:
            indexed = gray.convertToFormat(QImage.Format_Indexed8)
            indexed.setColorTable([qRgb(min(255, int(level*1.15+10.5)), min(255, int(level*.95+8.5)), min(255, int(level*.70+3.5))) for level in range(256)])
            result = indexed.convertToFormat(QImage.Format_RGB32)
    elif effect == 'mirror':
        # Keep the left half and reflect it across the center, including odd widths.
        half = result.width() // 2
        reflected = result.copy(0, 0, half, result.height()).mirrored(True, False)
        painter = QPainter(result)
        painter.drawImage(result.width()-half, 0, reflected)
        painter.end()
    result.setColorSpace(QColorSpace(QColorSpace.SRgb))
    return result


class PhotoEffects:
    def __init__(self, root):
        self.root = Path(root).resolve()
        self.base = self.root / 'Pictures' / 'Photo Booth'
        self._allocated = set()

    def _folder(self, originals=False):
        path = self.root
        for part in ('Pictures', 'Photo Booth') + (('.originals',) if originals else ()):
            path = path / part
            if path.is_symlink():
                raise ValueError('Photo Booth folders cannot be symbolic links')
            path.mkdir(exist_ok=True)
            if not path.is_dir():
                raise ValueError('Photo Booth needs a directory for its photos')
        return path

    def capture_path(self):
        folder = self._folder(originals=True)
        path = folder / ('Original ' + datetime.now().strftime('%Y-%m-%d %H.%M.%S') + '-' + uuid.uuid4().hex + '.jpg')
        self._allocated.add(str(path))
        return str(path)

    def _read(self, source):
        source = Path(source)
        if not source.is_absolute() or str(source) not in self._allocated:
            raise ValueError('Only a new Photo Booth capture can be processed')
        folder = self._folder(originals=True)
        if source.parent != folder or source.is_symlink() or not source.is_file():
            raise ValueError('The original capture is missing or outside Photo Booth')
        if source.stat().st_size > MAX_FILE_BYTES:
            raise ValueError('The original capture is too large')
        reader = QImageReader(str(source))
        reader.setAutoTransform(True)
        size = reader.size()
        if not size.isValid() or size.width() * size.height() > MAX_PIXELS:
            raise ValueError('The captured image dimensions are unsupported')
        image = reader.read()
        if image.isNull():
            raise ValueError('The captured image could not be read')
        return image

    def _save(self, image, label):
        folder = self._folder()
        path = folder / (label + ' ' + datetime.now().strftime('%Y-%m-%d %H.%M.%S') + '-' + uuid.uuid4().hex[:10] + '.png')
        target = QFile(str(path))
        if not target.open(QIODevice.WriteOnly | QIODevice.NewOnly):
            raise OSError('A new photo could not be created: ' + target.errorString())
        saved = image.save(target, 'PNG')
        target.close()
        if not saved:
            path.unlink(missing_ok=True)
            raise OSError('The photo could not be saved')
        return {'path':str(path), 'url':QUrl.fromLocalFile(str(path)).toString(), 'name':path.name}

    def finish(self, source, effect='normal', flip=False):
        image = apply_effect(self._read(source), effect, bool(flip))
        return self._save(image, EFFECTS[effect])

    def contact_sheet(self, sources, effect='normal', flip=False):
        if not isinstance(sources, (list, tuple)) or len(sources) != 4 or any(not isinstance(source, str) for source in sources) or len(set(sources)) != 4:
            raise ValueError('A four-photo sheet needs four different captures')
        first = self._read(sources[0])
        size = first.size()
        cell = size.scaled(QSize(1024, 1024), Qt.KeepAspectRatio) if max(size.width(), size.height()) > 1024 else size
        padding, gap = 16, 12
        sheet = QImage(cell.width()*2 + padding*2 + gap, cell.height()*2 + padding*2 + gap, QImage.Format_RGB32)
        sheet.fill(QColor('#faf8f2'))
        painter = QPainter(sheet)
        painter.setRenderHint(QPainter.SmoothPixmapTransform, True)
        try:
            for index, source in enumerate(sources):
                frame = apply_effect(first if index == 0 else self._read(source), effect, bool(flip))
                if index == 0: first = QImage()
                x = padding + (index % 2) * (cell.width() + gap)
                y = padding + (index // 2) * (cell.height() + gap)
                painter.fillRect(QRect(x, y, cell.width(), cell.height()), QColor('#151519'))
                scaled = frame.scaled(cell, Qt.KeepAspectRatio, Qt.SmoothTransformation)
                painter.drawImage(x + (cell.width()-scaled.width())//2, y + (cell.height()-scaled.height())//2, scaled)
        finally:
            painter.end()
        sheet.setColorSpace(QColorSpace(QColorSpace.SRgb))
        return self._save(sheet, 'Four Photos')
