import QtQuick
import QtQuick.Controls

FocusScope {
    id: surface
    objectName: "desktopFiles"
    required property var desktop
    readonly property string appKind: "finder"
    readonly property bool isDesktop: true
    readonly property bool isFullscreen: false
    readonly property bool searchFocused: false
    readonly property bool sidebarVisible: false
    readonly property bool pathbarVisible: false
    readonly property string viewMode: "icons"
    property var browser: Bridge.createDesktopBrowser()
    property var selected: []
    property var positions: ({})
    property int anchorIndex: -1
    readonly property bool active: desktop.shellActive && !desktop.activeWindow
    readonly property int rowsPerColumn: Math.max(1, Math.floor((height - 150) / 104))
    Component.onCompleted: {
        try { positions = JSON.parse(Bridge.suite.preference("desktop.positions", "{}")); } catch(e) { positions = {}; }
    }
    Connections {
        target: surface.browser
        function onChanged() { surface.selected = surface.selected.filter(path => surface.browser.files.some(f => f.path === path)); }
    }
    function activate() { desktop.activeWindow = null; forceActiveFocus(); }
    function selectedItem() { return browser.files.find(f => f.path === selected[0]) || null; }
    function selectAll() { selected = browser.files.map(f => f.path); }
    function go(path) { desktop.openFolder(path); }
    function openItem(item) {
        if (!item) return;
        if (item.isDir) desktop.newWindow(item.path); else desktop.showPreview(item.path);
    }
    function selectItem(index, modifiers) {
        activate();
        let item = browser.files[index]; if (!item) return;
        if ((modifiers & Qt.ShiftModifier) && anchorIndex >= 0) {
            selected = browser.files.slice(Math.min(index, anchorIndex), Math.max(index, anchorIndex) + 1).map(f => f.path);
        } else if (modifiers & (Qt.ControlModifier | Qt.MetaModifier)) {
            selected = selected.indexOf(item.path) >= 0 ? selected.filter(p => p !== item.path) : selected.concat([item.path]);
            anchorIndex = index;
        } else { selected = [item.path]; anchorIndex = index; }
    }
    function positionFor(path, index) {
        let p = positions[path];
        let px = p ? p.x : width - 115 - Math.floor(index / rowsPerColumn) * 112;
        let py = p ? p.y : 48 + (index % rowsPerColumn) * 104;
        return Qt.point(Math.max(4, Math.min(width - 100, px)), Math.max(34, Math.min(height - 190, py)));
    }
    function savePositions(next) { positions = next; Bridge.suite.setPreference("desktop.positions", JSON.stringify(next)); }
    function cleanUp() { savePositions({}); }
    function reposition(paths, primary, px, py) {
        let index = browser.files.findIndex(f => f.path === primary);
        if (index < 0) return;
        let origin = positionFor(primary, index), dx = px - origin.x, dy = py - origin.y;
        let next = Object.assign({}, positions);
        for (let path of paths) {
            let i = browser.files.findIndex(f => f.path === path); if (i < 0) continue;
            let p = positionFor(path, i);
            next[path] = {x: Math.max(4, Math.min(width - 100, p.x + dx)), y: Math.max(34, Math.min(height - 190, p.y + dy))};
        }
        savePositions(next);
    }
    function receiveDrop(paths, sourceKind, primary, destination, px, py, copy) {
        let captured = paths.slice();
        if (sourceKind === "desktop" && destination === "Desktop" && !copy) {
            reposition(captured, primary, px - 46, py - 32); return;
        }
        // Model mutations must happen after Qt finishes delivering the drop.
        Qt.callLater(function() {
            let results = Bridge.dropFiles(captured, destination, copy);
            if (destination === "Desktop") {
                let next = Object.assign({}, positions);
                for (let i = 0; i < results.length; i++) {
                    next[results[i]] = {x: px - 46 + i * 16, y: py - 32 + i * 16};
                }
                selected = results;
                savePositions(next);
            }
        });
    }
    function renameSelection() {
        let item = selectedItem(); if (!item || selected.length !== 1) return;
        desktop.prompt("Rename", "Choose a new name for this item.", item.name, function(value) {
            let result = Bridge.rename(item.path, value);
            if (result) {
                let next = Object.assign({}, positions); if (next[item.path]) { next[result] = next[item.path]; delete next[item.path]; savePositions(next); }
                selected = [result];
            }
        });
    }
    function newFolder() {
        desktop.prompt("New Folder", "Enter a name for the new folder.", "untitled folder", function(value) {
            let result = Bridge.newFolder("Desktop", value); if (result) selected = [result];
        });
    }
    function showContext(px, py, item) {
        activate();
        if (item && selected.indexOf(item.path) < 0) selected = [item.path];
        if (!item) selected = [];
        let r = desktop.row, sep = desktop.sep;
        let rows = item ? [r("Open", "open"), sep(), r("Move to Trash", "trash"), sep(), r("Get Info", "getinfo", "⌘I"), r("Rename", "rename", "", selected.length === 1), r("Duplicate", "duplicate"), r("Quick Look", "preview", "Space"), r("Copy", "copy"), sep(), {label: "Tags…", submenu: ["Red","Orange","Yellow","Green","Blue","Purple","Gray"].map(c => r(c, "tag:" + c)).concat([sep(),r("Remove Tags", "tag:")])}] : [r("New Folder", "newfolder"), r("Get Info", "desktopinfo"), r("Paste Items", "paste", "", Bridge.canPaste), sep(), r("Change Wallpaper…", "settings:Wallpaper"), sep(), r("Clean Up", "desktopcleanup"), {label: "Sort By", submenu: [r("Name", "sortname"), r("Kind", "sortkind"), r("Date Modified", "sortdate"), r("Size", "sortsize")]}];
        desktop.openOptions(px, py, rows);
    }
    MouseArea {
        id: backgroundMouse
        objectName: "desktopBackgroundMouse"
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        property point start
        property var previous: []
        property bool selecting: false
        onPressed: function(mouse) {
            surface.activate(); start = Qt.point(mouse.x, mouse.y); previous = surface.selected.slice(); selecting = false;
            if (mouse.button === Qt.LeftButton && !(mouse.modifiers & (Qt.ControlModifier | Qt.MetaModifier | Qt.ShiftModifier))) surface.selected = [];
        }
        onPositionChanged: function(mouse) {
            if (!(pressedButtons & Qt.LeftButton)) return;
            if (Math.abs(mouse.x - start.x) + Math.abs(mouse.y - start.y) < 6) return;
            selecting = true;
            let x1 = Math.min(start.x, mouse.x), x2 = Math.max(start.x, mouse.x), y1 = Math.min(start.y, mouse.y), y2 = Math.max(start.y, mouse.y);
            selectionRect.x = x1; selectionRect.y = y1; selectionRect.width = x2 - x1; selectionRect.height = y2 - y1;
            let hit = [];
            for (let i = 0; i < files.count; i++) { let tile = files.itemAt(i); if (tile && tile.x < x2 && tile.x + tile.width > x1 && tile.y < y2 && tile.y + tile.height > y1) hit.push(tile.modelData.path); }
            surface.selected = mouse.modifiers & (Qt.ControlModifier | Qt.MetaModifier | Qt.ShiftModifier) ? Array.from(new Set(previous.concat(hit))) : hit;
        }
        onReleased: selecting = false
        onCanceled: selecting = false
        onClicked: function(mouse) { if (mouse.button === Qt.RightButton) surface.showContext(mouse.x, mouse.y, null); }
        Accessible.role: Accessible.Pane
        Accessible.name: "Desktop"
    }
    DropArea {
        anchors.fill: parent
        keys: ["tahoe/files"]
        onDropped: function(drop) {
            if (!drop.source || !drop.source.paths) return;
            surface.receiveDrop(drop.source.paths, drop.source.origin || "finder", drop.source.primaryPath || "", "Desktop", drop.x, drop.y, (!!(drop.modifiers & Qt.AltModifier) || drop.proposedAction === Qt.CopyAction));
            drop.acceptProposedAction();
        }
    }
    Repeater {
        id: files
        model: surface.browser.files
        delegate: Item {
            id: tile
            required property var modelData
            required property int index
            objectName: "desktopFile:" + modelData.path
            visible: desktop.showDesktopItems
            width: 92; height: 96
            x: surface.positionFor(modelData.path, index).x
            y: surface.positionFor(modelData.path, index).y
            readonly property bool chosen: surface.selected.indexOf(modelData.path) >= 0
            Rectangle { x: 10; y: -2; width: 72; height: 68; radius: 6; color: "#4a000000"; border.color: "#72ffffff"; visible: tile.chosen }
            Image { x: 14; width: 64; height: 64; source: tile.modelData.image || tile.modelData.icon; fillMode: Image.PreserveAspectFit }
            Rectangle { x: Math.max(0, (92 - label.implicitWidth - 8) / 2); y: 67; width: Math.min(92,label.implicitWidth + 8); height: label.height + 3; radius: 4; color: surface.active ? desktop.accentColor : "#65717c"; visible: tile.chosen }
            Text { id: label; x: 2; y: 68; width: 88; text: tile.modelData.name; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 12; color: "white"; style: tile.chosen ? Text.Normal : Text.Outline; styleColor: "#70000000"; wrapMode: Text.WrapAtWordBoundaryOrAnywhere; maximumLineCount: 2; elide: Text.ElideRight }
            MouseArea {
                id: iconMouse
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                drag.target: iconDrag
                drag.threshold: 8
                drag.smoothed: false
                onPressed: function(mouse) {
                    surface.activate();
                    if (mouse.button !== Qt.LeftButton) return;
                    if (!tile.chosen || (mouse.modifiers & (Qt.ControlModifier | Qt.MetaModifier | Qt.ShiftModifier))) surface.selectItem(tile.index, mouse.modifiers);
                    iconDrag.prepare(tile, mouse.x, mouse.y, surface.selected, tile.modelData.image || tile.modelData.icon, tile.modelData.path, mouse.modifiers);
                }
                onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton) { let p = mapToItem(surface, mouse.x, mouse.y); surface.showContext(p.x, p.y, tile.modelData); }
                    else if (!(mouse.modifiers & (Qt.ControlModifier | Qt.MetaModifier | Qt.ShiftModifier))) surface.selectItem(tile.index, 0);
                }
                onDoubleClicked: surface.openItem(tile.modelData)
                onReleased: { if (iconDrag.Drag.active) iconDrag.Drag.drop(); }
                Accessible.role: Accessible.ListItem
                Accessible.name: tile.modelData.name + " on Desktop"
                Accessible.selected: tile.chosen
                Accessible.onPressAction: surface.selectItem(tile.index, 0)
            }
            FileDragPreview { id: iconDrag; desktop: surface.desktop; sourceMouse: iconMouse; origin: "desktop" }
            DropArea {
                anchors.fill: parent
                enabled: tile.modelData.isDir
                keys: ["tahoe/files"]
                onEntered: function(drag) { if (drag.source && drag.source.paths.indexOf(tile.modelData.path) >= 0) drag.accepted = false; }
                onDropped: function(drop) {
                    let p = mapToItem(surface, drop.x, drop.y);
                    surface.receiveDrop(drop.source.paths, drop.source.origin || "finder", drop.source.primaryPath || "", tile.modelData.path, p.x, p.y, (!!(drop.modifiers & Qt.AltModifier) || drop.proposedAction === Qt.CopyAction));
                    drop.acceptProposedAction();
                }
                Rectangle { anchors.fill: parent; radius: 7; visible: parent.containsDrag; color: "#35007aff"; border.color: desktop.accentColor }
            }
        }
    }
    Rectangle { id: selectionRect; visible: backgroundMouse.selecting; color: "#25007aff"; border.color: "#90ffffff"; radius: 2 }
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { renameSelection(); event.accepted = true; }
        else if (event.key === Qt.Key_Space && selected.length) { desktop.showPreview(selected[0]); event.accepted = true; }
        else if (event.key === Qt.Key_Escape) { selected = []; event.accepted = true; }
        else if ([Qt.Key_Up,Qt.Key_Down,Qt.Key_Left,Qt.Key_Right].indexOf(event.key) >= 0 && browser.files.length) {
            let index = browser.files.findIndex(f => f.path === selected[0]);
            let step = event.key === Qt.Key_Down ? 1 : event.key === Qt.Key_Up ? -1 : event.key === Qt.Key_Left ? rowsPerColumn : -rowsPerColumn;
            selectItem(Math.max(0, Math.min(browser.files.length - 1, index < 0 ? 0 : index + step)), event.modifiers); event.accepted = true;
        }
    }
}
