import QtQuick

Item {
    id: row
    required property bool dark
    property bool reducedMotion: false
    property string label: ""
    property string description: ""
    property alias checked: toggle.checked
    signal toggled(bool value)
    width: parent.width
    height: description ? 66 : 44
    Text {
        x: 0
        y: row.description ? 12 : (parent.height - height) / 2
        width: parent.width - 54
        text: row.label
        color: row.dark ? "#f0f1f2" : "#282a2d"
        font.pixelSize: 13
    }
    Text {
        x: 0
        y: 31
        width: parent.width - 54
        text: row.description
        color: row.dark ? "#b2b4b7" : "#777a80"
        font.pixelSize: 11
        wrapMode: Text.Wrap
    }
    ToggleSwitch {
        id: toggle
        width: 32
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        dark: row.dark
        reducedMotion: row.reducedMotion
        Accessible.name: row.label
        onToggled: row.toggled(checked)
    }
}
