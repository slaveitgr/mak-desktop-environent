import QtQuick
import MakOS.Cutefish 1.0

Item {
    id: adapter
    property var host: null
    readonly property var view: host ? host.view : null
    readonly property bool glassReady: backend.active && backend.glassEnabled
    readonly property int revealOffset: backend.revealOffset
    readonly property int revealDuration: backend.revealDuration
    function refresh() {
        if (host && view) backend.menus = host.desktop.nativeMenuRows(view);
    }
    CutefishWindow {
        id: backend
        objectName: "makOSCutefishBridge"
        window: adapter.host
        dark: adapter.view ? adapter.view.dark : false
        glassEnabled: !!(adapter.view && adapter.view.active && adapter.host.desktop.wallpaperTint && !adapter.host.desktop.reduceTransparency &&
                         (adapter.view.appKind === "finder" ? adapter.view.sidebarVisible : adapter.view.sidebarWidth > 0))
        glassRect: Qt.rect(8, 8 + (adapter.view ? Math.round(adapter.view.chromeOffset) : 0),
                          adapter.view ? (adapter.view.appKind === "finder" ? adapter.view.sideWidth : adapter.view.sidebarWidth - 8) : 0,
                          adapter.host && adapter.view ? Math.max(0, adapter.host.height - 16 - Math.round(adapter.view.chromeOffset)) : 0)
        onRefreshRequested: adapter.refresh()
        onCommandTriggered: function(command) {
            if (!adapter.view || adapter.view.closing) return;
            adapter.host.desktop.activeWindow = adapter.view;
            adapter.host.desktop.dispatch(command);
            adapter.refresh();
        }
    }
    onViewChanged: refresh()
    // Binding cannot track properties read inside all JS menu-provider helpers.
    // Refresh before opening plus a bounded revision check keeps enable/check
    // states accurate while a menu stays open. Identical JSON causes no traffic.
    Timer { interval: 200; running: !!adapter.view; repeat: true; onTriggered: adapter.refresh() }
}
