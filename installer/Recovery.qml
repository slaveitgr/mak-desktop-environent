import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: root
    objectName: "makOSRecovery"
    width: 1152; height: 768
    minimumWidth: 760; minimumHeight: 600
    visible: !RecoveryBackend.externalActive
    visibility: nativeShell ? Window.Maximized : Window.Windowed
    flags: Qt.Window | Qt.FramelessWindowHint
    title: "makOS Recovery"
    color: "#66686a"
    property int selected: 1
    property string openMenu: ""
    property string dialogTitle: ""
    property string dialogText: ""
    readonly property var menuRows: ({
        "system":[{label:"About makOS Recovery",action:"about"},{label:"Try makOS",action:"desktop"}],
        "makOS Recovery":[{label:"About makOS Recovery",action:"about"},{label:"Quit Recovery",action:"desktop"}],
        "Utilities":[{label:"Restore from Backup",action:"restore"},{label:"Install makOS",action:"install"},{label:"Web Browser",action:"browser"},{label:"Disk Utility",action:"disks"},{label:"Terminal",action:"terminal"}],
        "Window":[{label:"makOS Recovery",action:""}],
        "Help":[{label:"Recovery Help",action:"help"}]
    })
    function showMenu(name, position) { openMenu=name; topMenu.x=position; topMenu.y=29; topMenu.open(); }
    function continueSelection() { topMenu.close(); RecoveryBackend.launch(RecoveryBackend.choices[selected].id); }
    Loader { source: nativeShell ? "RecoveryIntegration.qml" : ""; onLoaded: item.host=root }
    onClosing: function(event) { event.accepted=false; if(!RecoveryBackend.externalActive)RecoveryBackend.command("desktop"); }
    Connections {
        target: RecoveryBackend
        function onMessage(title, text) { root.dialogTitle=title; root.dialogText=text; information.open(); }
        function onReturning() { if(nativeShell)root.showMaximized();else root.show(); root.raise(); root.requestActivate(); }
    }
    Shortcut { sequence: "Ctrl+Q"; onActivated: RecoveryBackend.command("desktop") }
    Shortcut { sequence: "Escape"; onActivated: { information.close(); topMenu.close(); } }
    Shortcut { sequence: "Up"; enabled: !information.opened && !topMenu.opened; onActivated: root.selected=Math.max(0,root.selected-1) }
    Shortcut { sequence: "Down"; enabled: !information.opened && !topMenu.opened; onActivated: root.selected=Math.min(3,root.selected+1) }
    Shortcut { sequence: "Return"; enabled: !information.opened && !topMenu.opened; onActivated: root.continueSelection() }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient { GradientStop { position:0; color:"#777a7d" } GradientStop { position:1; color:"#515355" } }
    }
    Rectangle {
        id: topbar
        visible: !nativeShell
        height:30; width:parent.width; color:"#e0e1e2"
        Rectangle { anchors.bottom:parent.bottom; width:parent.width; height:1; color:"#b0b1b2" }
        Row {
            x:12; height:30; spacing:2
            Repeater {
                model:["system","makOS Recovery","Utilities","Window","Help"]
                delegate: Rectangle {
                    required property string modelData
                    width:modelData==="system"?34:menuLabel.implicitWidth+22; height:29; radius:4
                    color: root.openMenu===modelData && topMenu.opened ? "#b9bbbd" : "transparent"
                    Image { visible:modelData==="system"; anchors.centerIn:parent; source:"../assets/symbols/apple.png"; width:16; height:19; fillMode:Image.PreserveAspectFit }
                    Text { id:menuLabel; visible:modelData!=="system"; anchors.centerIn:parent; text:modelData; color:"#202124"; font.pixelSize:13; font.weight:modelData==="makOS Recovery"?Font.DemiBold:Font.Normal }
                    MouseArea { anchors.fill:parent; hoverEnabled:true; onClicked:root.showMenu(modelData,parent.mapToItem(root.contentItem,0,0).x); onEntered:if(topMenu.opened)root.showMenu(modelData,parent.mapToItem(root.contentItem,0,0).x) }
                }
            }
        }
        Row {
            anchors.right:parent.right; anchors.rightMargin:17; height:30; spacing:18
            Image { anchors.verticalCenter:parent.verticalCenter; source:"../assets/symbols/wifi.png"; width:17; height:14; fillMode:Image.PreserveAspectFit }
            Image { anchors.verticalCenter:parent.verticalCenter; source:"../assets/symbols/battery.png"; width:24; height:14; fillMode:Image.PreserveAspectFit }
        }
    }
    Rectangle {
        id: shadow
        anchors.centerIn: panel; width:panel.width+6; height:panel.height+6; radius:16
        color:"#19000000"
    }
    Rectangle {
        id: panel
        width:590; height:477; radius:12
        anchors.centerIn:parent
        color:"#f4f4f4"; border.color:"#535557"; border.width:1
        Rectangle { x:1; y:1; width:parent.width-2; height:40; radius:11; color:"#e7e7e7" }
        Rectangle { x:1; y:28; width:parent.width-2; height:14; color:"#e7e7e7" }
        Text { y:13; anchors.horizontalCenter:parent.horizontalCenter; text:"makOS Recovery"; font.pixelSize:13; font.weight:Font.DemiBold; color:"#4c4c4e" }
        Row { x:16; y:16; spacing:8; Repeater { model:3; Rectangle { width:11; height:11; radius:6; color:"#d2d2d2"; border.color:"#c8c8c8" } } }
        Column {
            x:22; y:57; width:parent.width-44; spacing:5
            Repeater {
                model:RecoveryBackend.choices
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    objectName:"recoveryChoice_"+modelData.id
                    width:parent.width; height:77; radius:8
                    color:root.selected===index?"#e3e9f1":optionPointer.containsMouse?"#ebebeb":"transparent"
                    border.width:root.selected===index?1:0; border.color:"#8facd0"
                    Image { x:15; anchors.verticalCenter:parent.verticalCenter; width:53; height:53; source:modelData.icon; fillMode:Image.PreserveAspectFit; mipmap:true }
                    Column { x:86; anchors.verticalCenter:parent.verticalCenter; spacing:6
                        Text { text:modelData.title; font.pixelSize:15; font.weight:Font.DemiBold; color:"#202124" }
                        Text { text:modelData.description; font.pixelSize:12; color:"#5c5c60" }
                    }
                    MouseArea { id:optionPointer; anchors.fill:parent; hoverEnabled:true; onClicked:root.selected=index; onDoubleClicked:{ root.selected=index; root.continueSelection(); } }
                }
            }
        }
        Rectangle { x:1; y:402; width:parent.width-2; height:1; color:"#d8d8d8" }
        Button {
            objectName:"continueButton"
            x:parent.width-width-24; y:425; width:102; height:28
            text:"Continue"; onClicked:root.continueSelection()
            contentItem:Text { text:parent.text; color:"white"; font.pixelSize:13; horizontalAlignment:Text.AlignHCenter; verticalAlignment:Text.AlignVCenter }
            background:Rectangle { radius:6; color:parent.down?"#0052b8":"#0877ed"; border.color:"#0564d3" }
        }
        Button {
            x:24; y:425; width:94; height:28; text:"Try makOS"; onClicked:RecoveryBackend.command("desktop")
            contentItem:Text { text:parent.text; color:"#393b3e"; font.pixelSize:12; horizontalAlignment:Text.AlignHCenter; verticalAlignment:Text.AlignVCenter }
            background:Rectangle { radius:6; color:parent.down?"#ddd":"#fff"; border.color:"#c9c9cb" }
        }
    }
    Text { visible:!RecoveryBackend.live; anchors.horizontalCenter:parent.horizontalCenter; anchors.bottom:parent.bottom; anchors.bottomMargin:24; text:"Recovery Preview"; color:"#d7d9da"; font.pixelSize:12 }
    Popup {
        id:topMenu; width:240; padding:6; closePolicy:Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background:Rectangle { radius:9; color:"#eff0f0"; border.color:"#a6a7a8"; opacity:0.97 }
        contentItem:Column { spacing:2; Repeater {
            model:root.menuRows[root.openMenu] || []
            delegate:ItemDelegate {
                required property var modelData
                width:228; height:26
                text:modelData.label; enabled:modelData.action!==""
                onClicked:{ topMenu.close(); RecoveryBackend.command(modelData.action); }
                contentItem:Text { text:parent.text; color:parent.hovered?"white":"#202124"; font.pixelSize:13; verticalAlignment:Text.AlignVCenter }
                background:Rectangle { radius:4; color:parent.hovered?"#0877ed":"transparent" }
            }
        } }
    }
    Dialog {
        id:information; modal:true; anchors.centerIn:parent; width:430
        title:root.dialogTitle; standardButtons:Dialog.Ok
        contentItem:Text { text:root.dialogText; wrapMode:Text.WordWrap; font.pixelSize:13; color:"#282a2d" }
    }
}
