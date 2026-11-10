import QtQuick

// Every app process and the shell share this record. Applying remote changes
// never writes them back, and the service watches SQLite's data_version.
Item {
    id: settings
    required property var desktop
    property bool ready: false
    property bool applying: false
    readonly property var fields: ["appearanceMode","glassTinted","wallpaperTint","alwaysShowScrollbars","dockMagnification","dockAutoHide","dockIndicators","dockLaunchAnimation","showDesktopItems","wallpaperMode","showClock","showSearchIcon","dark","reduceMotion","reduceTransparency"]
    function load() {
        let value;
        try { value=JSON.parse(Bridge.suite.preference("shell.appearance","{}")); } catch(e) { return; }
        applying=true;
        for(let key of fields) if(value[key]!==undefined && typeof value[key]===typeof desktop[key]) desktop[key]=value[key];
        applying=false;
    }
    function save() {
        if(!ready||applying)return;
        let value={}; for(let key of fields)value[key]=desktop[key];
        Bridge.suite.setPreference("shell.appearance",JSON.stringify(value));
    }
    Component.onCompleted: {load();ready=true;}
    Connections { target:Bridge.suite; function onChanged(){settings.load();} }
    Connections {
        target:settings.desktop
        function onAppearanceModeChanged(){settings.save();}
        function onGlassTintedChanged(){settings.save();}
        function onWallpaperTintChanged(){settings.save();}
        function onAlwaysShowScrollbarsChanged(){settings.save();}
        function onDockMagnificationChanged(){settings.save();}
        function onDockAutoHideChanged(){settings.save();}
        function onDockIndicatorsChanged(){settings.save();}
        function onDockLaunchAnimationChanged(){settings.save();}
        function onShowDesktopItemsChanged(){settings.save();}
        function onWallpaperModeChanged(){settings.save();}
        function onShowClockChanged(){settings.save();}
        function onShowSearchIconChanged(){settings.save();}
        function onDarkChanged(){settings.save();}
        function onReduceMotionChanged(){settings.save();}
        function onReduceTransparencyChanged(){settings.save();}
    }
}
