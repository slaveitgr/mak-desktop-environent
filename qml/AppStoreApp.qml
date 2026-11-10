import QtQuick
import QtQuick.Controls
import "AppStoreCatalog.js" as Catalog

FocusScope {
    id: store
    objectName: "appStoreApp"
    required property var host
    readonly property color accent: host.desktop.accentColor || "#ee526b"
    readonly property int sidebarWidth: host.sidebarWidth
    readonly property real bodyWidth: Math.max(260, width - sidebarWidth - 76)
    property string section: "Discover"
    property string categoryFilter: ""
    property string selectedId: ""
    property alias searchText: search.text
    property var navigation: []
    property bool restoring: false
    readonly property bool canGoBack: navigation.length > 0
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
    ].concat(Bridge.applicationCatalog.filter(a => ["apps", "appstore"].indexOf(a.id) < 0)).map(Catalog.metadata)
    readonly property var selectedApp: allApps.find(a => a.id === selectedId) || null
    readonly property var filteredApps: allApps.filter(a => (search.text.trim() ? (a.name + " " + a.subtitle).toLowerCase().includes(search.text.trim().toLowerCase()) : Catalog.sectionMatches(a, section)) && (!categoryFilter || a.category === categoryFilter))
    readonly property var featuredApps: section === "Discover" || section === "Work" ? ["notes", "calendar"].map(id => allApps.find(a => a.id === id)).filter(a => a) : filteredApps.slice(0, 2)
    readonly property var heroApp: allApps.find(a => a.id === "notes") || null
    readonly property bool categoryPage: !selectedApp && !search.text.trim() && section === "Categories" && !categoryFilter
    readonly property string heading: search.text.trim() ? "Search Results" : categoryFilter || section
    readonly property bool specialPage: section === "Arcade" || section === "Updates"
    readonly property var sections: [
        {
            name: "Discover",
            icon: "star"
        },
        {
            name: "Arcade",
            icon: "games"
        },
        {
            name: "Create",
            icon: "image"
        },
        {
            name: "Work",
            icon: "compose"
        },
        {
            name: "Play",
            icon: "play"
        },
        {
            name: "Develop",
            icon: "settings"
        },
        {
            name: "Categories",
            icon: "grid"
        },
        {
            name: "Updates",
            icon: "downloads"
        }
    ]
    function snapshot() {
        return {
            section: section,
            category: categoryFilter,
            id: selectedId,
            query: search.text,
            scroll: scroll.contentItem.contentY
        };
    }
    function pushNavigation() {
        navigation = navigation.concat([snapshot()]);
    }
    function resetScroll() {
        scroll.contentItem.contentY = 0;
    }
    function chooseSection(name) {
        if (!sections.some(s => s.name === name))
            return;
        pushNavigation();
        restoring = true;
        section = name;
        categoryFilter = "";
        selectedId = "";
        search.text = "";
        restoring = false;
        resetScroll();
    }
    function chooseCategory(name) {
        if (Catalog.categories.indexOf(name) < 0)
            return;
        pushNavigation();
        restoring = true;
        section = "Categories";
        categoryFilter = name;
        selectedId = "";
        search.text = "";
        restoring = false;
        resetScroll();
    }
    function openDetail(id) {
        if (!allApps.some(a => a.id === id))
            return;
        pushNavigation();
        selectedId = id;
        resetScroll();
    }
    function goBack() {
        if (!canGoBack)
            return;
        let previous = navigation[navigation.length - 1];
        navigation = navigation.slice(0, -1);
        restoring = true;
        section = previous.section;
        categoryFilter = previous.category;
        selectedId = previous.id;
        search.text = previous.query;
        restoring = false;
        Qt.callLater(function () {
            scroll.contentItem.contentY = previous.scroll;
        });
    }
    function launch(id) {
        if (allApps.some(a => a.id === id))
            host.desktop.openApplication(id);
    }
    function command(name) {
        if (name === "find") {
            search.forceActiveFocus();
            search.selectAll();
        } else if (name === "back")
            goBack();
        else if (name.startsWith("section:"))
            chooseSection(name.slice(8));
    }
    Keys.onEscapePressed: {
        if (selectedApp || canGoBack)
            goBack();
        else
            search.clear();
    }
    IconButton {
        objectName: "storeBackButton"
        x: sidebarWidth + 14
        y: -43
        width: 32
        height: 32
        symbol: "back"
        tip: "Back"
        dark: host.dark
        visible: canGoBack
        onClicked: store.goBack()
    }
    TextField {
        id: search
        objectName: "storeSearch"
        x: 18
        y: 8
        width: sidebarWidth - 36
        height: 29
        placeholderText: "Search"
        color: host.ink
        font.pixelSize: 12
        leftPadding: 31
        rightPadding: 8
        selectByMouse: true
        Accessible.name: "Search App Store"
        background: Rectangle {
            radius: 15
            color: host.dark ? "#26ffffff" : "#15000000"
        }
        Icon {
            x: 10
            y: 7
            width: 15
            height: 15
            name: "search"
            color: host.muted
        }
        onTextChanged: if (!store.restoring) {
            store.selectedId = "";
            store.categoryFilter = "";
            store.section = "Discover";
            store.resetScroll();
        }
        onAccepted: if (store.filteredApps.length)
            store.openDetail(store.filteredApps[0].id)
    }
    Column {
        x: 18
        y: 53
        width: sidebarWidth - 28
        spacing: 0
        Repeater {
            model: store.sections
            delegate: ItemDelegate {
                id: sectionButton
                required property var modelData
                objectName: "storeSection:" + modelData.name
                width: parent.width
                height: 38
                Accessible.name: modelData.name
                Accessible.selected: store.section === modelData.name && !search.text.trim()
                onClicked: store.chooseSection(modelData.name)
                contentItem: Item {
                    Icon {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        name: modelData.icon
                        color: sectionButton.Accessible.selected ? store.accent : host.ink
                    }
                    Text {
                        x: 37
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name
                        color: sectionButton.Accessible.selected ? store.accent : host.ink
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }
                }
                background: Rectangle {
                    radius: 9
                    color: sectionButton.Accessible.selected || sectionButton.hovered ? host.dark ? "#18ffffff" : "#10000000" : "transparent"
                }
            }
        }
    }
    Row {
        x: 24
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 22
        spacing: 10
        Image {
            source: Bridge.assetRoot + "appstore.png"
            width: 30
            height: 30
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Included with makOS"
            color: host.ink
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
    }
    ScrollView {
        id: scroll
        objectName: "storeContent"
        x: sidebarWidth + 38
        y: 5
        width: store.bodyWidth
        height: parent.height - 5
        clip: true
        contentWidth: availableWidth
        Column {
            width: scroll.availableWidth
            spacing: 26
            bottomPadding: 30
            Column {
                visible: !store.selectedApp
                width: parent.width
                spacing: 18
                Text {
                    objectName: "storeHeading"
                    width: parent.width
                    text: store.heading
                    color: host.ink
                    font.pixelSize: 32
                    font.weight: Font.Bold
                    wrapMode: Text.Wrap
                }
                Text {
                    visible: store.specialPage
                    width: parent.width
                    text: store.section === "Arcade" ? "Apple Arcade is not available on makOS. Explore the included games in Play." : "Package updates are not connected yet. This catalog lists applications included with makOS."
                    color: host.muted
                    font.pixelSize: 14
                    wrapMode: Text.Wrap
                }
            }
            Grid {
                visible: store.categoryPage
                width: parent.width
                columns: width >= 660 ? 3 : 2
                spacing: 18
                Repeater {
                    model: Catalog.categories
                    delegate: ItemDelegate {
                        required property string modelData
                        objectName: "storeCategory:" + modelData
                        width: (parent.width - (parent.columns - 1) * 18) / parent.columns
                        height: 44
                        Accessible.name: modelData
                        onClicked: store.chooseCategory(modelData)
                        contentItem: Text {
                            text: modelData
                            color: host.ink
                            font.pixelSize: 13
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                        background: Item {
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: 1
                                color: host.dark ? "#15ffffff" : "#15000000"
                            }
                        }
                    }
                }
            }
            Rectangle {
                visible: !store.selectedApp && store.section === "Discover" && !search.text.trim() && !store.categoryFilter
                width: parent.width
                height: 300
                radius: 13
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: "#514674"
                    }
                    GradientStop {
                        position: 1
                        color: "#332b56"
                    }
                }
                Column {
                    x: 28
                    y: 35
                    width: Math.max(130, parent.width * 0.35)
                    spacing: 18
                    Text {
                        text: "MAKE IT YOURS"
                        color: "#e3deed"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }
                    Text {
                        width: parent.width
                        text: "Your ideas.
Your next chapter."
                        color: "white"
                        font.pixelSize: 28
                        font.weight: Font.Bold
                        wrapMode: Text.Wrap
                    }
                    Text {
                        width: parent.width
                        text: "Capture your thoughts with Notes, included with makOS."
                        color: "#e3deed"
                        font.pixelSize: 14
                        wrapMode: Text.Wrap
                    }
                }
                Image {
                    x: parent.width * 0.63 - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 150
                    height: 150
                    source: store.heroApp ? Bridge.assetRoot + store.heroApp.image : ""
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (store.heroApp)
                        store.openDetail(store.heroApp.id)
                }
                Accessible.role: Accessible.Button
                Accessible.name: "Explore Notes"
                Accessible.onPressAction: if (store.heroApp)
                    store.openDetail(store.heroApp.id)
            }
            Row {
                visible: !store.selectedApp && !store.categoryPage && !store.specialPage && !search.text.trim() && !store.categoryFilter
                width: parent.width
                spacing: 20
                Repeater {
                    model: store.featuredApps
                    delegate: Column {
                        required property var modelData
                        required property int index
                        objectName: "storeFeature:" + modelData.id
                        width: (parent.width - 20) / 2
                        spacing: 8
                        Text {
                            width: parent.width
                            text: "INCLUDED WITH MAKOS"
                            color: store.accent
                            font.pixelSize: 10
                            font.weight: Font.Bold
                        }
                        Text {
                            width: parent.width
                            text: modelData.subtitle
                            color: host.ink
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: modelData.name
                            color: host.muted
                            font.pixelSize: 14
                            elide: Text.ElideRight
                        }
                        Rectangle {
                            width: parent.width
                            height: 230
                            radius: 13
                            gradient: Gradient {
                                GradientStop {
                                    position: 0
                                    color: index === 0 ? "#365574" : "#5a4468"
                                }
                                GradientStop {
                                    position: 1
                                    color: index === 0 ? "#192f49" : "#32223f"
                                }
                            }
                            Image {
                                anchors.centerIn: parent
                                width: 120
                                height: 120
                                source: Bridge.assetRoot + modelData.image
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: store.openDetail(modelData.id)
                            }
                            Accessible.role: Accessible.Button
                            Accessible.name: modelData.name
                            Accessible.onPressAction: store.openDetail(modelData.id)
                        }
                    }
                }
            }
            Column {
                visible: !store.selectedApp && !store.categoryPage && !store.specialPage
                width: parent.width
                spacing: 16
                Text {
                    width: parent.width
                    text: search.text.trim() ? store.filteredApps.length + " Results" : "Included Apps"
                    color: host.ink
                    font.pixelSize: 21
                    font.weight: Font.Bold
                }
                Text {
                    visible: store.filteredApps.length === 0
                    width: parent.width
                    text: "No included apps found."
                    color: host.muted
                    font.pixelSize: 14
                }
                Grid {
                    width: parent.width
                    columns: width >= 660 ? 2 : 1
                    columnSpacing: 24
                    rowSpacing: 0
                    Repeater {
                        model: store.filteredApps
                        delegate: Item {
                            required property var modelData
                            objectName: "storeAppRow:" + modelData.id
                            width: (parent.width - (parent.columns - 1) * 24) / parent.columns
                            height: 84
                            Image {
                                x: 4
                                y: 14
                                width: 52
                                height: 52
                                source: Bridge.assetRoot + modelData.image
                            }
                            Column {
                                x: 72
                                y: 21
                                width: parent.width - 154
                                spacing: 5
                                Text {
                                    width: parent.width
                                    text: modelData.name
                                    color: host.ink
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: modelData.subtitle
                                    color: host.muted
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: store.openDetail(modelData.id)
                            }
                            Button {
                                objectName: "storeOpen:" + modelData.id
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 66
                                height: 27
                                text: "Open"
                                onClicked: store.launch(modelData.id)
                                contentItem: Text {
                                    text: parent.text
                                    color: store.accent
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                background: Rectangle {
                                    radius: 14
                                    color: host.dark ? "#e8e8ee" : "#eeeef1"
                                }
                            }
                            Rectangle {
                                x: 72
                                anchors.bottom: parent.bottom
                                width: parent.width - 72
                                height: 1
                                color: host.dark ? "#15ffffff" : "#15000000"
                            }
                        }
                    }
                }
            }
            Column {
                visible: !!store.selectedApp
                width: parent.width
                spacing: 28
                Item {
                    width: parent.width
                    height: 132
                    Image {
                        x: 8
                        y: 12
                        width: 98
                        height: 98
                        source: store.selectedApp ? Bridge.assetRoot + store.selectedApp.image : ""
                    }
                    Column {
                        x: 142
                        y: 8
                        width: parent.width - 150
                        spacing: 8
                        Text {
                            objectName: "storeDetailTitle"
                            width: parent.width
                            text: store.selectedApp ? store.selectedApp.name : ""
                            color: host.ink
                            font.pixelSize: 27
                            font.weight: Font.Bold
                            wrapMode: Text.Wrap
                        }
                        Text {
                            width: parent.width
                            text: store.selectedApp ? store.selectedApp.subtitle : ""
                            color: host.muted
                            font.pixelSize: 14
                            wrapMode: Text.Wrap
                        }
                        Button {
                            objectName: "storeDetailOpen"
                            text: "Open"
                            width: 76
                            height: 30
                            onClicked: if (store.selectedApp)
                                store.launch(store.selectedApp.id)
                            contentItem: Text {
                                text: parent.text
                                color: "white"
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                radius: 15
                                color: store.accent
                            }
                        }
                    }
                }
                Rectangle {
                    width: parent.width
                    height: 1
                    color: host.dark ? "#18ffffff" : "#15000000"
                }
                Row {
                    width: parent.width
                    spacing: 16
                    Repeater {
                        model: [
                            {
                                label: "CATEGORY",
                                value: store.selectedApp ? store.selectedApp.category : ""
                            },
                            {
                                label: "AVAILABILITY",
                                value: "Included"
                            },
                            {
                                label: "PLATFORM",
                                value: "makOS / Linux"
                            }
                        ]
                        delegate: Column {
                            required property var modelData
                            width: (parent.width - 32) / 3
                            spacing: 10
                            Text {
                                width: parent.width
                                text: modelData.label
                                color: host.muted
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                horizontalAlignment: Text.AlignHCenter
                            }
                            Text {
                                width: parent.width
                                text: modelData.value
                                color: host.ink
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }
                Rectangle {
                    width: parent.width
                    height: 180
                    radius: 13
                    color: host.dark ? "#2f3741" : "#ecf0f6"
                    Image {
                        x: 24
                        anchors.verticalCenter: parent.verticalCenter
                        width: 90
                        height: 90
                        source: store.selectedApp ? Bridge.assetRoot + store.selectedApp.image : ""
                    }
                    Text {
                        x: 140
                        y: 30
                        width: parent.width - 168
                        text: store.selectedApp ? store.selectedApp.description : ""
                        color: host.ink
                        font.pixelSize: 16
                        wrapMode: Text.Wrap
                    }
                }
                Text {
                    width: parent.width
                    text: "Information"
                    color: host.ink
                    font.pixelSize: 22
                    font.weight: Font.Bold
                }
                Text {
                    width: parent.width
                    text: "Included with makOS. Open launches the application already available on this desktop."
                    color: host.muted
                    font.pixelSize: 13
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
