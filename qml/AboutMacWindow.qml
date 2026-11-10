import QtQuick
import QtQuick.Controls

DesktopWindow {
    id: about
    appKind:"aboutmac"
    windowTitle:"About This Mac"
    sidebarWidth:0
    width:420;height:550
    minimumWindowWidth:380;minimumWindowHeight:500
    property var information: Bridge.systemInfo
    function command(name) {}
    Item {
        parent:about.clientItem
        anchors.fill:parent
        Column {
            x:32;y:68;width:parent.width-64;spacing:16
            Item {
                width:180;height:124;anchors.horizontalCenter:parent.horizontalCenter
                Rectangle {x:8;y:0;width:164;height:100;radius:8;color:"#191c23";border.color:"#8d969f";border.width:2
                    Image{anchors.fill:parent;anchors.margins:6;source:Bridge.assetRoot+"wallpaper-light.jpg";fillMode:Image.PreserveAspectCrop}
                }
                Rectangle{x:76;y:100;width:28;height:16;color:"#a7adb4"}
                Rectangle{x:50;y:116;width:80;height:5;radius:2;color:"#bbc1c9"}
            }
            Text {width:parent.width;text:information.name;font.pixelSize:28;font.weight:Font.Bold;color:about.ink;horizontalAlignment:Text.AlignHCenter}
            Text {width:parent.width;text:"Version "+information.version;font.pixelSize:14;color:about.muted;horizontalAlignment:Text.AlignHCenter}
            Column {
                width:parent.width;spacing:10
                Repeater {
                    model:[{label:"Processor",value:information.processor},{label:"Memory",value:information.memory},{label:"Architecture",value:information.architecture},{label:"Preview Host",value:information.platform}]
                    delegate:Row {
                        required property var modelData
                        width:parent.width;spacing:12
                        Text{width:90;text:modelData.label;color:about.muted;font.pixelSize:12;horizontalAlignment:Text.AlignRight}
                        Text{width:parent.width-102;text:modelData.value;color:about.ink;font.pixelSize:12;wrapMode:Text.Wrap}
                    }
                }
            }
            DialogButton{anchors.horizontalCenter:parent.horizontalCenter;text:"More Info…";dark:about.dark;onClicked:desktop.openSettings("About")}
            Text{width:parent.width;text:"An independent desktop for Linux.\nThis preview uses the host operating system.";color:about.muted;horizontalAlignment:Text.AlignHCenter;font.pixelSize:11;lineHeight:1.3}
        }
    }
}
