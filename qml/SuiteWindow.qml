import QtQuick
import QtQuick.Controls

DesktopWindow {
    id: win
    objectName: "suiteWindow"
    sidebarWidth: ["apps", "calculator", "chess", "photobooth", "terminal", "safari", "maps"].indexOf(appKind) >= 0 ? 0 : 222
    minimumWindowWidth: appKind === "calculator" ? 300 : 640
    minimumWindowHeight: appKind === "calculator" ? 480 : 460
    searchFocused: true
    titlebarHeight: appKind === "terminal" ? 32 : 50
    trafficLightsX: appKind === "terminal" ? 9 : 18
    trafficLightsY: appKind === "terminal" ? 10 : 18
    trafficLightSize: appKind === "terminal" ? 12 : 13
    windowCorner: appKind === "terminal" ? 16 : 25
    bodyColor: appKind === "terminal" ? "#202530" : dark ? "#242b2e" : "#f6f6f7"
    borderColor: appKind === "terminal" ? "#5b6068" : dark ? "#596068" : "#b8bdc4"
    property alias pageItem: content.item
    property bool closePrepared: false
    property bool privateBrowsing: false
    function command(name) {
        if (content.item && content.item.command) content.item.command(name);
    }
    function prepareClose() {
        if (closePrepared) return;
        closePrepared = true;
        if (content.item && content.item.flush) content.item.flush();
    }
    Component.onDestruction: prepareClose()
    Item {
        parent: win.clientItem
        anchors.fill: parent
        Rectangle { visible:win.appKind==="terminal";width:parent.width;height:32;color:"#242b2f";radius:win.isFullscreen?0:16;Rectangle {y:16;width:parent.width;height:16;color:parent.color} }
        Image { visible:win.appKind==="terminal";x:82;y:10;width:13;height:13;source:visible?Bridge.assetRoot+"/folder.png":"";fillMode:Image.PreserveAspectFit }
        Text {
            visible: win.appKind !== "appstore"
            x: win.appKind === "terminal" ? 102 : win.sidebarWidth > 0 ? win.sidebarWidth + 24 : 110
            y: win.appKind === "terminal" ? 9 : 15
            width: Math.max(80, parent.width - x - 65)
            text: win.appKind === "terminal" && content.item ? content.item.sessionTitle : win.windowTitle
            color: win.appKind === "terminal" ? "#b8bdc4" : win.ink
            opacity: win.active ? 1 : 0.45
            font.pixelSize: win.appKind === "terminal" ? 12 : 14
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Loader {
            id: content
            x: win.appKind === "terminal" ? 1 : 0; y: win.appKind === "terminal" ? 32 : 52
            width: parent.width - 2*x; height: parent.height - y - (win.appKind === "terminal" ? 1 : 0)
            Component.onCompleted: {
                let id = win.appKind;
                let file = ["notes", "reminders", "contacts", "calendar", "mail", "messages"].indexOf(id) >= 0 ? "RecordsApp.qml"
                    : id === "calculator" ? "CalculatorApp.qml" : id === "chess" ? "ChessApp.qml"
                    : id === "photobooth" ? "PhotoBoothApp.qml" : id === "terminal" ? "TerminalApp.qml"
                    : id === "safari" || id === "maps" ? "WebApp.qml"
                    : id === "photos" || id === "music" ? "MediaApp.qml"
                    : id === "phone" || id === "facetime" ? "CallsApp.qml"
                    : id === "appstore" ? "AppStoreApp.qml" : "AppsLibrary.qml";
                setSource(file, {host: win});
            }
            onStatusChanged: if (status === Loader.Error) win.desktop.showInfo(win.windowTitle, "The application could not be loaded. Check the application log.")
        }
    }
}
