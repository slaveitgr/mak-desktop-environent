import QtQuick
import QtQuick.Controls
import QtQuick.Window
import org.kde.layershell 1.0 as LayerShell

// Loaded only by --wayland-shell; requires an ABI-compatible LayerShellQt plugin.
// Desktop, menu bar and Dock are independent Wayland layer surfaces.
Main {
    id: shell
    layerShellMode: true
    width: Screen.width
    height: Screen.height
    minimumWidth: 1
    minimumHeight: 1
    LayerShell.Window.scope: "makos-desktop"
    LayerShell.Window.layer: LayerShell.Window.LayerBackground
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand

    ApplicationWindow {
        id: bar
        objectName: "makOSMenuBarSurface"
        transientParent: null
        visible: true
        color: "transparent"
        width: shell.width
        height: (shell.controller.presentation.active ? !shell.controller.presentation.chromeVisible : shell.controller.desktopMenuAutoHide && !shell.controller.menuBarRevealed) ? 2 : 30
        flags: Qt.Window | Qt.FramelessWindowHint
        LayerShell.Window.scope: "makos-menu-bar"
        LayerShell.Window.layer: LayerShell.Window.LayerOverlay
        LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
        LayerShell.Window.exclusionZone: shell.controller.presentation.active ? 0 : height
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
        HoverHandler {
            onHoveredChanged: {
                shell.controller.layerTopHovered = hovered;
                shell.controller.updateMenuBarVisibility();
            }
        }
    }

    ApplicationWindow {
        id: dockWindow
        objectName: "makOSDockSurface"
        transientParent: null
        visible: true
        color: "transparent"
        width: Math.ceil(shell.dockView.width + 64)
        height: (shell.controller.presentation.active ? !shell.controller.presentation.dockVisible : shell.controller.dockAutoHide && !shell.controller.dockRevealed) ? 2 : Math.ceil(shell.dockView.baseIconSize * 2 + 70)
        flags: Qt.Window | Qt.FramelessWindowHint
        LayerShell.Window.scope: "makos-dock"
        LayerShell.Window.layer: LayerShell.Window.LayerOverlay
        LayerShell.Window.anchors: LayerShell.Window.AnchorBottom
        LayerShell.Window.exclusionZone: shell.controller.presentation.active || shell.controller.dockAutoHide ? 0 : Math.ceil(shell.dockView.height + 18)
        LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand
        // Until compositor blur is connected, sample a same-scene wallpaper.
        Item {
            id: dockBackdrop
            x: -dockWindow.x
            y: -dockWindow.y
            width: shell.width
            height: shell.height
            visible: false
            Image {
                anchors.fill: parent
                source: Bridge.assetRoot + (shell.controller.wallpaperIsDark ? "wallpaper-dark.jpg" : "wallpaper-light.jpg")
                fillMode: Image.PreserveAspectCrop
            }
        }
        HoverHandler {
            onHoveredChanged: {
                shell.controller.layerBottomHovered = hovered;
                shell.controller.updateDockVisibility();
            }
        }
    }

    Component.onCompleted: {
        topbarView.parent = bar.contentItem;
        dockView.parent = dockWindow.contentItem;
        dockView.backdrop = dockBackdrop;
        controller.shellOverlay = bar.contentItem;
    }
    onShellClosing: { bar.close(); dockWindow.close(); }
}
