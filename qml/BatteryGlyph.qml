import QtQuick

Item {
    id: glyph
    property color color: "white"
    property real level: 0
    property bool available: false
    property bool charging: false
    property bool lowPower: false
    implicitWidth: 25
    implicitHeight: 12
    Rectangle {
        x: 0; y: 1; width: parent.width - 3; height: parent.height - 2
        radius: 2.7; color: "transparent"; border.width: 1; border.color: glyph.color
        Rectangle {
            x: 2; y: 2; height: parent.height - 4
            width: glyph.available ? Math.max(0, (parent.width - 4) * Math.max(0, Math.min(1, glyph.level))) : 0
            radius: 1.2
            color: glyph.lowPower ? "#ffd54a" : glyph.level <= 0.1 ? "#ff665d" : glyph.color
        }
    }
    Rectangle { x: parent.width - 2; y: (parent.height - 4) / 2; width: 2; height: 4; radius: 1; color: glyph.color; opacity: 0.65 }
    Canvas {
        id: chargePath
        anchors.centerIn: parent; width: 8; height: 12; visible: glyph.charging && glyph.available
        onPaint: { let c=getContext("2d");c.reset();c.fillStyle="#252529";c.strokeStyle=glyph.color;c.lineWidth=0.8;c.beginPath();c.moveTo(4.8,0);c.lineTo(0,6.6);c.lineTo(3.5,6.6);c.lineTo(2.5,12);c.lineTo(8,4.5);c.lineTo(4.3,4.5);c.closePath();c.fill();c.stroke(); }
        Connections { target:glyph; function onColorChanged(){chargePath.requestPaint();} }
    }
}
