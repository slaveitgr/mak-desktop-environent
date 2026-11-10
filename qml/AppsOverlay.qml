import QtQuick
import QtQuick.Controls

MaterialPopup {
    id: launcher
    objectName: "appsOverlay"
    required property var desktop
    required property Item backdrop
    width: Math.min(1040, desktop.width - 64)
    height: Math.min(740, desktop.height - 130)
    x: Math.round((desktop.width-width)/2)
    y: Math.max(40, Math.round((desktop.height-height)/2)-12)
    padding: 12
    modal: true
    focus: true
    reducedMotion: desktop.reduceMotion
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    onOpened: { Bridge.session.refreshApplications(); library.focusSearch(true); }
    background: Glass {
        backdrop: launcher.backdrop; sampleX: launcher.x; sampleY: launcher.y
        dark: launcher.desktop.dark; corner: 30; tint: 0.62; frost: 0.98
        reducedTransparency: launcher.desktop.reduceTransparency
        reveal: launcher.materialization
    }
    QtObject {
        id: launcherHost
        readonly property string appKind: "apps"
        readonly property var desktop: launcher.desktop
        readonly property bool dark: desktop.dark
        readonly property color ink: dark ? "#f5f5f7" : "#24252a"
        readonly property color muted: dark ? "#c1c1ca" : "#666670"
        function dismiss() { launcher.close(); }
    }
    contentItem: AppsLibrary { id: library; host: launcherHost }
}
