"""Offscreen menu artwork, layout, keyboard and material regression checks.

Uses only generated fixtures and shipped resource assets; no native UI or OS action.
Run with the project's PySide6 Python environment.
"""
import hashlib
import json
import os
from pathlib import Path

os.environ["QT_QPA_PLATFORM"] = "offscreen"
os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"

from PySide6.QtCore import QObject, QPoint, QPointF, Qt, QUrl
from PySide6.QtGui import QFont, QGuiApplication, QImage
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickItem, QQuickWindow
from PySide6.QtTest import QTest

ROOT = Path(__file__).resolve().parents[1]
app = QGuiApplication([])
app.setFont(QFont(".AppleSystemUIFont", 13))
engine = QQmlApplicationEngine()
warnings = []
engine.warnings.connect(lambda messages: warnings.extend(str(x) for x in messages))
fixture = [
    dict(label="as Icons", command="icons", checked=True, shortcut="⌘1"),
    dict(label="New Folder", command="newfolder", enabled=False, shortcut="⇧⌘N"),
    dict(separator=True),
    dict(label="Unmapped Fixture", command="unknown-fixture"),
    dict(label="Sort By", submenu=[dict(label="Name", command="sortname")]),
    dict(label="A deliberately long action label that must not overlap its shortcut", command="forcequit", shortcut="⌥⌘⎋"),
] + [dict(label="Fixture " + str(i), command="fixture:" + str(i)) for i in range(20)]
qml = '''import QtQuick
import QtQuick.Controls
import "MenuSymbols.js" as MenuSymbols
ApplicationWindow {
    width: 800; height: 600; visible: true
    Rectangle { id: scene; anchors.fill: parent; color: "#327bad" }
    GlassMenu {
        id: menu; objectName: "menu"; x: 30; y: 30
        reducedMotion: true; maximumHeight: 240; backdrop: scene
        rows: FIXTURE_ROWS
    }
    function mapping(rowJson) { return JSON.stringify(MenuSymbols.assignmentFor(JSON.parse(rowJson))); }
    function asset(rowJson) { return MenuSymbols.assetFor(JSON.parse(rowJson)); }
    Component.onCompleted: menu.open()
}'''.replace("FIXTURE_ROWS", json.dumps(fixture, ensure_ascii=False))
engine.loadData(qml.encode(), QUrl.fromLocalFile(str(ROOT / "qml/MenuVerification.qml")))
assert engine.rootObjects(), warnings
window = engine.rootObjects()[0]
menu = window.findChild(QObject, "menu")
window.requestActivate()
QTest.qWait(80)


def child(name):
    result = window.findChild(QObject, name)
    if result is None:
        pending = [window.contentItem()]
        while pending:
            item = pending.pop()
            if item.objectName() == name:
                result = item
                break
            pending.extend(item.childItems())
    assert result is not None, name
    return result


def mapping(row):
    return json.loads(window.mapping(json.dumps(row)))


def color(item, name):
    return item.property(name).name()


def click(item):
    point = item.mapToScene(QPointF(item.width() / 2, item.height() / 2))
    QTest.mouseClick(window, Qt.LeftButton, Qt.NoModifier, QPoint(round(point.x()), round(point.y())))
    QTest.qWait(10)


# Evidence-backed mappings, explicit inferences, disabled labels and opt-outs.
assert mapping(dict(label="Rename", enabled=False)) == dict(symbol="pencil", basis="observed-finder-archive")
assert mapping(dict(label="New Finder Window"))["symbol"] == "plus.rectangle"
assert mapping(dict(label="as Gallery"))["symbol"] == "squares.below.rectangle"
assert mapping(dict(label="Show Clipboard", enabled=False))["symbol"] == "clipboard"
assert mapping(dict(label="About This Mac", command="aboutmac"))["basis"] == "inferred"
assert mapping(dict(label="Log Out Fixture…", command="session:logout"))["symbol"] == "rectangle.portrait.and.arrow.right"
assert mapping(dict(label="Undo Rename", command="undo"))["symbol"] == "arrow.uturn.backward"
assert mapping(dict(label="Applications"))["basis"] == "inferred-fallback-for-observed-resource"
assert window.asset(json.dumps(dict(label="AirDrop"))) == "../assets/symbols/airdrop.png"
for row in [dict(label="Name"), dict(label="Red", command="tag:Red"), dict(label="Window Title", command="window:0"), dict(label="Services"), dict(separator=True), dict(label="Open", symbol=""), dict(label="Open", symbol="../../private")]:
    assert mapping(row)["symbol"] == "", row

# Checkmarks and action icons occupy separate gutters; every label aligns.
assert menu.property("hasSymbols")
assert menu.property("labelInset") == 46
check = child("menuCheck_0")
symbol = child("menuSymbol_0")
label = child("menuLabel_0")
assert check.isVisible() and symbol.isVisible()
assert check.x() + check.width() <= symbol.x()
assert symbol.x() + symbol.width() < label.x()
assert child("menuLabel_3").x() == label.x()
assert not child("menuSymbol_3").isVisible()
long_label = child("menuLabel_5")
shortcut = child("menuShortcut_5")
assert long_label.x() + long_label.width() + 16 <= shortcut.x() + 0.01

chosen = []
submenus = []
menu.chosen.connect(chosen.append)
menu.submenuRequested.connect(lambda rows, offset: submenus.append(offset))
menu.setProperty("currentIndex", 0)
QTest.qWait(5)
assert color(symbol, "tint") == color(label, "color") == color(check, "color") == "#ffffff"
assert child("menuRow_0").property("highlighted")
menu.setProperty("currentIndex", 1)
QTest.qWait(5)
assert not child("menuRow_1").property("highlighted")
assert child("menuSymbol_1").opacity() == child("menuLabel_1").opacity() == 0.35
assert color(child("menuSymbol_1"), "tint") != "#ffffff"
QTest.keyClick(window, Qt.Key_Return)
QTest.qWait(10)
assert not chosen and menu.property("visible"), "disabled keyboard entry fired"
click(child("menuRow_1"))
assert not chosen and menu.property("visible"), "disabled mouse entry fired"

# Keyboard navigation skips separator/disabled rows; submenu dispatch still works.
menu.resetTracking()
QTest.keyClick(window, Qt.Key_Down)
assert menu.property("currentIndex") == 0
QTest.keyClick(window, Qt.Key_Down)
assert menu.property("currentIndex") == 3
QTest.keyClick(window, Qt.Key_Down)
assert menu.property("currentIndex") == 4
QTest.keyClick(window, Qt.Key_Right)
assert submenus and abs(submenus[-1] - menu.rowOffset(4)) < 0.01

# Menu rollover clears both hover selection and a previously scrolled position.
viewport = child("menuViewport")
menu.setProperty("currentIndex", len(fixture) - 1)
QTest.qWait(10)
assert viewport.property("contentY") > 0
menu.resetTracking()
QTest.qWait(5)
assert menu.property("currentIndex") == -1 and viewport.property("contentY") == 0

# The material stays blurred/translucent and respects Reduce Transparency.
material = child("menuMaterial")
for dark, tint in [(False, 0.62), (True, 0.58)]:
    menu.setProperty("dark", dark)
    QTest.qWait(5)
    assert abs(material.property("tint") - tint) < 1e-6
    assert abs(material.property("frost") - 0.97) < 1e-6
    assert material.property("refraction") == 3
    menu.setProperty("reducedTransparency", True)
    QTest.qWait(5)
    assert material.property("reducedTransparency")
    menu.setProperty("reducedTransparency", False)

# The actual selected action is emitted once, then the menu closes.
menu.resetTracking()
QTest.keyClick(window, Qt.Key_Down)
QTest.keyClick(window, Qt.Key_Return)
QTest.qWait(20)
assert chosen == ["icons"] and not menu.property("visible")

# Every exported glyph has content, matching dimensions and recorded source hash.
provenance = json.loads((ROOT / "assets/symbols/menu.provenance.json").read_text())
for entry in provenance["assets"]:
    path = ROOT / "assets/symbols" / entry["file"]
    image = QImage(str(path))
    assert (image.width(), image.height()) == tuple(entry["pixel_size"])
    assert hashlib.sha256(path.read_bytes()).hexdigest() == entry["png_sha256"]
    assert any(image.pixelColor(x, y).alpha() > 0 for y in range(72) for x in range(72))
assert not warnings, warnings
print("PASS: menu symbols, evidence scope, gutters, disabled/selected tint, keyboard/submenus, rollover reset, translucent material and asset integrity")
window.close()
