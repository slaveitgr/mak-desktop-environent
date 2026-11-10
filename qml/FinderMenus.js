.pragma library

// Source: work/rea-reference/finder.ui-reference.json; resource-only REA.
// Menu labels, parent-menu membership and key equivalents are observed in:
// /System/Library/CoreServices/Finder.app/Contents/Resources/Base.lproj/MenuBar.nib
// ev_6c940a0068b34aa3b865a23e40e19d4da3c2280efbb0ce9b25e78c6361de98cf
// Sort labels are also observed in Base.lproj/ArrangeByMenu.nib, same evidence.
// LocalizableMerged.strings provides Quick Look (N169.17), Put Back (N153.1),
// Use Stacks (N148.1) and Tags… (N160):
// ev_22d8fb968a245334ceaf662718e08567353957990d15e9d17fdf74f28e40b859.
//
// This is a conservative visible-menu reconstruction: archive object order is
// not runtime menu order. Option-key alternates, Quit Finder, burn-disc entries
// and legacy/hidden controls are deliberately omitted. Settings… modernizes the
// archived Preferences… label; its exact current runtime spelling is unverified.
// Tags uses the existing local color commands in a submenu rather than claiming
// the native tag-editor popover. Pictures/Trash navigation and the final Help
// entries preserve working prototype features; their membership is not native.
//
// rows(name, host, desktop, bridge) is side-effect free. Commands are dispatched
// by Main. Unsupported native features have enabled:false and no command.

function item(label, command, shortcut, enabled, checked, submenu) {
    var result = {
        label: label,
        command: command || "",
        shortcut: shortcut || "",
        enabled: enabled === undefined ? true : !!enabled,
        checked: !!checked
    };
    if (submenu) result.submenu = submenu;
    return result;
}
function disabled(label, shortcut) { return item(label, "", shortcut, false); }
function separator() { return {separator: true}; }

function rows(name, host, desktop, bridge) {
    desktop = desktop || {};
    bridge = bridge || {};
    var windows = desktop.windows || [];
    var finder = host && host.appKind === "finder" && host.browser ? host : null;
    var has = !!finder;
    var isDesktop = has && finder.isDesktop === true;
    var windowAvailable = has && !isDesktop;
    var browser = has ? finder.browser : null;
    var path = has ? browser.currentPath : "";
    var selected = has && finder.selected && finder.selected.length > 0;
    var trash = has && browser.isTrash;
    var applications = has && path === "@applications";
    // Preserve Main's virtual-folder guards: Recents/tag results can operate on
    // selected files, but cannot be destinations for new folders/paste/move.
    // Applications is a read-only launcher; Trash only restores selected files.
    var editable = has && !trash && !applications;
    var normal = editable && !path.startsWith("@");
    var inspectable = selected && !applications;
    var cmd = desktop.shortcutMark || (bridge.isMac === false ? "Ctrl+" : "⌘");
    var fullScreenShortcut = bridge.isMac === false ? "F11" : "⌃⌘F";
    var finderWindows = windows.filter(function (window) { return window.appKind === "finder" && !window.closing; });
    var liveWindows = windows.filter(function (window) { return !window.closing; });
    var otherWindows = liveWindows.some(function (window) { return window.appKind !== "finder"; });

    if (name === "Finder") {
        return [
            item("About Finder", "about"),
            separator(),
            disabled("Settings…", cmd + ","),
            disabled("Empty Trash…", "⇧" + cmd + "⌫"),
            separator(),
            disabled("Services"),
            separator(),
            item("Hide Finder", "hide", cmd + "H", finderWindows.length > 0),
            item("Hide Others", "hideothers", "⌥" + cmd + "H", otherWindows),
            item("Show All", "unhideall", "", liveWindows.length > 0)
        ];
    }
    if (name === "File") {
        var tags = ["Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Gray"].map(function (color) {
            return item(color, "tag:" + color, "", selected && editable);
        });
        tags.push(separator(), item("Remove Tags", "tag:", "", selected && editable));
        return [
            item("New Finder Window", "newwindow", cmd + "N"),
            item("New Folder", "newfolder", "⇧" + cmd + "N", normal),
            disabled("New Folder with Selection", "⌃" + cmd + "N"),
            disabled("New Smart Folder"),
            disabled("New Tab", cmd + "T"),
            separator(),
            item("Open", "open", cmd + "O", selected),
            disabled("Open With"),
            item("Close Window", "close", cmd + "W", windowAvailable),
            separator(),
            item("Get Info", "getinfo", cmd + "I", inspectable),
            item("Rename", "rename", "Return", selected && editable),
            disabled("Compress"),
            item("Duplicate", "duplicate", cmd + "D", selected && editable),
            disabled("Make Alias", "⌃" + cmd + "A"),
            item("Quick Look", "preview", cmd + "Y", inspectable),
            disabled("Print", cmd + "P"),
            disabled("Share…"),
            separator(),
            disabled("Show Original", cmd + "R"),
            disabled("Add to Sidebar", "⌃" + cmd + "T"),
            item(trash ? "Put Back" : "Move to Trash", trash ? "restore" : "trash", cmd + "⌫", inspectable),
            disabled("Eject", cmd + "E"),
            separator(),
            item("Tags…", "", "", selected && editable, false, tags),
            separator(),
            disabled("Find", cmd + "F")
        ];
    }
    if (name === "Edit") {
        return [
            item(bridge.undoTitle ? "Undo " + bridge.undoTitle : "Undo", "undo", cmd + "Z", !!bridge.undoTitle),
            disabled("Redo", "⇧" + cmd + "Z"),
            separator(),
            disabled("Cut", cmd + "X"),
            item("Copy", "copy", cmd + "C", selected && editable),
            item("Copy as Pathname", "copypaths", "⌥" + cmd + "C", inspectable),
            item(bridge.canPaste ? "Paste Items" : "Paste", "paste", cmd + "V", normal && bridge.canPaste),
            item("Move Items Here", "move", "⌥" + cmd + "V", normal && bridge.canPaste),
            item("Select All", "selectall", cmd + "A", has),
            separator(),
            disabled("Show Clipboard")
        ];
    }
    if (name === "View") {
        var sorting = [
            item("Name", "sortname", "", has),
            item("Kind", "sortkind", "", has),
            disabled("Date Last Opened"),
            disabled("Date Added"),
            item("Date Modified", "sortdate", "", has),
            disabled("Date Created"),
            item("Size", "sortsize", "", has),
            disabled("Tags")
        ];
        return [
            item("as Icons", "icons", cmd + "1", windowAvailable, windowAvailable && finder.viewMode === "icons"),
            item("as List", "list", cmd + "2", windowAvailable, windowAvailable && finder.viewMode === "list"),
            item("as Columns", "columns", cmd + "3", windowAvailable, windowAvailable && finder.viewMode === "columns"),
            item("as Gallery", "gallery", cmd + "4", windowAvailable, windowAvailable && finder.viewMode === "gallery"),
            separator(),
            disabled(windowAvailable ? "Use Groups" : "Use Stacks", "⌃" + cmd + "0"),
            disabled("Group By"),
            item("Sort By", "", "", has, false, sorting),
            item("Clean Up", "desktopcleanup", "", isDesktop),
            disabled("Clean Up By"),
            separator(),
            item(windowAvailable && finder.sidebarVisible ? "Hide Sidebar" : "Show Sidebar", "sidebar", "⌥" + cmd + "S", windowAvailable),
            disabled("Show Preview", "⇧" + cmd + "P"),
            separator(),
            disabled("Hide Toolbar", "⌥" + cmd + "T"),
            disabled("Show All Tabs", "⇧" + cmd + "\\"),
            disabled("Show Tab Bar", "⇧" + cmd + "T"),
            item(windowAvailable && finder.pathbarVisible ? "Hide Path Bar" : "Show Path Bar", "pathbar", "⌥" + cmd + "P", windowAvailable),
            disabled("Hide Status Bar", cmd + "/"),
            item("Show / Hide Hidden Files", "hidden", "⇧" + cmd + ".", has),
            separator(),
            disabled("Customize Toolbar…"),
            disabled("Show View Options", cmd + "J"),
            disabled("Show Preview Options"),
            separator(),
            item(has && finder.isFullscreen ? "Exit Full Screen" : "Enter Full Screen", "fullscreen", fullScreenShortcut, windowAvailable)
        ];
    }
    if (name === "Go") {
        return [
            item("Back", "back", cmd + "[", has && browser.canBack),
            item("Forward", "forward", cmd + "]", has && browser.canForward),
            item("Enclosing Folder", "up", cmd + "↑", windowAvailable),
            separator(),
            item("Recents", "go:@recents", "⇧" + cmd + "F"),
            item("Documents", "go:Documents", "⇧" + cmd + "O"),
            item("Desktop", "go:Desktop", "⇧" + cmd + "D"),
            item("Downloads", "go:Downloads", "⌥" + cmd + "L"),
            item("Home", "go:", "⇧" + cmd + "H"),
            disabled("Computer", "⇧" + cmd + "C"),
            disabled("AirDrop", "⇧" + cmd + "R"),
            disabled("Network", "⇧" + cmd + "K"),
            disabled("iCloud Drive", "⇧" + cmd + "I"),
            disabled("Shared", "⇧" + cmd + "S"),
            item("Applications", "go:@applications", "⇧" + cmd + "A"),
            disabled("Utilities", "⇧" + cmd + "U"),
            item("Pictures", "go:Pictures"),
            item("Trash", "go:.Trash"),
            separator(),
            disabled("Recent Folders"),
            separator(),
            disabled("Go to Folder…", "⇧" + cmd + "G"),
            disabled("Connect to Server…", cmd + "K")
        ];
    }
    if (name === "Window") {
        var result = [
            item("Minimize", "minimize", cmd + "M", windowAvailable && !finder.isFullscreen),
            item("Zoom", "zoom", "", windowAvailable),
            disabled("Cycle Through Windows", cmd + "`"),
            separator(),
            item("Bring All to Front", "showall", "", finderWindows.length > 0),
            disabled("Show Progress Window")
        ];
        if (finderWindows.length) result.push(separator());
        // Preserve original desktop.windows indices for Main's window:<index> route.
        windows.forEach(function (window, index) {
            if (window.appKind === "finder" && !window.closing)
                result.push(item(window.windowTitle, "window:" + index, "", true, window === finder));
        });
        return result;
    }
    if (name === "Help") {
        return [
            disabled("Mac User Guide", cmd + "?"),
            disabled("Tips for Your Mac"),
            separator(),
            item("Keyboard Shortcuts", "help"),
            item("Appearance…", "appearance"),
            item("About This Prototype", "about")
        ];
    }
    return [];
}
