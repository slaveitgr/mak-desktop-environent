import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Column {
    id: panel
    required property var host
    readonly property var backend: Bridge.linuxSettings
    readonly property var state: backend.state
    readonly property var audio: state.audio || ({available: false})
    readonly property var network: state.network || ({available: false})
    readonly property var bluetooth: state.bluetooth || ({available: false})
    readonly property var power: state.power || ({available: false})
    readonly property var battery: state.battery || ({available: false})
    readonly property var display: state.display || ({available: false})
    readonly property bool canChange: backend.ready && !backend.busy
    property bool inputSelected: false
    readonly property var audioDevices: (inputSelected ? audio.inputs : audio.outputs) || []
    readonly property var currentAudio: audioDevices.find(device => device.default) || null
    spacing: 14

    component Caption: Text {
        width: parent.width
        font.pixelSize: 12
        color: panel.host.muted
        wrapMode: Text.Wrap
    }
    component Heading: Text {
        width: parent.width
        font.pixelSize: 13
        font.weight: Font.DemiBold
        color: panel.host.ink
        topPadding: 6
    }
    component ValueRow: Item {
        property string label: ""
        property string value: ""
        width: parent.width
        height: Math.max(44, valueText.implicitHeight + 20)
        Text { x: 0; anchors.verticalCenter: parent.verticalCenter; width: parent.width * 0.5; text: parent.label; font.pixelSize: 13; color: panel.host.ink; elide: Text.ElideRight }
        Text { id: valueText; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: parent.width * 0.48; text: parent.value; horizontalAlignment: Text.AlignRight; wrapMode: Text.Wrap; font.pixelSize: 12; color: panel.host.muted }
    }
    // A confirmed value only: clicking asks for a change without changing the
    // switch locally. It moves after the native service reports its value.
    component NativeToggle: Item {
        id: toggle
        property string label: ""
        property bool value: false
        signal requested(bool requestedValue)
        width: parent.width
        height: 44
        opacity: enabled ? 1 : 0.45
        Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 48; text: toggle.label; font.pixelSize: 13; color: panel.host.ink; elide: Text.ElideRight }
        Rectangle {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            width: 32; height: 19; radius: 10
            color: toggle.value ? panel.host.desktop.accentColor : (panel.host.dark ? "#565a5f" : "#c8cbd0")
            Rectangle { x: toggle.value ? 15 : 2; y: 2; width: 15; height: 15; radius: 8; color: "white" }
        }
        MouseArea { anchors.fill: parent; onClicked: toggle.requested(!toggle.value) }
        Accessible.role: Accessible.CheckBox
        Accessible.name: label
        Accessible.checkable: true
        Accessible.checked: value
        Accessible.onPressAction: if (enabled) requested(!value)
    }

    Caption {
        visible: backend.errorText !== "" || backend.busy
        text: backend.busy ? "Waiting for the system to confirm this change…" : backend.errorText
        color: backend.busy ? panel.host.muted : (panel.host.dark ? "#ffba82" : "#905300")
    }
    DialogButton { text: "Refresh"; dark: panel.host.dark; enabled: backend.ready && !backend.busy; onClicked: backend.refresh() }

    Column {
        width: parent.width; spacing: 12; visible: panel.host.page === "Sound"
        Heading { text: "Sound Effects" }
        SettingsCard {
            dark: panel.host.dark
            ValueRow { label: "Alert sound"; value: "Not connected" }
            ValueRow { label: "Play sound effects through"; value: "Not connected" }
            ValueRow { label: "Alert volume"; value: "Not connected" }
        }
        Caption { text: "Startup, interface and volume feedback sounds are not connected to the Linux sound service yet." }
        Heading { text: "Output & Input" }
        TabBar {
            width: parent.width; currentIndex: panel.inputSelected ? 1 : 0
            TabButton { text: "Output"; onClicked: panel.inputSelected = false }
            TabButton { text: "Input"; onClicked: panel.inputSelected = true }
        }
        SettingsCard {
            dark: panel.host.dark
            ValueRow { label: "Name"; value: "Type" }
            Repeater {
                model: panel.audioDevices
                delegate: Rectangle {
                    required property var modelData
                    width: parent.width; height: 42; radius: 6
                    color: modelData.default ? panel.host.desktop.accentColor : "transparent"
                    Text { x: 8; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 92; text: modelData.name; color: modelData.default ? "white" : panel.host.ink; elide: Text.ElideRight; font.pixelSize: 13 }
                    Text { anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: modelData.type || "Audio"; color: modelData.default ? "white" : panel.host.muted; font.pixelSize: 12 }
                    MouseArea { anchors.fill: parent; enabled: panel.canChange && panel.audio.available; onClicked: panel.backend.apply("audio.default", true, modelData.id) }
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.name + (modelData.default ? ", selected" : "")
                    Accessible.onPressAction: if (panel.canChange) panel.backend.apply("audio.default", true, modelData.id)
                }
            }
            Caption { visible: !panel.audio.available || panel.audioDevices.length === 0; topPadding: 12; bottomPadding: 12; text: panel.audio.available ? "No audio devices were reported by PipeWire." : "The Linux audio service is unavailable." }
        }
        SettingsCard {
            dark: panel.host.dark
            visible: panel.currentAudio !== null
            ValueRow { label: panel.inputSelected ? "Input volume" : "Output volume"; value: panel.currentAudio ? Math.round(panel.currentAudio.volume * 100) + "%" : "" }
            Slider {
                id: volume
                property real requestedVolume: 0
                property string requestedTarget: ""
                width: parent.width; height: 34; from: 0; to: 1; stepSize: 0.01
                enabled: panel.canChange && panel.currentAudio && panel.currentAudio.writable
                Binding { target: volume; property: "value"; value: panel.currentAudio ? Math.min(1, panel.currentAudio.volume) : 0; when: !volume.pressed }
                onPressedChanged: {
                    if (pressed && panel.currentAudio) { requestedVolume = value; requestedTarget = panel.currentAudio.id; }
                    else if (!pressed && requestedTarget && enabled) panel.backend.apply("audio.volume", requestedVolume, requestedTarget);
                }
                onMoved: {
                    requestedVolume = value;
                    if (!pressed && panel.currentAudio && enabled) panel.backend.apply("audio.volume", value, panel.currentAudio.id);
                }
                Accessible.name: panel.inputSelected ? "Input volume" : "Output volume"
            }
            NativeToggle {
                label: "Mute"; value: panel.currentAudio ? panel.currentAudio.muted : false
                enabled: panel.canChange && panel.currentAudio && panel.currentAudio.writable
                onRequested: requestedValue => panel.backend.apply("audio.muted", requestedValue, panel.currentAudio.id)
            }
            ValueRow { label: panel.inputSelected ? "Input level" : "Balance"; value: "Not connected" }
        }
    }
    Column {
        width: parent.width; spacing: 12; visible: panel.host.page === "Wi-Fi" || panel.host.page === "Network"
        SettingsCard {
            dark: panel.host.dark
            NativeToggle {
                label: "Wi-Fi"; value: !!panel.network.wifiEnabled
                enabled: panel.canChange && !!panel.network.wifiWritable
                onRequested: requestedValue => panel.backend.apply("wifi.enabled", requestedValue, "")
            }
        }
        Caption {
            text: !panel.network.available ? "NetworkManager is unavailable." : !panel.network.wifiPresent ? "No Wi-Fi adapter was reported." : !panel.network.wifiHardwareEnabled ? "Wi-Fi is blocked by the hardware switch." : !panel.network.wifiWritable ? "Changing Wi-Fi requires administrator authorization, which is not connected yet." : "Wi-Fi power is controlled by NetworkManager."
        }
        Heading { text: "Network Services" }
        SettingsCard {
            dark: panel.host.dark
            Repeater {
                model: panel.network.interfaces || []
                delegate: ValueRow {
                    required property var modelData
                    label: modelData.type + " · " + modelData.name
                    value: modelData.state === 100 ? (modelData.connection || "Connected") : modelData.state === 30 ? "Disconnected" : modelData.state === 20 ? "Unavailable" : "State " + modelData.state
                }
            }
        }
        Caption { text: "Joining networks, passwords, VPN, DNS, proxies and firewall settings are not connected yet. Existing connections are shown without changing them." }
    }
    Column {
        width: parent.width; spacing: 12; visible: panel.host.page === "Bluetooth"
        SettingsCard {
            dark: panel.host.dark
            Repeater {
                model: panel.bluetooth.adapters || []
                delegate: NativeToggle {
                    required property var modelData
                    label: modelData.name; value: modelData.powered
                    enabled: panel.canChange && modelData.writable
                    onRequested: requestedValue => panel.backend.apply("bluetooth.powered", requestedValue, modelData.id)
                }
            }
        }
        Caption { visible: !panel.bluetooth.available || panel.bluetooth.hardwareBlocked; text: panel.bluetooth.hardwareBlocked ? "Bluetooth is blocked by the hardware switch." : "No available Bluetooth adapter was reported by BlueZ." }
        Heading { text: "Devices" }
        SettingsCard {
            dark: panel.host.dark
            Repeater {
                model: panel.bluetooth.devices || []
                delegate: ValueRow { required property var modelData; label: modelData.name; value: modelData.connected ? "Connected" : modelData.paired ? "Paired" : "Not paired" }
            }
        }
        Caption { text: "Adapter power uses BlueZ. Discovery, pairing, device connection and removal are not connected yet." }
    }
    Column {
        width: parent.width; spacing: 12; visible: panel.host.page === "Battery"
        Heading { text: "Battery" }
        SettingsCard {
            dark: panel.host.dark
            ValueRow { label: "Battery Level"; value: panel.battery.available ? panel.battery.percent + "%" : "Unavailable" }
            ValueRow { label: "Power Source"; value: panel.battery.available ? (panel.battery.onBattery ? "Battery" : "Power Adapter") : "Unavailable" }
            ValueRow { label: "Status"; value: panel.battery.available ? panel.battery.status : "No battery reported" }
        }
        Heading { text: "Energy Mode" }
        SettingsCard {
            dark: panel.host.dark
            Repeater {
                model: panel.power.profiles || []
                delegate: RadioButton {
                    required property string modelData
                    width: parent.width; height: 44
                    text: modelData === "power-saver" ? "Low Power" : modelData === "balanced" ? "Automatic" : modelData === "performance" ? "High Power" : modelData
                    checked: panel.power.active === modelData
                    enabled: panel.canChange && panel.power.available
                    onClicked: { panel.backend.apply("power.profile", modelData, ""); checked = Qt.binding(() => panel.power.active === modelData); }
                    contentItem: Text { text: parent.text; leftPadding: 30; verticalAlignment: Text.AlignVCenter; color: panel.host.ink; font.pixelSize: 13 }
                }
            }
        }
        Caption { text: !panel.power.available ? "Power profiles are unavailable on this system." : panel.power.degraded || "These modes are provided by the Linux power service." }
        Caption { text: "Sleep timers, charging limits and battery history are not connected yet." }
    }
    Column {
        width: parent.width; spacing: 12; visible: panel.host.page === "Displays"
        Repeater {
            model: panel.display.monitors || []
            delegate: SettingsCard {
                required property var modelData
                dark: panel.host.dark
                ValueRow { label: "Display"; value: modelData.name }
                ValueRow { label: "Resolution"; value: modelData.width + " × " + modelData.height }
                ValueRow { label: "Scale"; value: Math.round(modelData.scale * 100) + "%" }
                ValueRow { label: "Use as"; value: modelData.primary ? "Main display" : "Extended display" }
            }
        }
        Caption { text: panel.display.available ? "Live display information from the Cutefish compositor. Resolution, scaling, arrangement and Night Shift changes are not connected yet." : "The Cutefish compositor display service is unavailable." }
    }
}
