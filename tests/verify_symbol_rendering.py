"""Render template symbols with the real Qt software scenegraph and inspect pixels."""
import os
from pathlib import Path
import sys
os.environ['QT_QPA_PLATFORM']='offscreen'
os.environ['QT_QUICK_BACKEND']='software'
from PySide6.QtCore import QObject,QUrl,QCoreApplication,QEvent
from PySide6.QtGui import QGuiApplication,QColor
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow
from PySide6.QtTest import QTest

root=Path(__file__).resolve().parents[1]
app=QGuiApplication([]);engine=QQmlApplicationEngine();warnings=[]
engine.warnings.connect(lambda errors:warnings.extend(str(e) for e in errors))
engine.loadData(b'''import QtQuick
import QtQuick.Window
Window {
    visible: true; width: 100; height: 60; color: "transparent"
    Icon { objectName: "sample"; x: 10; y: 10; width: 40; height: 40; name: "wifi"; color: "#ff0000" }
}
''',QUrl.fromLocalFile(str(root/'qml/SymbolRenderFixture.qml')))
assert engine.rootObjects(),warnings
window=engine.rootObjects()[0];sample=window.findChild(QObject,'sample')
QTest.qWait(200)
assert sample.property('softwareRenderer')
def capture():
    image=window.grabWindow()
    assert not image.isNull()
    return image
def colored(image,channel):
    return sum(1 for y in range(image.height()) for x in range(image.width())
               if image.pixelColor(x,y).alpha()>64 and getattr(image.pixelColor(x,y),channel)()>180)
first=capture()
assert 30<colored(first,'red')<1500,'The native symbol must render, with transparent space around its shape'
assert colored(first,'blue')==0
sample.setProperty('color',QColor('#0000ff'));QTest.qWait(100)
second=capture()
assert colored(second,'blue')>30 and colored(second,'red')==0,'Tint changes must repaint the template'
sample.setProperty('name','folder');QTest.qWait(150)
third=capture();assert colored(third,'blue')>30 and third!=second,'Changing a symbol must repaint its actual shape'
if len(sys.argv)>1:assert third.save(sys.argv[1])
assert not warnings,warnings
window.hide();engine.deleteLater();QCoreApplication.sendPostedEvents(None,QEvent.DeferredDelete)
print('PASS: software-rendered native symbol pixels, transparency, tint and symbol changes.')
