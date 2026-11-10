import QtQuick
import "ControlCatalog.js" as Catalog

Item {
    id: state
    objectName: "controlState"
    required property var desktop
    readonly property int revision: Bridge.suite.revision
    readonly property var catalog: Catalog.controls
    readonly property string menuControlIds: catalog.filter(c => c.menu || inMenu(c.id)).map(c=>c.id).join(",")
    readonly property var menuControls: menuControlIds.split(",").filter(id=>!!id).map(id=>info(id))
    readonly property var registeredApps: []
    function preference(key, fallback) {
        let r = revision;
        if (Bridge.ddeAudio.available) {
            if (key === "sound.volume") return String(Bridge.ddeAudio.volume);
            if (key === "sound.muted") return String(Bridge.ddeAudio.muted);
        }
        return Bridge.suite.preference(key, fallback);
    }
    function setPreference(key, value) {
        if (Bridge.ddeAudio.available) {
            if (key === "sound.volume") { Bridge.ddeAudio.setVolume(Number(value)); return; }
            if (key === "sound.muted") { Bridge.ddeAudio.setMuted(String(value) === "true"); return; }
        }
        Bridge.suite.setPreference(key, String(value));
    }
    function info(id) { return catalog.find(c => c.id === id) || null; }
    function iconFor(id) {
        if (id === "sound") {
            let muted = preference("sound.muted","false") === "true";
            let level = Number(preference("sound.volume","0.75"));
            return muted || level <= 0 ? "speaker-muted" : level < 0.34 ? "speaker-low" : level > 0.66 ? "speaker-high" : "speaker";
        }
        return info(id) ? info(id).icon : "control";
    }
    function inMenu(id) {
        let item = info(id); if (!item) return false;
        if (id === "clock") return desktop.showClock;
        if (id === "search") return desktop.showSearchIcon;
        return preference("control.bar." + id, item.defaultBar ? "true" : "false") === "true";
    }
    function setInMenu(id, value) {
        if (!info(id)) return;
        if (id === "clock") desktop.showClock = value;
        if (id === "search") desktop.showSearchIcon = value;
        setPreference("control.bar." + id, value);
    }
    function mode(id) {
        let item = info(id), raw = preference("control.mode." + id, item && item.defaultMode || "Always");
        return raw === "When Active" ? raw : "Always";
    }
    function setMode(id, value) { if (info(id) && ["Always","When Active"].indexOf(value) >= 0) setPreference("control.mode." + id, value); }
    readonly property var musicWindow: desktop.windows.find(w => w.appKind === "music" && !w.closing) || null
    readonly property var musicPage: musicWindow ? musicWindow.pageItem : null
    readonly property var nowPlaying: ({title: musicPage && musicPage.playingTrack ? musicPage.playingTrack.name : "Not Playing", playing: !!(musicPage && musicPage.playbackPlaying), available: !!(musicPage && musicPage.playingTrack)})
    function mediaCommand(command) {
        if (musicPage) musicPage.command(command);
        else desktop.openApplication("music");
    }
    function isActive(id) {
        if (id === "focus") return preference("focus.doNotDisturb", "false") === "true";
        if (id === "nowplaying" || id === "sound") return nowPlaying.playing;
        if (id === "timer") return timerRunning || timerRemaining > 0;
        if (id === "display") return Number(preference("display.brightness","1")) < 0.999;
        if (id === "darkmode") return desktop.dark;
        return false;
    }
    function menuVisible(id) {
        let item = info(id);
        return inMenu(id) && (!item.supportsMode || mode(id) === "Always" || isActive(id));
    }
    readonly property string menuOrderJSON: preference("control.barOrder", JSON.stringify(Catalog.defaultMenuOrder))
    readonly property var menuOrder: {
        let result;
        try { result = JSON.parse(menuOrderJSON); } catch(e) { result = Catalog.defaultMenuOrder.slice(); }
        if (!Array.isArray(result)) result = Catalog.defaultMenuOrder.slice();
        let seen = {};
        return result.concat(catalog.map(c => c.id)).filter(id => id !== "clock" && info(id) && !seen[id] && (seen[id] = true));
    }
    readonly property string visibleIds: menuOrder.filter(id => menuVisible(id)).join(",")
    readonly property var visibleItems: visibleIds.split(",").filter(id=>!!id).map(id => info(id))
    function moveMenuItem(id, target) {
        let order = menuOrder.filter(i => i !== id), at = order.indexOf(target);
        order.splice(at < 0 ? order.length : at, 0, id);
        setPreference("control.barOrder", JSON.stringify(order));
    }
    readonly property string layoutJSON: preference("control.layout", JSON.stringify(Catalog.defaultLayout))
    readonly property var layout: {
        let raw;
        try { raw = JSON.parse(layoutJSON); } catch(e) { raw = Catalog.defaultLayout; }
        if (!Array.isArray(raw)) raw = Catalog.defaultLayout;
        let seen = {};
        return raw.filter(e => e && info(e.id) && !seen[e.id] && (seen[e.id] = true)).map(e => ({id:e.id, size:info(e.id).sizes.indexOf(e.size) >= 0 ? e.size : info(e.id).defaultSize}));
    }
    function saveLayout(value) { setPreference("control.layout", JSON.stringify(value)); }
    function addControl(id, size) {
        let item = info(id); if (!item || layout.some(e => e.id === id)) return;
        saveLayout(layout.concat([{id:id,size:item.sizes.indexOf(size) >= 0 ? size : item.defaultSize}]));
    }
    function removeControl(id) { saveLayout(layout.filter(e => e.id !== id)); }
    function moveControl(id, index) {
        let item = layout.find(e => e.id === id); if (!item) return;
        let next = layout.filter(e => e.id !== id); next.splice(Math.max(0,Math.min(next.length,index)),0,item); saveLayout(next);
    }
    function resizeControl(id, size) {
        let item = info(id); if (!item || item.sizes.indexOf(size) < 0) return;
        saveLayout(layout.map(e => e.id === id ? {id:id,size:size} : e));
    }
    function appAllowed(id) { return preference("control.app." + id,"true") === "true"; }
    function setAppAllowed(id, allowed) { if (registeredApps.some(app => app.id === id)) setPreference("control.app." + id,allowed); }
    function reset() {
        saveLayout(Catalog.defaultLayout); setPreference("control.barOrder",JSON.stringify(Catalog.defaultMenuOrder));
        for (let item of catalog) { setInMenu(item.id,!!item.defaultBar); setMode(item.id,item.defaultMode || "Always"); }
    }
    property double timerDeadline: 0
    property int pausedSeconds: 0
    property double tick: Date.now()
    readonly property bool timerRunning: timerDeadline > 0
    readonly property int timerRemaining: timerRunning ? Math.max(0,Math.ceil((timerDeadline - tick) / 1000)) : pausedSeconds
    function startTimer(seconds) {
        let duration = Math.max(1,Math.min(86400,Math.round(Number(seconds) || pausedSeconds || 60)));
        tick = Date.now(); pausedSeconds = 0; timerDeadline = tick + duration * 1000;
        setPreference("control.timerDeadline",timerDeadline); setPreference("control.timerPaused",0);
    }
    function pauseTimer() { pausedSeconds = timerRemaining; timerDeadline = 0; setPreference("control.timerDeadline",0); setPreference("control.timerPaused",pausedSeconds); }
    function resetTimer() { timerDeadline = 0; pausedSeconds = 0; setPreference("control.timerDeadline",0); setPreference("control.timerPaused",0); }
    Component.onCompleted: {
        let saved = Number(preference("control.timerDeadline","0"));
        let now = Date.now(), paused = Number(preference("control.timerPaused","0"));
        timerDeadline = Number.isFinite(saved) && saved > now ? Math.min(saved,now+86400000) : 0;
        pausedSeconds = timerDeadline || !Number.isFinite(paused) ? 0 : Math.max(0,Math.min(86400,Math.round(paused)));
    }
    Timer {
        interval:250; repeat:true; running:state.timerRunning
        onTriggered: {
            state.tick = Date.now();
            if (state.timerRemaining === 0) {
                state.resetTimer();
                if (!state.isActive("focus")) desktop.showInfo("Timer", "Your timer has finished.");
            }
        }
    }
}
