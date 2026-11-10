.pragma library

// Native artwork is exported with public AppKit APIs. Finder title assignments
// below are resolved NSActionImage/NSImage links from the existing REA MenuBar.nib
// graph (not screenshots or runtime visibility evidence). Other assignments are
// semantic inferences. Reusing a Finder title in another app does not establish
// that app's native menu assignment. See assets/symbols/menu.provenance.json.
var archivedLabels = {
    "Add to Sidebar": "star",
    "AirDrop": "airdrop",
    "Applications": "bag",
    "Back": "chevron.backward",
    "Clean Up": "square.grid.3x3",
    "Compress": "zipper.page",
    "Connect to Server…": "rectangle.connected.to.line.below",
    "Copy as Pathname": "document.on.document",
    "Customize Toolbar…": "wrench.adjustable",
    "Desktop": "menubar.dock.rectangle",
    "Documents": "document",
    "Downloads": "arrow.down.circle",
    "Duplicate": "plus.square.on.square",
    "Eject": "eject",
    "Empty Trash": "trash",
    "Enclosing Folder": "arrow.up.folder",
    "Find": "magnifyingglass",
    "Forward": "chevron.forward",
    "Get Info": "info.circle",
    "Go to Folder…": "arrow.forward.folder",
    "Group By": "arrow.up.arrow.down",
    "Hide Preview": "sidebar.trailing",
    "Hide Sidebar": "sidebar.leading",
    "Home": "house",
    "Mac User Guide": "book.pages",
    "Make Alias": "link",
    "Move Items Here": "folder",
    "Move to Trash": "trash",
    "Network": "network",
    "New Finder Window": "plus.rectangle",
    "New Folder": "folder.badge.plus",
    "New Smart Folder": "gearshape",
    "New Tab": "plus.square.on.square",
    "Open": "arrow.up.forward.app",
    "Preferences…": "gear",
    "Print": "printer",
    "QuickLook": "eye",
    "Recent Folders": "clock",
    "Recents": "clock",
    "Rename": "pencil",
    "Select All": "character.textbox",
    "Shared": "folder.badge.person.crop",
    "Share…": "square.and.arrow.up",
    "Show Clipboard": "clipboard",
    "Show Original": "arrowshape.turn.up.left",
    "Show View Options": "gearshape",
    "Sort By": "arrow.up.arrow.down",
    "Tags…": "tag",
    "Tips for Your Mac": "lightbulb",
    "Use Groups": "square.grid.3x1.below.line.grid.1x2",
    "Utilities": "wrench.and.screwdriver",
    "as Columns": "rectangle.split.3x1",
    "as Gallery": "squares.below.rectangle",
    "as Icons": "square.grid.2x2",
    "as List": "list.bullet",
    "iCloud Drive": "icloud"
};

var inferredLabels = {
    "About This Mac": "display",
    "About This Mak": "display",
    "App Store…": "bag",
    "Bring All to Front": "rectangle.on.rectangle",
    "Clean Up By": "square.grid.3x3",
    "Close": "xmark",
    "Close Window": "xmark",
    "Computer": "desktopcomputer",
    "Copy": "document.on.document",
    "Cut": "scissors",
    "Cycle Through Windows": "rectangle.on.rectangle",
    "Empty Trash…": "trash",
    "Enter Full Screen": "arrow.up.left.and.arrow.down.right",
    "Exit Full Screen": "arrow.down.right.and.arrow.up.left",
    "Force Quit…": "xmark.octagon",
    "Hide Finder": "eye.slash",
    "Hide Others": "eye.slash",
    "Lock Screen": "lock",
    "Minimize": "minus",
    "New Folder with Selection": "folder.badge.plus",
    "Open With": "arrow.up.forward.app",
    "Paste": "document.on.clipboard",
    "Paste Items": "document.on.clipboard",
    "Pictures": "photo",
    "Print…": "printer",
    "Put Back": "arrow.uturn.backward",
    "Quick Look": "eye",
    "Recent Items": "clock",
    "Redo": "arrow.uturn.forward",
    "Restart…": "arrow.clockwise",
    "Settings…": "gear",
    "Show All": "eye",
    "Show Preview": "sidebar.trailing",
    "Show Sidebar": "sidebar.leading",
    "Shut Down…": "power",
    "Sleep": "moon.zzz",
    "System Settings…": "gearshape",
    "Trash": "trash",
    "Undo": "arrow.uturn.backward",
    "Use Stacks": "square.grid.3x1.below.line.grid.1x2",
    "Zoom": "arrow.up.left.and.arrow.down.right"
};

var inferredCommands = {
    "about": "info.circle",
    "aboutmac": "display",
    "app:back": "chevron.backward",
    "app:copy": "document.on.document",
    "app:copyExpression": "document.on.document",
    "app:cut": "scissors",
    "app:find": "magnifyingglass",
    "app:forward": "chevron.forward",
    "app:paste": "document.on.clipboard",
    "app:reload": "arrow.clockwise",
    "app:selectAll": "character.textbox",
    "app:undo": "arrow.uturn.backward",
    "appearance": "gearshape",
    "back": "chevron.backward",
    "close": "xmark",
    "columns": "rectangle.split.3x1",
    "copy": "document.on.document",
    "copypaths": "document.on.document",
    "duplicate": "plus.square.on.square",
    "forcequit": "xmark.octagon",
    "forward": "chevron.forward",
    "fullscreen": "arrow.up.left.and.arrow.down.right",
    "gallery": "squares.below.rectangle",
    "getinfo": "info.circle",
    "go:": "house",
    "go:.Trash": "trash",
    "go:@applications": "bag",
    "go:@recents": "clock",
    "go:Desktop": "menubar.dock.rectangle",
    "go:Documents": "document",
    "go:Downloads": "arrow.down.circle",
    "go:Pictures": "photo",
    "help": "keyboard",
    "hide": "eye.slash",
    "hideothers": "eye.slash",
    "icons": "square.grid.2x2",
    "launch:appstore": "bag",
    "list": "list.bullet",
    "minimize": "minus",
    "move": "folder",
    "newfolder": "folder.badge.plus",
    "newwindow": "plus.rectangle",
    "open": "arrow.up.forward.app",
    "paste": "document.on.clipboard",
    "preview": "eye",
    "rename": "pencil",
    "restore": "arrow.uturn.backward",
    "selectall": "character.textbox",
    "session:lock": "lock",
    "session:logout": "rectangle.portrait.and.arrow.right",
    "session:restart": "arrow.clockwise",
    "session:shutdown": "power",
    "session:sleep": "moon.zzz",
    "settings": "gearshape",
    "showall": "rectangle.on.rectangle",
    "sidebar": "sidebar.leading",
    "trash": "trash",
    "undo": "arrow.uturn.backward",
    "unhideall": "eye",
    "up": "arrow.up.folder",
    "zoom": "arrow.up.left.and.arrow.down.right"
};

var availableSymbols = ["airdrop", "arrow.clockwise", "arrow.down.circle", "arrow.down.right.and.arrow.up.left", "arrow.forward.folder", "arrow.up.arrow.down", "arrow.up.folder", "arrow.up.forward.app", "arrow.up.left.and.arrow.down.right", "arrow.uturn.backward", "arrow.uturn.forward", "arrowshape.turn.up.left", "bag", "book.pages", "character.textbox", "chevron.backward", "chevron.forward", "clipboard", "clock", "desktopcomputer", "display", "document", "document.on.clipboard", "document.on.document", "eject", "eye", "eye.slash", "folder", "folder.badge.person.crop", "folder.badge.plus", "gear", "gearshape", "house", "icloud", "info.circle", "keyboard", "lightbulb", "link", "list.bullet", "lock", "magnifyingglass", "menubar.dock.rectangle", "minus", "moon.zzz", "network", "pencil", "photo", "plus.rectangle", "plus.square.on.square", "power", "printer", "rectangle.connected.to.line.below", "rectangle.on.rectangle", "rectangle.portrait.and.arrow.right", "rectangle.split.3x1", "scissors", "sidebar.leading", "sidebar.trailing", "square.and.arrow.up", "square.grid.2x2", "square.grid.3x1.below.line.grid.1x2", "square.grid.3x3", "squares.below.rectangle", "star", "tag", "trash", "wrench.adjustable", "wrench.and.screwdriver", "xmark", "xmark.octagon", "zipper.page"];

function assignmentFor(row) {
    if (!row || row.separator) return {symbol: "", basis: "none"};
    // An explicit empty symbol opts a known command out of decoration.
    if (row.symbol !== undefined) {
        var valid = availableSymbols.indexOf(row.symbol) >= 0;
        return {symbol: valid ? row.symbol : "", basis: valid ? "explicit" : "none"};
    }
    var label = String(row.label || "");
    if (archivedLabels[label]) {
        var fallbackLabels = ["Applications", "Tips for Your Mac", "Make Alias", "Show Original"];
        var basis = fallbackLabels.indexOf(label) >= 0 ? "inferred-fallback-for-observed-resource" : label === "AirDrop" ? "observed-finder-assignment-coretypes-artwork" : "observed-finder-archive";
        return {symbol: archivedLabels[label], basis: basis};
    }
    if (inferredLabels[label]) return {symbol: inferredLabels[label], basis: "inferred"};
    var command = String(row.command || "");
    if (inferredCommands[command]) return {symbol: inferredCommands[command], basis: "inferred"};
    return {symbol: "", basis: "none"};
}
function symbolFor(row) { return assignmentFor(row).symbol; }
function assetFor(row) {
    var symbol = symbolFor(row);
    return symbol === "airdrop" ? "../assets/symbols/airdrop.png" : symbol ? "../assets/symbols/menu-" + symbol + ".png" : "";
}
