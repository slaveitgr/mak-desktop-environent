import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

DesktopWindow {
    id: win
    width: 723
    height: Math.max(minimumWindowHeight, Math.min(861, desktop.height - 96))
    sidebarWidth: 223
    property string page: "Appearance"
    property var history: ["Appearance"]
    property int historyIndex: 0
    windowTitle: "System Settings"
    searchFocused: settingsSearch.activeFocus
    readonly property var pages: Bridge.settingsCategories
    readonly property var generalPages: ["About", "Software Update", "Storage", "AppleCare & Warranty", "AirDrop & Continuity", "AutoFill & Passwords", "Date & Time", "Language & Region", "Login Items & Extensions", "Sharing", "Startup Disk", "Time Machine", "Device Management", "Transfer or Reset"]
    readonly property var navigationPages: settingsSearch.text.trim() ? pages.concat(generalPages.filter(name => !pages.some(p => p.name === name)).map(name => ({
                name: name,
                icon: "settings",
                color: "#8b8d92",
                connected: false
            }))) : pages.filter(p => p.name !== "Apple Account")
    function categoryAsset(name) {
        let names = {
            "Accessibility": "accessibility",
            "Appearance": "appearance",
            "Bluetooth": "bluetooth",
            "Menu Bar": "menu-bar",
            "Desktop & Dock": "desktop-dock",
            "Displays": "displays",
            "Family": "family",
            "Focus": "focus",
            "Game Center": "game-center",
            "Internet Accounts": "internet-accounts",
            "Keyboard": "keyboard",
            "Lock Screen": "lock-screen",
            "Mouse": "mouse",
            "Network": "network",
            "Notifications": "notifications",
            "Battery": "battery",
            "Printers & Scanners": "printers",
            "Screen Time": "screen-time",
            "Privacy & Security": "privacy-security",
            "Siri": "siri",
            "Sound": "sound",
            "Spotlight": "spotlight",
            "Trackpad": "trackpad",
            "Users & Groups": "users-groups",
            "Wallet & Apple Pay": "wallet",
            "Wallpaper": "wallpaper",
            "Wi-Fi": "wifi",
            "General": "general",
            "Apple Account": "apple-account"
        };
        return names[name] ? Bridge.assetRoot + "settings-reference/category-" + names[name] + "-" + (win.dark ? "dark" : "light") + ".png" : "";
    }
    function editSearch(command) {
        settingsSearch.forceActiveFocus();
        if (command === "copy")
            settingsSearch.copy();
        else if (command === "cut")
            settingsSearch.cut();
        else if (command === "paste")
            settingsSearch.paste();
        else if (command === "undo")
            settingsSearch.undo();
        else if (command === "selectAll")
            settingsSearch.selectAll();
    }
    Shortcut {
        sequence: "Ctrl+F"
        enabled: win.active
        onActivated: settingsSearch.forceActiveFocus()
    }
    function navigate(name) {
        if (page === name)
            return;
        history = history.slice(0, historyIndex + 1).concat([name]);
        historyIndex++;
        page = name;
        scroller.contentY = 0;
        activate();
    }
    function travel(delta) {
        let index = historyIndex + delta;
        if (index >= 0 && index < history.length) {
            historyIndex = index;
            page = history[index];
            scroller.contentY = 0;
        }
        activate();
    }
    Item {
        parent: win.clientItem
        anchors.fill: parent
        TextField {
            id: settingsSearch
            objectName: "settingsSearch"
            x: 18
            y: 61
            width: 195
            height: 28
            placeholderText: "Search"
            leftPadding: 28
            font.pixelSize: 13
            color: win.ink
            selectionColor: desktop.highlightColor
            selectedTextColor: win.ink
            background: Rectangle {
                radius: 15
                color: win.dark ? "#2c3032" : "#e7e8ea"
            }
            Icon {
                x: 7
                y: 7
                width: 16
                height: 16
                name: "search"
                color: win.muted
            }
            Accessible.name: "Search settings"
            onActiveFocusChanged: if (activeFocus)
                desktop.focusWindow(win, true)
        }
        Flickable {
            objectName: "settingsSidebar"
            x: 18
            y: 106
            width: 195
            height: parent.height - y - 16
            contentHeight: sidebarColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                width: 5
                policy: desktop.alwaysShowScrollbars ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
            }
            Column {
                id: sidebarColumn
                width: parent.width
                spacing: 0
                Item {
                    width: parent.width
                    height: 64
                    visible: !settingsSearch.text.trim()
                    Rectangle {
                        anchors.fill: parent
                        anchors.bottomMargin: 8
                        radius: 8
                        color: accountMouse.containsMouse ? (win.dark ? "#15ffffff" : "#09000000") : "transparent"
                    }
                    Rectangle {
                        x: 3
                        y: 6
                        width: 38
                        height: 38
                        radius: 19
                        color: win.dark ? "#53616a" : "#a9b7c2"
                        Icon {
                            anchors.centerIn: parent
                            width: 27
                            height: 27
                            name: "account"
                            color: "#edf3f6"
                        }
                    }
                    Text {
                        x: 50
                        y: 9
                        width: parent.width - x
                        text: "Local User"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        color: win.ink
                    }
                    Text {
                        x: 50
                        y: 30
                        width: parent.width - x
                        text: "Not signed in"
                        font.pixelSize: 11
                        color: win.muted
                    }
                    MouseArea {
                        id: accountMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: win.navigate("Apple Account")
                        Accessible.role: Accessible.Button
                        Accessible.name: "Local User, Apple Account settings, not signed in"
                        Accessible.onPressAction: clicked(null)
                    }
                }
                Repeater {
                    model: win.navigationPages
                    delegate: Item {
                        required property var modelData
                        readonly property bool matches: modelData.name.toLowerCase().indexOf(settingsSearch.text.toLowerCase()) >= 0
                        readonly property int groupGap: settingsSearch.text.trim() ? 0 : ["Software Update", "Wi-Fi", "General", "Notifications", "Lock Screen", "Internet Accounts", "Keyboard"].indexOf(modelData.name) >= 0 ? 16 : 0
                        width: parent.width
                        height: matches ? 32 + groupGap : 0
                        visible: matches
                        Rectangle {
                            y: parent.groupGap
                            width: parent.width
                            height: 32
                            radius: 7
                            color: win.page === modelData.name ? (win.active ? desktop.accentColor : win.dark ? "#454c52" : "#d5d9df") : navigationMouse.containsMouse ? (win.dark ? "#15ffffff" : "#09000000") : "transparent"
                            Item {
                                x: 7
                                anchors.verticalCenter: parent.verticalCenter
                                width: desktop.sidebarIconSize === "small" ? 18 : desktop.sidebarIconSize === "large" ? 23 : 20
                                height: width
                                Image {
                                    id: categoryImage
                                    anchors.fill: parent
                                    source: win.categoryAsset(modelData.name)
                                    fillMode: Image.PreserveAspectFit
                                    visible: status === Image.Ready
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    visible: categoryImage.status !== Image.Ready
                                    radius: 5
                                    color: modelData.color
                                    Icon {
                                        anchors.fill: parent
                                        anchors.margins: 1
                                        name: modelData.icon
                                        color: "white"
                                    }
                                }
                            }
                            Text {
                                x: 34
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - x - 6
                                text: modelData.name
                                color: win.page === modelData.name && win.active ? "white" : win.ink
                                opacity: win.active ? 1 : 0.6
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }
                            MouseArea {
                                id: navigationMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: win.navigate(modelData.name)
                                Accessible.role: Accessible.Button
                                Accessible.name: modelData.name + " settings"
                                Accessible.onPressAction: clicked(null)
                            }
                        }
                    }
                }
            }
        }
        Rectangle {
            x: 231
            y: 8
            width: 72
            height: 35
            radius: 17.5
            color: "transparent"
            border.color: win.active ? (win.dark ? "#2cffffff" : "#19000000") : "transparent"
            Row {
                anchors.centerIn: parent
                IconButton {
                    symbol: "back"
                    width: 34
                    height: 30
                    dark: win.dark
                    enabled: win.historyIndex > 0
                    tip: "Previous settings page"
                    onClicked: win.travel(-1)
                }
                IconButton {
                    symbol: "forward"
                    width: 34
                    height: 30
                    dark: win.dark
                    enabled: win.historyIndex < win.history.length - 1
                    tip: "Next settings page"
                    onClicked: win.travel(1)
                }
            }
        }
        Text {
            x: 316
            y: 8
            height: 34
            verticalAlignment: Text.AlignVCenter
            text: win.page
            color: win.ink
            opacity: win.active ? 1 : 0.45
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
        Flickable {
            id: scroller
            objectName: "settingsContent"
            x: 243
            y: 52
            width: parent.width - x - 20
            height: parent.height - y - 18
            contentHeight: contentLoader.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                width: 7
                policy: desktop.alwaysShowScrollbars ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
            }
            Loader {
                id: contentLoader
                width: scroller.width
                sourceComponent: win.page === "Appearance" ? appearancePage : win.page === "Desktop & Dock" ? dockPage : win.page === "Accessibility" ? accessibilityPage : win.page === "Wallpaper" ? wallpaperPage : win.page === "Menu Bar" ? menuPage : win.page === "Displays" ? displayPage : win.page === "General" ? generalPage : win.page === "About" ? aboutPage : detailedPage
            }
        }
    }
    Component {
        id: appearancePage
        AppearanceSettings {
            objectName: "appearanceSettings"
            host: win
        }
    }
    Component {
        id: dockPage
        Column {
            spacing: 12
            SettingsCard {
                dark: win.dark
                Item {
                    width: parent.width
                    height: 72
                    Text {
                        y: 11
                        text: "Size"
                        color: win.ink
                        font.pixelSize: 13
                    }
                    Slider {
                        id: dockSize
                        x: 48
                        y: 7
                        width: parent.width - 48
                        height: 32
                        from: 24
                        to: 64
                        stepSize: 1
                        value: {
                            let revision = Bridge.suite.revision;
                            return Number(Bridge.suite.preference("dock.size", "54"));
                        }
                        onMoved: Bridge.suite.setPreference("dock.size", String(value))
                        Accessible.name: "Dock icon size"
                    }
                    Text {
                        x: 48
                        y: 44
                        text: "Small"
                        color: win.muted
                        font.pixelSize: 11
                    }
                    Text {
                        anchors.right: parent.right
                        y: 44
                        text: "Large"
                        color: win.muted
                        font.pixelSize: 11
                    }
                }
                SettingsToggle {
                    dark: win.dark
                    reducedMotion: desktop.reduceMotion
                    label: "Magnification"
                    enabled: !desktop.cutefishMode
                    checked: desktop.dockMagnification
                    onToggled: function (value) {
                        desktop.dockMagnification = value;
                    }
                }
                SettingsToggle {
                    dark: win.dark
                    reducedMotion: desktop.reduceMotion
                    label: "Automatically hide and show the Dock"
                    checked: desktop.dockAutoHide
                    onToggled: function (value) {
                        desktop.dockAutoHide = value;
                        if (desktop.cutefishMode) Bridge.cutefishShell.setDockAutoHide(value);
                    }
                }
                SettingsToggle {
                    dark: win.dark
                    reducedMotion: desktop.reduceMotion
                    label: "Show indicators for open applications"
                    enabled: !desktop.cutefishMode
                    checked: desktop.dockIndicators
                    onToggled: function (value) {
                        desktop.dockIndicators = value;
                    }
                }
                SettingsToggle {
                    dark: win.dark
                    reducedMotion: desktop.reduceMotion
                    label: "Animate opening applications"
                    enabled: !desktop.cutefishMode
                    checked: desktop.dockLaunchAnimation
                    onToggled: function (value) {
                        desktop.dockLaunchAnimation = value;
                    }
                }
            }
            Text {
                topPadding: 14
                text: "Desktop"
                color: win.muted
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
            SettingsCard {
                dark: win.dark
                SettingsToggle {
                    dark: win.dark
                    reducedMotion: desktop.reduceMotion
                    label: "Show items on the desktop"
                    checked: desktop.showDesktopItems
                    onToggled: function (value) {
                        desktop.showDesktopItems = value;
                    }
                }
            }
        }
    }
    Component {
        id: accessibilityPage
        Column {
            spacing: 12
            Text {
                text: "Display"
                color: win.ink
                font.pixelSize: 20
                font.weight: Font.DemiBold
                bottomPadding: 8
            }
            SettingsCard {
                dark: win.dark
                SettingsToggle {
                    dark: win.dark
                    reducedMotion: desktop.reduceMotion
                    label: "Reduce motion"
                    description: "Reduce animations and movement throughout the desktop."
                    checked: desktop.reduceMotion
                    onToggled: function (value) {
                        desktop.reduceMotion = value;
                    }
                }
                SettingsToggle {
                    dark: win.dark
                    reducedMotion: desktop.reduceMotion
                    label: "Reduce transparency"
                    description: "Use opaque surfaces for easier reading."
                    checked: desktop.reduceTransparency
                    onToggled: function (value) {
                        desktop.reduceTransparency = value;
                    }
                }
            }
        }
    }
    Component {
        id: wallpaperPage
        Column {
            spacing: 16
            Image {
                width: parent.width
                height: 210
                source: Bridge.assetRoot + (desktop.wallpaperIsDark ? "wallpaper-dark.jpg" : "wallpaper-light.jpg")
                fillMode: Image.PreserveAspectCrop
            }
            Text {
                text: "Tahoe"
                color: win.ink
                font.pixelSize: 20
                font.weight: Font.DemiBold
            }
            Row {
                spacing: 10
                Repeater {
                    model: [
                        {
                            label: "Automatic",
                            value: "appearance"
                        },
                        {
                            label: "Day",
                            value: "day"
                        },
                        {
                            label: "Night",
                            value: "night"
                        }
                    ]
                    delegate: DialogButton {
                        required property var modelData
                        text: modelData.label
                        dark: win.dark
                        primary: desktop.wallpaperMode === modelData.value
                        onClicked: desktop.wallpaperMode = modelData.value
                    }
                }
            }
        }
    }
    Component {
        id: menuPage
        MenuBarSettings { objectName: "menuBarSettings"; host: win }
    }
    Component {
        id: displayPage
        Column {
            spacing: 18
            Rectangle {
                width: parent.width
                height: 220
                radius: 12
                color: win.dark ? "#2b3033" : "white"
                Rectangle {
                    anchors.centerIn: parent
                    width: 250
                    height: 155
                    radius: 10
                    color: "#16191e"
                    border.width: 8
                    border.color: "#454a50"
                    Image {
                        anchors.fill: parent
                        anchors.margins: 9
                        source: Bridge.assetRoot + "wallpaper-light.jpg"
                        fillMode: Image.PreserveAspectCrop
                    }
                }
            }
            Text {
                text: "Desktop Display"
                color: win.ink
                font.pixelSize: 20
                font.weight: Font.DemiBold
            }
            Text {
                text: "Workspace: " + Math.round(desktop.width) + " × " + Math.round(desktop.height)
                color: win.muted
                font.pixelSize: 13
            }
            DialogButton {
                text: "Full Screen Desktop"
                dark: win.dark
                onClicked: desktop.dispatch("shellfullscreen")
            }
        }
    }
    Component {
        id: aboutPage
        Column {
            spacing: 14
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 72
                height: 72
                source: Bridge.assetRoot + "settings.png"
            }
            Text {
                width: parent.width
                text: "Tahoe Desktop"
                horizontalAlignment: Text.AlignHCenter
                color: win.ink
                font.pixelSize: 24
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                text: "Prototype 0.4"
                horizontalAlignment: Text.AlignHCenter
                color: win.muted
                font.pixelSize: 13
            }
            SettingsCard {
                dark: win.dark
                Text {
                    width: parent.width
                    topPadding: 12
                    bottomPadding: 12
                    text: "Workspace\n" + Bridge.rootPath
                    color: win.ink
                    font.pixelSize: 12
                    wrapMode: Text.WrapAnywhere
                }
            }
        }
    }

    Component {
        id: generalPage
        Column {
            spacing: 12
            SettingsCard {
                dark: win.dark
                Item {
                    width: parent.width
                    height: 140
                    Image {
                        x: (parent.width - width) / 2
                        y: 16
                        width: 52
                        height: 52
                        source: Bridge.assetRoot + "settings.png"
                    }
                    Text {
                        y: 79
                        width: parent.width
                        text: "General"
                        color: win.ink
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        y: 110
                        width: parent.width
                        text: "Manage your overall setup and preferences."
                        color: win.muted
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
            SettingsCard {
                dark: win.dark
                Repeater {
                    model: win.generalPages
                    delegate: Item {
                        required property string modelData
                        width: parent.width
                        height: 44
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData
                            color: win.ink
                            font.pixelSize: 13
                        }
                        Icon {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            name: "chevron"
                            color: win.muted
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: win.dark ? "#12ffffff" : "#0c000000"
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: win.navigate(modelData)
                            Accessible.role: Accessible.Button
                            Accessible.name: modelData
                            Accessible.onPressAction: clicked(null)
                        }
                    }
                }
            }
        }
    }
    Component {
        id: detailedPage
        SettingsDetails {
            host: win
        }
    }
}
