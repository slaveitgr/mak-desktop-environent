import QtQuick
import QtQuick.Controls

AbstractButton {
    id: button
    property string symbol: ""
    property bool dark: false
    property bool filled: false
    property color ink: dark ? "#f5f5f7" : "#25262b"
    implicitWidth: symbol ? 30 : Math.max(52, caption.implicitWidth + 24)
    implicitHeight: 30
    hoverEnabled: true
    Accessible.name: text
    ToolTip.visible: hovered && symbol !== ""
    ToolTip.text: text
    ToolTip.delay: 700
    opacity: enabled ? 1 : 0.35
    background: Rectangle {
        radius: height / 2
        color: button.down ? (button.dark ? "#55ffffff" : "#25000000") : button.filled || button.hovered ? (button.dark ? "#28ffffff" : "#17ffffff") : "transparent"
        border.width: button.activeFocus ? 2 : 0
        border.color: "#3398ff"
    }
    contentItem: Item {
        Icon {
            anchors.centerIn: parent
            width: 17; height: 17
            visible: button.symbol !== ""
            name: button.symbol
            color: button.ink
        }
        Text {
            id: caption
            anchors.centerIn: parent
            visible: button.symbol === ""
            text: button.text
            color: button.ink
            font.pixelSize: 12
            font.weight: Font.Medium
        }
    }
}
