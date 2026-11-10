import QtQuick
import QtQuick.Controls
import QtQuick.Effects

FocusScope {
    id: win
    property var nativeWindow: null
    readonly property bool compositorGlass: !!(nativeWindow && nativeWindow.compositorGlass)
    readonly property bool nativeCutefish: desktop.cutefishMode && !!nativeWindow
    readonly property bool chromeRevealed: nativeCutefish ? nativeWindow.compositorReveal > 0 : desktop.presentation.chromeVisible
    property var nativeSnapshot: null
    property url nativeThumbnail: ""
    required property var desktop
    property string appKind: "settings"
    property string windowTitle: "System Settings"
    property var browser: null
    property var selected: []
    property bool searchFocused: false
    readonly property bool dark: desktop.dark
    readonly property bool active: nativeWindow ? nativeWindow.active : desktop.shellActive && desktop.activeWindow === win
    readonly property color ink: dark ? "#f0f1f2" : "#242629"
    readonly property color muted: dark ? "#a7aaae" : "#777a80"
    property int sidebarWidth: 222
    property int minimumWindowWidth: 600
    property int minimumWindowHeight: 420
    property bool minimized: false
    property bool appHidden: false
    property bool closing: false
    property bool zoomed: false
    property bool isFullscreen: false
    property bool geometryAnimating: false
    property int geometryDuration: 280
    property real appearanceProgress: 0
    property real minimizeProgress: minimized ? 1 : 0
    property rect minimizeTarget: Qt.rect(600, 760, 52, 43)
    property rect savedGeometry: Qt.rect(0, 0, 0, 0)
    property rect fullscreenRestoreGeometry: Qt.rect(0, 0, 0, 0)
    property size fullscreenViewport: Qt.size(0, 0)
    property real chromeOffset: isFullscreen ? (nativeCutefish ? nativeWindow.compositorReveal : desktop.presentation.chromeVisible ? 30 : 0) : 0
    property alias surfaceItem: surface
    property alias clientItem: client
    width: 720
    height: 680
    visible: nativeWindow ? !appHidden : !appHidden && (!minimized || minimizeProgress < 0.999) && (!desktop.presentation.active || desktop.presentation.window === win)
    enabled: !closing && !minimized && !appHidden
    opacity: nativeCutefish ? 1 : closing ? 0 : appearanceProgress
    scale: nativeCutefish ? 1 : 0.965 + 0.035 * appearanceProgress
    Behavior on opacity {
        NumberAnimation {
            duration: desktop.reduceMotion ? 0 : 140
        }
    }
    Behavior on appearanceProgress {
        NumberAnimation {
            duration: desktop.reduceMotion ? 0 : 220
            easing.type: Easing.OutCubic
        }
    }
    Behavior on minimizeProgress {
        NumberAnimation {
            duration: desktop.reduceMotion ? 0 : 560
            easing.type: Easing.InOutCubic
        }
    }
    Behavior on chromeOffset {
        NumberAnimation {
            duration: desktop.reduceMotion ? 0 : 180
            easing.type: Easing.OutCubic
        }
    }
    Behavior on x {
        enabled: win.geometryAnimating
        NumberAnimation {
            duration: desktop.reduceMotion ? 0 : win.geometryDuration
            easing.type: Easing.InOutCubic
        }
    }
    Behavior on y {
        enabled: win.geometryAnimating
        NumberAnimation {
            duration: desktop.reduceMotion ? 0 : win.geometryDuration
            easing.type: Easing.InOutCubic
        }
    }
    Behavior on width {
        enabled: win.geometryAnimating
        NumberAnimation {
            duration: desktop.reduceMotion ? 0 : win.geometryDuration
            easing.type: Easing.InOutCubic
        }
    }
    Behavior on height {
        enabled: win.geometryAnimating
        NumberAnimation {
            duration: desktop.reduceMotion ? 0 : win.geometryDuration
            easing.type: Easing.InOutCubic
        }
    }
    onXChanged: if (desktop) desktop.motionTick++
    onYChanged: if (desktop) desktop.motionTick++
    onWidthChanged: if (desktop) desktop.motionTick++
    onHeightChanged: if (desktop) desktop.motionTick++
    Component.onCompleted: Qt.callLater(function () {
        win.appearanceProgress = 1;
    })
    TapHandler {
        onPressedChanged: if (pressed)
            desktop.focusWindow(win, true)
    }
    function activate() {
        desktop.focusWindow(win);
    }
    function animateGeometry(px, py, w, h, duration) {
        if (nativeWindow) {
            if (!isFullscreen) { nativeWindow.x = px; nativeWindow.y = py; nativeWindow.width = w; nativeWindow.height = h; }
            return;
        }
        geometryDuration = duration;
        geometryAnimating = true;
        x = px;
        y = py;
        width = w;
        height = h;
        geometryTimer.restart();
    }
    function zoom() {
        if (nativeWindow) {
            if (zoomed) nativeWindow.showNormal(); else nativeWindow.showMaximized();
            zoomed = !zoomed;
            return;
        }
        if (isFullscreen)
            desktop.presentation.exit();
        if (!zoomed) {
            savedGeometry = Qt.rect(x, y, width, height);
            animateGeometry(12, 38, desktop.width - 24, desktop.height - 138, 280);
        } else
            animateGeometry(savedGeometry.x, savedGeometry.y, savedGeometry.width, savedGeometry.height, 280);
        zoomed = !zoomed;
        activate();
    }
    Timer {
        id: geometryTimer
        interval: win.geometryDuration + 20
        onTriggered: win.geometryAnimating = false
    }
    Timer {
        running: win.closing
        interval: win.nativeCutefish || desktop.reduceMotion ? 1 : 150
        onTriggered: desktop.destroyWindow(win)
    }
    WindowBackdrop {
        id: underlay
        desktop: win.desktop
        owner: win
    }
    Item {
        id: surface
        y: win.chromeOffset
        width: win.width
        height: win.height - y
        Rectangle {
            id: shadow
            anchors.fill: parent
            radius: win.isFullscreen ? 0 : 25
            color: "black"
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            anchors.fill: shadow
            source: shadow
            shadowEnabled: !win.nativeCutefish && !win.isFullscreen
            shadowColor: win.active ? "#65000000" : "#37000000"
            shadowBlur: 1
            shadowVerticalOffset: 14
            blurMax: 48
        }
        Rectangle {
            anchors.fill: parent
            radius: win.isFullscreen ? 0 : 25
            color: win.compositorGlass ? "transparent" : (win.dark ? "#242b2e" : "#f6f6f7")
            border.width: win.isFullscreen ? 0 : 1
            border.color: win.dark ? "#596068" : "#b8bdc4"
        }
        Rectangle {
            visible: win.compositorGlass
            x: win.sidebarWidth + 8
            width: parent.width - x
            height: parent.height
            color: win.dark ? "#242b2e" : "#f6f6f7"
        }
        Glass {
            visible: !win.compositorGlass && win.sidebarWidth > 0 && win.active && desktop.wallpaperTint
            x: 8
            y: 8
            width: Math.max(0, win.sidebarWidth - 8)
            height: parent.height - 16
            backdrop: underlay
            sampleX: (win.nativeWindow ? win.nativeWindow.x : win.x) + x
            sampleY: (win.nativeWindow ? win.nativeWindow.y : win.y) + surface.y + y
            corner: 19
            dark: win.dark
            tint: desktop.glassTinted ? 0.98 : win.dark ? 0.94 : 0.84
            frost: 0.9
            refraction: 4
            reducedTransparency: desktop.reduceTransparency
        }
        MouseArea {
            anchors.fill: parent
            onPressed: win.activate()
        }
        Item {
            id: client
            anchors.fill: parent
        }
        MouseArea {
            x: 0
            y: 0
            width: win.sidebarWidth > 0 ? win.sidebarWidth : win.width
            height: 50
            property point start
            property point original
            onPressed: function (mouse) {
                win.activate();
                win.geometryAnimating = false;
                if (win.nativeWindow) { win.nativeWindow.startSystemMove(); return; }
                start = mapToItem(desktop, mouse.x, mouse.y);
                original = Qt.point(win.x, win.y);
            }
            onPositionChanged: function (mouse) {
                if (win.nativeWindow || !pressed || win.isFullscreen || win.zoomed)
                    return;
                let p = mapToItem(desktop, mouse.x, mouse.y);
                win.x = Math.max(-win.width + 200, Math.min(desktop.width - 160, original.x + p.x - start.x));
                win.y = Math.max(30, Math.min(desktop.height - 130, original.y + p.y - start.y));
            }
            onDoubleClicked: if (!win.isFullscreen)
                win.zoom()
        }
        Row {
            x: 18
            y: 18
            spacing: 8
            visible: !win.isFullscreen || win.chromeRevealed
            Repeater {
                model: ["#ff5f57", "#febc2e", "#28c840"]
                delegate: Rectangle {
                    required property string modelData
                    required property int index
                    width: 13
                    height: 13
                    radius: 6.5
                    color: (win.active || mouse.containsMouse) && !(index === 1 && win.isFullscreen) ? modelData : win.dark ? "#596065" : "#c4c8cd"
                    border.width: 0.6
                    border.color: Qt.darker(color, 1.12)
                    Text {
                        anchors.centerIn: parent
                        visible: mouse.containsMouse
                        text: index === 0 ? "×" : index === 1 ? "−" : win.isFullscreen ? "↙" : "↗"
                        color: "#60000000"
                        font.pixelSize: 11
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        enabled: index !== 1 || !win.isFullscreen
                        Accessible.role: Accessible.Button
                        Accessible.name: index === 0 ? "Close " + win.windowTitle : index === 1 ? "Minimize " + win.windowTitle : win.isFullscreen ? "Exit Full Screen" : "Enter Full Screen"
                        onClicked: {
                            win.activate();
                            if (index === 0)
                                desktop.closeWindow(win);
                            else if (index === 1)
                                desktop.minimizeWindow(win);
                            else
                                desktop.presentation.toggle(win);
                        }
                        Accessible.onPressAction: clicked(null)
                    }
                }
            }
        }
        MouseArea {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: 18
            height: 18
            enabled: !win.isFullscreen
            cursorShape: Qt.SizeFDiagCursor
            property point start
            property size original
            onPressed: function (mouse) {
                win.activate();
                win.geometryAnimating = false;
                if (win.nativeWindow) { win.nativeWindow.startSystemResize(Qt.RightEdge | Qt.BottomEdge); return; }
                start = mapToItem(desktop, mouse.x, mouse.y);
                original = Qt.size(win.width, win.height);
            }
            onPositionChanged: function (mouse) {
                if (win.nativeWindow || !pressed)
                    return;
                let p = mapToItem(desktop, mouse.x, mouse.y);
                win.width = Math.max(win.minimumWindowWidth, Math.min(desktop.width - win.x, original.width + p.x - start.x));
                win.height = Math.max(win.minimumWindowHeight, Math.min(desktop.height - win.y - 10, original.height + p.y - start.y));
            }
        }
    }
    ShaderEffectSource {
        id: texture
        sourceItem: surface
        hideSource: !win.nativeWindow && win.minimizeProgress > 0
        live: !win.nativeWindow && win.minimizeProgress > 0
        visible: false
        smooth: true
    }
    ShaderEffect {
        anchors.fill: parent
        visible: !win.nativeWindow && win.minimizeProgress > 0
        property var source: texture
        property real progress: win.minimizeProgress
        property size windowSize: Qt.size(win.width, win.height)
        property rect destination: Qt.rect(win.minimizeTarget.x - win.x, win.minimizeTarget.y - win.y, win.minimizeTarget.width, win.minimizeTarget.height)
        mesh: GridMesh {
            resolution: Qt.size(32, 40)
        }
        vertexShader: "../shaders/genie.vert.qsb"
        fragmentShader: "../shaders/genie.frag.qsb"
    }
}
