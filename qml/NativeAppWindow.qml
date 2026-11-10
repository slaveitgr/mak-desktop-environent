import QtQuick
import QtQuick.Controls
import QtQuick.Window

// One platform window per application. The existing application view is reused
// inside it; the compositor owns movement, stacking and window transitions.
ApplicationWindow {
    id: host
    required property var desktop
    property var view: null
    property bool disposing: false
    readonly property bool compositorGlass: !!(cutefishBridge.item && cutefishBridge.item.glassReady)
    readonly property int compositorReveal: cutefishBridge.item ? cutefishBridge.item.revealOffset : 0
    readonly property int compositorRevealDuration: cutefishBridge.item ? cutefishBridge.item.revealDuration : 200
    Loader {
        id: cutefishBridge
        source: desktop.cutefishMode ? "CutefishWindowBridge.qml" : ""
        onLoaded: item.host = host
    }
    readonly property Item overlayItem: contentItem
    objectName: "makOSNativeWindow"
    transientParent: null
    flags: Qt.Window | Qt.FramelessWindowHint
    color: "transparent"
    title: view ? view.windowTitle : "makOS"
    minimumWidth: view && view.minimumWindowWidth !== undefined ? view.minimumWindowWidth : 600
    minimumHeight: view && view.minimumWindowHeight !== undefined ? view.minimumWindowHeight : 420
    palette: desktop.hostPalette

    function attach(item) {
        let position = item.mapToGlobal(0, 0);
        x = position.x; y = position.y;
        view = item;
        width = item.width; height = item.height;
        item.nativeWindow = host;
        item.parent = contentItem;
        item.x = 0; item.y = 0;
        item.width = Qt.binding(function() { return host.width; });
        item.height = Qt.binding(function() { return host.height; });
        show();
    }
    function activate() {
        if (!visible || visibility === Window.Minimized) {
            if (view && view.isFullscreen) showFullScreen(); else showNormal();
        }
        raise();
        requestActivate();
    }
    function minimize() {
        if (!view || view.closing) return;
        if (desktop.cutefishMode) { showMinimized(); return; }
        // A texture cannot be shared between QQuickWindows. Keep an image for
        // the Dock, capturing while the native client is still mapped.
        let captured = view.surfaceItem.grabToImage(function(result) {
            if (!host.view || host.disposing) return;
            host.view.nativeSnapshot = result;
            host.view.nativeThumbnail = result.url;
            if (host.view.minimized) host.showMinimized();
        }, Qt.size(300, 200));
        if (!captured) showMinimized();
    }
    onActiveChanged: {
        if (active && view && !view.closing) {
            desktop.activeWindow = view;
            view.z = ++desktop.highestZ;
        }
    }
    onVisibilityChanged: function(visibility) {
        if (!view || disposing) return;
        if (desktop.cutefishMode && visibility !== Window.Minimized && visibility !== Window.Hidden)
            view.isFullscreen = visibility === Window.FullScreen;
        let minimized = visibility === Window.Minimized;
        if (view.minimized !== minimized && visibility !== Window.Hidden) {
            view.minimized = minimized;
            desktop.windows = desktop.windows.slice();
        }
    }
    onClosing: function(event) {
        if (view && !disposing) {
            event.accepted = false;
            desktop.closeWindow(view);
        }
    }
    Connections {
        target: host.view
        function onAppHiddenChanged() {
            if (host.view.appHidden) host.hide(); else host.activate();
        }
        function onIsFullscreenChanged() {
            if (host.view.isFullscreen) host.showFullScreen(); else host.showNormal();
        }
    }
    HoverHandler {
        id: pointer
        onHoveredChanged: if (!hovered && host.view && host.view.isFullscreen) {
            desktop.nativeTopHovered = false;
            desktop.nativeChromeHovered = false;
        }
        onPointChanged: {
            if (host.view && host.view.isFullscreen) {
                desktop.nativeTopHovered = point.position.y <= 2;
                desktop.nativeChromeHovered = point.position.y <= 55;
            }
        }
    }
}
