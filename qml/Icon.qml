import QtQuick

Item {
    id: icon
    property string name: "folder"
    property color color: "#3c4148"
    property real stroke: 1.65
    readonly property bool nativeSymbol: ["speaker-muted", "speaker-low", "speaker-high", "timer", "mirroring", "weather", "calendar", "pin", "star", "starfill", "plus", "compose", "play", "pause", "previous", "next", "camera", "video", "phone", "reload", "bookmark", "bookmarkfill", "keypad", "accessibility", "account", "airdrop", "appearance", "apple", "applications", "back", "battery", "bell", "bluetooth", "check", "chevron", "clock", "close", "cloud", "columns", "control", "desktop", "display", "document", "down", "downloads", "drive", "folder", "forward", "gallery", "games", "grid", "group", "home", "image", "key", "keyboard", "list", "lock", "menubar", "moon", "more", "mouse", "network", "newfolder", "printer", "search", "settings", "share", "shared", "shield", "sidebar", "speaker", "sun", "tag", "trackpad", "trash", "up", "wallet", "wifi"].indexOf(name) >= 0
    width: 20
    height: 20
    Image {
        id: templateImage
        anchors.fill: parent
        source: icon.nativeSymbol ? "../assets/symbols/" + icon.name + ".png" : ""
        visible: false
        smooth: true
    }
    ShaderEffect {
        anchors.fill: parent
        visible: icon.nativeSymbol
        property var source: templateImage
        property color tint: icon.color
        fragmentShader: "../shaders/symbol.frag.qsb"
    }
    FallbackIcon {
        anchors.fill: parent
        visible: !icon.nativeSymbol
        name: icon.name
        color: icon.color
        stroke: icon.stroke
    }
}
