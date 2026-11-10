import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

MaterialPopup {
    id: gallery
    required property var desktop
    required property Item backdrop
    property string section: "All"
    property string target: "Control Center"
    property string query: ""
    property string contextControl: ""
    readonly property var controls: desktop.controls
    readonly property bool dark: desktop.dark
    readonly property color ink: dark ? "#f3f3f6" : "#26262c"
    readonly property color muted: dark ? "#bbbcc6" : "#696a73"
    readonly property var categories: ["All"].concat(controls.catalog.map(item => item.category).filter((item, index, all) => all.indexOf(item) === index))
    readonly property var results: controls.catalog.filter(item => (section === "All" || item.category === section) && (!query || (item.label + " " + item.category + " " + item.description).toLowerCase().indexOf(query.toLowerCase()) >= 0))
    width: Math.min(780, desktop.width - 36)
    height: Math.min(590, desktop.height - 78)
    x: Math.max(18, (desktop.width - width) / 2)
    y: Math.max(42, (desktop.height - height) / 2)
    padding: 18
    focus: true
    reducedMotion: desktop.reduceMotion
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    onOpened: { query = ""; gallerySearch.text = ""; gallerySearch.forceActiveFocus(); }
    function added(id) {
        return target === "Menu Bar" ? controls.inMenu(id) : controls.layout.some(item => item.id === id);
    }
    function allowed(id) {
        return controls.info(id) !== null;
    }
    function toggle(id, size) {
        if (!allowed(id)) return;
        if (target === "Menu Bar") controls.setInMenu(id, !controls.inMenu(id));
        else if (added(id)) controls.removeControl(id);
        else controls.addControl(id, size);
    }
    function showCardMenu(id, item) {
        contextControl = id;
        let addedToCenter = controls.layout.some(entry => entry.id === id);
        cardMenu.rows = [
            {label: controls.inMenu(id) ? "Remove from Menu Bar" : "Add to Menu Bar", command: "menu"},
            {label: addedToCenter ? "Remove from Control Center" : "Add to Control Center", command: "center"}
        ];
        let point = item.mapToItem(gallery.parent, 35, 20);
        cardMenu.x = Math.max(8, Math.min(desktop.width - cardMenu.width - 8, point.x));
        cardMenu.y = Math.max(36, Math.min(desktop.height - cardMenu.height - 8, point.y));
        cardMenu.open();
    }
    onClosed: cardMenu.close()
    background: Glass {
        objectName: "controlGalleryMaterial"
        backdrop: gallery.backdrop; sampleX: gallery.x; sampleY: gallery.y
        dark: gallery.dark; corner: 28; tint: gallery.dark ? 0.58 : 0.64; frost: 0.98; refraction: 3
        reveal: gallery.materialization; reducedTransparency: desktop.reduceTransparency; shadowOpacity: 0.25
    }
    contentItem: Item {
        Item {
            id: header; width: parent.width; height: 45
            Text { x: 3; anchors.verticalCenter: parent.verticalCenter; text: "Add Controls"; color: gallery.ink; font.pixelSize: 22; font.weight: Font.DemiBold }
            ControlActionButton { objectName: "galleryClose"; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; symbol: "close"; text: "Close Add Controls"; dark: gallery.dark; onClicked: gallery.close() }
        }
        Rectangle {
            id: sidebar
            anchors.top: header.bottom; anchors.bottom: parent.bottom
            width: gallery.width < 660 ? 146 : 174; radius: 18
            color: gallery.dark ? "#22000000" : "#24ffffff"
            TextField {
                id: gallerySearch; objectName: "gallerySearch"
                x: 9; y: 10; width: parent.width - 18; height: 31
                placeholderText: "Search Controls"; color: gallery.ink; placeholderTextColor: gallery.muted
                font.pixelSize: 12; leftPadding: 28; selectByMouse: true
                onTextChanged: { gallery.query = text; gridViewport.contentY = 0; }
                background: Rectangle { radius: 9; color: gallery.dark ? "#2fffffff" : "#70ffffff"; border.color: gallerySearch.activeFocus ? "#338bff" : "#18000000" }
                Icon { x: 8; anchors.verticalCenter: parent.verticalCenter; width: 14; height: 14; name: "search"; color: gallery.muted }
                Accessible.name: "Search Controls"
            }
            Flickable {
                y: 53; width: parent.width; height: parent.height - y - 7
                contentWidth: width; contentHeight: categoryColumn.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: categoryColumn; x: 7; width: parent.width - 14; spacing: 3
                    Repeater {
                        model: gallery.categories
                        delegate: AbstractButton {
                            id: categoryButton
                            required property string modelData
                            objectName: "galleryCategory_" + modelData
                            width: categoryColumn.width; height: 33
                            Accessible.name: modelData === "All" ? "All Controls" : modelData
                            onClicked: { gallery.section = modelData; gridViewport.contentY = 0; }
                            background: Rectangle { radius: 9; color: gallery.section === categoryButton.modelData ? (gallery.dark ? "#48ffffff" : "#c5ffffff") : categoryButton.hovered ? "#18ffffff" : "transparent" }
                            contentItem: Text { leftPadding: 10; text: categoryButton.modelData === "All" ? "All Controls" : categoryButton.modelData; color: gallery.ink; verticalAlignment: Text.AlignVCenter; font.pixelSize: 12; font.weight: gallery.section === categoryButton.modelData ? Font.DemiBold : Font.Normal }
                        }
                    }
                }
            }
        }
        Item {
            id: catalogArea
            anchors.left: sidebar.right; anchors.leftMargin: 16; anchors.right: parent.right
            anchors.top: header.bottom; anchors.bottom: parent.bottom
            Item {
                id: targetBar; width: parent.width; height: 42
                Text { x: 2; anchors.verticalCenter: parent.verticalCenter; text: "Add to"; color: gallery.muted; font.pixelSize: 12 }
                ComboBox {
                    id: destination; objectName: "galleryTarget"
                    x: 52; y: 4; width: Math.min(190, parent.width - 54); height: 31
                    model: ["Control Center", "Menu Bar"]
                    currentIndex: gallery.target === "Menu Bar" ? 1 : 0
                    onActivated: gallery.target = currentText
                    Accessible.name: "Control destination"
                }
            }
            Flickable {
                id: gridViewport; objectName: "galleryViewport"
                anchors.top: targetBar.bottom; anchors.bottom: parent.bottom; width: parent.width
                contentWidth: width
                contentHeight: galleryGrid.implicitHeight + 12
                clip: true; boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                GridLayout {
                    id: galleryGrid; x: 2; y: 4; width: parent.width - 10
                    columns: catalogArea.width < 360 ? 1 : 2; rowSpacing: 10; columnSpacing: 10
                    Repeater {
                        model: gallery.results
                        delegate: Rectangle {
                            id: card
                            required property var modelData
                            objectName: "galleryCard_" + modelData.id
                            property string pendingSize: modelData.defaultSize
                            readonly property string chosenSize: {
                                let entry = gallery.controls.layout.find(item => item.id === modelData.id);
                                return entry ? entry.size : pendingSize;
                            }
                            readonly property bool added: gallery.added(modelData.id)
                            readonly property bool allowed: gallery.allowed(modelData.id)
                            Layout.fillWidth: true; Layout.preferredWidth: 180; Layout.preferredHeight: 173
                            radius: 19
                            color: gallery.dark ? "#4243434d" : "#98ffffff"
                            border.color: gallery.dark ? "#1fffffff" : "#66ffffff"
                            Icon { x: 13; y: 13; width: 28; height: 28; name: card.modelData.icon; color: gallery.ink }
                            Text { x: 13; y: 50; width: parent.width - 26; text: card.modelData.label; color: gallery.ink; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight }
                            Text { x: 13; y: 72; width: parent.width - 26; height: 35; text: card.modelData.description; color: gallery.muted; font.pixelSize: 10; wrapMode: Text.Wrap; elide: Text.ElideRight; maximumLineCount: 2 }
                            Row {
                                visible: gallery.target === "Control Center" && card.modelData.sizes.length > 1
                                x: 10; y: 111; spacing: 2
                                Repeater {
                                    model: card.modelData.sizes
                                    delegate: AbstractButton {
                                        id: sizeButton
                                        required property string modelData
                                        objectName: "gallerySize_" + card.modelData.id + "_" + modelData
                                        width: 34; height: 20
                                        Accessible.name: modelData + " " + card.modelData.label
                                        onClicked: {
                                            card.pendingSize = modelData;
                                            if (card.added && gallery.target === "Control Center") gallery.controls.resizeControl(card.modelData.id, modelData);
                                        }
                                        background: Rectangle { radius: 6; color: card.chosenSize === sizeButton.modelData ? (gallery.dark ? "#52ffffff" : "#e5ffffff") : "transparent" }
                                        contentItem: Text { text: sizeButton.modelData === "small" ? "S" : sizeButton.modelData === "medium" ? "M" : "L"; color: gallery.ink; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    }
                                }
                            }
                            ControlActionButton {
                                objectName: "galleryAdd_" + card.modelData.id
                                anchors.right: parent.right; anchors.rightMargin: 9; anchors.bottom: parent.bottom; anchors.bottomMargin: 8
                                text: !card.allowed ? "Not available" : card.added ? "Remove" : "Add"
                                enabled: card.allowed; filled: true; dark: gallery.dark
                                Accessible.name: (card.added ? "Remove " : "Add ") + card.modelData.label + (gallery.target === "Menu Bar" ? " in Menu Bar" : " in Control Center")
                                onClicked: gallery.toggle(card.modelData.id, card.chosenSize)
                            }
                            Icon { visible: card.added; x: 14; y: parent.height - 29; width: 16; height: 16; name: "check"; color: gallery.ink }
                            MouseArea {
                                objectName: "galleryContext_" + card.modelData.id
                                anchors.fill: parent; z: 5
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onPressed: function(mouse) { if (mouse.button !== Qt.RightButton && !(mouse.modifiers & (Qt.ControlModifier | Qt.MetaModifier))) mouse.accepted = false; }
                                onClicked: gallery.showCardMenu(card.modelData.id, card)
                                Accessible.ignored: true
                            }
                        }
                    }
                }
                Text { visible: gallery.results.length === 0; width: parent.width; y: 40; text: "No controls found"; horizontalAlignment: Text.AlignHCenter; color: gallery.muted; font.pixelSize: 14 }
            }
        }
    }
    GlassMenu {
        id: cardMenu; objectName: "galleryControlMenu"
        parent: gallery.parent; backdrop: gallery.backdrop; dark: gallery.dark
        reducedMotion: desktop.reduceMotion; reducedTransparency: desktop.reduceTransparency
        onChosen: function(command) {
            let id = gallery.contextControl;
            if (command === "menu") gallery.controls.setInMenu(id, !gallery.controls.inMenu(id));
            else if (command === "center") {
                if (gallery.controls.layout.some(item => item.id === id)) gallery.controls.removeControl(id);
                else gallery.controls.addControl(id);
            }
        }
    }
}
