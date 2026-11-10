import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

FocusScope {
    id: win
    property var nativeWindow: null
    readonly property bool compositorGlass: !!(nativeWindow && nativeWindow.compositorGlass)
    readonly property bool nativeCutefish: desktop.cutefishMode && !!nativeWindow
    readonly property bool chromeRevealed: nativeCutefish ? nativeWindow.compositorReveal > 0 : desktop.presentation.chromeVisible
    property var nativeSnapshot: null
    property url nativeThumbnail: ""
    readonly property int minimumWindowWidth: 660
    readonly property int minimumWindowHeight: 390
    required property var desktop
    required property var browser
    readonly property string appKind: "finder"
    readonly property string windowTitle: browser.title
    property bool dark: desktop.dark
    property bool active: nativeWindow ? nativeWindow.active : desktop.shellActive && desktop.activeWindow === win
    property bool minimized: false
    property bool appHidden: false
    property bool zoomed: false
    property bool isFullscreen: false
    property rect fullscreenRestoreGeometry: Qt.rect(0, 0, 940, 570)
    property size fullscreenViewport: Qt.size(0, 0)
    property int geometryDuration: 280
    property real chromeOffset: isFullscreen ? (nativeCutefish ? nativeWindow.compositorReveal : desktop.presentation.chromeVisible ? 30 : 0) : 0
    Behavior on chromeOffset {
        NumberAnimation {
            duration: desktop.reduceMotion ? 0 : win.nativeCutefish ? win.nativeWindow.compositorRevealDuration : 180
            easing.type: Easing.OutCubic
        }
    }
    property bool closing: false
    property bool geometryAnimating: false
    property real appearanceProgress: 0
    property real minimizeProgress: minimized ? 1 : 0
    property rect minimizeTarget: Qt.rect(600, 760, 52, 43)
    property alias surfaceItem: surface
    property rect savedGeometry: Qt.rect(0, 0, 0, 0)
    property string viewMode: "icons"
    property bool sidebarVisible: true
    property bool pathbarVisible: false
    property var selected: []
    property int anchorIndex: -1
    property int focusedIndex: -1
    property var columns: []
    property string typeBuffer: ""
    readonly property bool searchFocused: searchBox.activeFocus
    readonly property color ink: dark ? "#f0f2f4" : "#282c32"
    readonly property color muted: dark ? "#9ba3ab" : "#787d85"
    readonly property int sideWidth: sidebarVisible ? 222 : 0
    readonly property real sidebarRowHeight: desktop.sidebarIconSize === "small" ? 28 : desktop.sidebarIconSize === "large" ? 36 : 32
    readonly property real sidebarSymbolSize: desktop.sidebarIconSize === "small" ? 20 : desktop.sidebarIconSize === "large" ? 28 : 24
    width: 940
    height: 570
    opacity: nativeCutefish ? 1 : closing ? 0 : appearanceProgress
    scale: nativeCutefish ? 1 : 0.965 + 0.035 * appearanceProgress
    visible: nativeWindow ? !appHidden : !appHidden && (!minimized || minimizeProgress < 0.999) && (!desktop.presentation.active || desktop.presentation.window === win)
    enabled: !closing && !minimized && !appHidden
    transformOrigin: Item.Center
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
    onXChanged: desktop.motionTick++
    onYChanged: desktop.motionTick++
    onWidthChanged: desktop.motionTick++
    onHeightChanged: desktop.motionTick++
    onViewModeChanged: {
        resetColumns();
        fileArea.forceActiveFocus();
    }
    Component.onCompleted: {
        resetColumns();
        Qt.callLater(function () {
            win.appearanceProgress = 1;
        });
    }

    function activate() {
        desktop.focusWindow(win);
        fileArea.forceActiveFocus();
    }
    function resetColumns() {
        columns = [
            {
                path: browser.currentPath,
                entries: browser.files
            }
        ];
    }
    function go(path) {
        browser.navigate(path);
    }
    function selectItem(index, modifiers, entries) {
        activate();
        const files = entries || browser.files;
        if (index < 0 || index >= files.length)
            return;
        const path = files[index].path;
        if ((modifiers & Qt.ShiftModifier) && anchorIndex >= 0 && !entries) {
            let all = [];
            for (let i = Math.min(anchorIndex, index); i <= Math.max(anchorIndex, index); i++)
                all.push(files[i].path);
            selected = all;
        } else if (modifiers & (Qt.ControlModifier | Qt.MetaModifier)) {
            let next = selected.slice();
            let at = next.indexOf(path);
            if (at >= 0)
                next.splice(at, 1);
            else
                next.push(path);
            selected = next;
            anchorIndex = index;
        } else {
            selected = [path];
            anchorIndex = index;
        }
        focusedIndex = index;
    }
    function selectedItem() {
        const entries = browser.files;
        for (let i = 0; i < entries.length; i++)
            if (entries[i].path === selected[0])
                return entries[i];
        for (let col of columns)
            for (let item of col.entries)
                if (item.path === selected[0])
                    return item;
        return null;
    }
    function openItem(item) {
        if (!item)
            return;
        if (item.appId)
            desktop.openApplication(item.appId);
        else if (item.isDir)
            go(item.path);
        else
            desktop.showPreview(item.path);
    }
    function selectAll() {
        selected = browser.files.map(f => f.path);
    }
    function renameSelection() {
        let item = selectedItem();
        if (!item || browser.isTrash || browser.currentPath === "@applications")
            return;
        desktop.prompt("Rename", "Choose a new name for this item.", item.name, function (value) {
            let result = Bridge.rename(item.path, value);
            if (result)
                selected = [result];
        });
    }
    function newFolder() {
        if (browser.isTrash || browser.currentPath.startsWith("@"))
            return;
        desktop.prompt("New Folder", "Enter a name for the new folder.", "untitled folder", function (value) {
            let result = Bridge.newFolder(browser.currentPath, value);
            if (result)
                selected = [result];
        });
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
    function toggleFullscreen() {
        activate();
        desktop.presentation.toggle(win);
    }
    function zoom() {
        if (nativeWindow) {
            if (zoomed) nativeWindow.showNormal(); else nativeWindow.showMaximized();
            zoomed = !zoomed;
            return;
        }
        if (isFullscreen)
            desktop.presentation.exit();
        geometryDuration = 280;
        geometryAnimating = true;
        geometryTimer.restart();
        if (!zoomed) {
            savedGeometry = Qt.rect(x, y, width, height);
            x = 12;
            y = 38;
            width = desktop.width - 24;
            height = desktop.height - 138;
        } else {
            x = savedGeometry.x;
            y = savedGeometry.y;
            width = savedGeometry.width;
            height = savedGeometry.height;
        }
        zoomed = !zoomed;
        activate();
    }
    function showContext(px, py, item) {
        if (item && selected.indexOf(item.path) < 0)
            selected = [item.path];
        let p = win.mapToItem(desktop, px, py);
        desktop.openContext(p.x, p.y, win);
    }
    function previewStep(direction) {
        let idx = browser.files.findIndex(f => f.path === selected[0]);
        idx = Math.max(0, Math.min(browser.files.length - 1, idx + direction));
        if (idx >= 0 && browser.files[idx]) {
            selected = [browser.files[idx].path];
            desktop.showPreview(selected[0]);
        }
    }
    Connections {
        target: win.browser
        function onLocationChanged() {
            win.selected = [];
            win.focusedIndex = -1;
            win.anchorIndex = -1;
            searchBox.text = "";
            win.resetColumns();
        }
        function onChanged() {
            if (win.viewMode === "columns")
                win.resetColumns();
            let paths = win.browser.files.map(item => item.path);
            win.selected = win.selected.filter(path => paths.indexOf(path) >= 0);
        }
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
            id: shadowShape
            anchors.fill: parent
            radius: win.isFullscreen ? 0 : 25
            color: "black"
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            anchors.fill: shadowShape
            source: shadowShape
            shadowEnabled: !win.nativeCutefish && !win.isFullscreen
            shadowColor: win.active ? "#65000000" : "#37000000"
            shadowBlur: 1
            shadowVerticalOffset: 14
            shadowHorizontalOffset: 0
            blurMax: 48
            shadowScale: 1
        }
        Rectangle {
            visible: !win.compositorGlass
            anchors.fill: parent
            radius: win.isFullscreen ? 0 : 25
            color: win.dark ? "#242b2e" : "#fcfcfd"
            border.color: win.dark ? "#596068" : "#b8bdc4"
            border.width: win.isFullscreen ? 0 : 1
        }
        CompositorGlassFrame {
            visible: win.compositorGlass
            anchors.fill: parent
            bodyColor: win.dark ? "#242b2e" : "#fcfcfd"
            borderColor: win.dark ? "#596068" : "#b8bdc4"
            borderWidth: win.isFullscreen ? 0 : 1
            corner: win.isFullscreen ? 0 : 25
            glassRect: Qt.rect(8, 8, win.sideWidth, Math.max(0, height - 16))
        }
        Glass {
            visible: !win.compositorGlass && win.sidebarVisible && win.active && desktop.wallpaperTint
            x: 8
            y: 8
            width: win.sideWidth
            height: surface.height - 16
            backdrop: underlay
            sampleX: (win.nativeWindow ? win.nativeWindow.x : win.x) + x
            sampleY: (win.nativeWindow ? win.nativeWindow.y : win.y) + surface.y + y
            corner: 19
            dark: win.dark
            tint: desktop.glassTinted ? 0.97 : win.dark ? 0.93 : 0.82
            refraction: 4
            frost: 0.9
            reducedTransparency: desktop.reduceTransparency
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: win.activate()
        }

        Item {
            id: titlebar
            x: 8
            y: 8
            width: win.width - 16
            height: 42
            MouseArea {
                anchors.fill: parent
                preventStealing: true
                property point pressPosition
                property point originalPosition
                onPressed: function (mouse) {
                    win.geometryAnimating = false;
                    win.activate();
                    if (win.nativeWindow) { win.nativeWindow.startSystemMove(); return; }
                    pressPosition = mapToItem(desktop, mouse.x, mouse.y);
                    originalPosition = Qt.point(win.x, win.y);
                }
                onPositionChanged: function (mouse) {
                    if (win.nativeWindow || !pressed || win.zoomed || win.isFullscreen)
                        return;
                    let p = mapToItem(desktop, mouse.x, mouse.y);
                    win.x = Math.max(-win.width + 200, Math.min(desktop.width - 160, originalPosition.x + p.x - pressPosition.x));
                    win.y = Math.max(30, Math.min(desktop.height - 130, originalPosition.y + p.y - pressPosition.y));
                }
                onDoubleClicked: if (!win.isFullscreen)
                    win.zoom()
            }
            Row {
                id: lights
                visible: !win.isFullscreen || win.chromeRevealed
                x: 10
                y: 10
                spacing: 8
                Repeater {
                    model: ["#ff5f57", "#febc2e", "#28c840"]
                    delegate: Rectangle {
                        required property string modelData
                        required property int index
                        width: 13
                        height: 13
                        radius: 6.5
                        color: (win.active || lightMouse.containsMouse) && !(index === 1 && win.isFullscreen) ? modelData : win.dark ? "#596065" : "#c4c8cd"
                        border.color: Qt.darker(color, 1.12)
                        border.width: 0.6
                        Text {
                            anchors.centerIn: parent
                            text: index === 0 ? "×" : index === 1 ? "−" : win.isFullscreen ? "↙" : "↗"
                            visible: lightMouse.containsMouse
                            color: "#60000000"
                            font.pixelSize: 11
                            font.bold: true
                        }
                        MouseArea {
                            id: lightMouse
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            enabled: index !== 1 || !win.isFullscreen
                            Accessible.role: Accessible.Button
                            Accessible.name: index === 0 ? "Close Finder window" : index === 1 ? "Minimize Finder window" : win.isFullscreen ? "Exit Full Screen" : "Enter Full Screen"
                            onClicked: function (mouse) {
                                if (index === 0)
                                    desktop.closeWindow(win);
                                else if (index === 1)
                                    desktop.minimizeWindow(win);
                                else if (mouse && (mouse.modifiers & Qt.AltModifier))
                                    win.zoom();
                                else
                                    win.toggleFullscreen();
                            }
                            Accessible.onPressAction: clicked(null)
                        }
                    }
                }
            }
            Row {
                x: win.sidebarVisible ? win.sideWidth + 10 : 84
                y: 0
                spacing: 3
                Rectangle {
                    width: 70
                    height: 34
                    radius: 17
                    color: "transparent"
                    border.color: !win.active ? "transparent" : win.dark ? "#2cffffff" : "#19000000"
                    Row {
                        anchors.centerIn: parent
                        spacing: 0
                        IconButton {
                            symbol: "back"
                            width: 31
                            height: 30
                            dark: win.dark
                            enabled: browser.canBack
                            tip: "Back"
                            onClicked: {
                                win.activate();
                                browser.back();
                            }
                        }
                        IconButton {
                            symbol: "forward"
                            width: 31
                            height: 30
                            dark: win.dark
                            enabled: browser.canForward
                            tip: "Forward"
                            onClicked: {
                                win.activate();
                                browser.forward();
                            }
                        }
                    }
                }
                Text {
                    text: browser.title
                    opacity: win.active ? 1 : 0.45
                    color: win.ink
                    height: 34
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 10
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    width: Math.max(30, win.width - win.sideWidth - 430)
                    elide: Text.ElideRight
                }
            }
            Row {
                anchors.right: parent.right
                y: 0
                spacing: 12
                Rectangle {
                    width: win.width > 1150 ? 148 : 50
                    height: 34
                    radius: 17
                    color: "transparent"
                    border.color: !win.active ? "transparent" : win.dark ? "#2cffffff" : "#19000000"
                    Row {
                        visible: win.width > 1150
                        anchors.centerIn: parent
                        Repeater {
                            model: ["icons", "list", "columns", "gallery"]
                            delegate: IconButton {
                                required property string modelData
                                symbol: modelData === "icons" ? "grid" : modelData
                                width: 35
                                height: 28
                                dark: win.dark
                                selected: win.viewMode === modelData
                                tip: "View as " + modelData
                                onClicked: {
                                    win.activate();
                                    win.viewMode = modelData;
                                }
                            }
                        }
                    }
                    IconButton {
                        visible: win.width <= 1150
                        width: 48
                        height: 32
                        padding: 5
                        rightPadding: 22
                        symbol: win.viewMode === "icons" ? "grid" : win.viewMode
                        dark: win.dark
                        tip: "Change view"
                        onClicked: {
                            win.activate();
                            let p = mapToItem(desktop, 0, height + 4);
                            desktop.openOptions(p.x, p.y, [desktop.row("as Icons", "icons", "⌘1", true, win.viewMode === "icons"), desktop.row("as List", "list", "⌘2", true, win.viewMode === "list"), desktop.row("as Columns", "columns", "⌘3", true, win.viewMode === "columns"), desktop.row("as Gallery", "gallery", "⌘4", true, win.viewMode === "gallery")]);
                        }
                    }
                    Icon {
                        visible: win.width <= 1150
                        x: 32
                        y: 12
                        width: 11
                        height: 11
                        name: "down"
                        color: win.muted
                    }
                }
                Rectangle {
                    width: 50
                    height: 34
                    radius: 17
                    color: "transparent"
                    border.color: !win.active ? "transparent" : win.dark ? "#2cffffff" : "#19000000"
                    IconButton {
                        width: 47
                        height: 32
                        rightPadding: 20
                        symbol: "group"
                        dark: win.dark
                        tip: "Sort items"
                        onClicked: {
                            win.activate();
                            let p = mapToItem(desktop, 0, height + 4);
                            desktop.openOptions(p.x, p.y, [desktop.row("Name", "sortname"), desktop.row("Kind", "sortkind"), desktop.row("Date Modified", "sortdate"), desktop.row("Size", "sortsize")]);
                        }
                    }
                    Icon {
                        x: 32
                        y: 12
                        width: 11
                        height: 11
                        name: "down"
                        color: win.muted
                    }
                }
                Rectangle {
                    width: 112
                    height: 34
                    radius: 17
                    color: "transparent"
                    border.color: !win.active ? "transparent" : win.dark ? "#2cffffff" : "#19000000"
                    Row {
                        anchors.centerIn: parent
                        IconButton {
                            width: 36
                            height: 30
                            symbol: "share"
                            dark: win.dark
                            tip: "Share"
                            enabled: win.selected.length > 0
                            onClicked: {
                                win.activate();
                                let p = mapToItem(desktop, 0, height + 4);
                                desktop.openOptions(p.x, p.y, [desktop.row("Copy Pathnames", "copypaths")]);
                            }
                        }
                        IconButton {
                            width: 36
                            height: 30
                            symbol: "tag"
                            dark: win.dark
                            tip: "Edit Tags"
                            enabled: win.selected.length > 0 && !browser.isTrash && browser.currentPath !== "@applications"
                            onClicked: {
                                win.activate();
                                let p = mapToItem(desktop, 0, height + 4);
                                desktop.openOptions(p.x, p.y, [desktop.row("Red", "tag:Red"), desktop.row("Orange", "tag:Orange"), desktop.row("Yellow", "tag:Yellow"), desktop.row("Green", "tag:Green"), desktop.row("Blue", "tag:Blue"), desktop.row("Purple", "tag:Purple"), desktop.row("Gray", "tag:Gray"), desktop.sep(), desktop.row("Remove Tags", "tag:")]);
                            }
                        }
                        IconButton {
                            width: 36
                            height: 30
                            symbol: "more"
                            dark: win.dark
                            tip: "Action"
                            onClicked: {
                                win.activate();
                                let p = mapToItem(desktop, 0, height + 4);
                                desktop.openContext(p.x, p.y, win);
                            }
                        }
                    }
                }
                Rectangle {
                    width: 40
                    height: 34
                    radius: 17
                    color: "transparent"
                    border.color: !win.active ? "transparent" : win.dark ? "#2cffffff" : "#19000000"
                    IconButton {
                        anchors.centerIn: parent
                        symbol: "search"
                        dark: win.dark
                        tip: "Search"
                        onClicked: {
                            win.activate();
                            searchBar.visible = !searchBar.visible;
                            if (searchBar.visible)
                                searchBox.forceActiveFocus();
                            else
                                browser.search("");
                        }
                    }
                }
            }
        }

        Flickable {
            id: sidebar
            opacity: win.active ? 1 : 0.6
            visible: win.sidebarVisible
            x: 18
            y: 52
            width: win.sideWidth - 22
            height: surface.height - 67
            contentHeight: sideColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: sideColumn
                width: sidebar.width
                spacing: 0
                Repeater {
                    model: [
                        {
                            label: "Recents",
                            path: "@recents",
                            icon: "clock"
                        },
                        {
                            label: "Shared",
                            icon: "shared",
                            unavailable: true
                        },
                        {
                            section: "Favorites"
                        },
                        {
                            label: "Applications",
                            icon: "applications",
                            path: "@applications"
                        },
                        {
                            label: "Desktop",
                            path: "Desktop",
                            icon: "desktop"
                        },
                        {
                            label: "Documents",
                            path: "Documents",
                            icon: "document"
                        },
                        {
                            label: "Downloads",
                            path: "Downloads",
                            icon: "downloads"
                        },
                        {
                            section: "Locations"
                        },
                        {
                            label: "iCloud Drive",
                            icon: "cloud",
                            unavailable: true
                        },
                        {
                            label: "Home",
                            path: "",
                            icon: "home"
                        },
                        {
                            label: "AirDrop",
                            icon: "airdrop",
                            unavailable: true
                        },
                        {
                            label: "Trash",
                            path: ".Trash",
                            icon: "trash"
                        },
                        {
                            section: "Tags"
                        },
                        {
                            label: "Red",
                            path: "@tag:Red",
                            tag: "#ff6059"
                        },
                        {
                            label: "Orange",
                            path: "@tag:Orange",
                            tag: "#ffa33a"
                        },
                        {
                            label: "Yellow",
                            path: "@tag:Yellow",
                            tag: "#ffd43b"
                        },
                        {
                            label: "Green",
                            path: "@tag:Green",
                            tag: "#60c764"
                        },
                        {
                            label: "Blue",
                            path: "@tag:Blue",
                            tag: "#5aa7ef"
                        },
                        {
                            label: "Purple",
                            path: "@tag:Purple",
                            tag: "#b279df"
                        },
                        {
                            label: "Gray",
                            path: "@tag:Gray",
                            tag: "#a6a6ab"
                        }
                    ]
                    delegate: Item {
                        id: sideRow
                        opacity: modelData.unavailable ? 0.42 : 1
                        required property var modelData
                        width: sideColumn.width
                        height: modelData.section ? 36 : win.sidebarRowHeight
                        Rectangle {
                            anchors.fill: parent
                            radius: 7
                            visible: !sideRow.modelData.section
                            color: browser.currentPath === sideRow.modelData.path ? (win.dark ? "#38ffffff" : "#21000000") : sideMouse.containsMouse ? (win.dark ? "#13ffffff" : "#0b000000") : "transparent"
                        }
                        Text {
                            visible: sideRow.modelData.section !== undefined
                            x: 6
                            y: 14
                            text: sideRow.modelData.section || ""
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: win.muted
                        }
                        Icon {
                            visible: !sideRow.modelData.section && !sideRow.modelData.tag
                            x: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: (sideRow.modelData.icon === "applications" || sideRow.modelData.icon === "airdrop") ? win.sidebarSymbolSize - 4 : win.sidebarSymbolSize
                            height: width
                            name: sideRow.modelData.icon || "folder"
                            color: win.dark ? "#e5e8ea" : "#5e6470"
                        }
                        Text {
                            visible: !sideRow.modelData.section
                            x: win.sidebarSymbolSize + 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: sideRow.modelData.label || ""
                            font.pixelSize: desktop.sidebarIconSize === "small" ? 12 : desktop.sidebarIconSize === "large" ? 14 : 13
                            color: win.ink
                        }
                        Rectangle {
                            visible: !!sideRow.modelData.tag
                            x: 13
                            y: 10
                            width: 12
                            height: 12
                            radius: 6
                            color: sideRow.modelData.tag || "transparent"
                        }
                        MouseArea {
                            id: sideMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !sideRow.modelData.section && !sideRow.modelData.unavailable
                            onClicked: {
                                win.activate();
                                win.go(sideRow.modelData.path);
                            }
                            Accessible.role: Accessible.Button
                            Accessible.name: sideRow.modelData.label || ""
                            Accessible.ignored: !!sideRow.modelData.section
                            Accessible.onPressAction: clicked(null)
                        }
                        DropArea {
                            anchors.fill: parent
                            enabled: !sideRow.modelData.section && !sideRow.modelData.unavailable && !(sideRow.modelData.path || "").startsWith("@") && sideRow.modelData.path !== ".Trash"
                            keys: ["tahoe/files"]
                            onDropped: function (drop) {
                                let paths = drop.source.paths.slice(), destination = sideRow.modelData.path, copy = (!!(drop.modifiers & Qt.AltModifier) || drop.proposedAction === Qt.CopyAction);
                                Qt.callLater(function() { Bridge.dropFiles(paths, destination, copy); });
                                drop.acceptProposedAction();
                            }
                            Rectangle {
                                anchors.fill: parent
                                radius: 7
                                visible: parent.containsDrag
                                color: "#30007aff"
                                border.color: "#087cff"
                            }
                        }
                    }
                }
            }
            ScrollBar.vertical: ScrollBar {
                width: 5
                policy: desktop.alwaysShowScrollbars ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
            }
        }
        Item {
            id: searchBar
            visible: false
            x: win.sideWidth + 14
            y: 53
            width: win.width - x - 18
            height: 34
            Rectangle {
                anchors.fill: parent
                radius: 8
                color: win.dark ? "#171c21" : "#edf0f3"
                border.color: win.dark ? "#36ffffff" : "#22000000"
            }
            Icon {
                x: 9
                y: 8
                width: 17
                height: 17
                name: "search"
                color: win.muted
            }
            TextField {
                id: searchBox
                selectionColor: desktop.highlightColor
                x: 30
                width: parent.width - 38
                height: parent.height
                placeholderText: "Search “" + browser.title + "”"
                color: win.ink
                font.pixelSize: 13
                background: Item {}
                selectByMouse: true
                onTextChanged: browser.search(text)
                Keys.onEscapePressed: {
                    text = "";
                    searchBar.visible = false;
                    fileArea.forceActiveFocus();
                }
                Accessible.name: "Search files"
            }
        }
        FocusScope {
            id: fileArea
            x: win.sideWidth + 10
            y: searchBar.visible ? 94 : 64
            width: win.width - x - 12
            height: surface.height - y - (win.pathbarVisible ? 59 : 30)
            clip: true
            focus: true
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: function (mouse) {
                    win.activate();
                    win.selected = [];
                    if (mouse.button === Qt.RightButton) {
                        let p = mapToItem(win, mouse.x, mouse.y);
                        win.showContext(p.x, p.y, null);
                    }
                }
            }
            DropArea {
                anchors.fill: parent
                enabled: !browser.isTrash && !browser.currentPath.startsWith("@")
                keys: ["tahoe/files"]
                onDropped: function(drop) {
                    let paths = drop.source.paths.slice(), destination = browser.currentPath, copy = (!!(drop.modifiers & Qt.AltModifier) || drop.proposedAction === Qt.CopyAction);
                    Qt.callLater(function() { Bridge.dropFiles(paths, destination, copy); });
                    drop.acceptProposedAction();
                }
            }
            Item {
                anchors.fill: parent
                visible: win.viewMode === "gallery"
                property var entry: win.selectedItem() || browser.files[0] || null
                Image {
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        bottom: galleryStrip.top
                        margins: 34
                    }
                    source: parent.entry ? (parent.entry.image || parent.entry.icon) : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: galleryStrip.top
                    anchors.bottomMargin: 8
                    text: parent.entry ? parent.entry.name : ""
                    color: win.ink
                    font.pixelSize: 13
                }
                ListView {
                    id: galleryStrip
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }
                    height: 100
                    orientation: ListView.Horizontal
                    spacing: 6
                    clip: true
                    model: browser.files
                    delegate: Rectangle {
                        id: galleryEntry
                        required property var modelData
                        required property int index
                        width: 88
                        height: 94
                        radius: 8
                        color: win.selected.indexOf(modelData.path) >= 0 ? (win.dark ? "#35ffffff" : "#16000000") : "transparent"
                        Image {
                            x: 16
                            y: 6
                            width: 56
                            height: 56
                            source: modelData.image || modelData.icon
                            fillMode: Image.PreserveAspectFit
                        }
                        Text {
                            x: 4
                            y: 68
                            width: 80
                            text: modelData.name
                            color: win.ink
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                        MouseArea {
                            id: galleryMouse
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            drag.target: galleryDrag; drag.threshold: 8
                            drag.smoothed: false
                            onPressed: function(mouse) {
                                win.activate();
                                if (mouse.button !== Qt.LeftButton) return;
                                if (win.selected.indexOf(galleryEntry.modelData.path) < 0 || (mouse.modifiers & (Qt.ControlModifier | Qt.MetaModifier | Qt.ShiftModifier))) win.selectItem(galleryEntry.index, mouse.modifiers);
                                galleryDrag.prepare(galleryEntry, mouse.x, mouse.y, win.selected, galleryEntry.modelData.image || galleryEntry.modelData.icon, galleryEntry.modelData.path, mouse.modifiers);
                            }
                            onReleased: { if (galleryDrag.Drag.active) galleryDrag.Drag.drop(); }
                            onClicked: function (mouse) {
                                if (mouse.button === Qt.RightButton) { let p = mapToItem(win, mouse.x, mouse.y); win.showContext(p.x, p.y, galleryEntry.modelData); }
                                else if (!(mouse.modifiers & (Qt.ControlModifier | Qt.MetaModifier | Qt.ShiftModifier))) win.selectItem(galleryEntry.index, 0);
                            }
                            onDoubleClicked: win.openItem(galleryEntry.modelData)
                            Accessible.role: Accessible.ListItem
                            Accessible.name: galleryEntry.modelData.name
                            Accessible.onPressAction: win.selectItem(galleryEntry.index, 0)
                        }
                        FileDragPreview { id: galleryDrag; desktop: win.desktop; sourceMouse: galleryMouse }
                        DropArea {
                            anchors.fill: parent; enabled: galleryEntry.modelData.isDir; keys: ["tahoe/files"]
                            onDropped: function(drop) {
                                let paths = drop.source.paths.slice(), destination = galleryEntry.modelData.path, copy = (!!(drop.modifiers & Qt.AltModifier) || drop.proposedAction === Qt.CopyAction);
                                Qt.callLater(function() { Bridge.dropFiles(paths, destination, copy); });
                                drop.acceptProposedAction();
                            }
                            Rectangle { anchors.fill: parent; radius: 6; color: "#30007aff"; border.color: desktop.accentColor; visible: parent.containsDrag }
                        }
                    }
                }
            }
            GridView {
                id: grid
                anchors.fill: parent
                visible: win.viewMode === "icons"
                model: browser.files
                cellWidth: 112
                leftMargin: 8
                cellHeight: 124
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {
                    width: 7
                    policy: desktop.alwaysShowScrollbars ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                }
                delegate: Item {
                    id: tile
                    required property var modelData
                    required property int index
                    width: grid.cellWidth
                    height: grid.cellHeight
                    readonly property bool chosen: win.selected.indexOf(modelData.path) >= 0
                    Rectangle {
                        x: (tile.width - 72) / 2
                        y: -2
                        width: 72
                        height: 72
                        radius: 8
                        color: win.dark ? "#30ffffff" : "#16000000"
                        visible: tile.chosen
                    }
                    Image {
                        x: (tile.width - 64) / 2
                        y: 2
                        width: 64
                        height: 64
                        source: tile.modelData.image || tile.modelData.icon
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        sourceSize.width: 128
                        sourceSize.height: 128
                        Text {
                            visible: !!tile.modelData.thumbnailText
                            x: 14
                            y: 7
                            width: 36
                            height: 46
                            text: tile.modelData.thumbnailText || ""
                            font.pixelSize: 3
                            color: "#454545"
                            wrapMode: Text.WrapAnywhere
                            clip: true
                        }
                    }
                    Rectangle {
                        x: Math.max(4, (tile.width - nameLabel.implicitWidth - 10) / 2)
                        y: 70
                        width: Math.min(tile.width - 8, nameLabel.implicitWidth + 10)
                        height: nameLabel.height + 4
                        radius: 4
                        color: win.active ? desktop.accentColor : win.dark ? "#59616c" : "#bfc6ce"
                        visible: tile.chosen
                    }
                    Text {
                        id: nameLabel
                        x: 5
                        y: 72
                        width: tile.width - 10
                        text: tile.modelData.name
                        color: tile.chosen ? "white" : win.ink
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        x: tile.width - 16
                        y: 74
                        width: 7
                        height: 7
                        radius: 3.5
                        visible: !!tile.modelData.tag
                        color: ({
                                Red: "#ff6059",
                                Orange: "#ffa33a",
                                Yellow: "#ffd43b",
                                Green: "#60c764",
                                Blue: "#5aa7ef",
                                Purple: "#b279df",
                                Gray: "#a6a6ab"
                            })[tile.modelData.tag] || "transparent"
                    }
                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        drag.target: dragProxy
                        drag.threshold: 8
                        drag.smoothed: false
                        onPressed: function (mouse) {
                            win.activate();
                            if (mouse.button === Qt.LeftButton) {
                                if (win.selected.indexOf(tile.modelData.path) < 0 || (mouse.modifiers & (Qt.ControlModifier | Qt.MetaModifier | Qt.ShiftModifier))) win.selectItem(tile.index, mouse.modifiers);
                                dragProxy.prepare(tile, mouse.x, mouse.y, win.selected, tile.modelData.image || tile.modelData.icon, tile.modelData.path, mouse.modifiers);
                            }
                        }
                        onClicked: function (mouse) {
                            if (mouse.button === Qt.RightButton) {
                                let p = mapToItem(win, mouse.x, mouse.y);
                                win.showContext(p.x, p.y, tile.modelData);
                            } else if (!(mouse.modifiers & (Qt.ControlModifier | Qt.MetaModifier | Qt.ShiftModifier)))
                                win.selectItem(tile.index, mouse.modifiers);
                        }
                        onDoubleClicked: win.openItem(tile.modelData)
                        onReleased: {
                            if (dragProxy.Drag.active)
                                dragProxy.Drag.drop();
                        }
                        Accessible.role: Accessible.ListItem
                        Accessible.name: tile.modelData.name
                        Accessible.selected: tile.chosen
                        Accessible.onPressAction: win.selectItem(tile.index, 0)
                    }
                    FileDragPreview { id: dragProxy; desktop: win.desktop; sourceMouse: tileMouse }
                    DropArea {
                        anchors.fill: parent
                        enabled: tile.modelData.isDir
                        keys: ["tahoe/files"]
                        onDropped: function (drop) {
                            let paths = drop.source.paths.slice(), destination = tile.modelData.path, copy = (!!(drop.modifiers & Qt.AltModifier) || drop.proposedAction === Qt.CopyAction);
                            Qt.callLater(function() { Bridge.dropFiles(paths, destination, copy); });
                            drop.acceptProposedAction();
                        }
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 5
                            radius: 9
                            color: "#30007aff"
                            border.color: "#087cff"
                            visible: parent.containsDrag
                        }
                    }
                }
            }
            Item {
                anchors.fill: parent
                visible: win.viewMode === "list"
                Rectangle {
                    x: 0
                    y: 0
                    width: parent.width
                    height: 27
                    color: win.dark ? "#1affffff" : "#08000000"
                }
                Row {
                    id: headers
                    height: 27
                    Repeater {
                        model: [
                            {
                                label: "Name",
                                key: "name",
                                fraction: 0.47
                            },
                            {
                                label: "Date Modified",
                                key: "modified",
                                fraction: 0.27
                            },
                            {
                                label: "Size",
                                key: "size",
                                fraction: 0.12
                            },
                            {
                                label: "Kind",
                                key: "kind",
                                fraction: 0.14
                            }
                        ]
                        delegate: Item {
                            required property var modelData
                            width: fileArea.width * modelData.fraction
                            height: 27
                            Text {
                                x: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label
                                color: win.muted
                                font.pixelSize: 11
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: browser.sortBy(modelData.key)
                                Accessible.name: "Sort by " + modelData.label
                                Accessible.role: Accessible.Button
                            }
                        }
                    }
                }
                ListView {
                    id: listing
                    x: 0
                    y: 28
                    width: parent.width
                    height: parent.height - 28
                    model: browser.files
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {
                        width: 7
                    }
                    delegate: Rectangle {
                        id: listRow
                        required property var modelData
                        required property int index
                        width: listing.width
                        height: 29
                        radius: 5
                        readonly property bool chosen: win.selected.indexOf(modelData.path) >= 0
                        color: chosen ? (win.active ? "#087bff" : win.dark ? "#59616c" : "#bdc4cc") : index % 2 === 1 ? (win.dark ? "#09ffffff" : "#05000000") : "transparent"
                        Image {
                            x: 8
                            y: 4
                            width: 22
                            height: 21
                            source: modelData.image || modelData.icon
                            fillMode: Image.PreserveAspectFit
                            sourceSize.width: 44
                            sourceSize.height: 44
                        }
                        Text {
                            x: 36
                            width: parent.width * 0.47 - 42
                            anchors.verticalCenter: parent.verticalCenter
                            text: listRow.modelData.name
                            color: listRow.chosen ? "white" : win.ink
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                        Text {
                            x: parent.width * 0.47 + 10
                            width: parent.width * 0.27 - 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: listRow.modelData.dateText
                            color: listRow.chosen ? "white" : win.muted
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                        Text {
                            x: parent.width * 0.74 + 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: listRow.modelData.sizeText
                            color: listRow.chosen ? "white" : win.muted
                            font.pixelSize: 11
                        }
                        Text {
                            x: parent.width * 0.86 + 10
                            width: parent.width * 0.14 - 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: listRow.modelData.kind
                            color: listRow.chosen ? "white" : win.muted
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            id: listMouse
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            drag.target: listDrag
                            drag.threshold: 8
                            drag.smoothed: false
                            onPressed: function(mouse) {
                                win.activate();
                                if (mouse.button !== Qt.LeftButton) return;
                                if (!listRow.chosen || (mouse.modifiers & (Qt.ControlModifier | Qt.MetaModifier | Qt.ShiftModifier))) win.selectItem(listRow.index, mouse.modifiers);
                                listDrag.prepare(listRow, mouse.x, mouse.y, win.selected, listRow.modelData.image || listRow.modelData.icon, listRow.modelData.path, mouse.modifiers);
                            }
                            onReleased: { if (listDrag.Drag.active) listDrag.Drag.drop(); }
                            onClicked: function (mouse) {
                                if (mouse.button === Qt.RightButton) {
                                    let p = mapToItem(win, mouse.x, mouse.y);
                                    win.showContext(p.x, p.y, listRow.modelData);
                                } else
                                    win.selectItem(listRow.index, mouse.modifiers);
                            }
                            onDoubleClicked: win.openItem(listRow.modelData)
                            Accessible.role: Accessible.ListItem
                            Accessible.name: listRow.modelData.name
                            Accessible.selected: listRow.chosen
                            Accessible.onPressAction: win.selectItem(listRow.index, 0)
                        }
                        FileDragPreview { id: listDrag; desktop: win.desktop; sourceMouse: listMouse }
                        DropArea {
                            anchors.fill: parent; enabled: listRow.modelData.isDir; keys: ["tahoe/files"]
                            onDropped: function(drop) {
                                let paths = drop.source.paths.slice(), destination = listRow.modelData.path, copy = (!!(drop.modifiers & Qt.AltModifier) || drop.proposedAction === Qt.CopyAction);
                                Qt.callLater(function() { Bridge.dropFiles(paths, destination, copy); });
                                drop.acceptProposedAction();
                            }
                            Rectangle { anchors.fill: parent; color: "#30007aff"; border.color: desktop.accentColor; visible: parent.containsDrag }
                        }
                    }
                }
            }
            Flickable {
                id: columnFlick
                anchors.fill: parent
                visible: win.viewMode === "columns"
                clip: true
                contentWidth: columnRow.width
                contentHeight: height
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.horizontal: ScrollBar {
                    height: 7
                }
                Row {
                    id: columnRow
                    height: columnFlick.height
                    Repeater {
                        model: win.columns
                        delegate: Item {
                            id: column
                            required property var modelData
                            required property int index
                            width: 222
                            height: columnRow.height
                            Rectangle {
                                anchors.right: parent.right
                                width: 1
                                height: parent.height
                                color: win.dark ? "#25ffffff" : "#19000000"
                            }
                            ListView {
                                anchors.fill: parent
                                anchors.margins: 4
                                model: column.modelData.entries
                                clip: true
                                ScrollBar.vertical: ScrollBar {
                                    width: 5
                                }
                                delegate: Rectangle {
                                    id: columnEntry
                                    required property var modelData
                                    required property int index
                                    width: 214
                                    height: 28
                                    radius: 5
                                    color: win.selected.indexOf(modelData.path) >= 0 ? "#087bff" : "transparent"
                                    Image {
                                        x: 4
                                        y: 4
                                        width: 20
                                        height: 20
                                        source: modelData.icon
                                        fillMode: Image.PreserveAspectFit
                                    }
                                    Text {
                                        x: 30
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 158
                                        elide: Text.ElideRight
                                        text: columnEntry.modelData.name
                                        font.pixelSize: 12
                                        color: win.selected.indexOf(columnEntry.modelData.path) >= 0 ? "white" : win.ink
                                    }
                                    Icon {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 5
                                        y: 8
                                        width: 12
                                        height: 12
                                        name: "chevron"
                                        color: win.muted
                                        visible: columnEntry.modelData.isDir
                                    }
                                    MouseArea {
                                        id: columnMouse
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        drag.target: columnDrag; drag.threshold: 8
                                        drag.smoothed: false
                                        onPressed: function(mouse) {
                                            win.activate();
                                            if (mouse.button !== Qt.LeftButton) return;
                                            if (win.selected.indexOf(columnEntry.modelData.path) < 0 || (mouse.modifiers & (Qt.ControlModifier | Qt.MetaModifier | Qt.ShiftModifier))) win.selectItem(columnEntry.index, mouse.modifiers, column.modelData.entries);
                                            columnDrag.prepare(columnEntry, mouse.x, mouse.y, win.selected, columnEntry.modelData.image || columnEntry.modelData.icon, columnEntry.modelData.path, mouse.modifiers);
                                        }
                                        onReleased: { if (columnDrag.Drag.active) columnDrag.Drag.drop(); }
                                        onClicked: function(mouse) {
                                            if (mouse.button === Qt.RightButton) { let p = mapToItem(win, mouse.x, mouse.y); win.showContext(p.x, p.y, columnEntry.modelData); return; }
                                            if (!(mouse.modifiers & (Qt.ControlModifier | Qt.MetaModifier | Qt.ShiftModifier))) win.selectItem(columnEntry.index, 0, column.modelData.entries);
                                            let cols = win.columns.slice(0, column.index + 1);
                                            if (columnEntry.modelData.isDir)
                                                cols.push({
                                                    path: columnEntry.modelData.path,
                                                    entries: Bridge.children(columnEntry.modelData.path)
                                                });
                                            win.columns = cols;
                                            Qt.callLater(function () {
                                                columnFlick.contentX = Math.max(0, columnFlick.contentWidth - columnFlick.width);
                                            });
                                        }
                                        onDoubleClicked: win.openItem(columnEntry.modelData)
                                        Accessible.role: Accessible.ListItem
                                        Accessible.name: columnEntry.modelData.name
                                    }
                                    FileDragPreview { id: columnDrag; desktop: win.desktop; sourceMouse: columnMouse }
                                    DropArea {
                                        anchors.fill: parent; enabled: columnEntry.modelData.isDir; keys: ["tahoe/files"]
                                        onDropped: function(drop) {
                                            let paths = drop.source.paths.slice(), destination = columnEntry.modelData.path, copy = (!!(drop.modifiers & Qt.AltModifier) || drop.proposedAction === Qt.CopyAction);
                                            Qt.callLater(function() { Bridge.dropFiles(paths, destination, copy); });
                                            drop.acceptProposedAction();
                                        }
                                        Rectangle { anchors.fill: parent; radius: 5; color: "#30007aff"; border.color: desktop.accentColor; visible: parent.containsDrag }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: browser.files.length === 0
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: searchBox.text ? "No matching items" : browser.isTrash ? "Trash is empty" : "This folder is empty"
                    font.pixelSize: 17
                    font.weight: Font.Medium
                    color: win.muted
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: searchBox.text ? "Try a different name." : browser.isTrash ? "Items you move here can be put back." : "Create a folder or paste files here."
                    font.pixelSize: 12
                    color: win.muted
                }
            }
            Keys.onPressed: function (event) {
                const count = browser.files.length;
                if (event.key === Qt.Key_Space) {
                    if (win.selected.length)
                        desktop.showPreview(win.selected[0]);
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    win.renameSelection();
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Escape) {
                    if (win.isFullscreen)
                        desktop.presentation.exit();
                    win.selected = [];
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                    let step = (event.key === Qt.Key_Left || event.key === Qt.Key_Up) ? -1 : 1;
                    if (win.viewMode === "icons" && (event.key === Qt.Key_Up || event.key === Qt.Key_Down))
                        step *= Math.max(1, Math.floor(grid.width / grid.cellWidth));
                    let idx = win.focusedIndex < 0 ? 0 : Math.max(0, Math.min(count - 1, win.focusedIndex + step));
                    if (count)
                        win.selectItem(idx, event.modifiers);
                    grid.positionViewAtIndex(idx, GridView.Contain);
                    listing.positionViewAtIndex(idx, ListView.Contain);
                    event.accepted = true;
                    return;
                }
                if (event.text && !(event.modifiers & (Qt.ControlModifier | Qt.MetaModifier | Qt.AltModifier))) {
                    win.typeBuffer += event.text.toLowerCase();
                    typeTimer.restart();
                    let idx = browser.files.findIndex(f => f.name.toLowerCase().startsWith(win.typeBuffer));
                    if (idx >= 0)
                        win.selectItem(idx, 0);
                    event.accepted = true;
                }
            }
        }
        Timer {
            id: typeTimer
            interval: 900
            onTriggered: win.typeBuffer = ""
        }
        Rectangle {
            x: win.sideWidth + 10
            y: surface.height - 30
            width: win.width - x - 12
            height: 1
            color: win.dark ? "#16ffffff" : "#10000000"
        }
        Row {
            visible: win.pathbarVisible
            x: win.sideWidth + 18
            y: surface.height - 56
            height: 25
            spacing: 5
            Repeater {
                model: browser.breadcrumbs
                delegate: Row {
                    required property var modelData
                    required property int index
                    spacing: 5
                    Icon {
                        visible: index > 0
                        width: 10
                        height: 12
                        y: 7
                        name: "chevron"
                        color: win.muted
                    }
                    Text {
                        text: modelData.name
                        height: 25
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 11
                        color: win.muted
                        MouseArea {
                            anchors.fill: parent
                            onClicked: win.go(modelData.path)
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
            }
        }
        Text {
            x: win.sideWidth
            y: surface.height - 26
            width: win.width - win.sideWidth
            height: 20
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: (win.selected.length ? win.selected.length + " of " : "") + browser.files.length + " items"
            font.pixelSize: 11
            color: win.muted
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
                win.geometryAnimating = false;
                win.activate();
                if (win.nativeWindow) { win.nativeWindow.startSystemResize(Qt.RightEdge | Qt.BottomEdge); return; }
                start = mapToItem(desktop, mouse.x, mouse.y);
                original = Qt.size(win.width, win.height);
            }
            onPositionChanged: function (mouse) {
                if (pressed && !win.nativeWindow) {
                    let p = mapToItem(desktop, mouse.x, mouse.y);
                    win.width = Math.max(660, Math.min(desktop.width - win.x, original.width + p.x - start.x));
                    win.height = Math.max(390, Math.min(desktop.height - win.y - 10, original.height + p.y - start.y));
                }
            }
        }
    }
    ShaderEffectSource {
        id: windowTexture
        sourceItem: surface
        hideSource: !win.nativeWindow && win.minimizeProgress > 0
        live: !win.nativeWindow && win.minimizeProgress > 0
        visible: false
        smooth: true
    }
    ShaderEffect {
        anchors.fill: parent
        visible: !win.nativeWindow && win.minimizeProgress > 0
        property var source: windowTexture
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
