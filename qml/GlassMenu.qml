import QtQuick
import QtQuick.Controls
import "MenuSymbols.js" as MenuSymbols

MaterialPopup {
    id: popup
    property bool reducedTransparency: false
    signal traverse(int direction)
    signal submenuRequested(var rows, real offset)
    signal submenuDismissed()
    property real maximumHeight: 600
    readonly property bool hasSymbols: rows.some(row => MenuSymbols.symbolFor(row) !== "")
    readonly property real labelInset: hasSymbols ? 46 : 22
    function resetTracking() {
        currentIndex = -1;
        menuViewport.contentY = 0;
        submenuDismissed();
    }
    function rowOffset(index) {
        let offset = 0;
        for (let i=0;i<index;i++) offset += rows[i].separator ? 10 : 26;
        return offset;
    }
    function openSubmenu(index) { submenuRequested(rows[index].submenu, rowOffset(index) - menuViewport.contentY); }
    property string pendingCommand: ""
    function trigger(command) {
        pendingCommand = command;
        selectionDelay.restart();
    }
    Timer {
        id: selectionDelay
        interval: reducedMotion ? 1 : 65
        onTriggered: {
            let command = popup.pendingCommand;
            popup.close();
            popup.chosen(command);
        }
    }
    property var rows: []
    property bool dark: false
    property color accentColor: "#007aff"
    property Item backdrop
    property int currentIndex: -1
    onCurrentIndexChanged: {
        if (currentIndex < 0 || !rows[currentIndex] || !rows[currentIndex].submenu) submenuDismissed();
        Qt.callLater(revealCurrentRow);
    }
    function revealCurrentRow() {
        if (currentIndex >= 0) {
            let top = rowOffset(currentIndex);
            if (top < menuViewport.contentY) menuViewport.contentY = top;
            else if (top+25 > menuViewport.contentY+menuViewport.height) menuViewport.contentY = top+25-menuViewport.height;
        }
    }
    signal chosen(string command)
    padding: 6
    FontMetrics { id: metrics; font.pixelSize: 13 }
    width: Math.min(440, rows.reduce((size,row) => Math.max(size, metrics.advanceWidth(row.label || "") + metrics.advanceWidth(row.shortcut || "") + labelInset + 42), 250))
    transformOrigin: Popup.TopLeft
    height: Math.min(maximumHeight, menuColumn.implicitHeight + 12)
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    onOpened: resetTracking()
    readonly property point backdropOrigin: {
        let px=x, py=y, parentX=parent ? parent.x : 0, parentY=parent ? parent.y : 0;
        return parent && backdrop ? parent.mapToItem(backdrop,px,py) : Qt.point(px,py);
    }
    background: Glass {
        objectName: "menuMaterial"
        backdrop: popup.backdrop
        sampleX: popup.backdropOrigin.x
        sampleY: popup.backdropOrigin.y
        dark: popup.dark
        corner: 12
        tint: popup.dark ? 0.58 : 0.62
        refraction: 3
        frost: 0.97
        reveal: popup.materialization
        shadowOpacity: 0.24
        reducedTransparency: popup.reducedTransparency
    }
    contentItem: Flickable {
        id: menuViewport
        objectName: "menuViewport"
        focus: true
        contentHeight: menuColumn.implicitHeight
        contentWidth: width
        onContentHeightChanged: Qt.callLater(popup.revealCurrentRow)
        onHeightChanged: Qt.callLater(popup.revealCurrentRow)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        Column {
        id: menuColumn
        width: menuViewport.width
        spacing: 1
        Repeater {
            model: popup.rows
            delegate: Item {
                id: row
                required property var modelData
                required property int index
                objectName: "menuRow_" + index
                width: popup.availableWidth
                height: modelData.separator ? 9 : 25
                readonly property bool available: modelData.enabled !== false
                readonly property string symbolName: MenuSymbols.symbolFor(modelData)
                readonly property bool highlighted: !modelData.separator && available && popup.currentIndex === index
                readonly property color foreground: highlighted ? "white" : popup.dark ? "#f2f4f5" : "#22262a"
                readonly property real contentOpacity: available ? 1 : 0.35
                Rectangle {
                    visible: row.modelData.separator === true
                    x: 9
                    y: 4
                    width: parent.width - 18
                    height: 1
                    color: popup.dark ? "#28ffffff" : "#21000000"
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 5
                    color: popup.accentColor
                    visible: row.highlighted
                }
                Image {
                    id: symbolSource
                    objectName: "menuSymbolSource_" + row.index
                    x: 20
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18
                    source: MenuSymbols.assetFor(row.modelData)
                    visible: false
                    smooth: true
                }
                ShaderEffect {
                    objectName: "menuSymbol_" + row.index
                    x: symbolSource.x
                    y: symbolSource.y
                    width: symbolSource.width
                    height: symbolSource.height
                    visible: row.symbolName !== ""
                    opacity: row.contentOpacity
                    property var source: symbolSource
                    property color tint: row.foreground
                    fragmentShader: "../shaders/symbol.frag.qsb"
                }
                Text {
                    id: labelText
                    objectName: "menuLabel_" + row.index
                    visible: !row.modelData.separator
                    x: popup.labelInset
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.label || ""
                    width: Math.max(0, shortcutText.x - x - 16)
                    elide: Text.ElideRight
                    font.pixelSize: 13
                    color: row.foreground
                    opacity: row.contentOpacity
                }
                Icon {
                    objectName: "menuCheck_" + row.index
                    visible: !row.modelData.separator && !!row.modelData.checked
                    x: 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12
                    height: 12
                    name: "check"
                    color: row.foreground
                    opacity: row.contentOpacity
                }
                Text {
                    id: shortcutText
                    objectName: "menuShortcut_" + row.index
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.submenu ? "›" : row.modelData.shortcut || ""
                    font.pixelSize: 12
                    color: row.highlighted ? "white" : popup.dark ? "#b0b6bf" : "#727880"
                    opacity: row.contentOpacity
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: !row.modelData.separator && row.available
                    hoverEnabled: true
                    onEntered: {
                        popup.currentIndex = row.index;
                        if(row.modelData.submenu) popup.openSubmenu(row.index);
                    }
                    onClicked: if (row.available) {
                        if(row.modelData.submenu) popup.openSubmenu(row.index); else popup.trigger(row.modelData.command);
                    }
                    Accessible.role: Accessible.MenuItem
                    Accessible.name: row.modelData.label || ""
                    Accessible.ignored: row.modelData.separator === true
                    Accessible.onPressAction: if (row.available) {
                        if(row.modelData.submenu) popup.openSubmenu(row.index); else popup.trigger(row.modelData.command);
                    }
                }
            }
        }
        }
        Keys.onPressed: function (event) {
            if(event.key === Qt.Key_Right && popup.currentIndex>=0 && popup.rows[popup.currentIndex].submenu) {
                popup.openSubmenu(popup.currentIndex);
                event.accepted=true;return;
            }
            if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                popup.traverse(event.key === Qt.Key_Left ? -1 : 1);
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                let direction = event.key === Qt.Key_Down ? 1 : -1;
                let i = popup.currentIndex;
                for (let n = 0; n < popup.rows.length; n++) {
                    i = (i + direction + popup.rows.length) % popup.rows.length;
                    if (!popup.rows[i].separator && popup.rows[i].enabled !== false) {
                        popup.currentIndex = i;
                        break;
                    }
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Return && popup.currentIndex >= 0 && popup.rows[popup.currentIndex] && !popup.rows[popup.currentIndex].separator && popup.rows[popup.currentIndex].enabled !== false) {
                if(popup.rows[popup.currentIndex].submenu) popup.openSubmenu(popup.currentIndex); else popup.trigger(popup.rows[popup.currentIndex].command);
                event.accepted = true;
            }
        }
    }
}
