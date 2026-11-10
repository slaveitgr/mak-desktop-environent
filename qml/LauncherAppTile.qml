import QtQuick
import QtQuick.Controls

AbstractButton {
    id: tile
    required property var entry
    required property var host
    property bool selected: false
    signal launch(string application)
    hoverEnabled: true
    focusPolicy: Qt.NoFocus
    Accessible.name: "Open " + entry.name
    Accessible.selected: selected
    onClicked: launch(entry.id)
    background: Rectangle {
        anchors.fill: parent; anchors.margins: 5
        radius: 12
        color: tile.selected ? "#405e87" : tile.hovered ? (tile.host.dark ? "#18ffffff" : "#12000000") : "transparent"
    }
    Image {
        width: 76; height: 76
        anchors.horizontalCenter: parent.horizontalCenter
        y: 10
        source: tile.entry.iconUrl || Bridge.assetRoot + tile.entry.image
        fillMode: Image.PreserveAspectFit
        scale: tile.down ? 0.92 : 1
        Behavior on scale { NumberAnimation { duration: tile.host.desktop.reduceMotion ? 0 : 100 } }
    }
    Text {
        x: 2; y: 87; width: parent.width-4; height: 18
        text: tile.entry.name
        color: tile.host.ink
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: 13; font.weight: Font.Medium
        elide: Text.ElideRight
    }
}
