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
    CutefishShellState { id: shellState }
    CutefishShellSurface { window: shell; role: 0 }

    ApplicationWindow {
        id: bar
        objectName: "makOSMenuBarSurface"
        transientParent: null
        visible: true
        color: "transparent"
        width: shell.width; height: 30
        flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
        title: "makOS Menu Bar"
        CutefishShellSurface {
            window: bar; role: 1; edge: 0; exclusiveZone: 30
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
        height: Math.ceil(shell.dockView.baseIconSize * 2 + 70)
        flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
        title: "makOS Dock"
        CutefishShellSurface {
            window: dockWindow; role: 2; edge: 1
            exclusiveZone: shell.controller.dockAutoHide ? 0 : Math.ceil(shell.dockView.height + 18)
            position: Qt.point(Screen.virtualX + Math.round((shell.width-dockWindow.width)/2), Screen.virtualY+shell.height-dockWindow.height)
        }
        Item {
            id: dockBackdrop
            x: -Math.round((shell.width-dockWindow.width)/2)
            y: -shell.height+dockWindow.height
            width:shell.width; height:shell.height; visible:false
            Image { anchors.fill:parent; source:Bridge.assetRoot+(shell.controller.wallpaperIsDark?"wallpaper-dark.jpg":"wallpaper-light.jpg"); fillMode:Image.PreserveAspectCrop }
        }
    }
    Component.onCompleted: {
        topbarView.parent=bar.contentItem;
        dockView.parent=dockWindow.contentItem;
        dockView.backdrop=dockBackdrop;
        controller.shellOverlay=bar.contentItem;
    }
    onShellClosing: { bar.close(); dockWindow.close(); }
}
