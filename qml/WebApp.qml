import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    required property var host
    objectName: "webApp"
    readonly property var browsingProfile: downloadLoader.item ? downloadLoader.item.profile : null
    readonly property var downloadManager: downloadLoader.item
    readonly property bool downloadsVisible: downloadManager ? downloadManager.listVisible : false
    function ensureSession() {
        if (!downloadLoader.item)
            downloadLoader.setSource("BrowserDownloads.qml", {
                owner: root
            });
        return downloadLoader.item;
    }
    readonly property bool maps: host.appKind === "maps"
    property int currentTab: 0
    property int nextUid: 1
    property int pageRevision: 0
    property var currentPage: {
        let revision = pageRevision;
        return pageRepeater.itemAt(currentTab) ? pageRepeater.itemAt(currentTab).pageItem : null;
    }
    readonly property var bookmarks: {
        let revision = Bridge.suite.revision;
        return Bridge.suite.records("bookmarks", false);
    }
    property string feedback: ""
    readonly property string activeUrl: currentTab >= 0 && currentTab < tabModel.count ? tabModel.get(currentTab).pageUrl : ""
    readonly property bool bookmarked: bookmarks.some(item => item.url === activeUrl && activeUrl !== "")
    function flush() {
        if (downloadManager)
            downloadManager.flush();
        for (let i = 0; i < pageRepeater.count; i++) {
            let page = pageRepeater.itemAt(i).pageItem;
            if (page)
                page.stop();
        }
    }
    function command(name) {
        if (downloadManager && downloadManager.command(name))
            return;
        if (name === "downloads") {
            let manager = ensureSession();
            if (manager)
                manager.toggleList();
            return;
        }
        if (name === "reload") {
            if (currentPage)
                currentPage.reload();
            return;
        }
        if (name === "stop") {
            if (currentPage)
                currentPage.stop();
            return;
        }
        if (name === "home") {
            home();
            return;
        }
        if (name === "bookmark") {
            toggleBookmark();
            return;
        }
        if (name.startsWith("bookmark:")) {
            let bookmark = bookmarks.find(item => item.id === name.slice(9));
            if (bookmark)
                openUrl(bookmark.url, false);
            return;
        }
        if (name === "closeTab") {
            closeTab(currentTab);
            return;
        }
        if (name === "find" || name === "focusLocation") {
            address.forceActiveFocus();
            address.selectAll();
            return;
        }
        if (name === "new") {
            if (!maps)
                newTab();
            else
                address.forceActiveFocus();
        } else if (name === "back") {
            if (currentPage)
                currentPage.back();
        } else if (name === "forward") {
            if (currentPage)
                currentPage.forward();
        } else if (address.activeFocus && typeof address[name] === "function")
            address[name]();
        else if (currentPage)
            currentPage.command(name);
    }
    function newTab() {
        if (tabModel.count >= 12) {
            host.desktop.showInfo("Tabs", "Close a tab before opening another. This prototype keeps up to 12 tabs.");
            return false;
        }
        tabModel.append({
            uid: nextUid++,
            pageUrl: "",
            pageTitle: maps ? "Maps" : "Start Page"
        });
        currentTab = tabModel.count - 1;
        address.text = "";
        address.forceActiveFocus();
        return true;
    }
    function closeTab(index) {
        if (index < 0 || index >= tabModel.count)
            return;
        if (tabModel.count === 1) {
            home();
            return;
        }
        tabModel.remove(index);
        if (currentTab >= tabModel.count)
            currentTab = tabModel.count - 1;
        else if (index < currentTab)
            currentTab--;
        address.text = activeUrl;
    }
    function home() {
        let row = pageRepeater.itemAt(currentTab);
        if (row)
            row.clear();
        tabModel.setProperty(currentTab, "pageUrl", "");
        tabModel.setProperty(currentTab, "pageTitle", maps ? "Maps" : "Start Page");
        address.text = "";
    }
    function openUrl(value, inNewTab) {
        if (inNewTab && !maps && !newTab())
            return;
        if (!ensureSession())
            return;
        let url = Bridge.suite.webAddress(value);
        if (currentPage)
            currentPage.load(url);
        else
            tabModel.setProperty(currentTab, "pageUrl", url);
        address.text = url;
        address.focus = false;
    }
    function navigate() {
        let value = address.text.trim();
        if (!value)
            return;
        if (maps)
            openUrl("https://www.openstreetmap.org/search?query=" + encodeURIComponent(value), false);
        else
            openUrl(value, false);
    }
    function updateTab(uid, url, title) {
        for (let i = 0; i < tabModel.count; i++)
            if (tabModel.get(i).uid === uid) {
                if (url !== "about:blank")
                    tabModel.setProperty(i, "pageUrl", url);
                tabModel.setProperty(i, "pageTitle", title || (maps ? "Maps" : "New Tab"));
                if (i === currentTab && !address.activeFocus && !maps)
                    address.text = url;
                return;
            }
    }
    function toggleBookmark() {
        let existing = bookmarks.find(item => item.url === activeUrl);
        if (existing)
            Bridge.suite.setDeleted(existing.id, true);
        else if (activeUrl)
            Bridge.suite.save("bookmarks", "", {
                title: tabModel.get(currentTab).pageTitle,
                url: activeUrl
            });
    }
    onCurrentTabChanged: if (currentTab >= 0 && currentTab < tabModel.count && !maps)
        address.text = tabModel.get(currentTab).pageUrl
    Component.onCompleted: tabModel.append({
        uid: 0,
        pageUrl: "",
        pageTitle: maps ? "Maps" : "Start Page"
    })
    ListModel {
        id: tabModel
    }
    Rectangle {
        anchors.fill: parent
        color: host.dark ? "#202629" : "#f8f9fa"
        radius: 20
    }
    Rectangle {
        id: toolbar
        x: 12
        y: 0
        width: parent.width - 24
        height: 46
        color: "transparent"
        Row {
            id: navigation
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            IconButton {
                symbol: "back"
                tip: "Back"
                dark: host.dark
                enabled: root.currentPage && root.currentPage.canGoBack
                onClicked: root.currentPage.back()
            }
            IconButton {
                symbol: "forward"
                tip: "Forward"
                dark: host.dark
                enabled: root.currentPage && root.currentPage.canGoForward
                onClicked: root.currentPage.forward()
            }
            IconButton {
                symbol: "home"
                tip: "Start Page"
                dark: host.dark
                onClicked: root.home()
            }
        }
        TextField {
            id: address
            x: navigation.width + 14
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(140, parent.width - x - 153)
            height: 33
            color: host.ink
            placeholderTextColor: host.muted
            font.pixelSize: 13
            horizontalAlignment: activeFocus || root.maps ? TextInput.AlignLeft : TextInput.AlignHCenter
            selectByMouse: true
            leftPadding: 14
            rightPadding: 14
            placeholderText: root.maps ? "Search for a place or address" : "Search or enter website name"
            Accessible.name: root.maps ? "Search Maps" : "Search or enter website name"
            background: Rectangle {
                radius: 11
                color: host.dark ? "#374044" : "#e8ebee"
                border.width: address.activeFocus ? 2 : 0
                border.color: "#4c9dec"
            }
            onAccepted: root.navigate()
        }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Button {
                text: root.currentPage && root.currentPage.loading ? "×" : "↻"
                width: 32
                height: 32
                flat: true
                Accessible.name: root.currentPage && root.currentPage.loading ? "Stop loading" : "Reload page"
                onClicked: if (root.currentPage) {
                    if (root.currentPage.loading)
                        root.currentPage.stop();
                    else
                        root.currentPage.reload();
                }
                contentItem: Icon {
                    name: root.currentPage && root.currentPage.loading ? "close" : "reload"
                    color: host.ink
                }
            }
            Button {
                width: 32
                height: 32
                flat: true
                text: root.bookmarked ? "★" : "☆"
                enabled: root.activeUrl !== ""
                Accessible.name: root.bookmarked ? "Remove Bookmark" : "Add Bookmark"
                onClicked: root.toggleBookmark()
                contentItem: Icon {
                    name: root.bookmarked ? "bookmarkfill" : "bookmark"
                    color: root.bookmarked ? "#e6ac25" : host.ink
                }
            }
            IconButton {
                symbol: "downloads"
                tip: "Downloads"
                dark: host.dark
                onClicked: root.command("downloads")
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    width: 13
                    height: 13
                    radius: 7
                    color: "#1686f6"
                    visible: root.downloadManager && root.downloadManager.activeCount > 0
                    Text {
                        anchors.centerIn: parent
                        text: root.downloadManager ? root.downloadManager.activeCount : ""
                        color: "white"
                        font.pixelSize: 9
                    }
                }
            }
            IconButton {
                visible: !root.maps
                symbol: "plus"
                tip: "New Tab"
                dark: host.dark
                onClicked: root.newTab()
            }
        }
    }
    Rectangle {
        x: address.x + 12
        y: 37
        height: 2
        radius: 1
        width: root.currentPage ? address.width * root.currentPage.loadProgress / 100 : 0
        color: "#1686f6"
        visible: root.currentPage && root.currentPage.loading
    }
    Row {
        id: tabs
        visible: !root.maps && tabModel.count > 1
        x: 16
        y: 48
        height: visible ? 35 : 0
        spacing: 5
        Repeater {
            model: tabModel
            delegate: Rectangle {
                required property int index
                required property string pageTitle
                width: Math.max(90, (root.width - 32 - 5 * (tabModel.count - 1)) / tabModel.count)
                height: 32
                radius: 9
                color: root.currentTab === index ? (host.dark ? "#56616a" : "white") : (host.dark ? "#30383e" : "#e5e8eb")
                Text {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 36
                    text: pageTitle
                    color: host.ink
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.currentTab = index
                }
                IconButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    symbol: "close"
                    tip: "Close Tab"
                    width: 24
                    height: 24
                    dark: host.dark
                    onClicked: root.closeTab(index)
                }
            }
        }
    }
    Item {
        id: webArea
        x: 8
        y: tabs.visible ? 88 : 48
        width: parent.width - 16
        height: parent.height - y - (root.maps ? 28 : 8)
        clip: true
        Repeater {
            id: pageRepeater
            onItemAdded: root.pageRevision++
            onItemRemoved: root.pageRevision++
            model: tabModel
            delegate: Item {
                id: tabPage
                required property int index
                required property int uid
                required property string pageUrl
                required property string pageTitle
                property alias pageItem: pageLoader.item
                anchors.fill: parent
                visible: root.currentTab === index
                function clear() {
                    pageLoader.source = "";
                }
                function ensurePage() {
                    if (pageUrl && !pageLoader.source.toString() && root.ensureSession())
                        pageLoader.setSource("WebPage.qml", {
                            owner: root,
                            tabUid: uid,
                            initialUrl: pageUrl
                        });
                }
                onPageUrlChanged: ensurePage()
                Component.onCompleted: ensurePage()
                Loader {
                    id: pageLoader
                    anchors.fill: parent
                    onLoaded: root.pageRevision++
                    onSourceChanged: root.pageRevision++
                }
                ScrollView {
                    anchors.fill: parent
                    visible: !pageLoader.item
                    contentWidth: availableWidth
                    Column {
                        x: Math.max(25, (webArea.width - 650) / 2)
                        width: Math.min(650, webArea.width - 50)
                        spacing: 24
                        topPadding: 48
                        Image {
                            visible: root.maps
                            source: Bridge.assetRoot + "maps.png"
                            width: 92
                            height: 92
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: root.maps ? "Explore the World" : "Favorites"
                            color: host.ink
                            font.pixelSize: root.maps ? 32 : 25
                            font.weight: Font.Bold
                        }
                        Text {
                            visible: root.maps
                            width: parent.width
                            text: "Search places and addresses with OpenStreetMap, or open the world map."
                            wrapMode: Text.Wrap
                            font.pixelSize: 14
                            color: host.muted
                        }
                        DialogButton {
                            visible: root.maps
                            text: "Open World Map"
                            primary: true
                            dark: host.dark
                            onClicked: root.openUrl("https://www.openstreetmap.org/#map=2/20/0", false)
                        }
                        Flow {
                            visible: !root.maps
                            width: parent.width
                            spacing: 22
                            Repeater {
                                model: root.bookmarks.length ? root.bookmarks : [
                                    {
                                        title: "Apple",
                                        url: "https://www.apple.com"
                                    },
                                    {
                                        title: "Wikipedia",
                                        url: "https://www.wikipedia.org"
                                    },
                                    {
                                        title: "Qt",
                                        url: "https://www.qt.io"
                                    },
                                    {
                                        title: "OpenStreetMap",
                                        url: "https://www.openstreetmap.org"
                                    }
                                ]
                                delegate: Item {
                                    required property var modelData
                                    required property int index
                                    width: 100
                                    height: 116
                                    Rectangle {
                                        x: 10
                                        width: 80
                                        height: 80
                                        radius: 19
                                        color: ["#ddeaf7", "#eadfe9", "#e0efdd", "#f0e5d5"][index % 4]
                                        border.color: "#12000000"
                                        Text {
                                            anchors.centerIn: parent
                                            text: (modelData.title || modelData.url || "?").slice(0, 1).toUpperCase()
                                            font.pixelSize: 35
                                            font.weight: Font.DemiBold
                                            color: ["#3575ad", "#8c5689", "#59944c", "#b78948"][index % 4]
                                        }
                                    }
                                    Text {
                                        x: 0
                                        y: 87
                                        width: parent.width
                                        text: modelData.title || modelData.url
                                        color: host.ink
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.openUrl(modelData.url, false)
                                    }
                                }
                            }
                        }
                        Rectangle {
                            visible: !root.maps
                            width: parent.width
                            height: 90
                            radius: 15
                            color: host.dark ? "#28333a" : "#edf1f4"
                            Row {
                                x: 20
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 16
                                Icon {
                                    name: "shield"
                                    color: "#6c8d9a"
                                    width: 36
                                    height: 36
                                }
                                Column {
                                    spacing: 6
                                    Text {
                                        text: "Your own browsing session"
                                        color: host.ink
                                        font.pixelSize: 15
                                        font.weight: Font.DemiBold
                                    }
                                    Text {
                                        text: "Bookmarks are saved. Browsing data is cleared when this app closes."
                                        color: host.muted
                                        font.pixelSize: 12
                                        width: Math.max(120, webArea.width - 230)
                                        wrapMode: Text.Wrap
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Loader {
        id: downloadLoader
        anchors.fill: parent
        z: 100
    }
    Text {
        visible: root.maps
        x: 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        text: "Map data © OpenStreetMap contributors · OpenStreetMap web map"
        color: host.muted
        font.pixelSize: 11
    }
}
