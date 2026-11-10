import QtQuick
import QtQuick.Controls

Column {
    id: appearance
    required property var host
    readonly property var desktop: host.desktop
    readonly property color ink: host.ink
    readonly property color muted: host.muted
    readonly property color accent: desktop.accentColor
    readonly property color cardColor: host.dark ? "#2b3336" : "#ffffff"
    readonly property color lineColor: host.dark ? "#15ffffff" : "#10000000"
    readonly property var colorNames: ["Multicolor", "Blue", "Purple", "Pink", "Red", "Orange", "Yellow", "Green", "Graphite"]
    readonly property var colorValues: ["#1683fa", "#1683fa", "#a65bce", "#ec5c9c", "#ed5958", "#ef923d", "#e9c642", "#68b953", "#98989e"]
    readonly property string selectedAccent: pref("appearance.accent", "multicolor")
    readonly property string selectedHighlight: pref("appearance.highlight", "automatic")
    spacing: 0

    function pref(key, fallback) {
        let revision = Bridge.suite.revision;
        return Bridge.suite.preference(key, fallback);
    }
    function save(key, value) {
        let defaults = {
            "appearance.accent": "multicolor",
            "appearance.highlight": "automatic",
            "appearance.sidebarIconSize": "medium"
        };
        if (Bridge.suite.preference(key, defaults[key] || "") !== String(value))
            Bridge.suite.setPreference(key, String(value));
    }

    component Card: Rectangle {
        width: appearance.width
        radius: 10
        color: appearance.cardColor
        border.color: host.dark ? "#0bffffff" : "#0b000000"
    }
    component Divider: Rectangle {
        x: 10
        width: parent.width - 20
        height: 1
        color: appearance.lineColor
    }
    component SectionHeading: Item {
        property alias text: heading.text
        width: appearance.width
        height: 63
        Text {
            id: heading
            x: 10
            y: 39
            color: appearance.ink
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
    }
    component ChoiceRadio: RadioButton {
        width: parent.width
        height: 22
        leftPadding: 22
        topPadding: 0
        bottomPadding: 0
        opacity: enabled ? 1 : 0.4
        indicator: Rectangle {
            x: 0
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            radius: 7
            color: parent.checked ? appearance.accent : host.dark ? "#525a5d" : "white"
            border.color: parent.checked ? appearance.accent : host.dark ? "#747b7d" : "#b7babc"
            Rectangle {
                anchors.centerIn: parent
                width: 6
                height: 6
                radius: 3
                color: "white"
                visible: parent.parent.checked
            }
        }
        contentItem: Text {
            text: parent.text
            color: appearance.ink
            font.pixelSize: 12
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Item {}
    }
    component SettingCombo: ComboBox {
        width: 130
        height: 26
        font.pixelSize: 12
        palette.text: appearance.ink
        palette.buttonText: appearance.ink
        palette.base: host.dark ? "#394246" : "#f5f5f6"
        palette.highlight: appearance.accent
        background: Rectangle {
            radius: 6
            color: host.dark ? "#41494c" : "#f5f5f6"
            border.color: host.dark ? "#14ffffff" : "#12000000"
        }
    }

    Card {
        objectName: "appearanceMaterialCard"
        height: 173
        Item {
            width: parent.width
            height: 86
            Text {
                x: 10
                y: 28
                text: "Appearance"
                color: appearance.ink
                font.pixelSize: 13
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 10
                y: 10
                spacing: 10
                Repeater {
                    model: ["Auto", "Light", "Dark"]
                    delegate: AbstractButton {
                        id: modeButton
                        required property string modelData
                        width: 68
                        height: 68
                        readonly property bool chosen: modelData === "Auto" ? desktop.appearanceMode === "auto" : desktop.appearanceMode !== "auto" && (modelData === "Dark") === desktop.dark
                        Accessible.name: modelData + " appearance"
                        Accessible.role: Accessible.RadioButton
                        Accessible.checked: chosen
                        onClicked: desktop.setAppearance(modelData.toLowerCase())
                        background: Item {}
                        contentItem: Item {
                            Image {
                                x: 0.5
                                y: 2
                                width: 67
                                height: 44
                                source: Bridge.assetRoot + "settings-reference/appearance-" + modeButton.modelData.toLowerCase() + "-" + (host.dark ? "dark" : "light") + ".png"
                                fillMode: Image.PreserveAspectFit
                            }
                            Rectangle {
                                width: 68
                                height: 48
                                radius: 7
                                color: "transparent"
                                border.color: modeButton.chosen ? appearance.accent : "transparent"
                                border.width: modeButton.chosen ? 3 : 0
                            }
                            Text {
                                y: 54
                                width: parent.width
                                text: modeButton.modelData
                                color: appearance.ink
                                font.pixelSize: 11
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }
            }
        }
        Divider {
            y: 86
        }
        Item {
            y: 87
            width: parent.width
            height: 86
            Text {
                x: 10
                y: 15
                text: "Liquid Glass"
                color: appearance.ink
                font.pixelSize: 13
            }
            Text {
                x: 10
                y: 36
                width: parent.width - 184
                text: desktop.reduceTransparency ? "Turn off Reduce Transparency to change Liquid Glass." : "Choose your preferred look for Liquid Glass."
                color: appearance.muted
                font.pixelSize: 11
                wrapMode: Text.Wrap
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 10
                y: 10
                spacing: 10
                Repeater {
                    model: ["Clear", "Tinted"]
                    delegate: AbstractButton {
                        id: glassButton
                        required property string modelData
                        width: 68
                        height: 68
                        enabled: !desktop.reduceTransparency
                        opacity: enabled ? 1 : 0.4
                        readonly property bool chosen: desktop.glassTinted === (modelData === "Tinted")
                        Accessible.name: modelData + " Liquid Glass"
                        Accessible.role: Accessible.RadioButton
                        Accessible.checked: chosen
                        onClicked: {
                            desktop.glassTinted = modelData === "Tinted";
                            if (desktop.cutefishMode) Bridge.cutefishShell.setDockGlassTint(desktop.glassTinted ? 1 : 0.5);
                        }
                        background: Item {}
                        contentItem: Item {
                            Image {
                                x: 0.5
                                y: 2
                                width: 67
                                height: 44
                                source: Bridge.assetRoot + "settings-reference/glass-" + glassButton.modelData.toLowerCase() + "-" + (host.dark ? "dark" : "light") + ".png"
                                fillMode: Image.PreserveAspectFit
                            }
                            Rectangle {
                                width: 68
                                height: 48
                                radius: 7
                                color: "transparent"
                                border.color: glassButton.chosen ? appearance.accent : "transparent"
                                border.width: glassButton.chosen ? 3 : 0
                            }
                            Text {
                                y: 54
                                width: parent.width
                                text: glassButton.modelData
                                color: appearance.ink
                                font.pixelSize: 11
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }
            }
        }
    }
    SectionHeading {
        text: "Theme"
        objectName: "appearanceThemeHeading"
    }
    Card {
        height: 89
        Text {
            x: 10
            y: 14
            text: "Color"
            color: appearance.ink
            font.pixelSize: 13
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 10
            y: 10
            spacing: 5
            Repeater {
                model: appearance.colorNames
                delegate: AbstractButton {
                    id: swatch
                    required property string modelData
                    required property int index
                    width: 23
                    height: 23
                    readonly property bool chosen: appearance.selectedAccent === modelData.toLowerCase()
                    Accessible.name: modelData + " theme color"
                    Accessible.role: Accessible.RadioButton
                    Accessible.checked: chosen
                    onClicked: appearance.save("appearance.accent", modelData.toLowerCase())
                    background: Rectangle {
                        radius: 12
                        color: "transparent"
                        border.width: swatch.chosen ? 2 : 0
                        border.color: host.dark ? "#e0e4e7" : "#6a6e73"
                    }
                    contentItem: Item {
                        Rectangle {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            radius: 8
                            color: appearance.colorValues[swatch.index]
                            visible: swatch.index !== 0
                        }
                        Canvas {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            visible: swatch.index === 0
                            onPaint: {
                                let ctx = getContext("2d");
                                let colors = ["#7b62d9", "#e55bab", "#ec6562", "#eda742", "#d7d348", "#71bf67", "#57b9d6", "#5294e2"];
                                for (let i = 0; i < colors.length; i++) {
                                    ctx.beginPath();
                                    ctx.moveTo(8, 8);
                                    ctx.arc(8, 8, 8, (i - 2) * Math.PI / 4, (i - 1) * Math.PI / 4);
                                    ctx.closePath();
                                    ctx.fillStyle = colors[i];
                                    ctx.fill();
                                }
                            }
                        }
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: modelData
                    ToolTip.delay: 500
                }
            }
        }
        Divider {
            y: 44
        }
        Text {
            x: 10
            y: 59
            text: "Text highlight color"
            color: appearance.ink
            font.pixelSize: 13
        }
        SettingCombo {
            objectName: "appearanceHighlight"
            anchors.right: parent.right
            anchors.rightMargin: 10
            y: 54
            model: ["Automatic", "Blue", "Purple", "Pink", "Red", "Orange", "Yellow", "Green", "Graphite"]
            currentIndex: Math.max(0, model.map(name => name.toLowerCase()).indexOf(appearance.selectedHighlight))
            onActivated: appearance.save("appearance.highlight", currentText.toLowerCase())
            Accessible.name: "Text highlight color"
        }
    }
    Item {
        width: parent.width
        height: 10
    }
    Card {
        height: 133
        Text {
            x: 10
            y: 15
            width: parent.width - 240
            text: "Icon & widget style"
            color: appearance.ink
            font.pixelSize: 13
            wrapMode: Text.Wrap
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 10
            y: 10
            spacing: 8
            Repeater {
                model: ["Default", "Dark", "Clear", "Tinted"]
                delegate: AbstractButton {
                    id: iconStyle
                    required property string modelData
                    width: 48
                    height: 69
                    enabled: modelData === "Default"
                    opacity: enabled ? 1 : 0.4
                    Accessible.name: modelData + " icon and widget style"
                    Accessible.role: Accessible.RadioButton
                    Accessible.checked: modelData === "Default"
                    background: Item {}
                    contentItem: Item {
                        Rectangle {
                            width: 48
                            height: 48
                            radius: 8
                            color: host.dark ? "#20292d" : "#edf1f3"
                            border.width: iconStyle.modelData === "Default" ? 3 : 1
                            border.color: iconStyle.modelData === "Default" ? appearance.accent : "#335e707b"
                            Icon {
                                anchors.centerIn: parent
                                width: 29
                                height: 29
                                name: "folder"
                                color: iconStyle.modelData === "Default" ? "#49a9ed" : iconStyle.modelData === "Tinted" ? "#9fc7ec" : "#b4c0c9"
                            }
                        }
                        Text {
                            y: 54
                            width: parent.width
                            text: iconStyle.modelData
                            horizontalAlignment: Text.AlignHCenter
                            color: appearance.ink
                            font.pixelSize: 11
                        }
                    }
                    ToolTip.visible: hovered && !enabled
                    ToolTip.text: "This icon style is not available yet."
                }
            }
        }
        Divider {
            y: 88
        }
        Text {
            x: 10
            y: 103
            text: "Folder color"
            color: appearance.ink
            font.pixelSize: 13
        }
        SettingCombo {
            anchors.right: parent.right
            anchors.rightMargin: 10
            y: 98
            model: ["Automatic"]
            enabled: false
            Accessible.name: "Folder color"
            Accessible.description: "Custom folder colors are not available yet."
        }
    }
    SectionHeading {
        text: "Windows"
        objectName: "appearanceWindowsHeading"
    }
    Card {
        objectName: "appearanceWindowsCard"
        height: 240
        Text {
            x: 10
            y: 14
            text: "Sidebar icon size"
            color: appearance.ink
            font.pixelSize: 13
        }
        SettingCombo {
            objectName: "appearanceSidebarSize"
            anchors.right: parent.right
            anchors.rightMargin: 10
            y: 9
            model: ["Small", "Medium", "Large"]
            currentIndex: Math.max(0, model.map(name => name.toLowerCase()).indexOf(desktop.sidebarIconSize))
            onActivated: appearance.save("appearance.sidebarIconSize", currentText.toLowerCase())
            Accessible.name: "Sidebar icon size"
        }
        Divider {
            y: 44
        }
        SettingsToggle {
            x: 10
            y: 45
            width: parent.width - 20
            height: 43
            dark: host.dark
            reducedMotion: desktop.reduceMotion
            label: "Tint window background with wallpaper color"
            checked: desktop.wallpaperTint
            onToggled: value => desktop.wallpaperTint = value
        }
        Divider {
            y: 88
        }
        Text {
            x: 10
            y: 103
            text: "Show scroll bars"
            color: appearance.ink
            font.pixelSize: 13
        }
        Column {
            x: Math.max(150, parent.width - 280)
            y: 101
            width: parent.width - x - 10
            spacing: 0
            ChoiceRadio {
                text: "Automatically based on mouse or trackpad"
                enabled: false
                Accessible.description: "Automatic input-device detection is not connected."
            }
            ChoiceRadio {
                text: "When scrolling"
                checked: !desktop.alwaysShowScrollbars
                onClicked: desktop.alwaysShowScrollbars = false
            }
            ChoiceRadio {
                text: "Always"
                checked: desktop.alwaysShowScrollbars
                onClicked: desktop.alwaysShowScrollbars = true
            }
        }
        Divider {
            y: 173
        }
        Text {
            x: 10
            y: 188
            text: "Click in the scroll bar to"
            color: appearance.ink
            font.pixelSize: 13
        }
        Column {
            x: Math.max(170, parent.width - 260)
            y: 186
            width: parent.width - x - 10
            ChoiceRadio {
                text: "Jump to the next page"
                enabled: false
                Accessible.description: "Scroll-bar click behavior is managed by the current controls."
            }
            ChoiceRadio {
                text: "Jump to the spot that’s clicked"
                enabled: false
                Accessible.description: "Scroll-bar click behavior is managed by the current controls."
            }
        }
    }
}
