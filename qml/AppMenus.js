.pragma library

// Labels derive from the source-linked Tahoe resources in
// work/rea-reference/reference-ledger.json and the inspected native Calculator.
// Nib archives also contain hidden/debug/legacy menus: these are deliberately
// excluded. SwiftUI-created menus in Apps, Maps, Phone and Games remain a
// reconstruction, not proof of exact live menu order. Disabled entries name
// native features that have no corresponding service in this prototype.

function names(kind, title) {
    var menus = {
        apps: ["Edit", "View", "Window", "Help"],
        safari: ["File", "Edit", "View", "History", "Bookmarks", "Window", "Help"],
        messages: ["File", "Edit", "View", "Conversation", "Window", "Help"],
        mail: ["File", "Edit", "View", "Mailbox", "Message", "Format", "Window", "Help"],
        maps: ["File", "Edit", "View", "Window", "Help"],
        photos: ["File", "Edit", "Image", "View", "Window", "Help"],
        facetime: ["Edit", "Video", "Window", "Help"],
        phone: ["Edit", "View", "Window", "Help"],
        calendar: ["File", "Edit", "View", "Window", "Help"],
        reminders: ["File", "Edit", "View", "Window", "Help"],
        notes: ["File", "Edit", "Format", "View", "Window", "Help"],
        contacts: ["File", "Edit", "View", "Card", "Window", "Help"],
        music: ["File", "Edit", "Song", "View", "Controls", "Account", "Window", "Help"],
        games: ["Edit", "View", "Window", "Help"],
        appstore: ["Edit", "Window", "Help"],
        terminal: ["Shell", "Edit", "View", "Window", "Help"],
        calculator: ["Edit", "View", "Window", "Help"],
        chess: ["Game", "Edit", "View", "Moves", "Window", "Help"],
        photobooth: ["File", "Edit", "View", "Camera", "Window", "Help"]
    };
    return [title].concat(menus[kind] || ["File", "Edit", "View", "Window", "Help"]);
}
function item(label, command, shortcut, enabled, checked, submenu) {
    var result = {label:label, command:command || "", shortcut:shortcut || "", enabled:enabled === undefined ? true : !!enabled, checked:!!checked};
    if (submenu) result.submenu = submenu;
    return result;
}
function disabled(label, shortcut) { return item(label, "", shortcut, false); }
function separator() { return {separator:true}; }
function app(label, command, shortcut, enabled, checked) { return item(label, "app:" + command, shortcut, enabled, checked); }
function fullscreen(host) { return item(host && host.isFullscreen ? "Exit Full Screen" : "Enter Full Screen", "fullscreen", "⌃⌘F", !!host); }
function rows(kind, name, host, desktop) {
    var p = host ? host.pageItem : null;
    var title = host ? host.windowTitle : "Application";
    var cmd = desktop.shortcutMark || "⌘";
    var record = ["notes","reminders","contacts","calendar","mail","messages"].indexOf(kind) >= 0;
    var selected = !!(p && p.selectedId);
    var editable = selected && !p.trash;
    var editor = p && p.editTarget;
    var web = p && p.currentPage;
    var media = p && p.selection;
    var hasMedia = !!(p && p.filtered && p.filtered.length);
    var favorite = !!(media && p.favorites && p.favorites.indexOf(media.path) >= 0);
    var windowRows = [item("Minimize", "minimize", cmd+"M", !!host && !host.isFullscreen), item("Zoom", "zoom", "", !!host), fullscreen(host), separator(), item("Bring All to Front", "showall", "", !!host)];
    if (name === title) {
        var settingsApps = ["safari","messages","mail","maps","photos","facetime","phone","calendar","reminders","notes","contacts","music","games"];
        var main = [item("About " + title, "about"), separator()];
        // All settings are managed by the desktop's System Settings in this build.
        if (settingsApps.indexOf(kind) >= 0) main.push(item("Settings…", "settings", cmd+","), separator());
        main.push(item("Hide " + title, "hide", cmd+"H", !!host), item("Hide Others", "hideothers", "⌥"+cmd+"H", !!host), item("Show All", "unhideall", "", desktop.windows.some(w=>w.appHidden)), separator(), item("Quit " + title, "close", cmd+"Q", !!host));
        return main;
    }
    if (name === "Window") {
        var all = desktop.windows.filter(function(w) { return !w.closing && w.appKind === kind; });
        if (all.length) windowRows.push(separator());
        desktop.windows.forEach(function(w,i) { if (!w.closing && w.appKind === kind) windowRows.push(item(w.windowTitle,"window:"+i,"",true,w===host)); });
        return windowRows;
    }
    if (name === "Help") return [item(title + " Help", "about"), separator(), item("About This Desktop", "about")];
    if (name === "Edit") {
        if (kind === "calculator") return [app("Undo", "undo", cmd+"Z", !!p), separator(), app("Copy Result", "copy", cmd+"C", !!p), app("Copy Expression", "copyExpression", "", !!p), separator(), app("Clear", "new", "Esc", !!p)];
        if (kind === "chess") return [app("Undo", "undo", cmd+"Z", !!(p && p.game.canUndo)), disabled("Redo", "⇧"+cmd+"Z")];
        if (kind === "terminal") return [app("Copy", "copy", cmd+"C", !!p), app("Paste", "paste", cmd+"V", !!(p && p.session && p.session.running)), app("Select All", "selectAll", cmd+"A", !!p)];
        if (kind === "facetime" || kind === "phone") return [app("Copy", "copy", cmd+"C", !!(p && p.number)), separator(), app("New Contact…", "new", "", !!p)];
        if (record || kind === "safari" || kind === "maps") {
            var canEdit = record ? !!editor : !!p;
            var edits = [app("Undo", "undo", cmd+"Z", record ? !!(p && (p.undoDeletedId || editor && editor.canUndo)) : !!web), disabled("Redo", "⇧"+cmd+"Z"), separator(), app("Cut", "cut", cmd+"X", canEdit), app("Copy", "copy", cmd+"C", canEdit), app("Paste", "paste", cmd+"V", canEdit), app("Select All", "selectAll", cmd+"A", canEdit)];
            if (record) edits.push(separator(), app(p && p.trash ? "Restore" : "Delete", "delete", "", selected));
            edits.push(separator(), app(kind === "safari" || kind === "maps" ? "Search…" : "Find…", "find", cmd+"F", !!p));
            return edits;
        }
        if (kind === "photos" || kind === "music") return [disabled("Undo", cmd+"Z"), separator(), app(favorite ? "Remove from Favorites" : "Add to Favorites", "favorite", "", !!media)];
        if (kind === "photobooth") return [disabled("Undo", cmd+"Z"), disabled("Redo", "⇧"+cmd+"Z"), separator(), disabled("Copy", cmd+"C"), disabled("Delete")];
        return [app("Find…", "new", cmd+"F", !!p)];
    }
    if (name === "Format") {
        if (kind === "notes") return [disabled("Title"), disabled("Heading"), disabled("Subheading"), disabled("Body"), disabled("Monostyled"), separator(), disabled("Bulleted List"), disabled("Dashed List"), disabled("Numbered List"), disabled("Checklist"), separator(), disabled("Bold", cmd+"B"), disabled("Italic", cmd+"I"), disabled("Underline", cmd+"U")];
        return [disabled("Font"), disabled("Style"), disabled("Alignment"), separator(), disabled("Make Rich Text")];
    }
    if (kind === "safari") {
        if (name === "File") return [app("New Tab", "new", cmd+"T", !!p), disabled("New Window", cmd+"N"), disabled("New Private Window", "⇧"+cmd+"N"), separator(), app("Open Location…", "focusLocation", cmd+"L", !!p), app("Close Tab", "closeTab", cmd+"W", !!p), item("Close Window", "close", "⇧"+cmd+"W"), separator(), disabled("Save As…", cmd+"S"), disabled("Print…", cmd+"P")];
        if (name === "View") return [app("Reload Page", "reload", cmd+"R", !!web), app("Stop Loading", "stop", "Esc", !!(web && web.loading)), separator(), app("Show Start Page", "home", "", !!p), app(p && p.downloadsVisible ? "Hide Downloads" : "Show Downloads", "downloads", "", !!p), separator(), fullscreen(host)];
        if (name === "History") return [app("Back", "back", cmd+"[", !!(web && web.canGoBack)), app("Forward", "forward", cmd+"]", !!(web && web.canGoForward)), separator(), disabled("Show All History"), disabled("Clear History…")];
        if (name === "Bookmarks") {
            var bookmarks = p && p.bookmarks ? p.bookmarks.map(function(bookmark) { return app(bookmark.title || bookmark.url, "bookmark:" + bookmark.id, "", true); }) : [];
            return [app(p && p.bookmarked ? "Remove Bookmark" : "Add Bookmark…", "bookmark", cmd+"D", !!(p && p.activeUrl)), separator(), item("Favorites", "", "", bookmarks.length > 0, false, bookmarks)];
        }
    }
    if (kind === "maps") {
        if (name === "File") return [app("New Search", "new", cmd+"N", !!p), separator(), item("Close Window", "close", cmd+"W"), disabled("Print…", cmd+"P")];
        if (name === "View") return [app("Back", "back", cmd+"[", !!(web && web.canGoBack)), app("Forward", "forward", cmd+"]", !!(web && web.canGoForward)), app("Reload", "reload", cmd+"R", !!web), separator(), disabled("Show My Location"), disabled("Satellite"), separator(), fullscreen(host)];
    }
    if (kind === "notes") {
        if (name === "File") return [app("New Note", "new", cmd+"N", !!p), disabled("New Folder", "⇧"+cmd+"N"), disabled("New Smart Folder…"), separator(), app(p && p.draft && p.draft.pinned ? "Unpin Note" : "Pin Note", "pin", "", editable), app(p && p.trash ? "Restore Note" : "Delete Note", "delete", "", selected), separator(), item("Close", "close", cmd+"W"), disabled("Export as PDF…"), disabled("Print…", cmd+"P")];
        if (name === "View") return [app("Notes", "category:all", "", !!p, p && p.category === "all"), app("Pinned", "category:pinned", "", !!p, p && p.category === "pinned"), app("Recently Deleted", "category:deleted", "", !!p, p && p.trash), separator(), disabled("as Gallery"), separator(), fullscreen(host)];
    }
    if (kind === "reminders") {
        if (name === "File") return [app("New Reminder", "new", cmd+"N", !!p), disabled("New List", "⇧"+cmd+"N"), disabled("New Group"), separator(), app(p && p.draft && p.draft.done ? "Mark as Incomplete" : "Mark as Completed", "complete", "", editable), separator(), item("Close", "close", cmd+"W"), disabled("Print…", cmd+"P")];
        if (name === "View") return [item("Go To", "", "", !!p, false, [app("All", "category:all", "", !!p, p && p.category === "all"), app("Today", "category:today", "", !!p, p && p.category === "today"), app("Scheduled", "category:scheduled", "", !!p, p && p.category === "scheduled"), app("Completed", "category:completed", "", !!p, p && p.category === "completed")]), app(p && p.category === "completed" ? "Show All" : "Show Completed", "toggleCompleted", "", !!p), separator(), disabled("as Columns"), separator(), fullscreen(host)];
    }
    if (kind === "calendar") {
        if (name === "File") return [app("New Event", "new", cmd+"N", !!p), disabled("New Calendar"), disabled("New Calendar Subscription…"), separator(), disabled("Import…"), disabled("Export"), separator(), item("Close", "close", cmd+"W"), disabled("Print…", cmd+"P")];
        if (name === "View") return [disabled("By Day", cmd+"1"), disabled("By Week", cmd+"2"), app("By Month", "month", cmd+"3", false, true), disabled("By Year", cmd+"4"), separator(), app("Previous", "previous", cmd+"←", !!p), app("Next", "next", cmd+"→", !!p), app("Go to Today", "today", cmd+"T", !!p), separator(), fullscreen(host)];
    }
    if (kind === "contacts") {
        if (name === "File") return [app("New Card", "new", cmd+"N", !!p), disabled("New List"), disabled("New Smart List…"), separator(), disabled("Import…", cmd+"O"), disabled("Export"), separator(), item("Close", "close", cmd+"W"), disabled("Print…", cmd+"P")];
        if (name === "Card") return [app("Edit Card", "edit", cmd+"L", editable), app(p && p.draft && p.draft.favorite ? "Remove from Favorites" : "Add to Favorites", "favorite", "", editable), separator(), disabled("Go to My Card"), disabled("Make This My Card"), disabled("Look for Duplicates…")];
        if (name === "View") return [app("All Contacts", "category:all", "", !!p, p && p.category === "all"), app("Favorites", "category:favorites", "", !!p, p && p.category === "favorites"), app("Recently Deleted", "category:deleted", "", !!p, p && p.trash), separator(), fullscreen(host)];
    }
    if (kind === "mail") {
        if (name === "File") return [app("New Message", "new", cmd+"N", !!p), disabled("New Viewer Window"), separator(), app("Save As…", "export", "⇧"+cmd+"S", editable), disabled("Import Mailboxes…"), separator(), item("Close", "close", cmd+"W"), disabled("Print…", cmd+"P")];
        if (name === "Mailbox") return [app("Drafts", "category:all", "", !!p, p && p.category === "all"), app("Trash", "category:deleted", "", !!p, p && p.trash), separator(), disabled("Get New Mail", "⇧"+cmd+"N"), disabled("Synchronize"), disabled("New Mailbox…")];
        if (name === "Message") return [disabled("Send", "⇧"+cmd+"D"), disabled("Reply", cmd+"R"), disabled("Reply All", "⇧"+cmd+"R"), disabled("Forward", "⇧"+cmd+"F"), separator(), app(p && p.trash ? "Restore" : "Move to Trash", "delete", "", selected)];
        if (name === "View") return [app("Show Drafts", "category:all", "", !!p), separator(), disabled("Organize by Conversation"), disabled("Show Mailbox List"), separator(), fullscreen(host)];
    }
    if (kind === "messages") {
        if (name === "File") return [app("New Message", "new", cmd+"N", !!p), item("Close", "close", cmd+"W")];
        if (name === "Conversation") return [disabled("Send", "Return"), disabled("FaceTime"), disabled("Show Details"), separator(), app(p && p.trash ? "Restore Conversation" : "Delete Conversation…", "delete", "", selected)];
        if (name === "View") return [app("All Messages", "category:all", "", !!p, p && p.category === "all"), app("Recently Deleted", "category:deleted", "", !!p, p && p.trash), separator(), fullscreen(host)];
    }
    if (kind === "photos") {
        if (name === "File") return [app("Import…", "new", "⇧"+cmd+"I", !!p), disabled("New Album"), disabled("New Smart Album…"), separator(), disabled("Export"), item("Close", "close", cmd+"W")];
        if (name === "Image") return [app(favorite ? "Remove from Favorites" : "Add to Favorites", "favorite", ".", !!media), separator(), disabled("Edit"), disabled("Rotate Counterclockwise"), disabled("Hide Photo"), disabled("Duplicate Photo")];
        if (name === "View") return [app("Open Viewer", "open", "Return", !!media), app("Library", "library", "", !!p), separator(), app("Previous Photo", "previous", "←", hasMedia), app("Next Photo", "next", "→", hasMedia), separator(), fullscreen(host)];
    }
    if (kind === "music") {
        if (name === "File") return [app("Import…", "new", cmd+"O", !!p), disabled("New Playlist", cmd+"N"), disabled("Library"), separator(), item("Close Window", "close", cmd+"W")];
        if (name === "Song") return [app(favorite ? "Undo Favorite" : "Favorite", "favorite", "", !!media), disabled("Get Info", cmd+"I"), disabled("Add to Playlist"), disabled("Show in Apple Music")];
        if (name === "Controls") return [app("Play / Pause", "playPause", "Space", hasMedia), app("Next", "next", cmd+"→", hasMedia), app("Previous", "previous", cmd+"←", hasMedia), separator(), disabled("Shuffle"), disabled("Repeat")];
        if (name === "View") return [app("Library", "library", "", !!p), app("Favorites", "favorites", "", !!p), separator(), fullscreen(host)];
        if (name === "Account") return [disabled("Sign In…"), disabled("Account Settings…"), separator(), disabled("Authorizations")];
    }
    if (kind === "photobooth") {
        if (name === "File") return [app("Take Photo", "new", cmd+"T", !!(p && p.cameraStarted && !p.countdown)), disabled("Export…"), disabled("Export Original…"), separator(), item("Close", "close", cmd+"W"), disabled("Print…", cmd+"P")];
        if (name === "Camera") return [app("Start Camera", "startCamera", "", !!(p && p.allowed && !p.cameraStarted && !p.awaitingPermission)), app("Stop Camera", "stopCamera", "", !!(p && (p.cameraStarted || p.awaitingPermission))), separator(), app("Flip Photos Automatically", "mirror", "", !!p, p && p.mirror)];
        if (name === "View") return [disabled("Show Effects"), disabled("Next Page of Effects"), disabled("Previous Page of Effects"), separator(), app("Show Photos", "library", "", !!p), separator(), fullscreen(host)];
    }
    if (kind === "calculator" && name === "View") return [app("Basic", "mode:basic", cmd+"1", !!p, p && p.mode === "basic"), app("Scientific", "mode:scientific", cmd+"2", !!p, p && p.mode === "scientific"), disabled("Programmer", cmd+"3"), disabled("Math Notes"), separator(), app(p && p.historyVisible ? "Hide History" : "Show History", "history", "", !!p), item("Angle", "", "", !!p, false, [app("Degrees", "angle:degrees", "", !!p, p && p.angleMode === "degrees"), app("Radians", "angle:radians", "", !!p, p && p.angleMode === "radians")])];
    if (kind === "chess") {
        if (name === "Game") return [app("New…", "new", cmd+"N", !!p), disabled("Open…", cmd+"O"), disabled("Save", cmd+"S"), disabled("Save As…", "⇧"+cmd+"S"), separator(), disabled("Offer Draw"), disabled("Resign"), separator(), item("Close", "close", cmd+"W")];
        if (name === "Moves") return [app("Take Back Move", "undo", cmd+"Z", !!(p && p.game.canUndo)), disabled("Show Hint"), disabled("Show Last Move")];
        if (name === "View") return [disabled("Game Log"), disabled("Achievements"), separator(), fullscreen(host)];
    }
    if (kind === "terminal") {
        if (name === "Shell") return [app("New Window", "new", cmd+"N", !!(p && p.session && !p.session.running)), disabled("New Tab", cmd+"T"), disabled("New Command…"), disabled("New Remote Connection…"), separator(), item("Close Window", "close", cmd+"W")];
        if (name === "View") return [disabled("Show Tab Bar"), disabled("Bigger", cmd+"+"), disabled("Smaller", cmd+"−"), disabled("Default Font Size", cmd+"0"), separator(), fullscreen(host)];
    }
    if (kind === "facetime" && name === "Video") return [disabled("FaceTime Video"), disabled("FaceTime Audio"), separator(), disabled("Mute"), disabled("Turn Camera Off"), separator(), fullscreen(host)];
    if (kind === "phone" && name === "View") return [app("Keypad", "keypad", "", !!p, p && p.page === "Keypad"), app("Contacts", "contacts", "", !!p, p && p.page === "Contacts"), app("Recents", "recents", "", !!p, p && p.page === "Recents"), separator(), fullscreen(host)];
    if (name === "View") return [app("Search", "new", cmd+"F", !!p), separator(), fullscreen(host)];
    if (name === "File") return [app("New", "new", cmd+"N", !!p), item("Close", "close", cmd+"W")];
    return [];
}
