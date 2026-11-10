import QtQuick
import QtQuick.Controls

Slider {
    id: slider
    property string symbol: "speaker"
    property bool dark: false
    from: 0; to: 1
    implicitHeight: 32
    leftPadding: 0; rightPadding: 0
    opacity: enabled ? 1 : 0.4
    background: Rectangle {
        x: slider.leftPadding
        y: (slider.height - height) / 2
        width: slider.availableWidth; height: 30
        radius: 15
        color: slider.dark ? "#45000000" : "#26000000"
        clip: true
        Rectangle {
            width: Math.max(30, slider.visualPosition * parent.width)
            height: parent.height
            radius: 15
            color: slider.dark ? "#ededf2" : "#ffffff"
        }
        Icon {
            x: 8; anchors.verticalCenter: parent.verticalCenter
            width: 17; height: 17
            name: slider.symbol
            color: slider.visualPosition > 0.13 ? "#55565e" : slider.dark ? "#d0d0d7" : "#65666e"
        }
        border.width: slider.activeFocus ? 2 : 0
        border.color: "#3398ff"
    }
    handle: Rectangle {
        x: slider.leftPadding + slider.visualPosition * Math.max(0, slider.availableWidth - width)
        y: (slider.height - height) / 2
        width: 28; height: 28; radius: 14
        color: "#fafafa"
        opacity: slider.pressed || slider.hovered ? 1 : 0
        border.color: "#18000000"
    }
}
