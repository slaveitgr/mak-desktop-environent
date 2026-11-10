import QtQuick
import QtQuick.Controls

// Current row membership comes from the live Tahoe Settings comparison.
// Labels are also present in ControlCenterSettings.appex/Localizable.loctable,
// REA ev_f9cbeff6d204c428e14744a2689bee24220b5c09c473b61483ef6952d54a79fb.
Column {
    id: page
    objectName: "menuBarSettings"
    required property var host
    readonly property var desktop: host.desktop
    readonly property var controls: desktop.controls
    readonly property int revision: Bridge.suite.revision
    readonly property var menuControls: controls ? controls.menuControls : []
    readonly property var registeredApps: controls ? controls.registeredApps : []
    readonly property color ink: host.ink
    readonly property color muted: host.muted
    readonly property color accent: desktop.accentColor
    readonly property color cardColor: host.dark ? "#2b3336" : "#ffffff"
    readonly property color dividerColor: host.dark ? "#15ffffff" : "#10000000"
    spacing: 0

    function pref(key, fallback) {
        let r = revision;
        return Bridge.suite.preference(key, fallback);
    }
    function save(key, value, fallback) {
        if (Bridge.suite.preference(key, fallback || "") !== String(value))
            Bridge.suite.setPreference(key, String(value));
    }
    function inMenu(id) {
        let r = revision;
        return controls && controls.inMenu(id);
    }
    function mode(id) {
        let r = revision;
        return controls ? controls.mode(id) : "When Active";
    }
    function appAllowed(id) {
        let r = revision;
        return controls && controls.appAllowed(id);
    }
    function categoryAsset(control) {
        let categories = {
            display: "Displays",
            users: "Users & Groups",
            textinput: "Keyboard"
        };
        return host.categoryAsset ? host.categoryAsset(categories[control.id] || control.label) : "";
    }
    function iconColor(id) {
        let colors = {
            clock: "#25272c",
            battery: "#36b34a",
            focus: "#655bc9",
            nowplaying: "#eb335b",
            users: "#888b90",
            textinput: "#888b90",
            timemachine: "#35a44d",
            timer: "#25272c",
            weather: "#168fe5"
        };
        return colors[id] || "#1687ef";
    }

    component Card: Rectangle {
        width: page.width
        radius: 12
        color: page.cardColor
        border.color: host.dark ? "#0bffffff" : "#0b000000"
    }
    component RowDivider: Rectangle {
        x: 10
        anchors.bottom: parent.bottom
        width: parent.width - 20
        height: 1
        color: page.dividerColor
    }
    component SettingCombo: ComboBox {
        height: 27
        font.pixelSize: 12
        palette.text: page.ink
        palette.buttonText: page.ink
        palette.base: host.dark ? "#394246" : "#f5f5f6"
        palette.highlight: page.accent
        background: Rectangle {
            radius: 6
            color: host.dark ? "#41494c" : "#f5f5f6"
            border.color: host.dark ? "#14ffffff" : "#12000000"
        }
    }
    component VisibilityCheck: CheckBox {
        width: 18
        height: 24
        padding: 0
        spacing: 0
        indicator: Rectangle {
            anchors.centerIn: parent
            width: 15
            height: 15
            radius: 4
            color: parent.checked ? page.accent : host.dark ? "#535c60" : "#ffffff"
            border.color: parent.checked ? page.accent : host.dark ? "#6e777b" : "#b8bdc1"
            Icon {
                anchors.centerIn: parent
                width: 11
                height: 11
                name: "check"
                color: "white"
                visible: parent.parent.checked
            }
        }
        contentItem: Item {}
        background: Item {}
    }
    component OptionButton: DialogButton {
        dark: host.dark
        height: 27
        font.pixelSize: 12
    }
    component OptionsPopup: MaterialPopup {
        parent: Overlay.overlay
        width: Math.min(480, desktop.width - 32)
        x: Math.max(16, Math.min(desktop.width - width - 16, host.x + (host.width - width) / 2))
        y: Math.max(38, Math.min(desktop.height - height - 20, host.y + (host.height - height) / 2))
        padding: 20
        modal: true
        focus: true
        reducedMotion: desktop.reduceMotion
        closePolicy: Popup.CloseOnEscape
        background: Rectangle {
            radius: 16
            color: host.dark ? "#293135" : "#f5f5f7"
            border.color: host.dark ? "#556065" : "#c2c7cc"
        }
    }

    Card {
        height: 135
        Column {
            width: parent.width
            Item {
                width: parent.width
                height: 45
                Text {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 198
                    text: "Automatically hide and show the menu bar"
                    font.pixelSize: 13
                    color: page.ink
                    wrapMode: Text.Wrap
                }
                SettingCombo {
                    objectName: "menuBarAutoHide"
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 178
                    model: ["Always", "In Full Screen Only", "On Desktop Only", "Never"]
                    currentIndex: model.indexOf(page.pref("menubar.hide", "In Full Screen Only"))
                    onActivated: page.save("menubar.hide", currentText, "In Full Screen Only")
                    Accessible.name: "Automatically hide and show the menu bar"
                }
                RowDivider {}
            }
            Item {
                width: parent.width
                height: 45
                SettingsToggle {
                    objectName: "menuBarBackground"
                    x: 10
                    width: parent.width - 20
                    height: 45
                    dark: host.dark
                    reducedMotion: desktop.reduceMotion
                    label: "Show menu bar background"
                    checked: page.pref("menubar.background", "false") === "true"
                    onToggled: value => page.save("menubar.background", value, "false")
                }
                RowDivider {}
            }
            Item {
                width: parent.width
                height: 45
                Text {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 91
                    text: "Recent documents, applications, and servers"
                    font.pixelSize: 13
                    color: page.ink
                    wrapMode: Text.Wrap
                }
                SettingCombo {
                    objectName: "menuBarRecentItems"
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 70
                    model: ["None", "5", "10", "15", "20", "30", "50"]
                    currentIndex: Math.max(0, model.indexOf(page.pref("menubar.recents", "10") === "0" ? "None" : page.pref("menubar.recents", "10")))
                    onActivated: page.save("menubar.recents", currentText === "None" ? "0" : currentText, "10")
                    Accessible.name: "Number of recent documents, applications, and servers"
                }
            }
        }
    }
    Item {
        width: parent.width
        height: 25
    }
    Item {
        width: parent.width
        height: 82
        Text {
            x: 10
            text: "Menu Bar Controls"
            color: page.ink
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
        Text {
            x: 10
            y: 25
            width: parent.width - galleryButton.width - 30
            text: "System and app controls can be configured to appear in both Control Center and the menu bar."
            color: page.muted
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }
        OptionButton {
            id: galleryButton
            objectName: "addControls"
            anchors.right: parent.right
            anchors.rightMargin: 10
            y: 25
            text: "Add Controls…"
            onClicked: desktop.openControlGallery()
        }
    }
    Card {
        objectName: "menuBarControlsCard"
        height: moduleRows.implicitHeight
        Column {
            id: moduleRows
            width: parent.width
            Repeater {
                model: page.menuControls
                delegate: Item {
                    id: moduleRow
                    required property var modelData
                    required property int index
                    readonly property string controlId: modelData.id
                    readonly property bool shown: page.inMenu(controlId)
                    readonly property bool hasOptions: controlId === "clock" || controlId === "battery"
                    readonly property bool hasChoice: !!modelData.supportsMode || controlId === "users"
                    objectName: "moduleRow_" + controlId
                    width: parent.width
                    height: 45
                    Item {
                        x: 39
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        Image {
                            id: moduleImage
                            anchors.fill: parent
                            source: page.categoryAsset(moduleRow.modelData)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }
                        Rectangle {
                            anchors.fill: parent
                            visible: moduleImage.status !== Image.Ready
                            radius: 4
                            color: page.iconColor(moduleRow.controlId)
                            Icon {
                                anchors.centerIn: parent
                                width: 15
                                height: 15
                                name: moduleRow.modelData.icon || "control"
                                color: "white"
                            }
                        }
                    }
                    Text {
                        x: 64
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - x - (moduleRow.hasChoice ? 174 : moduleRow.hasOptions ? 155 : 20)
                        text: moduleRow.modelData.label
                        color: page.ink
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                    VisibilityCheck {
                        objectName: "moduleToggle_" + moduleRow.controlId
                        visible: moduleRow.controlId !== "clock"
                        x: 13
                        anchors.verticalCenter: parent.verticalCenter
                        checked: moduleRow.shown
                        Accessible.name: "Show " + moduleRow.modelData.label + " in Menu Bar"
                        onClicked: if (page.controls)
                            page.controls.setInMenu(moduleRow.controlId, checked)
                    }
                    SettingCombo {
                        objectName: "moduleMode_" + moduleRow.controlId
                        visible: !!moduleRow.modelData.supportsMode
                        enabled: moduleRow.shown
                        opacity: enabled ? 1 : 0.45
                        width: 154
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        model: ["Show When Active", "Always Show"]
                        currentIndex: page.mode(moduleRow.controlId) === "Always" ? 1 : 0
                        onActivated: if (page.controls)
                            page.controls.setMode(moduleRow.controlId, currentIndex === 1 ? "Always" : "When Active")
                        Accessible.name: moduleRow.modelData.label + " menu bar visibility"
                    }
                    SettingCombo {
                        objectName: moduleRow.controlId === "users" ? "menuBarUserStyle" : ""
                        visible: moduleRow.controlId === "users"
                        enabled: moduleRow.shown
                        opacity: enabled ? 1 : 0.45
                        width: 154
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        model: ["Icon", "Account Name", "Full Name"]
                        currentIndex: Math.max(0, model.indexOf(page.pref("users.style", "Icon")))
                        onActivated: page.save("users.style", currentText, "Icon")
                        Accessible.name: "Fast User Switching menu bar style"
                    }
                    OptionButton {
                        objectName: moduleRow.hasOptions ? moduleRow.controlId + "Options" : ""
                        visible: moduleRow.hasOptions
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: moduleRow.controlId === "clock" ? "Clock Options…" : "Battery Options…"
                        onClicked: moduleRow.controlId === "clock" ? clockOptions.open() : batteryOptions.open()
                    }
                    RowDivider {
                        visible: moduleRow.index < page.menuControls.length - 1
                    }
                }
            }
        }
    }
    Item {
        width: parent.width
        height: 25
    }
    Text {
        x: 10
        width: parent.width - 20
        text: "Allow in the Menu Bar"
        color: page.ink
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }
    Item {
        width: parent.width
        height: 12
    }
    Card {
        height: page.registeredApps.length ? appRows.implicitHeight : 58
        Column {
            id: appRows
            width: parent.width
            Repeater {
                model: page.registeredApps
                delegate: Item {
                    id: appRow
                    required property var modelData
                    required property int index
                    width: parent.width
                    height: 45
                    Icon {
                        x: 11
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        name: appRow.modelData.icon || "applications"
                        color: page.ink
                    }
                    Text {
                        x: 40
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 90
                        text: appRow.modelData.label
                        color: page.ink
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                    VisibilityCheck {
                        objectName: "menuBarAppAllowed:" + appRow.modelData.id
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        checked: page.appAllowed(appRow.modelData.id)
                        Accessible.name: "Allow " + appRow.modelData.label + " in the Menu Bar"
                        onClicked: if (page.controls)
                            page.controls.setAppAllowed(appRow.modelData.id, checked)
                    }
                    RowDivider {
                        visible: appRow.index < page.registeredApps.length - 1
                    }
                }
            }
        }
        Text {
            visible: !page.registeredApps.length
            x: 10
            width: parent.width - 20
            anchors.verticalCenter: parent.verticalCenter
            text: "No apps have registered menu bar controls."
            color: page.muted
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
    }
    Item {
        width: parent.width
        height: 10
    }
    Text {
        x: 10
        width: parent.width - 20
        text: "Apps can add menu bar items for quick access to their features. Turning off an app prevents its items from appearing here."
        color: page.muted
        font.pixelSize: 11
        wrapMode: Text.Wrap
    }
    Item {
        width: parent.width
        height: 24
    }
    Row {
        width: parent.width
        layoutDirection: Qt.RightToLeft
        OptionButton {
            objectName: "resetControlCenter"
            text: "Reset Control Center…"
            onClicked: resetConfirmation.open()
        }
    }
    Item {
        width: parent.width
        height: 14
    }

    OptionsPopup {
        id: clockOptions
        objectName: "clockOptionsPopup"
        height: clockContents.implicitHeight + 40
        contentItem: Column {
            id: clockContents
            spacing: 14
            Text {
                text: "Clock Options"
                font.pixelSize: 17
                font.weight: Font.DemiBold
                color: page.ink
            }
            ScrollView {
                id: clockScroll
                width: parent.width
                height: Math.min(clockForm.implicitHeight, desktop.height - 220)
                clip: true
                ClockSettings {
                    id: clockForm
                    width: clockScroll.availableWidth
                    host: page.host
                    showHeading: false
                }
            }
            Row {
                width: parent.width
                layoutDirection: Qt.RightToLeft
                OptionButton {
                    objectName: "clockOptionsDone"
                    text: "Done"
                    primary: true
                    onClicked: clockOptions.close()
                }
            }
        }
    }
    OptionsPopup {
        id: batteryOptions
        objectName: "batteryOptionsPopup"
        height: batteryContents.implicitHeight + 40
        contentItem: Column {
            id: batteryContents
            spacing: 14
            Text {
                text: "Options"
                font.pixelSize: 17
                font.weight: Font.DemiBold
                color: page.ink
            }
            Card {
                width: parent.width
                height: 90
                SettingsToggle {
                    objectName: "batteryShowPercentage"
                    x: 10
                    width: parent.width - 20
                    height: 45
                    dark: host.dark
                    reducedMotion: desktop.reduceMotion
                    label: "Show Percentage"
                    checked: page.pref("battery.showPercentage", "false") === "true"
                    onToggled: value => page.save("battery.showPercentage", value, "false")
                }
                Rectangle {
                    x: 10
                    y: 44
                    width: parent.width - 20
                    height: 1
                    color: page.dividerColor
                }
                Item {
                    x: 10
                    y: 45
                    width: parent.width - 20
                    height: 45
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Show Energy Mode"
                        font.pixelSize: 13
                        color: page.ink
                    }
                    SettingCombo {
                        objectName: "batteryEnergyMode"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 150
                        model: ["When Active", "Always"]
                        currentIndex: page.pref("battery.energyMode", "Always") === "When Active" ? 0 : 1
                        onActivated: page.save("battery.energyMode", currentText, "Always")
                        Accessible.name: "Show Energy Mode"
                    }
                }
            }
            Row {
                width: parent.width
                layoutDirection: Qt.RightToLeft
                OptionButton {
                    objectName: "batteryOptionsDone"
                    text: "Done"
                    primary: true
                    onClicked: batteryOptions.close()
                }
            }
        }
    }
    OptionsPopup {
        id: resetConfirmation
        objectName: "resetControlCenterPopup"
        width: Math.min(410, desktop.width - 32)
        height: resetContents.implicitHeight + 40
        contentItem: Column {
            id: resetContents
            spacing: 16
            Text {
                width: parent.width
                text: "Reset Control Center?"
                color: page.ink
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                text: "This will restore the Control Center layout and menu bar visibility settings to their defaults."
                color: page.muted
                font.pixelSize: 13
                wrapMode: Text.Wrap
            }
            Row {
                anchors.right: parent.right
                spacing: 8
                OptionButton {
                    objectName: "resetCancel"
                    text: "Cancel"
                    onClicked: resetConfirmation.close()
                }
                OptionButton {
                    objectName: "resetConfirm"
                    text: "Reset"
                    primary: true
                    onClicked: {
                        if (page.controls)
                            page.controls.reset();
                        resetConfirmation.close();
                    }
                }
            }
        }
    }
}
