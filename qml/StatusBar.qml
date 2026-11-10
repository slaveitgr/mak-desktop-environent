import QtQuick
import QtQuick.Controls

Item {
    id: bar
    required property var desktop
    property real availableWidth: desktop.width - 450
    property real clockWidth: clockContent.implicitWidth + 16
    readonly property var items: desktop.controls.visibleItems
    readonly property int capacity: Math.max(1, Math.floor((availableWidth - (desktop.showClock ? clockWidth : 0) - 60) / 30))
    readonly property var shown: items.slice(Math.max(0,items.length-capacity))
    readonly property var overflow: items.slice(0,Math.max(0,items.length-capacity))
    width: row.implicitWidth
    height: 30
    function open(id, item, hover) {
        let p = item.mapToItem(desktop,item.width,30);
        desktop.showStatusPanel(id,p.x,!!hover);
    }
    function context(id, item) {
        let p = item.mapToItem(desktop,0,30);
        desktop.openOptions(p.x,p.y,[desktop.row("Remove from Menu Bar","controlhide:"+id),desktop.row("Add to Control Center","controladd:"+id),desktop.sep(),desktop.row("Menu Bar Settings…","settings:Menu Bar")]);
    }
    Row {
        id: row
        spacing: 2
        Item {
            visible: bar.overflow.length > 0
            width: visible ? 28 : 0; height: 30
            Icon { anchors.centerIn: parent; name:"more"; width:20; height:18; color:"white" }
            MouseArea {
                anchors.fill:parent; Accessible.role:Accessible.Button; Accessible.name:"More menu bar controls"
                onClicked:{let p=mapToItem(desktop,0,30);desktop.openOptions(p.x,p.y,bar.overflow.map(item=>desktop.row(item.label,"controlopen:"+item.id)));}
                Accessible.onPressAction:clicked(null)
            }
        }
        Repeater {
            id: statusRepeater
            model: bar.shown
            delegate: Rectangle {
                id: statusItem
                required property var modelData
                required property int index
                property string idValue: modelData.id
                readonly property string labelText: idValue === "users" && desktop.controls.preference("users.style","Icon") !== "Icon" ? Bridge.systemInfo.user : idValue === "battery" && desktop.controls.preference("battery.showPercentage","false") === "true" ? "—%" : ""
                width: labelText ? label.implicitWidth + (idValue === "battery" ? 30 : 14) : 28
                height:30; radius:5
                color: desktop.statusPanelVisible && desktop.statusPanel === idValue ? "#38ffffff" : button.containsMouse ? "#16ffffff" : "transparent"
                Icon { anchors.verticalCenter:parent.verticalCenter; x:4; width:20; height:19; name:desktop.controls.iconFor(statusItem.idValue); color:"white"; visible:statusItem.idValue!=="users" || !statusItem.labelText }
                Text {id:label; text:statusItem.labelText; anchors.verticalCenter:parent.verticalCenter; x:statusItem.idValue==="battery"?26:7; color:"white"; font.pixelSize:12}
                MouseArea {
                    id: button
                    objectName: "statusButton_" + statusItem.idValue
                    anchors.fill:parent; hoverEnabled:true
                    acceptedButtons:Qt.LeftButton|Qt.RightButton
                    property point startPoint
                    property bool rearranging:false
                    property bool moved:false
                    onPressed:function(mouse) {
                        startPoint = mapToItem(bar,mouse.x,mouse.y); moved=false;
                        rearranging=mouse.button===Qt.LeftButton && !!(mouse.modifiers & Qt.ControlModifier);
                    }
                    onPositionChanged:function(mouse) {
                        if (!pressed || !rearranging) return;
                        let p=mapToItem(bar,mouse.x,mouse.y);
                        if (Math.abs(p.x-startPoint.x)+Math.abs(p.y-startPoint.y)>8) moved=true;
                    }
                    onReleased:function(mouse) {
                        if (!rearranging || !moved) return;
                        let p=mapToItem(bar,mouse.x,mouse.y);
                        let id=statusItem.idValue, target="";
                        if (p.y>60 || p.y< -30) { Qt.callLater(function(){desktop.controls.setInMenu(id,false);}); return; }
                        for(let i=0;i<statusRepeater.count;i++){let item=statusRepeater.itemAt(i);let q=item.mapToItem(bar,0,0);if(p.x>=q.x&&p.x<q.x+item.width)target=item.idValue;}
                        if(target && target!==id)Qt.callLater(function(){desktop.controls.moveMenuItem(id,target);});
                    }
                    onClicked:function(mouse) {
                        if(moved)return;
                        if(mouse && mouse.button===Qt.RightButton){bar.context(statusItem.idValue,statusItem);return;}
                        bar.open(statusItem.idValue,statusItem,false);
                    }
                    onEntered: if(desktop.statusPanelVisible && desktop.statusPanel!==statusItem.idValue && statusItem.idValue!=="search")bar.open(statusItem.idValue,statusItem,true)
                    Accessible.role:Accessible.Button
                    Accessible.name:statusItem.modelData.label
                    Accessible.onPressAction:clicked(null)
                }
            }
        }
        Rectangle {
            id: controlButton
            width:30;height:30;radius:5
            color:desktop.statusPanelVisible && desktop.statusPanel==="control"?"#38ffffff":controlMouse.containsMouse?"#16ffffff":"transparent"
            Icon{anchors.centerIn:parent;width:20;height:19;name:"control";color:"white"}
            MouseArea {
                id:controlMouse;objectName:"statusButton_control";anchors.fill:parent;hoverEnabled:true
                onClicked:bar.open("control",controlButton,false)
                onEntered:if(desktop.statusPanelVisible && desktop.statusPanel!=="control")bar.open("control",controlButton,true)
                Accessible.role:Accessible.Button;Accessible.name:"Control Center";Accessible.onPressAction:clicked(null)
            }
        }
        Rectangle {
            id: clockItem
            objectName:"menuBarClock"
            width:visible?bar.clockWidth:0;height:30;visible:desktop.showClock;radius:5
            color:desktop.statusPanelVisible && desktop.statusPanel==="clock"?"#38ffffff":clockMouse.containsMouse?"#16ffffff":"transparent"
            Row {
                id:clockContent;anchors.centerIn:parent;height:30;spacing:6
                Text {height:30;verticalAlignment:Text.AlignVCenter;text:desktop.clockDateText+(!desktop.clockAnalog?(desktop.clockDateText?"  ":"")+desktop.clockTimeText:"");font.pixelSize:12;font.weight:Font.Medium;color:"white"}
                Canvas {
                    visible:desktop.clockAnalog;width:visible?20:0;height:30
                    property date time:desktop.now
                    onTimeChanged:requestPaint()
                    onVisibleChanged:requestPaint()
                    onPaint:{let c=getContext("2d");c.reset();c.strokeStyle="white";c.lineWidth=1.3;c.beginPath();c.arc(10,15,8,0,Math.PI*2);c.stroke();function hand(a,l,col){c.strokeStyle=col;c.beginPath();c.moveTo(10,15);c.lineTo(10+Math.sin(a)*l,15-Math.cos(a)*l);c.stroke();}hand((time.getHours()%12+time.getMinutes()/60)*Math.PI/6,4.5,"white");hand(time.getMinutes()*Math.PI/30,6.5,"white");if(desktop.clockSeconds)hand(time.getSeconds()*Math.PI/30,6.5,"#ff675c");}
                }
            }
            MouseArea{id:clockMouse;objectName:"statusButton_clock";anchors.fill:parent;hoverEnabled:true;onClicked:bar.open("clock",clockItem,false);Accessible.role:Accessible.Button;Accessible.name:"Date and Notifications, "+Qt.formatDateTime(desktop.now,"dddd d MMMM h:mm AP");Accessible.onPressAction:clicked(null)}
        }
    }
    // Popup overlays intercept the hover that would normally reach the bar.
    MouseArea {
        objectName:"statusBarTracking"
        parent:Overlay.overlay;z:10002
        property point origin: { let bx=bar.x, by=bar.y, bw=bar.width, dy=bar.parent.y; return bar.mapToItem(desktop,0,0); }
        x:origin.x;y:origin.y;width:bar.width;height:30
        visible:desktop.statusPanelVisible
        hoverEnabled:true;acceptedButtons:Qt.LeftButton|Qt.RightButton
        function itemAt(px) {
            for(let i=0;i<statusRepeater.count;i++){let item=statusRepeater.itemAt(i), p=item.mapToItem(bar,0,0);if(px>=p.x&&px<p.x+item.width)return item;}
            let control=controlButton.mapToItem(bar,0,0),clock=clockItem.mapToItem(bar,0,0);
            if(px>=control.x&&px<control.x+controlButton.width)return controlButton;
            if(clockItem.visible&&px>=clock.x&&px<clock.x+clockItem.width)return clockItem;
            return null;
        }
        function idFor(item){return item===controlButton?"control":item===clockItem?"clock":item.idValue;}
        onPositionChanged:function(mouse){let item=itemAt(mouse.x);if(!item)return;let id=idFor(item);if(id!=="search"&&id!=="clock"&&desktop.statusPanel!==id)bar.open(id,item,true);}
        onClicked:function(mouse){let item=itemAt(mouse.x);if(!item)return;let id=idFor(item);if(mouse.button===Qt.RightButton&&id!=="control"&&id!=="clock"){desktop.closeStatusPanel();bar.context(id,item);}else bar.open(id,item,false);}
    }
}
