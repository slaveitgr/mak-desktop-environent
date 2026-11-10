import QtQuick
import QtQuick.Controls

DesktopWindow {
    id: win
    objectName: "suiteWindow"
    sidebarWidth: ["apps", "calculator", "chess", "photobooth", "terminal", "safari", "maps"].indexOf(appKind) >= 0 ? 0 : 222
    minimumWindowWidth: appKind === "calculator" ? 300 : 640
    minimumWindowHeight: appKind === "calculator" ? 480 : 460
    searchFocused: true
    property alias pageItem: content.item
    property bool closePrepared: false
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
        Text {
            x: win.sidebarWidth > 0 ? win.sidebarWidth + 24 : 110
            y: 15
            width: Math.max(80, parent.width - x - 65)
            text: win.windowTitle
            color: win.ink
            opacity: win.active ? 1 : 0.45
            font.pixelSize: 14
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Loader {
            id: content
            x: 0; y: 52
            width: parent.width; height: parent.height - y
            Component.onCompleted: {
                let id = win.appKind;
                let file = ["notes", "reminders", "contacts", "calendar", "mail", "messages"].indexOf(id) >= 0 ? "RecordsApp.qml"
                    : id === "calculator" ? "CalculatorApp.qml" : id === "chess" ? "ChessApp.qml"
                    : id === "photobooth" ? "PhotoBoothApp.qml" : id === "terminal" ? "TerminalApp.qml"
                    : id === "safari" || id === "maps" ? "WebApp.qml"
                    : id === "photos" || id === "music" ? "MediaApp.qml"
                    : id === "phone" || id === "facetime" ? "CallsApp.qml" : "AppsLibrary.qml";
                setSource(file, {host: win});
            }
            onStatusChanged: if (status === Loader.Error) win.desktop.showInfo(win.windowTitle, "The application could not be loaded. Check the application log.")
        }
    }
}
