import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: root
    objectName: "makOSRecovery"
    width: 1152; height: 768
    minimumWidth: 760; minimumHeight: 600
    visible: !RecoveryBackend.externalActive && !diskOpen
    visibility: nativeShell ? Window.Maximized : Window.Windowed
    flags: Qt.Window | Qt.FramelessWindowHint
    title: "makOS Recovery"
    color: "#070708"
    property bool diskOpen:false
    property int selected: 0
    property string openMenu: ""
    property string dialogTitle: ""
    property string dialogText: ""
    readonly property var menuRows: ({
        "system":[{label:"About makOS Recovery",action:"about"},{label:"Try makOS",action:"desktop"}],
        "Recovery":[{label:"About makOS Recovery",action:"about"},{label:"Quit Recovery",action:"desktop"}],
        "File":[{label:"Continue",action:"continue"},{label:"Close Window",action:"desktop"}],
        "Edit":[{label:"Copy",action:""}],
        "Utilities":[{label:"Restore from Backup",action:"restore"},{label:"Install makOS",action:"install"},{label:"Web Browser",action:"browser"},{label:"Disk Utility",action:"disks"},{label:"Terminal",action:"terminal"}],
        "Window":[{label:"makOS Recovery",action:""}],
        "Help":[{label:"Recovery Help",action:"help"}]
    })
    function showMenu(name, position) { openMenu=name; topMenu.x=position; topMenu.y=29; topMenu.open(); }
    function continueSelection() { topMenu.close(); RecoveryBackend.launch(RecoveryBackend.choices[selected].id); }
    Loader { source: nativeShell ? "RecoveryIntegration.qml" : ""; onLoaded: item.host=root }
    onClosing: function(event) { event.accepted=false; if(!RecoveryBackend.externalActive)RecoveryBackend.command("desktop"); }
    DiskUtility { id:diskUtility; onReturned:{root.diskOpen=false;if(nativeShell)root.showMaximized();else root.show();root.raise();root.requestActivate();} }
    Connections {
        target: RecoveryBackend
        function onOpenDisks(){root.diskOpen=true;root.hide();diskUtility.show();diskUtility.raise();diskUtility.requestActivate();}
        function onMessage(title, text) { root.dialogTitle=title; root.dialogText=text; information.open(); }
        function onExternalChanged(){if(RecoveryBackend.externalActive)root.hide();}
        function onReturning() { if(nativeShell)root.showMaximized();else root.show(); root.raise(); root.requestActivate(); }
    }
    Shortcut { sequence: "Ctrl+Q"; onActivated: RecoveryBackend.command("desktop") }
    Shortcut { sequence: "Escape"; onActivated: { information.close(); topMenu.close(); } }
    Shortcut { sequence: "Up"; enabled: !information.opened && !topMenu.opened; onActivated: root.selected=Math.max(0,root.selected-1) }
    Shortcut { sequence: "Down"; enabled: !information.opened && !topMenu.opened; onActivated: root.selected=Math.min(3,root.selected+1) }
    Shortcut { sequence: "Return"; enabled: !information.opened && !topMenu.opened; onActivated: root.continueSelection() }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient { GradientStop { position:0; color:"#0b0b0d" } GradientStop { position:1; color:"#030304" } }
    }
    Rectangle {
        id: topbar
        visible: !nativeShell
        height:30; width:parent.width; color:"#101012"
        Rectangle { anchors.bottom:parent.bottom; width:parent.width; height:1; color:"#18181a" }
        Row {
            x:12; height:30; spacing:2
            Repeater {
                model:["system","Recovery","File","Edit","Utilities","Window","Help"]
                delegate: Rectangle {
                    required property string modelData
                    width:modelData==="system"?34:menuLabel.implicitWidth+22; height:29; radius:4
                    color: root.openMenu===modelData && topMenu.opened ? "#424246" : "transparent"
                    Image { visible:modelData==="system"; anchors.centerIn:parent; source:"assets/original/apple-logo-dark.png"; width:16; height:19; fillMode:Image.PreserveAspectFit }
                    Text { id:menuLabel; visible:modelData!=="system"; anchors.centerIn:parent; text:modelData; color:"#ededee"; font.pixelSize:13; font.weight:modelData==="Recovery"?Font.DemiBold:Font.Normal }
                    MouseArea { anchors.fill:parent; hoverEnabled:true; onClicked:root.showMenu(modelData,parent.mapToItem(root.contentItem,0,0).x); onEntered:if(topMenu.opened)root.showMenu(modelData,parent.mapToItem(root.contentItem,0,0).x) }
                }
            }
        }
    }

    Rectangle {
        id: shadow
        anchors.centerIn: panel; width:panel.width+6; height:panel.height+6; radius:16
        color:"#19000000"
    }
    Rectangle {
        id: panel
        width:520; height:458; radius:10
        anchors.centerIn:parent
        color:"#161618"; border.color:"#48484c"; border.width:1
        Column {
            x:20; y:20; width:parent.width-40; spacing:6
            Repeater {
                model:RecoveryBackend.choices
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    objectName:"recoveryChoice_"+modelData.id
                    width:parent.width; height:86; radius:6
                    color:root.selected===index?"#29292e":optionPointer.containsMouse?"#222226":"transparent"
                    border.width:0
                    Image { x:13; anchors.verticalCenter:parent.verticalCenter; width:56; height:56; source:modelData.icon; fillMode:Image.PreserveAspectFit; mipmap:true }
                    Column { x:88; width:parent.width-100; anchors.verticalCenter:parent.verticalCenter; spacing:4
                        Text { text:modelData.title; font.pixelSize:14; font.weight:Font.DemiBold; color:"#ededee" }
                        Text { text:modelData.description; width:parent.width; wrapMode:Text.WordWrap; font.pixelSize:12; color:"#a7a7ac" }
                    }
                    MouseArea { id:optionPointer; anchors.fill:parent; hoverEnabled:true; onClicked:root.selected=index; onDoubleClicked:{ root.selected=index; root.continueSelection(); } }
                }
            }
        }
        Button {
            objectName:"continueButton"
            x:parent.width-width-24; y:412; width:84; height:25
            text:"Continue"; onClicked:root.continueSelection()
            contentItem:Text { text:parent.text; color:"white"; font.pixelSize:13; horizontalAlignment:Text.AlignHCenter; verticalAlignment:Text.AlignVCenter }
            background:Rectangle { radius:5; color:parent.down?"#65656b":"#49494f"; border.color:"#64646a" }
        }
    }
    Text { visible:!RecoveryBackend.live; anchors.horizontalCenter:parent.horizontalCenter; anchors.bottom:parent.bottom; anchors.bottomMargin:24; text:"Recovery Preview"; color:"#d7d9da"; font.pixelSize:12 }
    Popup {
        id:topMenu; width:240; padding:6; closePolicy:Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background:Rectangle { radius:9; color:"#29292d"; border.color:"#55555a"; opacity:0.97 }
        contentItem:Column { spacing:2; Repeater {
            model:root.menuRows[root.openMenu] || []
            delegate:ItemDelegate {
                required property var modelData
                width:228; height:26
                text:modelData.label; enabled:modelData.action!==""
                onClicked:{ topMenu.close(); if(modelData.action==="continue")root.continueSelection();else RecoveryBackend.command(modelData.action); }
                contentItem:Text { text:parent.text; color:parent.hovered?"white":"#ededee"; font.pixelSize:13; verticalAlignment:Text.AlignVCenter }
                background:Rectangle { radius:4; color:parent.hovered?"#0877ed":"transparent" }
            }
        } }
    }
    Dialog {
        id:information; modal:true; anchors.centerIn:parent; width:430
        title:root.dialogTitle; standardButtons:Dialog.Ok
        palette.window:"#29292d"; palette.windowText:"#ededee"; palette.text:"#ededee"; palette.button:"#4a4a50"; palette.buttonText:"#ededee"
        background:Rectangle { color:"#29292d"; radius:12; border.color:"#55555a" }
        contentItem:Text { text:root.dialogText; wrapMode:Text.WordWrap; font.pixelSize:13; color:"#ededee" }
    }
}
