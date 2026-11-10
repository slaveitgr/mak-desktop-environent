import QtQuick
import QtQuick.Controls

Item {
    id: tile
    required property var panel
    required property var entry
    required property int order
    readonly property var definition: panel.controls.info(entry.id) || ({})
    readonly property bool small: entry.size === "small"
    readonly property bool sliderTile: !small && ["display", "sound"].indexOf(entry.id) >= 0
    readonly property bool mediaTile: !small && entry.id === "nowplaying"
    readonly property bool active: panel.controls.isActive(entry.id)
    readonly property bool dark: panel.dark
    readonly property bool editing: panel.editing
    property alias dragging: dragArea.drag.active
    property string controlId: entry.id
    implicitHeight: entry.size === "large" ? (mediaTile ? 106 : 92) : 76
    z: dragArea.drag.active ? 20 : 0
    focus: false
    Accessible.role: Accessible.Button
    Accessible.name: definition.label || entry.id
    Accessible.description: editing ? "Drag to reorder. Use Left and Right to move this control." : ""
    Accessible.onPressAction: panel.activateControl(entry.id)
    Keys.onLeftPressed: if (editing) panel.controls.moveControl(entry.id, Math.max(0, order - 1))
    Keys.onRightPressed: if (editing) panel.controls.moveControl(entry.id, Math.min(panel.controls.layout.length - 1, order + 1))
    Keys.onDeletePressed: if (editing) panel.controls.removeControl(entry.id)
    Behavior on x { enabled: !panel.desktop.reduceMotion && !dragArea.drag.active; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on y { enabled: !panel.desktop.reduceMotion && !dragArea.drag.active; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    Rectangle {
        id: card
        width: tile.width; height: tile.height
        radius: 20
        color: tile.dark ? "#5043434d" : "#9bffffff"
        border.width: tile.editing && tile.panel.selectedControl === tile.entry.id ? 2 : 1
        border.color: tile.editing && tile.panel.selectedControl === tile.entry.id ? "#80ffffff" : tile.dark ? "#19ffffff" : "#40ffffff"
        scale: dragArea.drag.active ? 1.04 : 1
        Behavior on scale { NumberAnimation { duration: tile.panel.desktop.reduceMotion ? 0 : 120 } }

        AbstractButton {
            anchors.fill: parent
            visible: !tile.sliderTile && !tile.mediaTile
            enabled: !tile.editing
            Accessible.name: tile.definition.label || tile.entry.id
            onClicked: tile.panel.activateControl(tile.entry.id)
            background: Rectangle { radius: 20; color: parent.down ? "#20ffffff" : "transparent" }
            contentItem: Item {
                Rectangle {
                    x: tile.small ? (parent.width - 34) / 2 : 12
                    y: tile.small ? 9 : (parent.height - 34) / 2
                    width: 34; height: 34; radius: 17
                    color: tile.active ? (tile.entry.id === "focus" ? "#7655cc" : "#087aff") : tile.dark ? "#29ffffff" : "#12000000"
                    Icon { anchors.centerIn: parent; width: 22; height: 22; name: tile.definition.icon || "control"; color: tile.active ? "white" : tile.panel.ink }
                }
                Column {
                    x: tile.small ? 4 : 55
                    y: tile.small ? 48 : (parent.height - height) / 2
                    width: parent.width - x - (tile.small ? 4 : 10)
                    spacing: 2
                    Text {
                        width: parent.width
                        text: tile.entry.id === "timer" && tile.panel.controls.timerRemaining > 0 ? tile.panel.timeLabel(tile.panel.controls.timerRemaining) : tile.definition.label || tile.entry.id
                        color: tile.panel.ink; font.pixelSize: tile.small ? 10 : 12; font.weight: Font.DemiBold
                        horizontalAlignment: tile.small ? Text.AlignHCenter : Text.AlignLeft
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        visible: !tile.small && text !== ""
                        text: tile.panel.captionFor(tile.entry.id)
                        color: tile.panel.muted; font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }
            }
        }

        Item {
            anchors.fill: parent
            visible: tile.sliderTile
            enabled: !tile.editing
            Text { x: 13; y: 9; text: tile.definition.label || ""; color: tile.panel.ink; font.pixelSize: 12; font.weight: Font.DemiBold }
            ControlActionButton {
                anchors.right: parent.right; anchors.rightMargin: 5; y: 1
                text: "Show " + tile.definition.label + " details"; symbol: "chevron"; dark: tile.dark
                onClicked: tile.panel.showDetail(tile.entry.id)
            }
            ControlSlider {
                x: 11; y: parent.height - height - 10; width: parent.width - 22
                objectName: "controlSlider_" + tile.entry.id
                dark: tile.dark
                symbol: tile.entry.id === "sound" ? "speaker" : "sun"
                enabled: tile.entry.id !== "keyboardbrightness"
                Accessible.name: tile.entry.id === "sound" ? "Music volume" : "Desktop brightness"
                value: tile.entry.id === "sound" ? (tile.panel.soundMuted ? 0 : tile.panel.volume) : tile.panel.brightness
                onMoved: tile.panel.changeLevel(tile.entry.id, value)
            }
        }

        Item {
            anchors.fill: parent
            visible: tile.mediaTile
            enabled: !tile.editing
            Image { x: 11; y: 11; width: 36; height: 36; source: Bridge.assetRoot + "music.png"; smooth: true }
            Text {
                x: 55; y: 13; width: parent.width - 65
                text: tile.panel.controls.nowPlaying.title || "Not Playing"
                color: tile.panel.ink; font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight
            }
            Text { x: 55; y: 31; width: parent.width - 65; text: "Music"; color: tile.panel.muted; font.pixelSize: 10 }
            MouseArea { x: 0; y: 0; width: parent.width; height: 48; onClicked: tile.panel.openMusic(); Accessible.role: Accessible.Button; Accessible.name: "Open Music"; Accessible.onPressAction: tile.panel.openMusic() }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height - 34; spacing: tile.entry.size === "large" ? 19 : 3
                ControlActionButton { text: "Previous Track"; symbol: "previous"; dark: tile.dark; enabled: tile.panel.controls.nowPlaying.available; onClicked: tile.panel.controls.mediaCommand("previous") }
                ControlActionButton { text: tile.panel.controls.nowPlaying.playing ? "Pause" : "Play"; symbol: tile.panel.controls.nowPlaying.playing ? "pause" : "play"; dark: tile.dark; enabled: tile.panel.controls.nowPlaying.available; onClicked: tile.panel.controls.mediaCommand("playPause") }
                ControlActionButton { text: "Next Track"; symbol: "next"; dark: tile.dark; enabled: tile.panel.controls.nowPlaying.available; onClicked: tile.panel.controls.mediaCommand("next") }
            }
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            enabled: tile.editing
            z: 4
            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            drag.target: card
            drag.threshold: 8
            drag.smoothed: false
            onPressed: { tile.panel.selectedControl = tile.entry.id; tile.forceActiveFocus(); }
            onReleased: {
                let position = card.mapToItem(tile.panel.gridItem, card.width / 2, card.height / 2);
                let moved = Math.abs(card.x) + Math.abs(card.y) > 8;
                let owner = tile.panel, id = tile.entry.id;
                card.x = 0; card.y = 0;
                // The persisted model replaces Repeater delegates; wait until
                // this pointer release has returned before changing that model.
                if (moved) Qt.callLater(function() { owner.dropControl(id, position); });
            }
            onCanceled: { card.x = 0; card.y = 0; }
        }
        ControlActionButton {
            objectName: "controlRemove_" + tile.entry.id
            visible: tile.editing; z: 5
            x: -4; y: -5; width: 24; height: 24
            text: "Remove " + tile.definition.label; symbol: "close"; dark: tile.dark; filled: true
            onClicked: tile.panel.controls.removeControl(tile.entry.id)
        }
        ControlActionButton {
            objectName: "controlResize_" + tile.entry.id
            visible: tile.editing && tile.definition.sizes && tile.definition.sizes.length > 1; z: 5
            anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.rightMargin: 3; anchors.bottomMargin: 3
            width: 27; height: 27; text: "Resize " + tile.definition.label; symbol: "more"; dark: tile.dark; filled: true
            onClicked: tile.panel.cycleSize(tile.entry.id, tile.entry.size)
        }
        MouseArea {
            objectName: "controlContext_" + tile.entry.id
            anchors.fill: parent
            z: 6
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: function(mouse) {
                if (mouse.button !== Qt.RightButton && !(mouse.modifiers & (Qt.ControlModifier | Qt.MetaModifier))) mouse.accepted = false;
            }
            onClicked: tile.panel.showTileMenu(tile.entry.id, tile)
            Accessible.ignored: true
        }
    }
}
