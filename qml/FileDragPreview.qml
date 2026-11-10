import QtQuick

// Internal workspace drag: the image stays above windows while the source
// MouseArea owns the grab. Paths are captured before a model can refresh.
Item {
    id: preview
    required property var desktop
    required property var sourceMouse
    property var paths: []
    property string origin: "finder"
    property string primaryPath: ""
    property bool copyRequested: false
    property url imageSource
    parent: desktop.fileDragLayer
    width: 64
    height: 64
    visible: sourceMouse.drag.active
    opacity: 0.82
    Drag.active: sourceMouse.drag.active
    Drag.keys: ["tahoe/files"]
    Drag.source: preview
    Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
    Drag.proposedAction: copyRequested ? Qt.CopyAction : Qt.MoveAction
    Drag.hotSpot.x: 32
    Drag.hotSpot.y: 32
    function prepare(item, px, py, selection, image, path, modifiers) {
        let point = item.mapToItem(parent, px, py);
        x = point.x - 32; y = point.y - 32;
        paths = selection.slice(); imageSource = image; primaryPath = path;
        copyRequested = !!(modifiers & Qt.AltModifier);
    }
    Connections {
        target: preview.sourceMouse
        function onPositionChanged(mouse) {
            if (preview.sourceMouse.pressed) preview.copyRequested = !!(mouse.modifiers & Qt.AltModifier);
        }
    }
    Image { anchors.fill: parent; source: preview.imageSource; fillMode: Image.PreserveAspectFit }
    Rectangle {
        visible: preview.paths.length > 1
        anchors.right: parent.right; anchors.bottom: parent.bottom
        width: Math.max(22, count.implicitWidth + 10); height: 22; radius: 11
        color: "#e34238"; border.color: "white"
        Text { id: count; anchors.centerIn: parent; text: preview.paths.length; color: "white"; font.pixelSize: 12 }
    }
}
