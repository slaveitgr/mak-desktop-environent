import QtQuick
import QtQuick.Controls

FocusScope {
    id: library
    required property var host
    property string section: "All Apps"
    property bool alphabetical: true
    property alias searchText: search.text
    readonly property bool launcher: host.appKind === "apps"
    readonly property bool store: host.appKind === "appstore"
    readonly property bool games: host.appKind === "games"
    readonly property int contentLeft: launcher ? 28 : 240
    readonly property real contentWidth: Math.max(0, width - contentLeft - 22)
    readonly property var allApps: [
        {
            id: "finder",
            name: "Finder",
            image: "finder.png"
        },
        {
            id: "settings",
            name: "System Settings",
            image: "settings.png"
        }
    ].concat(Bridge.applicationCatalog.filter(a => a.id !== "apps")).concat(launcher ? Bridge.session.applications : [])
    readonly property var categories: ["All Apps", "Productivity", "Communication", "Creativity", "Utilities", "Games"].concat(Bridge.session.enabled && launcher ? ["Linux Apps"] : [])
    readonly property var filteredApps: {
        let query = search.text.trim().toLowerCase();
        let result = allApps.filter(a => (!games || a.id === "chess") && (games || section === "All Apps" || category(a.id) === section) && (a.name + " " + detail(a.id)).toLowerCase().includes(query));
        result.sort((a, b) => {
            if (!alphabetical) {
                let byCategory = category(a.id).localeCompare(category(b.id));
                if (byCategory !== 0)
                    return byCategory;
            }
            return a.name.localeCompare(b.name);
        });
        return result;
    }
    readonly property int selectedIndex: grid.currentIndex
    readonly property string selectedApp: selectedIndex >= 0 && selectedIndex < filteredApps.length ? filteredApps[selectedIndex].id : ""
    function category(id) {
        if (id.startsWith("xdg:")) return "Linux Apps";
        if (["notes", "reminders", "calendar", "contacts"].indexOf(id) >= 0)
            return "Productivity";
        if (["safari", "messages", "mail", "facetime", "phone"].indexOf(id) >= 0)
            return "Communication";
        if (["photos", "music", "photobooth"].indexOf(id) >= 0)
            return "Creativity";
        if (["chess", "games"].indexOf(id) >= 0)
            return "Games";
        return "Utilities";
    }
    function detail(id) {
        if (id.startsWith("xdg:")) { let entry = Bridge.session.applications.find(a => a.id === id); return entry ? entry.description : "Installed Linux application"; }
        let details = {
            finder: "Browse and organise your files",
            settings: "Make this desktop your own",
            notes: "Ideas, saved as you type",
            reminders: "Keep track of what’s next",
            calendar: "Your plans at a glance",
            contacts: "Everyone, together",
            safari: "Browse the web",
            messages: "Your local message drafts",
            mail: "Compose and export mail drafts",
            facetime: "Contacts for video calls",
            phone: "Contacts and keypad",
            photos: "Your pictures, in one place",
            music: "Listen to your music files",
            photobooth: "A moment, captured",
            calculator: "Everyday calculations",
            terminal: "A real local shell",
            chess: "A classic game for two",
            games: "Your game library",
            appstore: "Explore the built-in apps",
            maps: "Explore with OpenStreetMap"
        };
        return details[id] || "";
    }
    function chooseSection(name) {
        if (categories.indexOf(name) < 0)
            return;
        section = name;
        grid.positionViewAtBeginning();
    }
    function focusSearch(clear) {
        if (clear)
            search.clear();
        search.forceActiveFocus();
        search.selectAll();
    }
    function launch(id) {
        if (!id)
            return;
        host.desktop.openApplication(id);
        if (launcher)
            host.desktop.closeWindow(host);
    }
    function activateSelection() {
        if (filteredApps.length)
            launch(filteredApps[Math.max(0, grid.currentIndex)].id);
    }
    function moveSelection(offset) {
        if (!filteredApps.length)
            return;
        grid.currentIndex = Math.max(0, Math.min(filteredApps.length - 1, grid.currentIndex + offset));
        grid.positionViewAtIndex(grid.currentIndex, GridView.Contain);
        grid.forceActiveFocus();
    }
    function command(name) {
        if (name === "new" || name === "find")
            focusSearch(false);
        else if (name === "sort")
            alphabetical = !alphabetical;
        else if (name.indexOf("category:") === 0)
            chooseSection(name.slice(9));
    }
    onFilteredAppsChanged: {
        grid.currentIndex = filteredApps.length ? 0 : -1;
        grid.positionViewAtBeginning();
    }
    Component.onCompleted: { search.forceActiveFocus(); if (launcher) Bridge.session.refreshApplications(); }
    Keys.onEscapePressed: focusSearch(true)

    Rectangle {
        anchors.fill: parent
        anchors.margins: 8
        radius: 18
        color: host.dark ? "#182027" : "#f5f6f9"
        visible: library.launcher
        opacity: 0.55
    }
    Item {
        id: header
        x: library.contentLeft + 4
        y: 12
        width: library.contentWidth - 8
        height: library.launcher ? 136 : library.store ? 118 : 92
        TextField {
            id: search
            objectName: "appsSearch"
            width: parent.width - 46
            height: 38
            placeholderText: library.games ? "Search Games" : "Search Apps"
            color: host.ink
            selectionColor: "#267ee8"
            selectedTextColor: "white"
            leftPadding: 34
            rightPadding: text.length ? 32 : 14
            font.pixelSize: 14
            background: Rectangle {
                radius: 19
                color: host.dark ? "#394149" : "#e6e9ed"
                border.color: search.activeFocus ? "#659bf3" : "transparent"
            }
            Icon {
                x: 10
                y: 10
                width: 18
                height: 18
                name: "search"
                color: host.muted
            }
            ToolButton {
                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28
                visible: search.text.length > 0
                Accessible.name: "Clear search"
                onClicked: library.focusSearch(true)
                contentItem: Icon {
                    name: "close"
                    color: host.muted
                }
                background: Rectangle {
                    radius: 14
                    color: parent.hovered ? host.dark ? "#55606b" : "#cdd5df" : "transparent"
                }
            }
            Accessible.name: placeholderText
            Keys.onReturnPressed: library.activateSelection()
            Keys.onEnterPressed: library.activateSelection()
            Keys.onDownPressed: library.moveSelection(0)
            Keys.onEscapePressed: library.focusSearch(true)
        }
        ToolButton {
            id: sortButton
            objectName: "appsSort"
            anchors.right: parent.right
            width: 38
            height: 38
            hoverEnabled: true
            Accessible.name: library.alphabetical ? "Sort by category" : "Sort by name"
            Accessible.description: library.alphabetical ? "Currently sorted by name" : "Currently sorted by category, then name"
            onClicked: library.alphabetical = !library.alphabetical
            ToolTip.visible: hovered
            ToolTip.delay: 500
            ToolTip.text: Accessible.name
            contentItem: Item {
                Text {
                    anchors.centerIn: parent
                    visible: library.alphabetical
                    text: "A–Z"
                    color: host.ink
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
                Icon {
                    anchors.centerIn: parent
                    visible: !library.alphabetical
                    width: 18
                    height: 18
                    name: "grid"
                    color: host.ink
                }
            }
            background: Rectangle {
                radius: 19
                color: sortButton.hovered || sortButton.activeFocus ? host.dark ? "#46505c" : "#d9e1eb" : host.dark ? "#343d47" : "#e6e9ed"
                border.color: sortButton.activeFocus ? "#659bf3" : "transparent"
            }
        }
        Text {
            y: 57
            width: parent.width
            text: library.games ? "Your Games" : library.store ? "Discover" : section
            color: host.ink
            font.pixelSize: 28
            font.weight: Font.Bold
            elide: Text.ElideRight
        }
        Text {
            y: 97
            visible: library.store
            width: parent.width
            text: "Included with your desktop"
            color: host.muted
            font.pixelSize: 14
        }
        // Shipped Apps resources contain category chiclets and a search bar.
        // Runtime spacing is not recoverable from the resource-only REA pass.
        Flickable {
            id: categoryStrip
            objectName: "appsCategories"
            visible: library.launcher
            y: 99
            width: parent.width
            height: 40
            contentWidth: categoryRow.width
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            Row {
                id: categoryRow
                spacing: 6
                Repeater {
                    model: library.categories
                    delegate: Button {
                        id: categoryButton
                        required property string modelData
                        height: 30
                        width: implicitContentWidth + 24
                        text: modelData
                        readonly property bool selected: library.section === modelData
                        Accessible.name: modelData
                        Accessible.selected: selected
                        onClicked: library.chooseSection(modelData)
                        onActiveFocusChanged: if (activeFocus)
                            categoryStrip.contentX = Math.max(0, Math.min(categoryStrip.contentWidth - categoryStrip.width, x - 8))
                        contentItem: Text {
                            text: categoryButton.text
                            color: categoryButton.selected ? "white" : host.ink
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                        background: Rectangle {
                            radius: 15
                            color: categoryButton.selected ? "#267ee8" : host.dark ? "#3c4651" : "#e1e6ed"
                            border.color: categoryButton.activeFocus ? "#659bf3" : "transparent"
                        }
                    }
                }
            }
            ScrollBar.horizontal: ScrollBar {
                policy: ScrollBar.AsNeeded
                height: 4
            }
        }
    }
    Column {
        visible: !library.launcher
        x: 20
        y: 20
        width: 184
        spacing: 5
        Repeater {
            model: library.games ? ["All Apps"] : library.categories
            delegate: ItemDelegate {
                id: sidebarCategory
                required property string modelData
                width: 184
                height: 36
                text: modelData === "All Apps" && library.games ? "Library" : modelData
                Accessible.name: text
                Accessible.selected: section === modelData
                onClicked: library.chooseSection(modelData)
                contentItem: Text {
                    text: sidebarCategory.text
                    color: host.ink
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 12
                    font.pixelSize: 13
                    font.weight: section === modelData ? Font.DemiBold : Font.Normal
                }
                background: Rectangle {
                    radius: 9
                    color: section === modelData || sidebarCategory.activeFocus ? host.dark ? "#4a535e" : "#d8dfe7" : "transparent"
                    border.color: sidebarCategory.activeFocus ? "#659bf3" : "transparent"
                }
            }
        }
    }
    GridView {
        id: grid
        objectName: "appsGrid"
        x: library.contentLeft
        y: library.launcher ? 158 : library.store ? 144 : 118
        width: library.contentWidth
        height: Math.max(0, parent.height - y - 34)
        readonly property int columns: Math.max(1, Math.floor(width / (library.store ? 245 : 126)))
        cellWidth: width / columns
        cellHeight: library.store ? 114 : 132
        clip: true
        model: library.filteredApps
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: false
        activeFocusOnTab: true
        Accessible.name: library.games ? "Game library" : "Applications"
        Accessible.role: Accessible.List
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Right)
                library.moveSelection(1);
            else if (event.key === Qt.Key_Left)
                library.moveSelection(-1);
            else if (event.key === Qt.Key_Down)
                library.moveSelection(columns);
            else if (event.key === Qt.Key_Up) {
                if (currentIndex < columns)
                    library.focusSearch(false);
                else
                    library.moveSelection(-columns);
            } else if (event.key === Qt.Key_Home)
                library.moveSelection(-count);
            else if (event.key === Qt.Key_End)
                library.moveSelection(count);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                library.activateSelection();
            else if (event.key === Qt.Key_Escape)
                library.focusSearch(true);
            else if (event.text.length && !(event.modifiers & (Qt.ControlModifier | Qt.MetaModifier | Qt.AltModifier))) {
                library.focusSearch(false);
                search.text = event.text;
                search.cursorPosition = search.text.length;
            } else {
                event.accepted = false;
                return;
            }
            event.accepted = true;
        }
        ScrollBar.vertical: ScrollBar {
            policy: host.desktop.alwaysShowScrollbars ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
        }
        delegate: ItemDelegate {
            id: tile
            required property var modelData
            required property int index
            width: grid.cellWidth - 8
            height: grid.cellHeight - 8
            hoverEnabled: true
            focusPolicy: Qt.NoFocus
            Accessible.name: "Open " + modelData.name
            Accessible.description: library.detail(modelData.id)
            Accessible.selected: grid.currentIndex === index
            onClicked: {
                grid.currentIndex = index;
                library.launch(modelData.id);
            }
            background: Rectangle {
                radius: 18
                readonly property bool selected: grid.activeFocus && grid.currentIndex === tile.index
                color: selected ? host.dark ? "#344f72" : "#cddff7" : tile.hovered ? host.dark ? "#374452" : "#dce4ef" : "transparent"
                border.color: selected ? "#659bf3" : "transparent"
                Behavior on color {
                    ColorAnimation {
                        duration: host.desktop.reduceMotion ? 0 : 120
                    }
                }
            }
            Image {
                width: library.store ? 58 : 70
                height: width
                x: library.store ? 14 : (parent.width - width) / 2
                y: 12
                source: tile.modelData.iconUrl || Bridge.assetRoot + tile.modelData.image
                fillMode: Image.PreserveAspectFit
                scale: tile.down ? 0.92 : 1
                Behavior on scale {
                    NumberAnimation {
                        duration: host.desktop.reduceMotion ? 0 : 100
                    }
                }
            }
            Text {
                x: library.store ? 84 : 4
                y: library.store ? 19 : 88
                width: parent.width - x - 4
                height: library.store ? 18 : 34
                text: tile.modelData.name
                color: host.ink
                font.pixelSize: 13
                font.weight: Font.Medium
                horizontalAlignment: library.store ? Text.AlignLeft : Text.AlignHCenter
                wrapMode: Text.WordWrap
                maximumLineCount: library.store ? 1 : 2
                elide: Text.ElideRight
            }
            Text {
                visible: library.store
                x: 84
                y: 40
                width: parent.width - 92
                height: 30
                text: library.detail(tile.modelData.id)
                color: host.muted
                font.pixelSize: 11
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Text {
                visible: library.store
                x: 84
                y: 78
                text: "OPEN"
                color: "#1683f5"
                font.pixelSize: 11
                font.weight: Font.Bold
            }
        }
        Column {
            anchors.centerIn: parent
            width: parent.width - 32
            spacing: 6
            visible: grid.count === 0
            Text {
                width: parent.width
                text: "No Apps Found"
                horizontalAlignment: Text.AlignHCenter
                color: host.ink
                font.pixelSize: 20
                font.weight: Font.Medium
            }
            Text {
                width: parent.width
                text: "Try another name or category."
                horizontalAlignment: Text.AlignHCenter
                color: host.muted
                font.pixelSize: 13
            }
        }
    }
    Text {
        x: library.contentLeft
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        width: library.contentWidth
        text: grid.count + (library.games ? grid.count === 1 ? " Game" : " Games" : grid.count === 1 ? " App" : " Apps")
        horizontalAlignment: Text.AlignHCenter
        color: host.muted
        font.pixelSize: 11
    }
}
