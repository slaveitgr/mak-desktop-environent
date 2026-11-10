import QtQuick
import QtQuick.Controls

AbstractButton {
    id: toggle
    property bool dark: false
    signal requested(bool value)
    implicitWidth: 34
    implicitHeight: 20
    checkable: false
    opacity: enabled ? 1 : 0.38
    onClicked: requested(!checked)
    Accessible.role: Accessible.CheckBox
    Accessible.checkable: true
    Accessible.checked: checked
    background: Rectangle {
        radius: height / 2
        color: toggle.checked ? "#1688fa" : toggle.dark ? "#77777e" : "#bcbcc2"
        border.width: toggle.activeFocus ? 2 : 0
        border.color: "#61afff"
    }
    contentItem: Item {
        Rectangle {
            x: toggle.checked ? parent.width - width - 2 : 2
            y: 2; width: parent.height - 4; height: width; radius: width / 2
            color: toggle.down ? "#ececef" : "white"
        }
    }
}
