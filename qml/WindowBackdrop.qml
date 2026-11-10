import QtQuick

// Acyclic composition: a Finder window can only sample windows below itself.
Item {
    id: backdrop
    required property var desktop
    required property var owner
    width: desktop.width
    height: desktop.height
    visible: false
    readonly property var lowerWindows: {
        let revision = desktop.highestZ;
        return desktop.windows.filter(w => w !== owner && w.z < owner.z && !w.minimized && !w.closing).sort((a, b) => a.z - b.z);
    }
    ShaderEffectSource {
        anchors.fill: parent
        sourceItem: backdrop.desktop.baseItem
        live: true
    }
    Repeater {
        model: backdrop.lowerWindows
        delegate: ShaderEffectSource {
            required property var modelData
            x: modelData.x
            y: modelData.y
            width: modelData.width
            height: modelData.height
            sourceItem: modelData
            live: true
            smooth: true
        }
    }
}
