"""Synthetic-image checks; no camera or user's photos are read."""
import hashlib
import math
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from PySide6.QtGui import QImage,QColor
from photo_effects import PhotoEffects,apply_effect

class PhotoEffectTests(unittest.TestCase):
    def setUp(self):
        self.temporary=TemporaryDirectory();self.root=Path(self.temporary.name).resolve();self.photos=PhotoEffects(self.root)
    def tearDown(self):self.temporary.cleanup()
    def capture(self, color, width=12, height=8):
        path=Path(self.photos.capture_path());image=QImage(width,height,QImage.Format_RGB32);image.fill(QColor(color))
        self.assertTrue(image.save(str(path),'PNG'))
        return str(path)
    def test_monochrome_and_sepia_transform_colors_without_changing_input(self):
        image=QImage(3,1,QImage.Format_RGB32)
        for x,color in enumerate(('red','#00ff00','blue')):image.setPixelColor(x,0,QColor(color))
        mono=apply_effect(image,'mono');sepia=apply_effect(image,'sepia')
        expected=(127,220,76)
        for x,gray in enumerate(expected):
            red,green,blue,_=mono.pixelColor(x,0).getRgb()
            self.assertEqual(red,green);self.assertEqual(green,blue);self.assertLessEqual(abs(red-gray),1)
            warm=sepia.pixelColor(x,0)
            self.assertGreaterEqual(warm.red(),warm.green());self.assertGreater(warm.green(),warm.blue())
        self.assertEqual(image.pixelColor(0,0),QColor('red'))
        self.assertEqual(image.pixelColor(2,0),QColor('blue'))
    def test_luminance_matches_preview_shader_transfer_with_rounding_tolerance(self):
        colors=[(r,g,b) for r in (0,64,128,255) for g in (0,64,128,255) for b in (0,64,128,255)]
        image=QImage(len(colors),1,QImage.Format_RGB32)
        for x,(r,g,b) in enumerate(colors):image.setPixelColor(x,0,QColor(r,g,b))
        mono=apply_effect(image,'mono')
        def linear(v):
            v=v/255
            return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
        for x,(r,g,b) in enumerate(colors):
            luminance=.2126*linear(r)+.7152*linear(g)+.0722*linear(b)
            encoded=12.92*luminance if luminance<=.0031308 else 1.055*luminance**(1/2.4)-.055
            expected=math.floor(encoded*255+.5)
            self.assertLessEqual(abs(mono.pixelColor(x,0).red()-expected),1)

    def test_reflection_and_flip_preserve_dimensions_and_odd_center(self):
        image=QImage(5,1,QImage.Format_RGB32)
        colors=['red','green','blue','yellow','magenta']
        for x,color in enumerate(colors):image.setPixelColor(x,0,QColor(color))
        mirrored=apply_effect(image,'mirror')
        self.assertEqual([mirrored.pixelColor(x,0).name() for x in range(5)],[QColor(x).name() for x in ['red','green','blue','green','red']])
        flipped=apply_effect(image,'normal',True)
        self.assertEqual([flipped.pixelColor(x,0).name() for x in range(5)],[QColor(x).name() for x in reversed(colors)])
        self.assertEqual(mirrored.size(),image.size())
    def test_saved_effect_is_new_png_and_original_is_unchanged(self):
        source=self.capture('red');before=hashlib.sha256(Path(source).read_bytes()).hexdigest()
        first=self.photos.finish(source,'mono',True);second=self.photos.finish(source,'sepia',False)
        self.assertNotEqual(first['path'],second['path'])
        self.assertEqual(Path(first['path']).parent,self.root/'Pictures/Photo Booth')
        self.assertEqual(Path(first['path']).suffix,'.png')
        self.assertTrue(first['url'].startswith('file:'))
        result=QImage(first['path']);self.assertFalse(result.isNull())
        color=result.pixelColor(0,0);self.assertEqual(color.red(),color.green());self.assertEqual(color.green(),color.blue())
        self.assertEqual(hashlib.sha256(Path(source).read_bytes()).hexdigest(),before)
    def test_four_capture_sheet_dimensions_order_and_borders(self):
        sources=[self.capture(color) for color in ['red','green','blue','yellow']]
        result=self.photos.contact_sheet(sources,'normal',False);sheet=QImage(result['path'])
        self.assertEqual((sheet.width(),sheet.height()),(68,60))
        self.assertEqual(sheet.pixelColor(0,0),QColor('#faf8f2'))
        for x,y,color in [(20,20,'red'),(44,20,'green'),(20,40,'blue'),(44,40,'yellow')]:self.assertEqual(sheet.pixelColor(x,y),QColor(color))
        self.assertTrue(all(Path(source).exists() for source in sources))
        with self.assertRaises(ValueError):self.photos.contact_sheet([sources[0]]*4)
        with self.assertRaises(ValueError):self.photos.contact_sheet(sources[:3])
    def test_outside_unallocated_and_symlink_sources_are_rejected(self):
        outside=self.root/'outside.png';image=QImage(2,2,QImage.Format_RGB32);image.fill(QColor('blue'));image.save(str(outside))
        with self.assertRaises(ValueError):self.photos.finish(str(outside))
        allocated=Path(self.photos.capture_path());allocated.symlink_to(outside)
        with self.assertRaises(ValueError):self.photos.finish(str(allocated))
        self.assertEqual(QImage(str(outside)).pixelColor(0,0),QColor('blue'))
    def test_symlink_output_directory_and_invalid_effect_cannot_write(self):
        source=self.capture('red')
        with self.assertRaises(ValueError):self.photos.finish(source,'unknown')
        base=self.root/'Pictures/Photo Booth';moved=self.root/'original-directory';base.rename(moved)
        outside=self.root/'outside';outside.mkdir();base.symlink_to(outside,target_is_directory=True)
        with self.assertRaises(ValueError):self.photos.capture_path()
        with self.assertRaises(ValueError):self.photos.finish(source)
        self.assertEqual(list(outside.iterdir()),[])

if __name__=='__main__':unittest.main()
