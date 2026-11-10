import QtQuick
import QtQuick.Controls

DesktopWindow {
    id: about
    appKind: "aboutmac"
    windowTitle: "About This Mak"
    sidebarWidth: 0
    width: 440; height: 590
    minimumWindowWidth: 400; minimumWindowHeight: 540
    property var information: Bridge.systemInfo
    function command(name) {}
    ScrollView {
        parent: about.clientItem
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        Column {
            x: 30; y: 28; width: parent.width - 60
            spacing: 18
            bottomPadding: 30
            Item {
                width: 180; height: 124; anchors.horizontalCenter: parent.horizontalCenter
                Rectangle {
                    x: 8; y: 0; width: 164; height: 100; radius: 8
                    color: "#191c23"; border.color: "#8d969f"; border.width: 2
                    Image { anchors.fill: parent; anchors.margins: 6; source: Bridge.assetRoot + "wallpaper-light.jpg"; fillMode: Image.PreserveAspectCrop }
                }
                Rectangle { x: 76; y: 100; width: 28; height: 16; color: "#a7adb4" }
                Rectangle { x: 50; y: 116; width: 80; height: 5; radius: 2; color: "#bbc1c9" }
            }
            Text {
                objectName: "aboutComputerModel"
                width: parent.width; text: information.name
                font.pixelSize: 25; font.weight: Font.Bold; color: about.ink
                horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
            }
            Column {
                objectName: "aboutHardwareRows"
                width: parent.width; spacing: 12
                Repeater {
                    model: [{label:"Processor", value:information.processor},
                            {label:"Graphics", value:information.graphics},
                            {label:"Memory", value:information.memory},
                            {label:"makOS", value:information.version}]
                    delegate: Row {
                        required property var modelData
                        objectName: "aboutRow:" + modelData.label
                        width: parent.width; spacing: 14
                        Text { width: 86; text: modelData.label; color: about.muted; font.pixelSize: 13; horizontalAlignment: Text.AlignRight }
                        Text { width: parent.width - 100; text: modelData.value || "Not available"; color: about.ink; font.pixelSize: 13; wrapMode: Text.Wrap }
                    }
                }
            }
            DialogButton {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "More Info…"; dark: about.dark
                onClicked: desktop.openSettings("About")
            }
            Text {
                objectName: "aboutPreviewHost"
                visible: information.isPreview
                width: parent.width
                text: "Preview running on " + information.platform
                color: about.muted; horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 11; wrapMode: Text.Wrap
            }
        }
    }
}
