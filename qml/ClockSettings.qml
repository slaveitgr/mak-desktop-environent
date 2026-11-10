import QtQuick
import QtQuick.Controls

// Grouping and labels were observed in Tahoe's live Clock Options sheet.
// The 24-hour format remains under General > Date & Time. Voice announcements
// are represented as unavailable until a speech service is actually connected.
Column {
    id: root
    required property var host
    property bool showHeading: true
    readonly property color ink: host.ink
    readonly property color muted: host.muted
    readonly property color accent: host.desktop.accentColor
    readonly property bool digital: pref("clock.style", "Digital") === "Digital"
    spacing: 12

    function pref(key, fallback) {
        let revision = Bridge.suite.revision;
        return Bridge.suite.preference(key, fallback);
    }
    function save(key, value, fallback) {
        if (Bridge.suite.preference(key, fallback || "") !== String(value))
            Bridge.suite.setPreference(key, String(value));
    }
    component GroupHeading: Text {
        x: 10
        color: root.ink
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }
    component Divider: Rectangle {
        width: parent.width
        height: 1
        color: root.host.dark ? "#15ffffff" : "#10000000"
    }
    component ClockToggle: SettingsToggle {
        dark: root.host.dark
        reducedMotion: root.host.desktop.reduceMotion
        height: 44
        opacity: enabled ? 1 : 0.45
    }
    component DisabledCombo: ComboBox {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 160
        height: 27
        font.pixelSize: 12
        enabled: false
        opacity: 0.45
        palette.text: root.ink
        palette.buttonText: root.ink
        background: Rectangle {
            radius: 6
            color: root.host.dark ? "#41494c" : "#f5f5f6"
            border.color: root.host.dark ? "#14ffffff" : "#12000000"
        }
    }
    Text {
        visible: root.showHeading
        text: "Clock"
        font.pixelSize: 17
        font.weight: Font.DemiBold
        color: root.ink
    }
    GroupHeading {
        text: "Date"
    }
    SettingsCard {
        dark: root.host.dark
        ClockToggle {
            objectName: "clockShowDate"
            label: "Show date"
            checked: root.pref("clock.date", "Always") !== "Never"
            onToggled: value => root.save("clock.date", value ? "Always" : "Never", "Always")
        }
        Divider {}
        ClockToggle {
            objectName: "clockShowWeekday"
            label: "Show the day of the week"
            checked: root.pref("clock.weekday", "true") === "true"
            onToggled: value => root.save("clock.weekday", value, "true")
        }
    }
    GroupHeading {
        text: "Time"
    }
    SettingsCard {
        dark: root.host.dark
        Item {
            width: parent.width
            height: 44
            Text {
                text: "Style"
                color: root.ink
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                Repeater {
                    model: ["Digital", "Analog"]
                    delegate: RadioButton {
                        id: styleChoice
                        required property string modelData
                        objectName: "clockStyle" + modelData
                        text: modelData
                        height: 28
                        padding: 0
                        spacing: 6
                        checked: root.pref("clock.style", "Digital") === modelData
                        onClicked: root.save("clock.style", modelData, "Digital")
                        contentItem: Text {
                            text: styleChoice.text
                            leftPadding: 20
                            color: root.ink
                            font.pixelSize: 12
                            verticalAlignment: Text.AlignVCenter
                        }
                        indicator: Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14
                            height: 14
                            radius: 7
                            color: styleChoice.checked ? root.accent : root.host.dark ? "#475054" : "white"
                            border.color: styleChoice.checked ? root.accent : root.host.dark ? "#7b8285" : "#b7bdc1"
                            Rectangle {
                                anchors.centerIn: parent
                                width: 6
                                height: 6
                                radius: 3
                                color: "white"
                                visible: styleChoice.checked
                            }
                        }
                        background: Item {}
                    }
                }
            }
        }
        Divider {}
        ClockToggle {
            objectName: "clockShowAMPM"
            label: "Show AM/PM"
            checked: root.pref("clock.ampm", "true") === "true"
            enabled: root.digital && root.pref("clock.24hour", "true") !== "true"
            onToggled: value => root.save("clock.ampm", value, "true")
        }
        Divider {}
        ClockToggle {
            objectName: "clockFlashSeparators"
            label: "Flash the time separators"
            checked: root.pref("clock.flash", "false") === "true"
            enabled: root.digital
            onToggled: value => root.save("clock.flash", value, "false")
        }
        Divider {}
        ClockToggle {
            objectName: "clockShowSeconds"
            label: "Display the time with seconds"
            checked: root.pref("clock.seconds", "false") === "true"
            enabled: root.digital
            onToggled: value => root.save("clock.seconds", value, "false")
        }
    }
    SettingsCard {
        dark: root.host.dark
        ClockToggle {
            objectName: "clockAnnounceTime"
            label: "Announce the time"
            checked: false
            enabled: false
        }
        Divider {}
        Item {
            width: parent.width
            height: 44
            Text {
                text: "Interval"
                color: root.muted
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }
            DisabledCombo {
                objectName: "clockAnnounceInterval"
                model: ["On the hour"]
                Accessible.name: "Time announcement interval"
            }
        }
        Divider {}
        Item {
            width: parent.width
            height: 44
            Text {
                text: "Voice"
                color: root.muted
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }
            DisabledCombo {
                objectName: "clockAnnounceVoice"
                model: ["System Voice"]
                Accessible.name: "Time announcement voice"
            }
        }
        Item {
            width: parent.width
            height: 40
            DialogButton {
                objectName: "clockCustomizeVoice"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Customize Voice…"
                font.pixelSize: 12
                height: 27
                dark: root.host.dark
                enabled: false
                opacity: 0.45
            }
        }
    }
    Text {
        x: 10
        width: parent.width - 20
        text: "Voice announcements aren’t connected in this desktop."
        color: root.muted
        font.pixelSize: 11
        wrapMode: Text.Wrap
    }
}
