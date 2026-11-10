import QtQuick
import QtQuick.Controls

TextField {
    id: control
    property bool dark: false
    implicitHeight: 34
    leftPadding: 11
    rightPadding: 11
    color: dark ? "#f2f2f4" : "#27272a"
    placeholderTextColor: dark ? "#82858a" : "#92959a"
    selectionColor: "#357bcb"
    selectedTextColor: "white"
    font.pixelSize: 13
    selectByMouse: true
    background: Rectangle {
        color: control.dark ? "#232629" : "#f1f2f4"
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? "#67a4ee" : control.dark ? "#383b40" : "#e2e4e8"
        radius: 8
    }
}
