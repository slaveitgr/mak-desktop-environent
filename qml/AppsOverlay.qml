import QtQuick
import QtQuick.Controls
import QtQuick.Window

MaterialPopup {
    id: launcher
    objectName: "appsOverlay"
    required property var desktop
    required property Item backdrop
    property string mode: "apps"
    property string pendingApplication: ""
    property string pendingFile: ""
    property string pendingAction: ""
    readonly property bool nativeGlass:!!(nativeGlassLoader.item&&nativeGlassLoader.item.ready)
    function showMode(nextMode) {
        if (["apps","spotlight","files","actions","clipboard"].indexOf(nextMode)<0) return;
        mode=nextMode;
        Qt.callLater(function(){if(launcher.mode==="apps")library.focusSearch(true);else spotlight.focusSearch(true);});
    }
    width: Math.min(mode==="apps"?844:640, desktop.width - 64)
    height: Math.min(mode==="apps"?576:mode==="clipboard"?446:mode==="spotlight"?(spotlight.query.trim()?440:56):544, desktop.height - 130)
    x: Math.round((desktop.width-width)/2)
    y: Math.max(40, Math.round((desktop.height-576)/2))
    padding: 0
    modal: true
    dim: false
    focus: true
    reducedMotion: desktop.reduceMotion
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    onOpened: { pendingApplication="";pendingFile="";pendingAction=""; Bridge.session.refreshApplications(); if(mode==="apps")library.focusSearch(true);else spotlight.focusSearch(true); }
    onClosed: {
        if (pendingApplication !== "") {
            let application = pendingApplication;
            pendingApplication = "";
            Qt.callLater(function(){ launcher.desktop.openApplication(application); });
        }
        if(pendingFile!==""){let file=pendingFile;pendingFile="";Qt.callLater(function(){Bridge.openSpotlightFile(file);});}
        if(pendingAction!==""){let action=pendingAction;pendingAction="";Qt.callLater(function(){launcher.desktop.startSpotlightAction(action);});}
    }
    background: Item {
        Glass {
            anchors.fill:parent;visible:launcher.mode!=="spotlight"&&!launcher.nativeGlass
            backdrop: launcher.backdrop; sampleX: launcher.x; sampleY: launcher.y
            dark: launcher.desktop.dark; corner: 30; tint: launcher.desktop.dark?0.76:0.74; frost: 0.98
            reducedTransparency: launcher.desktop.reduceTransparency
            reveal: launcher.materialization
        }
        Glass {
            y:64;width:parent.width;height:Math.max(0,parent.height-y);visible:launcher.mode==="spotlight"&&spotlight.query.trim().length>0
            backdrop:launcher.backdrop;sampleX:launcher.x;sampleY:launcher.y+y
            dark:launcher.desktop.dark;corner:24;tint:0.76;frost:0.98;reducedTransparency:launcher.desktop.reduceTransparency
        }
        Rectangle{anchors.fill:parent;visible:launcher.mode!=="spotlight";radius:30;color:"transparent";border.width:0.8;border.color:launcher.desktop.dark?"#687070":"#a8acad"}
    }
    QtObject {
        id: launcherHost
        readonly property string appKind: "apps"
        readonly property var desktop: launcher.desktop
        readonly property string mode: launcher.mode
        readonly property Item backdrop: launcher.backdrop
        readonly property real panelX:launcher.x
        readonly property real panelY:launcher.y
        readonly property bool dark: desktop.dark
        readonly property color ink: dark ? "#f5f5f7" : "#24252a"
        readonly property color muted: dark ? "#9a9b9d" : "#666670"
        function dismiss() { launcher.close(); }
        function showMode(mode) { launcher.showMode(mode); }
        function launchApp(id) { launcher.pendingApplication=id; launcher.close(); }
        function openFile(path) { launcher.pendingFile=path;launcher.close(); }
        function runAction(action) { launcher.pendingAction=action;launcher.close(); }
    }
    contentItem: Item {
        Loader {
            id:nativeGlassLoader
            source:typeof useCutefishShell!=="undefined"&&useCutefishShell&&Bridge.nativeWayland?"CutefishPopupGlass.qml":""
            onLoaded:item.popup=launcher
        }
        ApplicationsLauncher { id:library;anchors.fill:parent;host:launcherHost;visible:launcher.mode==="apps" }
        SpotlightView { id:spotlight;anchors.fill:parent;host:launcherHost;applications:library.allApps;visible:launcher.mode!=="apps" }
    }
}
