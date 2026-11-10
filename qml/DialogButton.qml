import QtQuick
import QtQuick.Controls

AbstractButton {
    id: button
    property bool primary: false
    property bool dark: false
    implicitWidth: Math.max(80, label.implicitWidth + 30)
    implicitHeight: 30
    hoverEnabled: true
    background: Rectangle {
        radius: 8
        color: button.primary ? (button.down ? "#0060d0" : "#087bff") : button.dark ? (button.down ? "#65707d" : "#4d5764") : (button.down ? "#d1d6dd" : "#e4e8ed")
        border.width: 1
        border.color: button.primary ? "#16000000" : button.dark ? "#25ffffff" : "#0c000000"
    }
    contentItem: Text {
        id: label
        text: button.text
        font.pixelSize: 13
        font.weight: Font.Medium
        color: button.primary || button.dark ? "white" : "#252b34"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
