import QtQuick
import QtQuick.Controls

AbstractButton {
    id: control
    property bool dark: false
    property bool reducedMotion: false
    checkable: true
    width: 248
    height: 27
    hoverEnabled: true
    Accessible.role: Accessible.CheckBox
    Accessible.name: text
    Accessible.checked: checked
    contentItem: Text {
        text: control.text
        verticalAlignment: Text.AlignVCenter
        font.pixelSize: 12
        color: control.dark ? "#eeeeef" : "#252a31"
    }
    background: Item {
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 19
            radius: 9.5
            color: control.checked ? "#0784ff" : control.dark ? "#63666b" : "#b4b8bd"
            opacity: control.enabled ? 1 : 0.5
            Behavior on color {
                ColorAnimation {
                    duration: control.reducedMotion ? 0 : 120
                }
            }
            Rectangle {
                x: control.checked ? 14 : 1
                y: 1
                width: 17
                height: 17
                radius: 8.5
                color: control.down ? "#f1f1f3" : "white"
                border.color: "#16000000"
                border.width: 0.5
                Behavior on x {
                    NumberAnimation {
                        duration: control.reducedMotion ? 0 : 150
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
