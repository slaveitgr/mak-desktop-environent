import QtQml

QtObject {
    id: state
    objectName: "fullscreenState"
    property real viewportWidth: 1360
    property real viewportHeight: 850
    property var window: null
    readonly property bool active: window !== null
    property bool chromeVisible: false
    property bool alwaysShowChrome: false
    onAlwaysShowChromeChanged: updateChrome()
    property bool dockVisible: false
    property bool pointerAtTop: false
    property bool pointerInChrome: false
    property bool menuOpen: false
    property bool pointerAtBottom: false
    property bool pointerInDock: false
    // A window's x/y/width/height expose the interpolated position while its
    // exit animation is running. Retain the intended destination briefly so
    // a second fullscreen request does not replace its normal window bounds.
    property var pendingRestores: []
    property Timer restoreCleanup: Timer {
        interval: 60
        repeat: true
        running: state.pendingRestores.length > 0
        onTriggered: state.pruneRestores()
    }
    onViewportWidthChanged: fit()
    onViewportHeightChanged: fit()
    onPointerAtTopChanged: {
        if (pointerAtTop && active)
            chromeVisible = true;
        updateChrome();
    }
    onPointerInChromeChanged: updateChrome()
    onMenuOpenChanged: updateChrome()
    onPointerAtBottomChanged: {
        if (pointerAtBottom && active)
            dockDelay.restart();
        else
            dockDelay.stop();
        updateDock();
    }
    onPointerInDockChanged: updateDock()
    property Timer chromeDelay: Timer {
        interval: 350
        onTriggered: if (!state.alwaysShowChrome)
            state.chromeVisible = false
    }
    property Timer dockDelay: Timer {
        interval: 180
        onTriggered: state.dockVisible = true
    }
    property Timer dockHideDelay: Timer {
        interval: 350
        onTriggered: state.dockVisible = false
    }
    function updateChrome() {
        if (active && alwaysShowChrome)
            chromeVisible = true;
        if (!active || alwaysShowChrome || pointerAtTop || pointerInChrome || menuOpen)
            chromeDelay.stop();
        else if (chromeVisible)
            chromeDelay.restart();
    }
    function updateDock() {
        if (!active || pointerAtBottom || pointerInDock)
            dockHideDelay.stop();
        else if (dockVisible)
            dockHideDelay.restart();
    }
    function fit() {
        if (window)
            window.animateGeometry(0, 0, viewportWidth, viewportHeight, 420);
    }
    function restorePending(entry) {
        let target = entry.target;
        if (!target || Date.now() >= entry.expires)
            return false;
        // Real desktop windows explicitly stop their geometry animation when
        // dragged. Lightweight targets need only implement animateGeometry.
        if (target.closing || target.geometryAnimating === false)
            return false;
        let rect = entry.geometry;
        return Math.abs(target.x - rect.x) > 0.01 || Math.abs(target.y - rect.y) > 0.01 || Math.abs(target.width - rect.width) > 0.01 || Math.abs(target.height - rect.height) > 0.01;
    }
    function pruneRestores() {
        pendingRestores = pendingRestores.filter(entry => restorePending(entry));
    }
    function enter(target) {
        if (!target || target === window)
            return;
        if (window)
            exit();
        pruneRestores();
        let pending = pendingRestores.find(entry => entry.target === target);
        target.fullscreenRestoreGeometry = pending ? pending.geometry : Qt.rect(target.x, target.y, target.width, target.height);
        target.fullscreenViewport = pending ? pending.viewport : Qt.size(viewportWidth, viewportHeight);
        pendingRestores = pendingRestores.filter(entry => entry.target !== target);
        window = target;
        target.isFullscreen = true;
        chromeVisible = alwaysShowChrome;
        dockVisible = false;
        fit();
    }
    function exit() {
        if (!window)
            return;
        let target = window;
        let rect = target.fullscreenRestoreGeometry;
        let resized = target.fullscreenViewport.width !== viewportWidth || target.fullscreenViewport.height !== viewportHeight;
        let width = resized ? Math.min(rect.width, viewportWidth - 24) : rect.width;
        let height = resized ? Math.min(rect.height, viewportHeight - 100) : rect.height;
        let x = resized ? Math.max(0, Math.min(rect.x, viewportWidth - width)) : rect.x;
        let y = resized ? Math.max(30, Math.min(rect.y, viewportHeight - height - 80)) : rect.y;
        target.isFullscreen = false;
        window = null;
        chromeDelay.stop();
        dockDelay.stop();
        dockHideDelay.stop();
        chromeVisible = false;
        dockVisible = false;
        target.animateGeometry(x, y, width, height, 420);
        // Bound both retention time and entry count, including windows closed
        // during a transition. No extra interface is required on the target.
        let pending = pendingRestores.filter(entry => entry.target !== target && restorePending(entry));
        pending.push({
            target: target,
            geometry: Qt.rect(x, y, width, height),
            viewport: Qt.size(viewportWidth, viewportHeight),
            expires: Date.now() + 460
        });
        pendingRestores = pending.slice(-64);
        pruneRestores();
    }
    function toggle(target) {
        if (window === target && target)
            exit();
        else
            enter(target);
    }
}
