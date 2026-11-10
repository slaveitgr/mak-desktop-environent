import QtQuick
import QtQuick.Controls

AbstractButton {
    id: control
    property string symbol: "more"
    property bool dark: false
    property bool selected: false
    property string tip: ""
    width: 32
    height: 32
    padding: 4
    hoverEnabled: true
    Accessible.name: tip
    ToolTip.visible: hovered && tip !== ""
    ToolTip.text: tip
    ToolTip.delay: 700
    background: Rectangle {
        radius: 9
        color: control.down ? (control.dark ? "#40ffffff" : "#26000000") : control.selected ? (control.dark ? "#30ffffff" : "#20000000") : control.hovered ? (control.dark ? "#20ffffff" : "#10000000") : "transparent"
        Behavior on color {
            ColorAnimation {
                duration: 100
            }
        }
    }
    contentItem: Icon {
        name: control.symbol
        width: 18
        height: 18
        color: control.dark ? "#e3e7ea" : "#4b5158"
        opacity: control.enabled ? 1 : 0.28
    }
}
