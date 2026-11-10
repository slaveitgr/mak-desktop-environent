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
        if (owner.nativeWindow) return [];
        return desktop.windows.filter(w => w !== owner && w.z < owner.z && !w.minimized && !w.closing).sort((a, b) => a.z - b.z);
    }
    ShaderEffectSource {
        anchors.fill: parent
        sourceItem: backdrop.owner.nativeWindow ? null : backdrop.desktop.baseItem
        live: true
    }
    Image {
        anchors.fill: parent
        visible: !!backdrop.owner.nativeWindow
        source: visible ? Bridge.assetRoot + (backdrop.desktop.wallpaperIsDark ? "wallpaper-dark.jpg" : "wallpaper-light.jpg") : ""
        fillMode: Image.PreserveAspectCrop
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
