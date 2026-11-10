import QtQuick
import QtQuick.Controls
import QtQuick.Window
import MakOS.Cutefish 1.0

// Three real native surfaces. Only the trusted session connection can assign
// these roles; ordinary applications remain ordinary xdg_toplevel clients.
Main {
    id: shell
    layerShellMode: true
    width: Screen.width; height: Screen.height
    minimumWidth: 1; minimumHeight: 1
    title: "makOS Desktop"
    nativeShellState: shellState
    nativeOsd: osdWindow
    CutefishShellState { id: shellState }
    CutefishShellSurface { window: shell; role: 0 }

    ApplicationWindow {
        id: bar
        objectName: "makOSMenuBarSurface"
        transientParent: null
        visible: true
        color: "transparent"
        width: shell.width
        // Cutefish's DockLayoutManager owns fullscreen edge tracking and slides.
        // Keep its native surface/content intact; QML sensors handle only the
        // separate desktop auto-hide preference.
        readonly property bool revealed: shell.controller.presentation.active || !shell.controller.desktopMenuAutoHide || shell.controller.menuBarRevealed
        height: revealed || collapseDelay.running ? 30 : 2
        onRevealedChanged: { if (revealed) collapseDelay.stop(); else collapseDelay.restart(); }
        Timer { id: collapseDelay; interval: shell.controller.reduceMotion ? 0 : 180 }
        HoverHandler {
            onHoveredChanged: {
                shell.controller.layerTopHovered = hovered;
                shell.controller.updateMenuBarVisibility();
            }
        }
        flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
        title: "makOS Menu Bar"
        CutefishShellSurface {
            window: bar; role: 1; edge: 0
            exclusiveZone: shell.controller.presentation.active || shell.controller.desktopMenuAutoHide ? 0 : 30
            position: Qt.point(Screen.virtualX, Screen.virtualY)
        }
    }
    ApplicationWindow {
        id: dockWindow
        objectName: "makOSDockSurface"
        transientParent: null
        visible: true
        color: "transparent"
        width: Math.ceil(shell.dockView.width + 64)
        readonly property bool revealed: shell.controller.presentation.active || !shell.controller.dockAutoHide || shell.controller.dockRevealed
        height: revealed || dockCollapseDelay.running ? Math.ceil(shell.dockView.baseIconSize * 2 + 70) : 2
        onRevealedChanged: { if (revealed) dockCollapseDelay.stop(); else dockCollapseDelay.restart(); }
        Timer { id: dockCollapseDelay; interval: shell.controller.reduceMotion ? 0 : 220 }
        HoverHandler {
            onHoveredChanged: {
                shell.controller.layerBottomHovered = hovered;
                shell.controller.updateDockVisibility();
            }
        }
        flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
        title: "makOS Dock"
        CutefishShellSurface {
            window: dockWindow; role: 2; edge: 1
            exclusiveZone: shell.controller.presentation.active || shell.controller.dockAutoHide ? 0 : Math.ceil(shell.dockView.height + 18)
            position: Qt.point(Screen.virtualX + Math.round((shell.width-dockWindow.width)/2), Screen.virtualY+shell.height-dockWindow.height)
        }
        CutefishWindow {
            id: nativeDockGlass
            objectName: "makOSDockGlass"
            window: dockWindow
            glassRect: {
                // Track both the animated anchor position and magnified width.
                const x = shell.dockView.x, y = shell.dockView.y;
                const width = shell.dockView.width, height = shell.dockView.height;
                const parent = shell.dockView.parent;
                const r = parent ? parent.mapToItem(dockWindow.contentItem, x, y, width, height) : Qt.rect(x,y,width,height);
                return Qt.rect(Math.round(r.x), Math.round(r.y), Math.round(r.width), Math.round(r.height));
            }
            glassRadius: 27
            glassTint: shell.controller.glassTinted ? 0.65 : shell.controller.dark ? 0.18 : 0.14
            glassEnabled: !shell.controller.reduceTransparency
            dark: shell.controller.dark
            menus: "[]"
        }
        Item {
            id: dockBackdrop
            x: -Math.round((shell.width-dockWindow.width)/2)
            y: -shell.height+dockWindow.height
            width:shell.width; height:shell.height; visible:false
            Image { anchors.fill:parent; source:Bridge.assetRoot+(shell.controller.wallpaperIsDark?"wallpaper-dark.jpg":"wallpaper-light.jpg"); fillMode:Image.PreserveAspectCrop }
        }
    }
    ApplicationWindow {
        id: osdWindow
        objectName: "makOSLevelOSDSurface"
        transientParent: null
        visible: osdState.active
        color: "transparent"
        width: 290; height: 62
        flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus | Qt.WindowTransparentForInput
        title: "makOS Hardware Level"
        property alias kind: osdState.kind
        property alias label: osdState.label
        property alias value: osdState.value
        property alias muted: osdState.muted
        property alias levelAvailable: osdState.levelAvailable
        property alias dismissalInterval: osdState.dismissalInterval
        function present(kind,value,muted,label,available) { return osdState.present(kind,value,muted,label,available); }
        function dismiss() { osdState.dismiss(); }
        HardwareLevelState { id: osdState }
        CutefishShellSurface {
            window: osdWindow; role: 3; exclusiveZone: 0
            position: Qt.point(Screen.virtualX + Math.max(8, shell.width-osdWindow.width-28), Screen.virtualY+41)
        }
        CutefishWindow {
            id: nativeOSDGlass
            window: osdWindow
            glassRect: Qt.rect(0, 0, osdWindow.width, osdWindow.height)
            glassRadius: 31
            glassEnabled: !shell.controller.reduceTransparency
            dark: shell.controller.dark
            menus: "[]"
        }
        LevelOSDContent { anchors.fill:parent;level:osdState;desktop:shell.controller;compositorGlass:nativeOSDGlass.active }
    }
    Component.onCompleted: {
        topbarView.parent=bar.contentItem;
        dockView.parent=dockWindow.contentItem;
        dockView.backdrop=dockBackdrop;
        dockView.compositorGlass=Qt.binding(function(){return nativeDockGlass.active && !shell.controller.reduceTransparency;});
        controller.shellOverlay=bar.contentItem;
    }
    onShellClosing: { bar.close(); dockWindow.close(); osdWindow.dismiss(); }
}
