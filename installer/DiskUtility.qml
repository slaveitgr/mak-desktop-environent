import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: disk
    objectName:"makOSDiskUtility"
    width:1050; height:650; minimumWidth:880; minimumHeight:540
    visible:false; color:"#1e1e1f"; title:"Disk Utility"
    flags:Qt.Window | Qt.FramelessWindowHint
    palette.window:"#29292d"; palette.windowText:"#eee"; palette.text:"#eee"; palette.button:"#49494f"; palette.buttonText:"#eee"
    property bool sidebarVisible:true
    property bool allDevices:true
    property string selectedPath:""
    property string actionTitle:""
    property string messageText:""
    readonly property var selected: DiskBackend.rows.find(r=>r.path===selectedPath) || ({})
    readonly property var visibleRows: DiskBackend.rows.filter(r=>allDevices || !r.physical)
    signal returned()
    function selectFirst() { if(!visibleRows.some(r=>r.path===selectedPath))selectedPath=visibleRows.length?visibleRows[0].path:""; }
    function requestAction(title) { actionTitle=title; operation.open(); }
    function nativeCommand(command) {
        if(command==="close")close();else if(command==="refresh")DiskBackend.refresh();
        else if(command==="sidebar")sidebarVisible=!sidebarVisible;
        else if(command==="devices")allDevices=true;else if(command==="volumes")allDevices=false;
        else requestAction(command);
    }
    onAllDevicesChanged:selectFirst()
    onClosing:returned()
    onVisibleChanged:if(visible){DiskBackend.refresh();raise();requestActivate();}
    Connections { target:DiskBackend; function onChanged(){disk.selectFirst();} function onMessage(title,text){disk.messageText=text;notice.title=title;notice.open();} }
    Shortcut { sequence:"Ctrl+W"; enabled:disk.visible; onActivated:disk.close() }
    Loader { active:nativeShell && disk.visible; source:active?"DiskIntegration.qml":""; onLoaded:item.host=disk }
    Rectangle {
        id:sidebar; width:disk.sidebarVisible?250:0; height:parent.height; visible:disk.sidebarVisible; color:"#303032"
        Row { x:20;y:20;spacing:8; Repeater { model:["#ff6058","#febc2e","#28c840"]; Rectangle { required property string modelData; required property int index; width:12;height:12;radius:6;color:modelData
            MouseArea { anchors.fill:parent; onClicked:{if(index===0)disk.close();else if(index===1)disk.showMinimized();else disk.visibility===Window.FullScreen?disk.showNormal():disk.showFullScreen();} }
        } } }
        ListView {
            id:devices; x:8;y:60;width:parent.width-16;height:parent.height-y-42; clip:true
            model:disk.visibleRows
            section.property:"category";section.criteria:ViewSection.FullString
            section.delegate:Text { required property string section; text:section; height:30;leftPadding:10;topPadding:10;color:"#99999e";font.pixelSize:11;font.weight:Font.DemiBold }
            delegate:Rectangle {
                required property var modelData
                width:devices.width;height:32;radius:5;color:disk.selectedPath===modelData.path?"#0966d5":"transparent"
                Row { x:10+(disk.allDevices?modelData.depth*16:0);height:parent.height;spacing:8
                    Image { width:17;height:19;anchors.verticalCenter:parent.verticalCenter;source:modelData.category==="External"?"assets/original/sidebar-external-dark.png":"assets/original/sidebar-internal-dark.png";fillMode:Image.PreserveAspectFit }
                    Text { width:devices.width-parent.x-40;elide:Text.ElideRight;anchors.verticalCenter:parent.verticalCenter;text:modelData.title;color:"#eee";font.pixelSize:13 }
                }
                MouseArea { anchors.fill:parent;onClicked:disk.selectedPath=modelData.path }
            }
            ScrollBar.vertical:ScrollBar{}
        }
        Text { anchors.bottom:parent.bottom;anchors.bottomMargin:15;anchors.horizontalCenter:parent.horizontalCenter;text:DiskBackend.preview?"Preview · Example disks":"";color:"#a2a2a7";font.pixelSize:11 }
    }
    Rectangle {
        id:toolbar; x:sidebar.width; width:parent.width-x;height:62;color:"#28282a"
        MouseArea { anchors.fill:parent;onPressed:disk.startSystemMove() }
        Button { id:viewButton; x:12;y:9;width:44;height:43; onClicked:viewMenu.open();contentItem:Column{spacing:3;Image{anchors.horizontalCenter:parent.horizontalCenter;width:19;height:19;source:"assets/original/view-dark.png"}Text{anchors.horizontalCenter:parent.horizontalCenter;text:"View";color:"#aaaab0";font.pixelSize:10}} background:Rectangle{color:parent.hovered?"#414145":"transparent";radius:5} }
        Text { x:68;y:20;text:"Disk Utility";color:"#eee";font.pixelSize:17;font.weight:Font.DemiBold }
        Row {
            anchors.right:parent.right;anchors.rightMargin:12;y:7;spacing:5
            Repeater {
                model:[{label:"Volume",symbol:"volume"},{label:"First Aid",symbol:"first-aid"},{label:"Partition",symbol:"partition"},{label:"Erase",symbol:"erase"},{label:"Restore",symbol:"restore"},{label:disk.selected.mount && disk.selected.mount!=="Not mounted"?"Unmount":"Mount",symbol:"mount"},{label:"Info",symbol:"info"}]
                delegate:Button { required property var modelData; width:52;height:48;enabled:disk.selectedPath!=="";onClicked:disk.requestAction(modelData.label)
                    contentItem:Column { spacing:3;Image{anchors.horizontalCenter:parent.horizontalCenter;source:modelData.symbol==="volume"?"assets/volume.svg":"assets/original/"+modelData.symbol+"-dark.png";width:22;height:22;opacity:parent.parent.enabled?1:0.4}Text{anchors.horizontalCenter:parent.horizontalCenter;text:modelData.label;color:"#aaaab0";font.pixelSize:10} }
                    background:Rectangle{color:parent.hovered?"#414145":"transparent";radius:5}
                }
            }
        }
        Rectangle { width:parent.width;height:1;anchors.bottom:parent.bottom;color:"#0f0f10" }
    }
    Item {
        x:sidebar.width+34;y:94;width:parent.width-x-34;height:parent.height-y-35;visible:disk.selectedPath!==""
        Image { x:0;y:0;width:76;height:86;source:disk.selected.category==="External"?"assets/original/drive-external.png":"assets/original/drive-internal.png";fillMode:Image.PreserveAspectFit }
        Text { x:96;y:8;width:parent.width-250;elide:Text.ElideRight;text:disk.selected.title||"";color:"#ececee";font.pixelSize:26;font.weight:Font.Bold }
        Text { x:96;y:46;width:parent.width-100;elide:Text.ElideRight;text:disk.selected.subtitle||"";color:"#aaaab0";font.pixelSize:13 }
        Rectangle { anchors.right:parent.right;y:13;width:130;height:39;radius:4;color:"transparent";border.color:"#77777c"; Text { anchors.centerIn:parent;text:disk.selected.capacity||"";color:"#ccc";font.pixelSize:18 } }
        Rectangle { y:111;width:parent.width;height:1;color:"#38383c" }
        Rectangle { y:140;width:parent.width;height:26;radius:5;color:"#29292d";border.color:"#77777c"
            Rectangle { x:1;y:1;height:parent.height-2;width:(parent.width-2)*(disk.selected.fraction||0);radius:4;color:"#207a94" }
        }
        Row { y:178;width:parent.width;spacing:30
            Repeater { model:disk.selected.usageKnown?[{label:"Used",value:disk.selected.used,color:"#207a94"},{label:"Available",value:disk.selected.available,color:"#55555b"}]:[{label:"Usage not available for this device",value:"Select a mounted volume to view usage.",color:"#55555b"}]
                Column { required property var modelData;spacing:7;Row{spacing:6;Rectangle{width:10;height:10;radius:3;color:modelData.color;anchors.verticalCenter:parent.verticalCenter}Text{text:modelData.label;color:"#ddd";font.pixelSize:12}}Text{text:modelData.value;color:"#99999f";font.pixelSize:12;leftPadding:16} }
            }
        }
        Rectangle {
            y:254;width:parent.width;height:167;radius:4;color:"transparent";border.color:"#66666c"
            Grid {
                x:10;y:3;width:parent.width-20;columns:2;columnSpacing:20
                Repeater {
                    model:[['Mount Point',disk.selected.mount],['Type',disk.selected.kind],['Capacity',disk.selected.capacity],['Format',disk.selected.format],['Available',disk.selected.available],['Connection',disk.selected.transport],['Used',disk.selected.used],['Device',disk.selected.path],['Partition Map',disk.selected.scheme],['Read Only',disk.selected.readOnly?'Yes':'No']]
                    Item { required property var modelData;width:(parent.width-20)/2;height:32
                        Text { anchors.left:parent.left;anchors.verticalCenter:parent.verticalCenter;text:modelData[0];color:"#c8c8ce";font.pixelSize:11 }
                        Text { anchors.right:parent.right;anchors.verticalCenter:parent.verticalCenter;horizontalAlignment:Text.AlignRight;width:parent.width-95;elide:Text.ElideMiddle;text:modelData[1]||"—";color:"#d4d4d8";font.pixelSize:11 }
                        Rectangle { width:parent.width;height:1;anchors.bottom:parent.bottom;color:"#414146" }
                    }
                }
            }
        }
    }
    Text { visible:!disk.selectedPath;anchors.centerIn:parent;width:400;wrapMode:Text.WordWrap;horizontalAlignment:Text.AlignHCenter;text:DiskBackend.busy?"Reading disks…":DiskBackend.error||"No disks found.";color:"#ccc" }
    Button { anchors.right:parent.right;anchors.bottom:parent.bottom;anchors.margins:14;text:"Refresh";enabled:!DiskBackend.busy;onClicked:DiskBackend.refresh() }
    Menu {
        id:viewMenu;x:sidebar.width+12;y:53;width:210
        background:Rectangle{color:"#303033";radius:7;border.color:"#66666c"}
        MenuItem { text:disk.sidebarVisible?"Hide Sidebar":"Show Sidebar";onTriggered:disk.sidebarVisible=!disk.sidebarVisible }
        MenuSeparator{}
        MenuItem { text:"Show Only Volumes";checkable:true;checked:!disk.allDevices;onTriggered:disk.allDevices=false }
        MenuItem { text:"Show All Devices";checkable:true;checked:disk.allDevices;onTriggered:disk.allDevices=true }
    }
    Dialog {
        id:operation;modal:true;anchors.centerIn:parent;width:540;padding:24;title:disk.actionTitle==="Erase"?'Erase “'+(disk.selected.title||'')+'”?':disk.actionTitle
        background:Rectangle{color:"#29292c";radius:14;border.color:"#606066"}
        contentItem:Column { spacing:18
            Row { spacing:18;Image{width:64;height:72;source:disk.selected.category==="External"?"assets/original/drive-external.png":"assets/original/drive-internal.png";fillMode:Image.PreserveAspectFit}Text{width:400;wrapMode:Text.WordWrap;color:"#eee";font.pixelSize:13;text:disk.actionTitle==="Erase"?"Erasing this device permanently removes its data. Choose its name, format and partition map in Disk Tools, then review the final confirmation there.":disk.actionTitle==="Info"?(disk.selected.subtitle+"\n"+disk.selected.path):"Open the selected device in Disk Tools to manage its volumes, partitions, filesystem or disk images."} }
            Text { width:parent.width;text:(disk.selected.title||'')+" · "+(disk.selected.path||'');color:"#aaaab0";font.pixelSize:12;elide:Text.ElideMiddle }
            Row { anchors.right:parent.right;spacing:12;Button{text:"Cancel";onClicked:operation.close()}Button{text:disk.actionTitle==="Info"?"Done":"Open Disk Tools…";onClicked:{operation.close();if(disk.actionTitle!=="Info")DiskBackend.openDiskTools(disk.selectedPath);}} }
        }
    }
    Dialog { id:notice;modal:true;anchors.centerIn:parent;width:420;standardButtons:Dialog.Ok;contentItem:Text{text:disk.messageText;wrapMode:Text.WordWrap;color:"#eee"}background:Rectangle{color:"#29292c";radius:12;border.color:"#606066"} }
}
