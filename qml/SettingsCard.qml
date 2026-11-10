import QtQuick

Rectangle {
    id: card
    required property bool dark
    default property alias rows: body.data
    width: parent.width
    implicitHeight: body.implicitHeight + 4
    radius: 12
    color: dark ? "#2b3033" : "#ffffff"
    border.color: dark ? "#0cffffff" : "#0c000000"
    Column {
        id: body
        x: 10
        y: 2
        width: parent.width - 20
    }
}
