import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtCore
import "AppMenus.js" as AppMenus
import "FinderMenus.js" as FinderMenus

ApplicationWindow {
    id: app
    visible: true
    width: comparisonMode ? Math.floor(Screen.width / 2) : Math.min(1360, Screen.width - 50)
    x: comparisonMode ? Math.floor(Screen.width / 2) : (Screen.width - width) / 2
    y: comparisonMode ? 60 : (Screen.height - height) / 2
    height: Math.min(850, Screen.height - 70)
    minimumWidth: comparisonMode ? 760 : 960
    minimumHeight: 650
    function flushApplications() { for(let w of desktop.windows) if(w.prepareClose)w.prepareClose(); }
    onClosing: function(event) {
        if (Bridge.session.enabled && !desktop.sessionEnding) {
            event.accepted = false;
            desktop.requestSessionAction("logout");
        } else flushApplications();
    }
    title: "Tahoe Desktop — Prototype"
    palette.window: desktop.dark ? "#242a2c" : "#f6f6f7"
    palette.base: desktop.dark ? "#30373d" : "#ffffff"
    palette.text: desktop.dark ? "#f0f1f2" : "#242629"
    palette.windowText: desktop.dark ? "#f0f1f2" : "#242629"
    palette.buttonText: desktop.dark ? "#f0f1f2" : "#242629"
    palette.placeholderText: desktop.dark ? "#a4acb6" : "#737b85"
    palette.button: desktop.dark ? "#414b55" : "#e5e8ec"
    palette.highlight: desktop.highlightColor
    palette.highlightedText: "white"
    color: "#153266"
    flags: Qt.Window | Qt.FramelessWindowHint
    Component.onCompleted: {
        if (Bridge.session.enabled) showMaximized();
        else if (startFullscreen) showFullScreen();
    }

    Item {
        id: desktop
        objectName: "desktop"
        anchors.fill: parent
        readonly property bool shellActive: app.active
        property bool sessionEnding: false
        property string sessionAction: "logout"
        function requestSessionAction(action) {
            if (!Bridge.session.enabled) {
                showInfo("Session Controls", "Choose Tahoe Desktop on the Linux login screen to use session controls.");
                return;
            }
            if (action === "lock" || action === "sleep") { Bridge.session.perform(action); return; }
            sessionAction = action;
            sessionConfirm.open();
        }
        Connections {
            target: Bridge.session
            function onCommandRequested(command) {
                if (command === "lock") { Bridge.session.perform("lock"); return; }
                app.showMaximized(); app.raise(); app.requestActivate();
                if (command === "apps" || command === "terminal") desktop.openApplication(command);
                if (command === "logout") desktop.requestSessionAction("logout");
            }
        }
        property bool dark: false
        property bool reduceMotion: false
        property bool reduceTransparency: false
        property string appearanceMode: "manual"
        property bool glassTinted: false
        property bool wallpaperTint: true
        property bool alwaysShowScrollbars: false
        property bool dockMagnification: true
        property bool dockAutoHide: false
        property bool dockIndicators: true
        property bool dockLaunchAnimation: true
        property bool showDesktopItems: true
        property string wallpaperMode: "appearance"
        readonly property bool wallpaperIsDark: wallpaperMode === "night" || (wallpaperMode === "appearance" && dark)
        property bool showClock: true
        property bool showSearchIcon: true
        property bool dockRevealed: false
        readonly property int preferenceRevision: Bridge.suite.revision
        readonly property int preferredDockSize: { let revision = preferenceRevision; return Math.max(24,Math.min(70,Number(Bridge.suite.preference("dock.size","54")))); }
        readonly property bool clock24: { let revision = preferenceRevision; return Bridge.suite.preference("clock.24hour","true") === "true"; }
        function preference(key, fallback) { let revision = preferenceRevision; return Bridge.suite.preference(key, fallback); }
        readonly property var themeColors: ({multicolor: "#007aff", blue: "#007aff", purple: "#af52de", pink: "#ff2d55", red: "#ff3b30", orange: "#ff9500", yellow: "#ffcc00", green: "#34c759", graphite: "#8e8e93"})
        readonly property color accentColor: themeColors[preference("appearance.accent", "multicolor")] || themeColors.multicolor
        readonly property color highlightColor: {
            let selected = preference("appearance.highlight", "automatic");
            return selected === "automatic" ? accentColor : themeColors[selected] || accentColor;
        }
        readonly property string sidebarIconSize: preference("appearance.sidebarIconSize", "medium")
        readonly property bool menuBarBackground: preference("menubar.background", "false") === "true"
        readonly property string menuBarHideMode: preference("menubar.hide", "In Full Screen Only")
        readonly property bool desktopMenuAutoHide: menuBarHideMode === "Always" || menuBarHideMode === "On Desktop Only"
        property bool menuBarRevealed: false
        readonly property bool menuBarPopupOpen: menu.opened || subMenu.opened || contextMenu.opened || systemPanel.opened || controlGallery.opened || appearance.opened || searchOverlay.opened
        onMenuBarPopupOpenChanged: updateMenuBarVisibility()
        onDesktopMenuAutoHideChanged: updateMenuBarVisibility()
        function updateMenuBarVisibility() {
            if (topEdge.hovered || normalMenuHover.hovered || menuBarPopupOpen) {
                menuBarHideTimer.stop();
                if (topEdge.hovered || menuBarPopupOpen) menuBarRevealed = true;
            } else if (menuBarRevealed) menuBarHideTimer.restart();
        }
        Timer { id: menuBarHideTimer; interval: 350; onTriggered: desktop.menuBarRevealed = false }
        readonly property bool clockAnalog: preference("clock.style", "Digital") === "Analog"
        readonly property bool clockSeconds: preference("clock.seconds", "false") === "true"
        readonly property string clockDateText: {
            let parts = [];
            if (preference("clock.weekday", "true") === "true") parts.push(Qt.formatDateTime(now, "ddd"));
            let dateMode = preference("clock.date", "Always");
            if (dateMode === "Always" || (dateMode === "When Space Allows" && width >= 1150)) parts.push(Qt.formatDateTime(now, "d MMM"));
            return parts.join(" ");
        }
        readonly property string clockTimeText: {
            let tail = ":mm" + (clockSeconds ? ":ss" : "");
            let value = clock24 ? Qt.formatDateTime(now, "HH" + tail) : String(now.getHours()%12 || 12) + Qt.formatDateTime(now, tail);
            if (!clock24 && preference("clock.ampm", "true") === "true") value += " " + Qt.formatDateTime(now, "AP");
            if (preference("clock.flash", "false") === "true" && now.getSeconds() % 2) value = value.replace(/:/g, " ");
            return value;
        }
        readonly property var hiddenDockApps: {let r=preferenceRevision;try{return JSON.parse(Bridge.suite.preference("dock.hidden","[]"));}catch(e){return[];}}
        function toggleDockPin(id) {let hidden=hiddenDockApps.slice();let i=hidden.indexOf(id);if(i>=0)hidden.splice(i,1);else hidden.push(id);Bridge.suite.setPreference("dock.hidden",JSON.stringify(hidden));}
        function openDockMenu(entry, x, y) {
            let id=entry.action.startsWith("app:")?entry.action.slice(4):entry.action;
            let running=windows.filter(w=>w.appKind===id && !w.closing);
            let rows=[];
            if(entry.window) rows=[row("Open","window:"+windows.indexOf(entry.window))];
            else if(id==="downloads" || id==="trash")rows=[row("Open in Finder","go:"+(id==="trash"?".Trash":"Downloads"))];
            else {
                rows=running.map(w=>row(w.windowTitle,"window:"+windows.indexOf(w),"",true,w===activeWindow));
                if(rows.length)rows.push(sep());
                rows.push({label:"Options",submenu:[row("Keep in Dock","dockpin:"+id,"",id!=="finder" && id!=="apps" && id!=="settings",hiddenDockApps.indexOf(id)<0),row("Open at Login","", "",false),row("Show in Finder","revealapp:"+id)]});
                rows.push(row("Show All Windows","dockshow:"+id,"",running.length>0));
                rows.push(row("Open","launch:"+id));
                if(running.length)rows.push(row(id==="finder"?"Relaunch":"Quit","dockquit:"+id));
            }
            rows=rows.concat([sep(),row(dockAutoHide?"Turn Hiding Off":"Turn Hiding On","dockhiding"),row(dockMagnification?"Turn Magnification Off":"Turn Magnification On","dockmagnification"),row("Dock Settings…","settings:Desktop & Dock")]);
            openOptions(x,y,rows);
        }
        property var recentApps: []
        readonly property var recentFiles: {
            try { let value = JSON.parse(preference("menubar.recentFiles","[]")); return Array.isArray(value) ? value.filter(p => typeof p === "string").slice(0,50) : []; } catch(e) { return []; }
        }
        function recentMenuRows() {
            let limit = Math.max(0,Math.min(50,Number(preference("menubar.recents","10")) || 0));
            let result = recentApps.slice(0,limit).map(id => { let a=Bridge.applicationCatalog.find(x=>x.id===id); return row(a.name,"launch:"+id); });
            let documents = recentFiles.slice(0,limit).map(path=>row(path.split("/").pop(),"recentfile:"+path));
            if(result.length && documents.length)result.push(sep());
            return result.concat(documents,[sep(),row("Clear Menu","clearrecent")]);
        }
        property string statusPanel: "control"
        readonly property bool statusPanelVisible: systemPanel.visible
        property alias controls: controlState
        ControlState { id: controlState; desktop: desktop }
        function closeStatusPanel() { systemPanel.close(); }
        function openStatusPanel(section) { showStatusPanel(section, desktop.width - 12, false); }
        function showStatusPanel(section, anchorX, hover) {
            if (section === "search") {
                systemPanel.close(); menu.close(); contextMenu.close(); subMenu.close();
                if (searchOverlay.visible && !hover) searchOverlay.close();
                else { searchOverlay.open(); spotlightInput.forceActiveFocus(); }
                return;
            }
            if (systemPanel.visible && statusPanel === section && !hover) { systemPanel.close(); return; }
            menu.close(); contextMenu.close(); subMenu.close(); searchOverlay.close();
            statusPanel = section;
            systemPanel.section = section;
            systemPanel.anchorX = Number.isFinite(anchorX) ? anchorX : desktop.width - 12;
            systemPanel.editing = false;
            systemPanel.open();
        }
        function openControlGallery() {
            systemPanel.close(); menu.close(); contextMenu.close(); subMenu.close();
            controlGallery.open();
        }
        function openAbout() {
            let w=windows.find(item=>item.appKind==="aboutmac" && !item.closing);
            if(!w) { w=aboutComponent.createObject(windowLayer,{desktop:desktop}); if(!w)return; w.x=(desktop.width-w.width)/2;w.y=65;windows=windows.concat([w]); }
            focusWindow(w);
        }
        readonly property string activeAppName: activeWindow ? (activeWindow.appKind === "settings" ? "System Settings" : activeWindow.appKind === "finder" ? "Finder" : activeWindow.windowTitle) : "Finder"
        function setAppearance(mode) {
            appearanceMode = mode === "auto" ? "auto" : "manual";
            dark = mode === "auto" ? (now.getHours() >= 18 || now.getHours() < 7) : mode === "dark";
        }
        onNowChanged: if (appearanceMode === "auto")
            dark = now.getHours() >= 18 || now.getHours() < 7
        Timer {
            id: dockRevealTimer
            interval: 180
            onTriggered: desktop.dockRevealed = true
        }
        Timer {
            id: dockHideTimer
            interval: 350
            onTriggered: desktop.dockRevealed = false
        }
        function updateDockVisibility() {
            if (bottomEdge.hovered) {
                dockHideTimer.stop();
                dockRevealTimer.restart();
            } else {
                dockRevealTimer.stop();
                if (dock.pointerInside)
                    dockHideTimer.stop();
                else
                    dockHideTimer.restart();
            }
        }
        property alias baseItem: baseLayer
        property alias sceneItem: scene
        property alias presentation: fullscreenState
        FullscreenState {
            id: fullscreenState
            viewportWidth: desktop.width
            viewportHeight: desktop.height
            pointerAtTop: topEdge.hovered
            alwaysShowChrome: desktop.menuBarHideMode === "Never" || desktop.menuBarHideMode === "On Desktop Only"
            pointerInChrome: chromeHover.hovered
            menuOpen: menu.opened || subMenu.opened || contextMenu.opened || systemPanel.opened || controlGallery.opened || appearance.opened || searchOverlay.opened
            pointerAtBottom: bottomEdge.hovered
            pointerInDock: dock.pointerInside
        }
        Item {
            z: 20000
            width: parent.width
            height: 3
            HoverHandler {
                id: topEdge
                onHoveredChanged: desktop.updateMenuBarVisibility()
            }
        }
        Item {
            z: 19000
            width: parent.width
            height: 83
            HoverHandler {
                id: chromeHover
            }
        }
        Item {
            z: 20000
            y: parent.height - 3
            width: parent.width
            height: 3
            HoverHandler {
                id: bottomEdge
                onHoveredChanged: desktop.updateDockVisibility()
            }
        }
        Settings {
            category: "Appearance"
            property alias appearanceMode: desktop.appearanceMode
            property alias glassTinted: desktop.glassTinted
            property alias wallpaperTint: desktop.wallpaperTint
            property alias alwaysShowScrollbars: desktop.alwaysShowScrollbars
            property alias dockMagnification: desktop.dockMagnification
            property alias dockAutoHide: desktop.dockAutoHide
            property alias dockIndicators: desktop.dockIndicators
            property alias dockLaunchAnimation: desktop.dockLaunchAnimation
            property alias showDesktopItems: desktop.showDesktopItems
            property alias wallpaperMode: desktop.wallpaperMode
            property alias showClock: desktop.showClock
            property alias showSearchIcon: desktop.showSearchIcon
            property alias dark: desktop.dark
            property alias reduceMotion: desktop.reduceMotion
            property alias reduceTransparency: desktop.reduceTransparency
        }
        property var windows: []
        property var activeWindow: null
        property int highestZ: 10
        property int motionTick: 0
        property alias wallpaperItem: wallpaper
        property var previewData: ({})
        property string infoTitle: ""
        property string infoText: ""
        property var promptCallback
        property string promptTitle: ""
        property string promptDescription: ""
        property date now: new Date()
        property string openMenuName: ""
        property int hoveredDock: -1
        readonly property string shortcutMark: Bridge.isMac ? "⌘" : "Ctrl+"
        readonly property bool editing: promptBox.opened || searchOverlay.opened || infoBox.opened || appearance.opened || (activeWindow && activeWindow.searchFocused)

        function focusWindow(window, keepFocus) {
            if (!window || window.closing)
                return;
            if (fullscreenState.active && fullscreenState.window !== window)
                fullscreenState.exit();
            let wasMinimized = window.minimized;
            if (wasMinimized) window.minimizeTarget = dock.targetFor(window);
            for (let sibling of windows) if (sibling.appKind === window.appKind) sibling.appHidden = false;
            activeWindow = window;
            window.minimized = false;
            window.z = ++highestZ;
            if (wasMinimized)
                windows = windows.slice();
            if (!keepFocus)
                window.forceActiveFocus();
        }
        function newWindow(path) {
            let browser = Bridge.createBrowser(path === undefined ? Bridge.initialFolder : path);
            let w = finderComponent.createObject(windowLayer, {
                desktop: desktop,
                browser: browser
            });
            if (!w)
                return;
            w.width = Math.min(970, desktop.width - (comparisonMode ? 20 : 100));
            w.height = comparisonMode ? 481 : Math.min(590, desktop.height - 160);
            w.x = Math.max(comparisonMode ? 10 : 20, (desktop.width - w.width) / 2 - 25) + (windows.length % 4) * 24;
            w.y = 70 + (windows.length % 4) * 25;
            windows = windows.concat([w]);
            focusWindow(w);
        }
        function openSettings(page) {
            let w = windows.find(item => item.appKind === "settings" && !item.closing);
            if (!w) {
                w = settingsComponent.createObject(windowLayer, {
                    desktop: desktop
                });
                if (!w)
                    return;
                w.width = Math.min(723, desktop.width - 40);
                w.height = Math.min(861, desktop.height - 164);
                w.x = Math.max(20, (desktop.width - w.width) / 2 + 35);
                w.y = 55;
                windows = windows.concat([w]);
            }
            focusWindow(w);
            if (page)
                w.navigate(page);
        }
        function openApplication(id) {
            if (id.startsWith("xdg:")) { Bridge.session.launch(id); return; }
            if (id === "finder") { activateFinder(); return; }
            if (id === "settings") { openSettings(""); return; }
            let info = Bridge.applicationCatalog.find(a => a.id === id);
            if (!info) return;
            recentApps = [id].concat(recentApps.filter(a=>a!==id)).slice(0,50);
            let w = windows.find(item => item.appKind === id && !item.closing);
            if (!w) {
                w = suiteComponent.createObject(windowLayer, {desktop: desktop, appKind: id, windowTitle: info.name});
                if (!w) return;
                w.width = Math.min(id === "calculator" ? 340 : id === "chess" ? 780 : 1020, desktop.width - 40);
                w.height = Math.min(id === "calculator" ? 540 : 680, desktop.height - 130);
                w.x = Math.max(20, (desktop.width - w.width) / 2 + (windows.length % 3) * 12);
                w.y = 55 + (windows.length % 3) * 16;
                windows = windows.concat([w]);
            }
            focusWindow(w);
        }
        function closeWindow(w) {
            if (!w || w.closing)
                return;
            if (fullscreenState.window === w)
                fullscreenState.exit();
            if (w.prepareClose) w.prepareClose();
            w.closing = true;
            if (activeWindow === w)
                activeWindow = null;
            let remaining = windows.filter(item => !item.minimized && !item.appHidden && !item.closing);
            if (remaining.length)
                focusWindow(remaining[remaining.length - 1]);
        }
        function destroyWindow(w) {
            if (!w)
                return;
            windows = windows.filter(item => item !== w);
            if (activeWindow === w)
                activeWindow = null;
            if (w.browser)
                Bridge.releaseBrowser(w.browser);
            w.destroy();
            let remaining = windows.filter(item => !item.minimized && !item.appHidden && !item.closing);
            if (remaining.length)
                focusWindow(remaining[remaining.length - 1]);
        }
        function minimizeWindow(w) {
            if (!w || w.isFullscreen)
                return;
            w.minimized = true;
            w.minimizeTarget = dock.targetFor(w);
            if (activeWindow === w)
                activeWindow = null;
            let remaining = windows.filter(item => !item.minimized && !item.appHidden && !item.closing);
            if (remaining.length)
                focusWindow(remaining[remaining.length - 1]);
            // Notify the Dock's JS-array model.
            windows = windows.slice();
        }
        function activateFinder() {
            let finder = activeWindow && activeWindow.appKind === "finder" ? activeWindow : windows.filter(w => w.appKind === "finder" && !w.closing).slice(-1)[0];
            if (finder)
                focusWindow(finder);
            else
                newWindow();
        }
        function openFolder(path) {
            let finder = activeWindow && activeWindow.appKind === "finder" ? activeWindow : windows.filter(w => w.appKind === "finder" && !w.closing).slice(-1)[0];
            if (finder) {
                finder.go(path);
                focusWindow(finder);
            } else
                newWindow(path);
        }
        function prompt(title, description, value, callback) {
            promptTitle = title;
            promptDescription = description;
            promptCallback = callback;
            promptInput.text = value;
            promptBox.open();
            Qt.callLater(function () {
                promptInput.forceActiveFocus();
                promptInput.selectAll();
            });
        }
        function acceptPrompt() {
            let cb = promptCallback;
            let value = promptInput.text;
            promptBox.close();
            if (cb)
                cb(value);
        }
        function showInfo(title, text) {
            infoTitle = title;
            infoText = text;
            infoBox.open();
        }
        function showPreview(path) {
            previewData = Bridge.preview(path);
            if (previewData.name) {
                Bridge.suite.setPreference("menubar.recentFiles",JSON.stringify([path].concat(recentFiles.filter(p=>p!==path)).slice(0,50)));
                preview.open();
            }
        }
        function selectedCount() {
            return activeWindow ? (activeWindow.selected || []).length : desktopFiles.selected.length;
        }
        function row(label, command, shortcut, enabled, checked) {
            return {
                label: label,
                command: command,
                shortcut: shortcut || "",
                enabled: enabled === undefined ? true : enabled,
                checked: checked || false
            };
        }
        function sep() {
            return {
                separator: true
            };
        }
        function menuRows(name) {
            let w = activeWindow;
            let has = !!w;
            if (has && w.appKind === "settings" && name !== "apple") {
                if (name === "System Settings")
                    return [row("About System Settings", "about"), sep(), row("Close System Settings", "close", "⌘W")];
                if (name === "Edit")
                    return [row("Undo", "settingsedit:undo", "⌘Z", w.searchFocused), sep(), row("Cut", "settingsedit:cut", "⌘X", w.searchFocused), row("Copy", "settingsedit:copy", "⌘C", w.searchFocused), row("Paste", "settingsedit:paste", "⌘V", w.searchFocused), row("Select All", "settingsedit:selectAll", "⌘A", w.searchFocused)];
                if (name === "View")
                    return w.pages.map(p => row(p.name, "settings:" + p.name, "", true, w.page === p.name));
                if (name === "Window")
                    return [row("Minimize", "minimize", "⌘M", !w.isFullscreen), row("Zoom", "zoom"), row(w.isFullscreen ? "Exit Full Screen" : "Enter Full Screen", "fullscreen", "⌃⌘F")].concat(windows.map((item, i) => row(item.windowTitle, "window:" + i, "", true, item === w)));
                if (name === "Help")
                    return [row("About This Prototype", "about")];
                return [];
            }
            if (has && w.appKind !== "finder" && name !== "apple")
                return AppMenus.rows(w.appKind,name,w,desktop);
            if (name === "apple")
                return [row("About This Mac", "aboutmac"), sep(), row("System Settings…", "settings"), row("App Store…", "launch:appstore"), sep(), {label:"Recent Items", submenu: recentMenuRows()}, sep(), row("Force Quit…", "forcequit", "⌥⌘⎋"), sep(), row("Sleep", "session:sleep"), row("Restart…", "session:restart"), row("Shut Down…", "session:shutdown"), sep(), row("Lock Screen", "session:lock", "⌃⌘Q"), row("Log Out " + Bridge.systemInfo.user + "…", "session:logout", "⇧⌘Q")];
            return FinderMenus.rows(name,w || desktopFiles,desktop,Bridge);
        }
        function openTopMenu(name, x) {
            systemPanel.close();
            searchOverlay.close();
            subMenu.close();
            if (menu.opened && openMenuName === name) {
                menu.close();
                return;
            }
            openMenuName = name;
            menu.rows = menuRows(name);
            menu.currentIndex = -1;
            if (menu.resetTracking) menu.resetTracking();
            menu.x = x;
            menu.y = 30;
            menu.open();
        }
        function openOptions(x, y, rows) {
            contextMenu.rows = rows;
            contextMenu.x = Math.max(8, Math.min(x, desktop.width - contextMenu.width - 8));
            contextMenu.y = Math.max(30, Math.min(y, desktop.height - contextMenu.height - 12));
            contextMenu.open();
        }
        function openContext(x, y, window) {
            focusWindow(window);
            let selected = selectedCount() > 0;
            let isTrash = window.browser.isTrash;
            if(window.browser.currentPath === "@applications") { openOptions(x,y,selected ? [row("Open","open")] : [row("as Icons","icons"),row("as List","list")]);return; }
            contextMenu.rows = selected ? [row("Open", "open"), row("Get Info", "getinfo", "⌘I"), row("Quick Look", "preview", "Space"), sep(), row("Rename…", "rename", "", !isTrash), row("Copy", "copy", "", !isTrash), row("Duplicate", "duplicate", "", !isTrash), sep(), row(isTrash ? "Put Back" : "Move to Trash", isTrash ? "restore" : "trash")] : [row("New Folder…", "newfolder", "", !isTrash && !window.browser.currentPath.startsWith("@")), row("Paste Items", "paste", "", Bridge.canPaste && !isTrash), sep(), row("Icon View", "icons"), row("List View", "list"), row("Column View", "columns")];
            contextMenu.x = Math.max(8, Math.min(x, desktop.width - contextMenu.width - 8));
            contextMenu.y = Math.min(y, desktop.height - contextMenu.height - 12);
            contextMenu.open();
        }
        function dispatch(command) {
            let w = activeWindow;
            if (command === "search") { openStatusPanel("search"); return; }
            if (command.startsWith("controlhide:")) { controls.setInMenu(command.slice(12),false); return; }
            if (command.startsWith("controladd:")) { controls.addControl(command.slice(11)); return; }
            if (command.startsWith("controlopen:")) { openStatusPanel(command.slice(12)); return; }
            if(command.startsWith("dockpin:")){toggleDockPin(command.slice(8));return;}
            if(command==="dockhiding"){dockAutoHide=!dockAutoHide;return;}
            if(command==="dockmagnification"){dockMagnification=!dockMagnification;return;}
            if(command.startsWith("dockshow:")){for(let window of windows.filter(i=>i.appKind===command.slice(9)&&!i.closing))focusWindow(window);return;}
            if(command.startsWith("revealapp:")){openFolder("@applications");activeWindow.selected=["@app:"+command.slice(10)];return;}
            if(command.startsWith("dockquit:")){let id=command.slice(9);for(let window of windows.filter(i=>i.appKind===id))closeWindow(window);if(id==="finder")newWindow();return;}
            if (command === "aboutmac") { openAbout(); return; }
            if (command.startsWith("launch:")) { openApplication(command.slice(7)); return; }
            if (command === "clearrecent") { recentApps=[]; Bridge.suite.setPreference("menubar.recentFiles","[]"); return; }
            if (command.startsWith("recentfile:")) { showPreview(command.slice(11)); return; }
            if (command === "forcequit") { forceQuit.open(); return; }
            if (command.startsWith("session:")) {
                requestSessionAction(command.slice(8));
                return;
            }
            if (command === "quit") {
                if (Bridge.session.enabled) requestSessionAction("logout"); else Qt.quit();
                return;
            }
            if (command === "apps") { openApplication("apps"); return; }
            if (command === "newwindow") {
                if (w && w.appKind !== "finder" && w.appKind !== "settings") { w.command("new"); return; }
                newWindow();
                return;
            }
            if (command.startsWith("go:")) {
                openFolder(command.slice(3));
                return;
            }
            if (command.startsWith("window:")) {
                focusWindow(windows[parseInt(command.slice(7))]);
                return;
            }
            if (command.startsWith("settingsedit:")) {
                if (w && w.appKind === "settings")
                    w.editSearch(command.slice(13));
                return;
            }
            if (command === "settings" || command.startsWith("settings:")) {
                openSettings(command.startsWith("settings:") ? command.slice(9) : "");
                return;
            }
            if (command === "appearance") {
                appearance.open();
                return;
            }
            if (command === "fullscreen") {
                fullscreenState.toggle(w);
                return;
            }
            if (command === "shellfullscreen") {
                app.visibility === Window.FullScreen ? app.showNormal() : app.showFullScreen();
                return;
            }
            if (command === "about") {
                showInfo("Tahoe Desktop", "A working desktop prototype\n\nDock, application menus and a Finder-style file manager, built with Qt Quick.\n\nFiles are stored in:\n" + Bridge.rootPath + "\n\nVersion 0.7 · Linux / macOS");
                return;
            }
            if (command === "help") {
                showInfo("Keyboard Shortcuts", "⌘N    New Finder window\n⌘W    Close window\n⌘M    Minimize window\n⇧⌘N    New folder\n⌘1 / ⌘2 / ⌘3    Change view\nSpace    Quick Look\nReturn    Rename\n⌘↓    Open selection\n⌘↑    Enclosing folder\n⌘C / ⌘V    Copy / Paste\n⌥⌘V    Move copied items here\n⌘⌫    Move to Trash\n⌘Z    Undo\n\nOn Linux use Ctrl in place of ⌘.\nEscape closes menus and previews.");
                return;
            }
            if (command === "showall" || command === "unhideall") {
                let kind = w ? w.appKind : "finder";
                for (let window of windows) if (command === "unhideall" || window.appKind === kind) {
                    window.appHidden = false;
                    if (!window.minimized) window.z = ++highestZ;
                }
                if (w) focusWindow(w);
                windows = windows.slice();
                return;
            }
            if (command === "hide" || command === "hideothers") {
                let kind = w ? w.appKind : "finder";
                for (let window of windows) if ((command === "hide" && window.appKind === kind) || (command === "hideothers" && window.appKind !== kind)) {
                    if (fullscreenState.window === window) fullscreenState.exit();
                    window.appHidden = true;
                }
                let remaining = windows.filter(item => !item.minimized && !item.appHidden && !item.closing).sort((a,b)=>a.z-b.z);
                activeWindow = null;
                if (remaining.length) focusWindow(remaining[remaining.length-1]);
                windows = windows.slice();
                return;
            }
            if (command === "undo") {
                if (w && w.appKind !== "finder") { if (w.command) w.command("undo"); return; }
                Bridge.undo();
                return;
            }
            if (!w) {
                if (command === "desktopcleanup") { desktopFiles.cleanUp(); return; }
                if (command === "desktopinfo") { showInfo("Desktop Info", Bridge.fileInfo("Desktop")); return; }
                if (["close","minimize","zoom","sidebar","pathbar","icons","list","columns","gallery","back","forward","up"].indexOf(command) >= 0) return;
                w = desktopFiles;
            }
            if (w.appKind === "settings") {
                if (command === "close")
                    closeWindow(w);
                else if (command === "minimize")
                    minimizeWindow(w);
                else if (command === "zoom")
                    w.zoom();
                else if (command === "back")
                    w.travel(-1);
                else if (command === "forward")
                    w.travel(1);
                return;
            }
            if (w.appKind !== "finder") {
                if (command === "close") closeWindow(w);
                else if (command === "minimize") minimizeWindow(w);
                else if (command === "zoom") w.zoom();
                else w.command(command.startsWith("app:") ? command.slice(4) : command);
                return;
            }
            if(w.browser.currentPath === "@applications" && (["trash","restore","rename","duplicate","paste","copy","move","newfolder","getinfo","preview","copypaths"].indexOf(command)>=0 || command.startsWith("tag:")))return;
            if (command.startsWith("tag:")) {
                Bridge.setTag(w.selected, command.slice(4));
                return;
            }
            switch (command) {
            case "getinfo":
                if (w.selected.length)
                    showInfo(w.selectedItem().name + " Info", Bridge.fileInfo(w.selected[0]));
                break;
            case "copypaths":
                Bridge.copyPathnames(w.selected);
                break;
            case "sortkind":
                w.browser.sortBy("kind");
                break;
            case "sortsize":
                w.browser.sortBy("size");
                break;
            case "gallery":
                w.viewMode = "gallery";
                break;
            case "newfolder":
                w.newFolder();
                break;
            case "open":
                w.openItem(w.selectedItem());
                break;
            case "preview":
                if (w.selected.length)
                    showPreview(w.selected[0]);
                break;
            case "rename":
                w.renameSelection();
                break;
            case "duplicate":
                Bridge.duplicate(w.selected);
                break;
            case "copy":
                Bridge.copy(w.selected);
                break;
            case "paste":
                Bridge.paste(w.browser.currentPath, false);
                break;
            case "move":
                Bridge.paste(w.browser.currentPath, true);
                break;
            case "trash":
                if (!w.browser.isTrash) {
                    Bridge.trash(w.selected);
                    w.selected = [];
                }
                break;
            case "restore":
                Bridge.restore(w.selected);
                w.selected = [];
                break;
            case "selectall":
                w.selectAll();
                break;
            case "close":
                closeWindow(w);
                break;
            case "minimize":
                minimizeWindow(w);
                break;
            case "zoom":
                w.zoom();
                break;
            case "icons":
            case "list":
            case "columns":
                w.viewMode = command;
                break;
            case "sidebar":
                w.sidebarVisible = !w.sidebarVisible;
                break;
            case "pathbar":
                w.pathbarVisible = !w.pathbarVisible;
                break;
            case "hidden":
                w.browser.toggleHidden();
                break;
            case "back":
                w.browser.back();
                break;
            case "forward":
                w.browser.forward();
                break;
            case "up":
                w.browser.up();
                break;
            case "sortname":
                w.browser.sortBy("name");
                break;
            case "sortdate":
                w.browser.sortBy("modified");
                break;
            }
        }

        Item {
            id: scene
            anchors.fill: parent
            Item {
                id: baseLayer
                anchors.fill: parent
                Item {
                    id: wallpaper
                    anchors.fill: parent
                    Image {
                        anchors.fill: parent
                        source: Bridge.assetRoot + "wallpaper-light.jpg"
                        fillMode: Image.PreserveAspectCrop
                    }
                    Image {
                        anchors.fill: parent
                        source: Bridge.assetRoot + "wallpaper-dark.jpg"
                        fillMode: Image.PreserveAspectCrop
                        opacity: desktop.wallpaperIsDark ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: desktop.reduceMotion ? 0 : 220
                                easing.type: Easing.InOutCubic
                            }
                        }
                    }
                }
                DesktopSurface {
                    id: desktopFiles
                    anchors.fill: parent
                    desktop: desktop
                }
            }
            Item {
                id: windowLayer
                anchors.fill: parent
            }
            Rectangle {
                anchors.fill: parent
                z: 100000
                color: "black"
                opacity: (1-Math.max(0.15,Math.min(1,Number(desktop.preference("display.brightness","1")) || 0.15)))*0.65
                enabled: false
            }
        }

        property alias fileDragLayer: fileDragLayer
        Item { id: fileDragLayer; anchors.fill: parent; z: 800 }

        Item {
            id: topChrome
            objectName: "topChrome"
            z: 11000
            width: parent.width
            height: 30
            y: fullscreenState.active ? (fullscreenState.chromeVisible ? 0 : -30) : desktop.desktopMenuAutoHide && !desktop.menuBarRevealed ? -30 : 0
            enabled: fullscreenState.active ? fullscreenState.chromeVisible : !desktop.desktopMenuAutoHide || desktop.menuBarRevealed
            HoverHandler { id: normalMenuHover; onHoveredChanged: desktop.updateMenuBarVisibility() }
            Behavior on y {
                NumberAnimation {
                    duration: desktop.reduceMotion ? 0 : 180
                    easing.type: Easing.OutCubic
                }
            }
            Rectangle {
                id: menuBar
                objectName: "menuBarBackground"
                z: 0
                x: 0
                y: 0
                width: parent.width
                height: 30
                color: fullscreenState.active ? "#000000" : desktop.reduceTransparency ? (desktop.dark ? "#292b30" : "#738a9b") : desktop.menuBarBackground ? "#550d1420" : "transparent"
            }
            Row {
                id: menuLabels
                z: 1
                x: 10
                y: 0
                spacing: 0
                height: 30
                Repeater {
                    id: topMenuItems
                    model: desktop.activeAppName === "Finder" ? ["apple", "Finder", "File", "Edit", "View", "Go", "Window", "Help"] : desktop.activeAppName === "System Settings" ? ["apple", "System Settings", "Edit", "View", "Window", "Help"] : ["apple"].concat(AppMenus.names(desktop.activeWindow ? desktop.activeWindow.appKind : "finder", desktop.activeAppName))
                    delegate: Rectangle {
                        id: menuLabel
                        required property string modelData
                        width: modelData === "apple" ? 37 : label.implicitWidth + 24
                        height: 30
                        radius: 5
                        color: menu.opened && desktop.openMenuName === modelData ? "#35ffffff" : menuHover.containsMouse ? "#16ffffff" : "transparent"
                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: menuLabel.modelData === "apple" ? "" : menuLabel.modelData
                            font.pixelSize: 13
                            font.weight: menuLabel.modelData === desktop.activeAppName ? Font.DemiBold : Font.Normal
                            color: "white"
                        }
                        Icon {
                            visible: menuLabel.modelData === "apple"
                            anchors.centerIn: parent
                            width: 17
                            height: 19
                            name: "apple"
                            color: "white"
                        }
                        MouseArea {
                            id: menuHover
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                let p = menuLabel.mapToItem(desktop, 0, 0);
                                desktop.openTopMenu(menuLabel.modelData, p.x);
                            }
                            onEntered: if (menu.opened && desktop.openMenuName !== menuLabel.modelData) {
                                let p = menuLabel.mapToItem(desktop, 0, 0);
                                desktop.openTopMenu(menuLabel.modelData, p.x);
                            }
                            Accessible.role: Accessible.MenuItem
                            Accessible.name: menuLabel.modelData === "apple" ? "Desktop menu" : menuLabel.modelData
                            Accessible.onPressAction: clicked(null)
                        }
                    }
                }
            }
            StatusBar {
                id: statusItems
                desktop: desktop
                anchors.right: parent.right
                anchors.rightMargin: 12
                availableWidth: desktop.width - menuLabels.width - 38
            }
        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: desktop.now = new Date()
        }

        DesktopDock {
            id: dock
            z: 9000
            desktop: desktop
            backdrop: scene
        }

        // Qt Quick Popups receive pointer events in Overlay.overlay. Track the
        // bar in that same overlay while a menu is open, so hovering adjacent
        // titles works without a second click (including the Apple menu).
        MouseArea {
            objectName: "menuBarTracking"
            parent: Overlay.overlay
            z: 10001
            x: menuLabels.x
            y: topChrome.y
            width: menuLabels.width
            height: 30
            visible: menu.visible
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            function labelAt(px) {
                for (let i = 0; i < topMenuItems.count; i++) {
                    let label = topMenuItems.itemAt(i);
                    if (label && px >= label.x && px < label.x + label.width) return label;
                }
                return null;
            }
            onPositionChanged: function(mouse) {
                let label = labelAt(mouse.x);
                if (label && desktop.openMenuName !== label.modelData)
                    desktop.openTopMenu(label.modelData, menuLabels.x + label.x);
            }
            onClicked: function(mouse) {
                let label = labelAt(mouse.x);
                if (label) desktop.openTopMenu(label.modelData, menuLabels.x + label.x);
            }
        }

        GlassMenu {
            id: menu
            objectName: "topMenu"
            accentColor: desktop.accentColor
            maximumHeight: desktop.height - 42
            onSubmenuDismissed: if(subMenu.parent===menu.contentItem) subMenu.close()
            parent: Overlay.overlay
            dark: desktop.dark
            backdrop: scene
            reducedMotion: desktop.reduceMotion
            reducedTransparency: desktop.reduceTransparency
            onChosen: function (command) {
                desktop.dispatch(command);
            }
            onClosed: { desktop.openMenuName = ""; if(subMenu.parent===menu.contentItem)subMenu.close(); }
            onSubmenuRequested: function(rows, offset) { subMenu.parent=menu.contentItem;subMenu.rows=rows;subMenu.x=menu.x+menu.width+subMenu.width>desktop.width-12 ? -subMenu.width+8 : menu.width-8;subMenu.y=Math.max(-menu.y+6,Math.min(desktop.height-subMenu.height-menu.y-18,offset));subMenu.open(); }
            onTraverse: function (direction) {
                let names = topMenuItems.model;
                let index = (names.indexOf(desktop.openMenuName) + direction + names.length) % names.length;
                desktop.openTopMenu(names[index], menuLabels.x + topMenuItems.itemAt(index).x);
            }
        }
        GlassMenu {
            id: subMenu
            objectName: "subMenu"
            accentColor: desktop.accentColor
            maximumHeight: desktop.height - 42
            parent: Overlay.overlay
            dark: desktop.dark
            backdrop: scene
            reducedMotion: desktop.reduceMotion
            reducedTransparency: desktop.reduceTransparency
            onChosen: function(command) { menu.close(); contextMenu.close(); desktop.dispatch(command); }
            onTraverse: function(direction) { if(direction<0) { let owner=parent===menu.contentItem?menu:contextMenu;close();owner.forceActiveFocus(); } }
        }
        Dialog {
            id: sessionConfirm
            objectName: "sessionConfirm"
            parent: Overlay.overlay
            anchors.centerIn: parent
            width: Math.min(440, desktop.width - 40)
            height: 190
            modal: true
            title: desktop.sessionAction === "logout" ? "Log Out?" : desktop.sessionAction === "restart" ? "Restart?" : "Shut Down?"
            standardButtons: Dialog.Ok | Dialog.Cancel
            contentItem: Label {
                wrapMode: Text.WordWrap
                text: "Your desktop drafts will be saved. Save work in other Linux applications before continuing."
            }
            onAccepted: {
                app.flushApplications();
                desktop.sessionEnding = desktop.sessionAction === "logout";
                Bridge.session.perform(desktop.sessionAction);
            }
        }
        SystemPanel {
            id: systemPanel
            objectName: "systemPanel"
            desktop: desktop
            parent: Overlay.overlay
            backdrop: scene
            section: desktop.statusPanel
        }
        ControlGallery {
            id: controlGallery
            objectName: "controlGallery"
            desktop: desktop
            parent: Overlay.overlay
            backdrop: scene
        }
        GlassMenu {
            id: contextMenu
            objectName: "contextMenu"
            accentColor: desktop.accentColor
            maximumHeight: desktop.height - 42
            onSubmenuDismissed: if(subMenu.parent===contextMenu.contentItem) subMenu.close()
            onSubmenuRequested: function(rows,offset){subMenu.parent=contextMenu.contentItem;subMenu.rows=rows;subMenu.x=contextMenu.x+contextMenu.width+subMenu.width>desktop.width-12 ? -subMenu.width+8 : contextMenu.width-8;subMenu.y=Math.min(desktop.height-subMenu.height-contextMenu.y-18,offset);subMenu.open();}
            onClosed: if(subMenu.parent===contextMenu.contentItem)subMenu.close()
            parent: Overlay.overlay
            dark: desktop.dark
            backdrop: scene
            reducedMotion: desktop.reduceMotion
            reducedTransparency: desktop.reduceTransparency
            onChosen: function (command) {
                desktop.dispatch(command);
            }
        }

        MaterialPopup {
            id: forceQuit
            objectName: "forceQuitPanel"
            reducedMotion: desktop.reduceMotion
            parent: Overlay.overlay
            width: 410; height: 390
            x: (desktop.width-width)/2; y: 100
            modal: true; focus: true
            background: Rectangle {radius:20;color:desktop.dark?"#303841":"#f4f5f7";border.color:desktop.dark?"#64707c":"#b6bec9"}
            contentItem: Column {
                spacing:14
                Text {text:"Force Quit Applications";font.pixelSize:19;font.weight:Font.DemiBold;color:desktop.dark?"white":"#222"}
                Text {width:parent.width;text:"Select an application in this desktop to close it.";wrapMode:Text.Wrap;color:desktop.dark?"#bbc2cd":"#68707d"}
                ListView {width:parent.width;height:245;clip:true;model:desktop.windows.filter(w=>!w.closing)
                    delegate:ItemDelegate {required property var modelData;width:ListView.view.width;height:44;text:modelData.windowTitle
                        contentItem:Text{text:parent.text;color:desktop.dark?"white":"#252a30";verticalAlignment:Text.AlignVCenter}
                        onClicked:{desktop.closeWindow(modelData);forceQuit.close();}
                    }
                }
                DialogButton {text:"Cancel";dark:desktop.dark;onClicked:forceQuit.close()}
            }
        }
        MaterialPopup {
            id: promptBox
            reducedMotion: desktop.reduceMotion
            parent: Overlay.overlay
            width: 420
            height: 211
            x: (desktop.width - width) / 2
            y: (desktop.height - height) / 2
            modal: true
            focus: true
            padding: 24
            closePolicy: Popup.CloseOnEscape
            background: Glass {
                backdrop: scene
                reducedTransparency: desktop.reduceTransparency
                reveal: promptBox.materialization
                sampleX: promptBox.x
                sampleY: promptBox.y
                dark: desktop.dark
                corner: 20
                tint: 0.94
            }
            contentItem: Column {
                spacing: 12
                Text {
                    text: desktop.promptTitle
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    color: desktop.dark ? "white" : "#20252b"
                }
                Text {
                    text: desktop.promptDescription
                    font.pixelSize: 12
                    color: desktop.dark ? "#c6ccd4" : "#626973"
                }
                TextField {
                    id: promptInput
                    width: parent.width
                    height: 34
                    selectByMouse: true
                    font.pixelSize: 13
                    color: desktop.dark ? "white" : "#20252b"
                    background: Rectangle {
                        radius: 7
                        color: desktop.dark ? "#28313b" : "white"
                        border.color: promptInput.activeFocus ? "#087cff" : "#a7adb5"
                        border.width: 2
                    }
                    onAccepted: desktop.acceptPrompt()
                    Accessible.name: "Item name"
                }
                Row {
                    anchors.right: parent.right
                    spacing: 8
                    DialogButton {
                        dark: desktop.dark
                        text: "Cancel"
                        onClicked: promptBox.close()
                    }
                    DialogButton {
                        dark: desktop.dark
                        text: "Save"
                        primary: true
                        onClicked: desktop.acceptPrompt()
                    }
                }
            }
            onClosed: if (desktop.activeWindow)
                desktop.activeWindow.activate()
        }
        MaterialPopup {
            id: infoBox
            reducedMotion: desktop.reduceMotion
            parent: Overlay.overlay
            width: 450
            height: Math.min(desktop.infoTitle === "Keyboard Shortcuts" ? 520 : desktop.infoTitle === "Tahoe Desktop" ? 360 : 230, desktop.height - 120)
            x: (desktop.width - width) / 2
            y: (desktop.height - height) / 2
            modal: true
            focus: true
            padding: 24
            background: Glass {
                backdrop: scene
                reducedTransparency: desktop.reduceTransparency
                reveal: infoBox.materialization
                sampleX: infoBox.x
                sampleY: infoBox.y
                dark: desktop.dark
                corner: 22
                tint: 0.94
            }
            contentItem: ColumnLayout {
                spacing: 18
                Text {
                    text: desktop.infoTitle
                    font.pixelSize: 19
                    font.weight: Font.DemiBold
                    color: desktop.dark ? "white" : "#20252b"
                }
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    Text {
                        width: infoBox.availableWidth
                        text: desktop.infoText
                        wrapMode: Text.Wrap
                        font.pixelSize: 13
                        lineHeight: 1.25
                        color: desktop.dark ? "#e1e6ec" : "#424a55"
                    }
                }
                DialogButton {
                    dark: desktop.dark
                    Layout.alignment: Qt.AlignRight
                    text: "Done"
                    onClicked: infoBox.close()
                }
            }
        }
        MaterialPopup {
            id: preview
            reducedMotion: desktop.reduceMotion
            parent: Overlay.overlay
            width: Math.min(790, desktop.width - 100)
            height: Math.min(600, desktop.height - 110)
            x: (desktop.width - width) / 2
            y: (desktop.height - height) / 2
            modal: false
            focus: true
            padding: 0
            closePolicy: Popup.CloseOnEscape
            background: Glass {
                backdrop: scene
                reducedTransparency: desktop.reduceTransparency
                reveal: preview.materialization
                sampleX: preview.x
                sampleY: preview.y
                dark: desktop.dark
                corner: 18
                tint: 0.96
            }
            contentItem: FocusScope {
                focus: true
                IconButton {
                    x: 12
                    y: 10
                    symbol: "close"
                    tip: "Close Quick Look"
                    dark: desktop.dark
                    onClicked: preview.close()
                }
                Text {
                    x: 52
                    y: 15
                    width: parent.width - 80
                    text: desktop.previewData.name || ""
                    elide: Text.ElideMiddle
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: desktop.dark ? "white" : "#252a30"
                }
                Image {
                    x: 20
                    y: 58
                    width: parent.width - 40
                    height: parent.height - 100
                    visible: !!desktop.previewData.image
                    source: desktop.previewData.image || ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
                ScrollView {
                    x: 28
                    y: 60
                    width: parent.width - 56
                    height: parent.height - 104
                    visible: !desktop.previewData.image
                    clip: true
                    TextArea {
                        readOnly: true
                        selectByMouse: true
                        text: desktop.previewData.text || ""
                        wrapMode: TextEdit.Wrap
                        font.family: Bridge.isMac ? "Menlo" : "monospace"
                        font.pixelSize: 13
                        color: desktop.dark ? "#e4e8ed" : "#333a44"
                        background: Item {}
                    }
                }
                Text {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 16
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: desktop.previewData.kind || ""
                    font.pixelSize: 11
                    color: desktop.dark ? "#aeb6c0" : "#777f89"
                }
                Keys.onSpacePressed: preview.close()
                Keys.onRightPressed: if (desktop.activeWindow)
                    if (desktop.activeWindow.appKind === "finder")
                        desktop.activeWindow.previewStep(1)
                Keys.onLeftPressed: if (desktop.activeWindow)
                    if (desktop.activeWindow.appKind === "finder")
                        desktop.activeWindow.previewStep(-1)
            }
        }
        MaterialPopup {
            id: appearance
            reducedMotion: desktop.reduceMotion
            parent: Overlay.overlay
            width: 288
            height: 270
            x: desktop.width - width - 14
            y: 37
            focus: true
            padding: 20
            background: Glass {
                backdrop: scene
                reducedTransparency: desktop.reduceTransparency
                reveal: appearance.materialization
                sampleX: appearance.x
                sampleY: appearance.y
                dark: desktop.dark
                corner: 22
                tint: desktop.dark ? 0.68 : 0.7
                shadowOpacity: 0.2
            }
            contentItem: Column {
                spacing: 17
                Text {
                    text: "Appearance"
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    color: desktop.dark ? "white" : "#252a31"
                }
                Row {
                    spacing: 12
                    Repeater {
                        model: [false, true]
                        delegate: Rectangle {
                            required property bool modelData
                            width: 116
                            height: 83
                            radius: 11
                            color: modelData ? "#2d3541" : "#edf3fa"
                            border.width: desktop.dark === modelData ? 2 : 1
                            border.color: desktop.dark === modelData ? "#087cff" : "#4a929aa5"
                            Icon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 12
                                width: 26
                                height: 26
                                name: modelData ? "moon" : "sun"
                                color: modelData ? "#eef3ff" : "#3d5579"
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 49
                                text: modelData ? "Dark" : "Light"
                                font.pixelSize: 12
                                color: modelData ? "white" : "#28303d"
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: desktop.setAppearance(modelData ? "dark" : "light")
                                Accessible.role: Accessible.RadioButton
                                Accessible.name: modelData ? "Dark appearance" : "Light appearance"
                                Accessible.checked: desktop.dark === modelData
                                Accessible.onPressAction: clicked(null)
                            }
                        }
                    }
                }
                Column {
                    spacing: 3
                    ToggleSwitch {
                        dark: desktop.dark
                        reducedMotion: desktop.reduceMotion
                        text: "Reduce motion"
                        checked: desktop.reduceMotion
                        onCheckedChanged: if (desktop.reduceMotion !== checked)
                            desktop.reduceMotion = checked
                    }
                    ToggleSwitch {
                        dark: desktop.dark
                        reducedMotion: desktop.reduceMotion
                        text: "Reduce transparency"
                        checked: desktop.reduceTransparency
                        onCheckedChanged: if (desktop.reduceTransparency !== checked)
                            desktop.reduceTransparency = checked
                    }
                }
                Text {
                    text: "Applies to this desktop."
                    font.pixelSize: 11
                    color: desktop.dark ? "#bac3ce" : "#697382"
                }
            }
        }
        MaterialPopup {
            id: searchOverlay
            reducedMotion: desktop.reduceMotion
            parent: Overlay.overlay
            width: Math.min(600, desktop.width - 100)
            height: 104
            x: (desktop.width - width) / 2
            y: desktop.height * 0.21
            focus: true
            padding: 20
            background: Glass {
                backdrop: scene
                reducedTransparency: desktop.reduceTransparency
                reveal: searchOverlay.materialization
                sampleX: searchOverlay.x
                sampleY: searchOverlay.y
                dark: desktop.dark
                corner: 24
                tint: desktop.dark ? 0.66 : 0.72
                shadowOpacity: 0.2
            }
            contentItem: Column {
                spacing: 8
                TextField {
                    id: spotlightInput
                    width: parent.width
                    height: 35
                    placeholderText: "Go to a folder: Documents, Pictures…"
                    font.pixelSize: 19
                    color: desktop.dark ? "white" : "#252b34"
                    background: Item {}
                    onAccepted: {
                        desktop.openFolder(text);
                        searchOverlay.close();
                        text = "";
                    }
                    Accessible.name: "Go to folder"
                }
                Text {
                    text: "Enter a path within your desktop workspace."
                    font.pixelSize: 11
                    color: desktop.dark ? "#b7c0cb" : "#707b89"
                }
            }
        }
        Connections {
            target: Bridge
            function onError(message) {
                desktop.showInfo("The action couldn’t be completed", message);
            }
        }
        Component {
            id: finderComponent
            FinderWindow {}
        }
        Component {
            id: aboutComponent
            AboutMacWindow {}
        }
        Component {
            id: suiteComponent
            SuiteWindow {}
        }
        Component {
            id: settingsComponent
            SettingsWindow {}
        }
        Component.onCompleted: {
            newWindow();
            if (startSettings)
                openSettings("");
        }
        Repeater {
            model: [
                {key: "O", action: "open"},
                {key: "Alt+C", action: "copypaths"},
                {key: "Y", action: "preview"},
                {key: "Alt+S", action: "sidebar"},
                {key: "Alt+P", action: "pathbar"},
                {key: "Shift+A", action: "go:@applications"},
                {key: "Shift+F", action: "go:@recents"},
                {key: "Alt+H", action: "hideothers"},
                {
                    key: "N",
                    action: "newwindow"
                },
                {
                    key: "W",
                    action: "close"
                },
                {
                    key: "M",
                    action: "minimize"
                },
                {
                    key: "H",
                    action: "hide"
                },
                {
                    key: "Shift+N",
                    action: "newfolder"
                },
                {
                    key: "1",
                    action: "icons"
                },
                {
                    key: "2",
                    action: "list"
                },
                {
                    key: "3",
                    action: "columns"
                },
                {
                    key: "4",
                    action: "gallery"
                },
                {
                    key: "I",
                    action: "getinfo"
                },
                {
                    key: "C",
                    action: "copy"
                },
                {
                    key: "V",
                    action: "paste"
                },
                {
                    key: "Alt+V",
                    action: "move"
                },
                {
                    key: "Z",
                    action: "undo"
                },
                {
                    key: "D",
                    action: "duplicate"
                },
                {
                    key: "A",
                    action: "selectall"
                },
                {
                    key: "Backspace",
                    action: "trash"
                },
                {
                    key: "Up",
                    action: "up"
                },
                {
                    key: "Down",
                    action: "open"
                },
                {
                    key: "[",
                    action: "back"
                },
                {
                    key: "]",
                    action: "forward"
                },
                {
                    key: "Shift+.",
                    action: "hidden"
                },
                {
                    key: "Shift+H",
                    action: "go:"
                },
                {
                    key: "Shift+D",
                    action: "go:Desktop"
                },
                {
                    key: "Shift+O",
                    action: "go:Documents"
                },
                {
                    key: "Alt+L",
                    action: "go:Downloads"
                }
            ]
            delegate: Item {
                required property var modelData
                Shortcut {
                    sequence: Bridge.modifier + "+" + modelData.key
                    enabled: !promptBox.opened && !infoBox.opened && !forceQuit.opened && !preview.opened && (["close", "minimize", "newwindow", "hide", "hideothers"].indexOf(modelData.action) >= 0 || !desktop.editing)
                    onActivated: desktop.dispatch(modelData.action)
                }
            }
        }
        Shortcut {
            sequence: Bridge.isMac ? "Ctrl+Meta+F" : "F11"
            enabled: !promptBox.opened && !infoBox.opened && !forceQuit.opened && !preview.opened
            onActivated: fullscreenState.toggle(desktop.activeWindow)
        }
        Shortcut {
            sequence: "Escape"
            enabled: fullscreenState.active && !desktop.editing && !preview.opened && !menu.opened && !contextMenu.opened
            onActivated: fullscreenState.exit()
        }
        Shortcut {
            sequence: Bridge.modifier + "+Q"
            enabled: !!desktop.activeWindow && desktop.activeWindow.appKind !== "finder" && !promptBox.opened && !infoBox.opened && !forceQuit.opened
            onActivated: desktop.closeWindow(desktop.activeWindow)
        }
        Shortcut {
            sequence: "Ctrl+Alt+Q"
            onActivated: if (Bridge.session.enabled) desktop.requestSessionAction("logout"); else Qt.quit()
        }
    }
}
