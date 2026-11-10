import QtQuick
import QtQuick.Controls

Item {
    id: dock
    required property var desktop
    required property Item backdrop
    property bool compositorGlass: false
    readonly property var minimizedWindows: desktop.dockWindows.filter(w => w.minimized && !w.closing)
    property var entries: []
    onMinimizedWindowsChanged: rebuildEntries()
    Component.onCompleted: rebuildEntries()
    Connections {
        target: Bridge
        function onStateChanged() {
            dock.rebuildEntries();
        }
    }
    Connections { target: Bridge.suite; function onChanged(){dock.rebuildEntries();} }
    function rebuildEntries() {
        let apps = [
            {
                name: "Finder",
                image: "finder.png",
                action: "finder"
            }
        ].concat(Bridge.applicationCatalog.filter(a=>a.id==="apps" || desktop.hiddenDockApps.indexOf(a.id)<0 || desktop.dockWindows.some(w=>w.appKind===a.id && !w.closing)).map(app => ({
                    name: app.label,
                    image: app.image,
                    action: "app:" + app.id
                }))).concat([
            {
                name: "System Settings",
                image: "settings.png",
                action: "settings"
            }
        ]);
        let next = apps.concat([
            {
                name: "Downloads",
                image: "downloads.png",
                action: "downloads"
            }
        ]).concat(minimizedWindows.map(w => ({
                    name: w.windowTitle,
                    window: w,
                    action: "restore"
                }))).concat([
            {
                name: "Trash",
                image: Bridge.trashCount > 0 ? "full-trash.png" : "trash.png",
                action: "trash"
            }
        ]);
        let previous = entries || [];
        // Keep running icon animations when ordinary Finder windows open/close.
        let same = previous.length === next.length && next.every((item, i) => item.action === previous[i].action && item.window === previous[i].window && item.name === previous[i].name && item.image === previous[i].image);
        if (!same)
            entries = next;
    }
    readonly property bool pointerInside: hoverSensor.hovered
    onPointerInsideChanged: desktop.updateDockVisibility()
    property real hoverPosition: -1000
    property int hoveredIndex: -1
    property bool tooltipReady: false
    readonly property int applicationCount: entries.filter(e=>e.action==="finder" || e.action==="settings" || e.action.startsWith("app:")).length
    readonly property real baseIconSize: Math.min(desktop.preferredDockSize, Math.max(24, (desktop.width - 100) / Math.max(1, entries.length) - 8))
    readonly property real pitch: baseIconSize + 8
    readonly property real restWidth: entries.length * pitch + 34
    width: iconRow.width + 24
    height: baseIconSize + 26
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    // The native compositor slides the entire Dock in fullscreen; applying a
    // second item slide would desynchronize its edge tracking and animation.
    anchors.bottomMargin: (desktop.presentation.active ? !desktop.externalShellMode && !desktop.presentation.dockVisible : desktop.dockAutoHide && !desktop.dockRevealed) ? -height - 45 : 9
    Behavior on anchors.bottomMargin {
        NumberAnimation {
            duration: desktop.reduceMotion ? 0 : 220
            easing.type: Easing.OutCubic
        }
    }

    function targetFor(window) {
        // Repeater creates the thumbnail immediately, but Row normally assigns
        // its x position on the next frame. Resolve the updated layout before
        // sampling it, otherwise a new thumbnail still appears at x == 0.
        rebuildEntries();
        iconRow.forceLayout();
        let at = entries.findIndex(e => e.window === window);
        let entry = at >= 0 ? dockEntries.itemAt(at) : null;
        if (entry) {
            let visual = entry.visualItem;
            // Map the entire thumbnail rectangle, including magnification and
            // the pressed icon's scale, rather than only transforming its origin.
            return visual.mapToItem(desktop, 0, visual.height * 0.145, visual.width, visual.height * 0.71);
        }
        let i = minimizedWindows.indexOf(window);
        let total = entries.length * pitch + 34;
        let size = baseIconSize;
        // A construction-time fallback still targets the distinct window slot
        // after Downloads, with the same proportions as its thumbnail.
        return Qt.rect((desktop.width - total) / 2 + 12 + (applicationCount + 1 + Math.max(0, i)) * pitch + 10 + 4, dock.y + iconRow.y + baseIconSize + 6 - size * 0.855, size, size * 0.71);
    }
    function amplitude(index) {
        if (desktop.reduceMotion || !desktop.dockMagnification || !hoverSensor.hovered)
            return 0;
        let center = (width - restWidth) / 2 + 12 + index * pitch + (index >= applicationCount ? 10 : 0) + pitch / 2;
        let distance = (hoverPosition - center) / 70;
        return Math.exp(-distance * distance * 1.4);
    }
    Item {
        x: -24
        y: -40
        width: dock.width + 48
        height: dock.height + 40
        HoverHandler {
            id: hoverSensor
            onPointChanged: dock.hoverPosition = point.position.x - 24
            onHoveredChanged: if (!hovered) {
                dock.hoveredIndex = -1;
                dock.tooltipReady = false;
                tooltipDelay.stop();
            }
        }
    }
    Timer {
        id: tooltipDelay
        interval: 300
        onTriggered: dock.tooltipReady = true
    }
    Glass {
        anchors.fill: parent
        visible: !dock.compositorGlass || desktop.reduceTransparency
        backdrop: dock.backdrop
        sampleX: dock.mapToItem(dock.backdrop, 0, 0).x
        sampleY: dock.mapToItem(dock.backdrop, 0, 0).y
        corner: 27
        dark: desktop.dark
        tint: desktop.glassTinted ? 0.65 : desktop.dark ? 0.18 : 0.14
        refraction: 9
        frost: 0.28
        shadowOpacity: 0.16
        reducedTransparency: desktop.reduceTransparency
    }
    Rectangle {
        anchors.fill: parent
        visible: dock.compositorGlass && !desktop.reduceTransparency
        radius: 27
        color: "transparent"
        border.width: 1
        border.color: desktop.dark ? "#42ffffff" : "#85ffffff"
    }
    Row {
        id: iconRow
        x: 12
        height: dock.baseIconSize + 16
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        spacing: 0
        Repeater {
            id: dockEntries
            model: dock.entries
            delegate: Item {
                id: entry
                required property var modelData
                required property int index
                property real bump: dock.amplitude(index)
                property real bounce: 0
                property bool isWindow: !!modelData.window
                property alias visualItem: visual
                property real iconSize: dock.baseIconSize + 24 * bump
                width: dock.pitch + 22 * bump + (index === dock.applicationCount - 1 ? 10 : 0)
                height: dock.baseIconSize + 16
                Behavior on bump {
                    NumberAnimation {
                        duration: desktop.reduceMotion ? 0 : 110
                        easing.type: Easing.OutCubic
                    }
                }
                Rectangle {
                    visible: entry.index === dock.applicationCount - 1
                    x: parent.width - 5
                    y: 15
                    width: 1
                    height: dock.baseIconSize - 11
                    color: desktop.dark ? "#42ffffff" : "#30000000"
                }
                Item {
                    id: visual
                    width: entry.iconSize
                    height: entry.iconSize
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: entry.index === dock.applicationCount - 1 ? -5 : 0
                    y: parent.height - height - 10 - entry.bounce
                    scale: iconMouse.pressed ? 0.94 : 1
                    Behavior on scale {
                        NumberAnimation {
                            duration: 90
                        }
                    }
                    Image {
                        anchors.fill: parent
                        source: entry.isWindow ? "" : Bridge.assetRoot + entry.modelData.image
                        fillMode: Image.PreserveAspectFit
                        visible: !entry.isWindow
                    }
                    Rectangle {
                        visible: entry.isWindow
                        anchors.centerIn: parent
                        width: parent.width
                        height: parent.height * 0.71
                        radius: 5
                        color: desktop.dark ? "#30343a" : "#f4f5f7"
                        border.color: "#70838a93"
                    }
                    ShaderEffectSource {
                        visible: entry.isWindow
                        anchors.centerIn: parent
                        width: parent.width - 2
                        height: parent.height * 0.71 - 2
                        sourceItem: entry.isWindow && !entry.modelData.window.nativeWindow ? entry.modelData.window.surfaceItem : null
                        live: false
                        smooth: true
                    }
                    Image {
                        visible: entry.isWindow && !!entry.modelData.window.nativeWindow
                        anchors.centerIn: parent
                        width: parent.width - 2
                        height: parent.height * 0.71 - 2
                        source: visible ? entry.modelData.window.nativeThumbnail : ""
                        fillMode: Image.PreserveAspectFit
                    }
                    Image {
                        visible: entry.isWindow
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        width: 24
                        height: 24
                        source: Bridge.assetRoot + (entry.isWindow ? (entry.modelData.window.appKind === "aboutmac" ? "settings.png" : entry.modelData.window.appKind + ".png") : "finder.png")
                    }
                }
                Rectangle {
                    width: 4
                    height: 4
                    radius: 2
                    x: (parent.width - width) / 2 - (entry.index === dock.applicationCount - 1 ? 5 : 0)
                    y: dock.baseIconSize + 11
                    visible: desktop.dockIndicators && desktop.dockWindows.some(w => !w.closing && (entry.modelData.action === w.appKind || entry.modelData.action === "app:" + w.appKind))
                    color: desktop.dark ? "#e6ffffff" : "#a6242930"
                }
                Glass {
                    opacity: dock.tooltipReady && dock.hoveredIndex === entry.index ? 1 : 0
                    visible: opacity > 0
                    scale: 0.96 + 0.04 * opacity
                    Behavior on opacity {
                        NumberAnimation {
                            duration: desktop.reduceMotion ? 0 : 110
                        }
                    }
                    x: (parent.width - width) / 2
                    y: visual.y - 38
                    width: tipLabel.implicitWidth + 22
                    height: 28
                    backdrop: dock.backdrop
                    sampleX: dock.x + iconRow.x + entry.x + x
                    sampleY: dock.y + iconRow.y + y
                    corner: 9
                    dark: desktop.dark
                    tint: desktop.dark ? 0.7 : 0.75
                    refraction: 3
                    shadowOpacity: 0.12
                    Text {
                        id: tipLabel
                        anchors.centerIn: parent
                        text: entry.modelData.name
                        font.pixelSize: 12
                        color: desktop.dark ? "#f4f4f5" : "#22262c"
                    }
                }
                MouseArea {
                    id: iconMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: {
                        dock.hoveredIndex = entry.index;
                        dock.tooltipReady = false;
                        tooltipDelay.restart();
                    }
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: function(mouse) {
                        if(mouse && mouse.button===Qt.RightButton){let p=entry.mapToItem(desktop,0,0);desktop.openDockMenu(entry.modelData,p.x,p.y);return;}
                        if (entry.isWindow) {
                            desktop.focusWindow(entry.modelData.window);
                        } else if (entry.modelData.action === "finder") {
                            if (!desktop.dockWindows.some(w => w.appKind === "finder" && !w.closing) && !desktop.reduceMotion && desktop.dockLaunchAnimation)
                                launchBounce.restart();
                            desktop.activateFinder();
                        } else if (entry.modelData.action === "settings") {
                            if (!desktop.dockWindows.some(w => w.appKind === "settings" && !w.closing) && !desktop.reduceMotion && desktop.dockLaunchAnimation)
                                launchBounce.restart();
                            desktop.openSettings("");
                        } else if (entry.modelData.action.startsWith("app:")) {
                            desktop.openApplication(entry.modelData.action.slice(4));
                            if (!desktop.reduceMotion && desktop.dockLaunchAnimation)
                                launchBounce.restart();
                        } else
                            desktop.openFolder(entry.modelData.action === "trash" ? ".Trash" : "Downloads");
                    }
                    Accessible.role: Accessible.Button
                    Accessible.name: entry.isWindow ? "Restore " + entry.modelData.name : entry.modelData.name + " in Dock"
                    Accessible.onPressAction: clicked(null)
                }
                DropArea {
                    anchors.fill: parent
                    keys: ["tahoe/files"]
                    enabled: entry.modelData.action === "trash" || entry.modelData.action === "downloads"
                    onDropped: function (drop) {
                        let paths = drop.source.paths.slice(), action = entry.modelData.action;
                        let copy = !!(drop.modifiers & Qt.AltModifier) || drop.proposedAction === Qt.CopyAction;
                        Qt.callLater(function() {
                            if (action === "trash") Bridge.trash(paths);
                            else Bridge.dropFiles(paths, "Downloads", copy);
                        });
                        drop.acceptProposedAction();
                    }
                }
                SequentialAnimation {
                    id: launchBounce
                    NumberAnimation {
                        target: entry
                        property: "bounce"
                        to: 18
                        duration: 170
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: entry
                        property: "bounce"
                        to: 0
                        duration: 180
                        easing.type: Easing.InQuad
                    }
                    NumberAnimation {
                        target: entry
                        property: "bounce"
                        to: 5
                        duration: 95
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: entry
                        property: "bounce"
                        to: 0
                        duration: 100
                        easing.type: Easing.InQuad
                    }
                }
            }
        }
    }
}
