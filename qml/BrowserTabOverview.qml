import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: overview
    objectName: "browserTabOverview"
    required property var owner
    required property var tabsModel
    property alias query: search.text
    readonly property int matchingCount: {
        let total = 0;
        for (let i = 0; i < tabsModel.count; i++)
            if (matches(tabsModel.get(i).pageTitle, tabsModel.get(i).pageUrl)) total++;
        return total;
    }
    color: owner.host.dark ? "#25282e" : "#eef0f3"
    radius: 12
    function matches(title, url) {
        let needle = query.trim().toLocaleLowerCase();
        return !needle || (title + " " + url).toLocaleLowerCase().indexOf(needle) >= 0;
    }
    function focusSearch() { search.forceActiveFocus(); }
    Keys.onEscapePressed: owner.overviewVisible = false
    TextField {
        id: search
        objectName: "browserTabSearch"
        x: Math.max(20, (parent.width - width) / 2); y: 22
        width: Math.min(360, parent.width - 40)
        height: 34
        placeholderText: "Search Tabs"
        Accessible.name: "Search Tabs"
        selectByMouse: true
        color: owner.host.ink
        background: Rectangle { color: owner.host.dark ? "#41434a" : "white"; radius: 9 }
    }
    ScrollView {
        anchors { top: search.bottom; topMargin: 24; left: parent.left; right: parent.right; bottom: parent.bottom; margins: 20 }
        clip: true
        contentWidth: availableWidth
        Flow {
            width: parent.width
            spacing: 22
            Repeater {
                model: overview.tabsModel
                delegate: Rectangle {
                    required property int index
                    required property string pageTitle
                    required property string pageUrl
                    required property string previewUrl
                    objectName: "browserTabCard_" + index
                    visible: overview.matches(pageTitle, pageUrl)
                    width: Math.max(200, (overview.width - 86) / 3)
                    height: 190
                    radius: 13
                    color: owner.host.dark ? "#383b42" : "white"
                    border.width: owner.currentTab === index ? 2 : 1
                    border.color: owner.currentTab === index ? "#479af4" : "#22000000"
                    Image {
                        x: 8; y: 8; width: parent.width - 16; height: 126
                        source: previewUrl
                        fillMode: Image.PreserveAspectFit
                        visible: source.toString() !== ""
                    }
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 42; width: 45; height: 45
                        visible: previewUrl === ""
                        name: owner.privateBrowsing ? "shield" : "network"
                        color: owner.host.muted
                    }
                    Text {
                        x: 12; y: 142; width: parent.width - 24
                        text: pageTitle; color: owner.host.ink
                        font.pixelSize: 13; font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        x: 12; y: 164; width: parent.width - 24
                        text: pageUrl; color: owner.host.muted
                        font.pixelSize: 11; elide: Text.ElideRight
                    }
                    MouseArea { anchors.fill: parent; onClicked: owner.selectTab(index) }
                    IconButton {
                        objectName: "browserTabCardClose_" + index
                        x: parent.width - 31; y: 5
                        symbol: "close"; tip: "Close Tab"
                        width: 26; height: 26; dark: owner.host.dark
                        onClicked: owner.closeTab(index)
                    }
                }
            }
            Button {
                objectName: "browserOverviewNewTab"
                text: "+ New Tab"
                width: 200; height: 190
                onClicked: owner.newTab()
            }
        }
    }
}
