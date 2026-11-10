import QtQuick
import QtQuick.Controls

Column {
    id: details
    required property var panel
    readonly property var backend: panel.controls.systemBackend
    readonly property var state: backend.state
    readonly property bool nativeSystem: panel.controls.nativeSystem
    readonly property bool writable: nativeSystem && backend.ready && !backend.busy
    readonly property var network: state.network || ({})
    readonly property var bluetooth: state.bluetooth || ({})
    readonly property var battery: state.battery || ({})
    readonly property var power: state.power || ({})
    readonly property var adapters: nativeSystem ? bluetooth.adapters || [] : []
    readonly property var primaryAdapter: adapters.length ? adapters[0] : null
    readonly property var connections: nativeSystem && network.wifiEnabled ? (network.interfaces || []).filter(device => device.type === "Wi-Fi" && !!device.connection) : []
    readonly property var devices: nativeSystem ? bluetooth.devices || [] : []
    property bool otherNetworks: false
    spacing: 9
    component Caption: Text {
        width: parent.width; color: details.panel.muted; font.pixelSize: 12; wrapMode: Text.Wrap
    }
    component Rule: Rectangle { width:parent.width;height:1;color:details.panel.dark?"#24ffffff":"#22000000" }
    component Heading: Text { width:parent.width;color:details.panel.muted;font.pixelSize:11;font.weight:Font.DemiBold }
    component DeviceRow: Item {
        property string name: ""
        property string subtitle: ""
        property string symbol: "wifi"
        property bool connected: false
        width:parent.width;height:subtitle?42:32
        Rectangle {
            x:3;anchors.verticalCenter:parent.verticalCenter;width:26;height:26;radius:13
            color:parent.connected?"#f7f7fa":details.panel.dark?"#25ffffff":"#17000000"
            Icon { anchors.centerIn:parent;width:17;height:17;name:parent.parent.symbol;color:parent.parent.connected?"#1688fa":details.panel.ink }
        }
        Column { x:38;anchors.verticalCenter:parent.verticalCenter;width:parent.width-43;spacing:1
            Text { width:parent.width;text:parent.parent.name;color:details.panel.ink;font.pixelSize:13;elide:Text.ElideRight }
            Text { width:parent.width;visible:!!text;text:parent.parent.subtitle;color:details.panel.muted;font.pixelSize:11;elide:Text.ElideRight }
        }
    }
    Column {
        width:parent.width;spacing:9;visible:details.panel.section === "wifi"
        Item {
            width:parent.width;height:29
            Text { x:5;anchors.verticalCenter:parent.verticalCenter;text:"Wi-Fi";font.pixelSize:14;font.weight:Font.DemiBold;color:details.panel.ink }
            ControlToggle {
                objectName:"controlWifiSwitch";anchors.right:parent.right;anchors.rightMargin:5;anchors.verticalCenter:parent.verticalCenter;dark:details.panel.dark
                checked:details.nativeSystem && !!details.network.wifiEnabled
                enabled:details.writable && !!details.network.wifiWritable
                Accessible.name:"Wi-Fi"
                onRequested:function(value){details.backend.apply("wifi.enabled",value,"");}
            }
        }
        Rule { }
        Caption {
            objectName:"controlWifiUnavailable"
            visible:!details.nativeSystem || !details.network.available || !details.network.wifiPresent || !details.network.wifiEnabled || !details.network.wifiHardwareEnabled
            text:!details.nativeSystem?"Wi-Fi is not connected in this preview.":!details.network.available?"Wi-Fi service unavailable.":!details.network.wifiPresent?"No Wi-Fi adapter detected.":!details.network.wifiHardwareEnabled?"Wi-Fi is disabled by the hardware switch.":"Wi-Fi is off."
        }
        Heading { visible:details.connections.length>0;text:"Known Networks" }
        Repeater {
            model:details.connections
            delegate:DeviceRow { required property var modelData;name:modelData.connection;connected:modelData.state===100;subtitle:connected?"":"Not Connected" }
        }
        AbstractButton {
            objectName:"controlOtherNetworks";width:parent.width;height:28
            enabled:details.nativeSystem && !!details.network.wifiPresent && !!details.network.wifiEnabled
            onClicked:details.otherNetworks=!details.otherNetworks
            contentItem:Item {
                Icon { x:4;anchors.verticalCenter:parent.verticalCenter;width:12;height:12;name:details.otherNetworks?"down":"chevron";color:details.panel.muted }
                Text { x:24;anchors.verticalCenter:parent.verticalCenter;text:"Other Networks";color:details.panel.ink;font.pixelSize:12 }
            }
            background:Rectangle {radius:6;color:parent.hovered?(details.panel.dark?"#16ffffff":"#10000000"):"transparent"}
        }
        Caption { visible:details.otherNetworks && details.nativeSystem && !!details.network.wifiEnabled;text:"Nearby network discovery and joining are not available yet." }
    }
    Column {
        width:parent.width;spacing:9;visible:details.panel.section === "bluetooth"
        Item {
            width:parent.width;height:29
            Text { x:5;anchors.verticalCenter:parent.verticalCenter;text:"Bluetooth";font.pixelSize:14;font.weight:Font.DemiBold;color:details.panel.ink }
            ControlToggle {
                objectName:"controlBluetoothSwitch";anchors.right:parent.right;anchors.rightMargin:5;anchors.verticalCenter:parent.verticalCenter;dark:details.panel.dark
                checked:!!details.primaryAdapter && !!details.primaryAdapter.powered
                enabled:details.writable && !!details.primaryAdapter && !!details.primaryAdapter.writable
                Accessible.name:"Bluetooth"
                onRequested:function(value){details.backend.apply("bluetooth.powered",value,details.primaryAdapter.id);}
            }
        }
        Rule { }
        Caption {
            objectName:"controlBluetoothUnavailable"
            visible:!details.nativeSystem || !details.bluetooth.available || !details.primaryAdapter || !!details.bluetooth.hardwareBlocked || !details.primaryAdapter.powered
            text:!details.nativeSystem?"Bluetooth is not connected in this preview.":!details.bluetooth.available?"Bluetooth service unavailable.":!details.primaryAdapter?"No Bluetooth adapter detected.":details.bluetooth.hardwareBlocked?"Bluetooth is disabled by the hardware switch.":"Bluetooth is off."
        }
        Repeater {
            model:details.adapters.slice(1)
            delegate:Item {
                required property var modelData
                width:parent.width;height:29
                Text { x:5;anchors.verticalCenter:parent.verticalCenter;width:parent.width-50;text:parent.modelData.name;elide:Text.ElideRight;color:details.panel.ink;font.pixelSize:13 }
                ControlToggle { anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;dark:details.panel.dark;checked:parent.modelData.powered;enabled:details.writable&&!!parent.modelData.writable;onRequested:function(value){details.backend.apply("bluetooth.powered",value,parent.modelData.id);} }
            }
        }
        Heading { visible:details.devices.length>0;text:"My Devices" }
        Repeater {
            model:details.devices
            delegate:DeviceRow {
                required property var modelData
                name:modelData.name;symbol:"bluetooth";connected:modelData.connected
                subtitle:(modelData.connected?"Connected":"Not Connected")+(modelData.connected && typeof modelData.battery==="number" && modelData.battery>=0 && modelData.battery<=100?" · "+Math.round(modelData.battery)+"%":"")
            }
        }
        Caption { visible:details.nativeSystem && !!details.primaryAdapter && !!details.primaryAdapter.powered;text:details.devices.length?"Connecting and pairing devices is not available yet.":"No devices reported by Bluetooth." }
    }
    Column {
        width:parent.width;spacing:10;visible:details.panel.section === "battery" || details.panel.section === "lowpower"
        Item {
            width:parent.width;height:29
            Text { x:5;anchors.verticalCenter:parent.verticalCenter;text:"Battery";font.pixelSize:14;font.weight:Font.DemiBold;color:details.panel.ink }
            Text { objectName:"controlBatteryPercentage";anchors.right:parent.right;anchors.rightMargin:5;anchors.verticalCenter:parent.verticalCenter;text:details.nativeSystem && details.battery.available?Math.round(details.battery.percent)+"%":"—";color:details.panel.muted;font.pixelSize:13 }
        }
        Caption { objectName:"controlBatteryUnavailable";visible:!details.nativeSystem || !details.battery.available;text:details.nativeSystem?"No battery detected.":"Battery status is not available in this preview." }
        Caption { objectName:"controlBatterySource";visible:details.nativeSystem && !!details.battery.available;text:"Power Source: "+(details.battery.onBattery?"Battery":"Power Adapter") }
        Caption { visible:details.nativeSystem && !!details.battery.available && !!text;text:details.battery.status || "" }
        Rule { visible:details.nativeSystem && !!details.power.available }
        Heading { visible:details.nativeSystem && !!details.power.available;text:"Energy Mode" }
        Repeater {
            model:details.nativeSystem && details.power.available?details.power.profiles || []:[]
            delegate:AbstractButton {
                required property string modelData
                objectName:"controlPower_"+modelData
                width:parent.width;height:28;enabled:details.writable
                onClicked:details.backend.apply("power.profile",modelData,"")
                contentItem:Item {
                    Icon { x:3;anchors.verticalCenter:parent.verticalCenter;width:14;height:14;name:"check";color:details.panel.ink;visible:details.power.active===parent.parent.modelData }
                    Text { x:25;anchors.verticalCenter:parent.verticalCenter;text:parent.parent.modelData==="power-saver"?"Low Power":parent.parent.modelData==="balanced"?"Automatic":"High Power";font.pixelSize:13;color:details.panel.ink }
                }
                background:Rectangle {radius:6;color:parent.hovered?(details.panel.dark?"#16ffffff":"#10000000"):"transparent"}
            }
        }
    }
    Caption { visible:details.nativeSystem && text!=="";text:details.backend.errorText }
}
