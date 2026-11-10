import QtQuick
import QtQuick.Controls

Item {
    id: terminalApp
    required property var host
    property var tabs: []
    property int activeTab: 0
    property int nextTabId: 1
    property int fontSize: 12
    property bool alwaysShowTabs: false
    property bool closed: false
    readonly property var session: tabs.length ? tabs[Math.max(0,Math.min(activeTab,tabs.length-1))].session : null
    readonly property bool tabBarVisible: alwaysShowTabs || tabs.length>1
    readonly property string sessionTitle: session ? session.locationName + " — " + session.title + " — " + session.columnCount + "×" + session.rowCount : "Terminal"
    property bool followOutput: true
    readonly property real cellWidth: { let currentFont=metrics.font; return metrics.advanceWidth("M"); }
    readonly property real cellHeight: metrics.lineSpacing
    FontMetrics { id:metrics;font:output.font }
    function focusTerminal() { output.forceActiveFocus(); }
    function resizeTerminal() {
        if(session)session.resize(Math.floor(Math.max(20,viewport.width-20)/Math.max(1,cellWidth)),Math.floor(Math.max(10,viewport.height-12)/Math.max(1,cellHeight)));
    }
    function addTab() {
        if(closed)return;
        let created=Bridge.createTerminal();
        tabs=tabs.concat([{id:nextTabId++,session:created}]);activeTab=tabs.length-1;
        resizeTerminal();
        if(Bridge.terminalAutoStart)created.start();
        followOutput=true;Qt.callLater(focusTerminal);
    }
    function closeTab(index) {
        if(index<0 || index>=tabs.length)return;
        if(tabs.length===1) {host.desktop.closeWindow(host);return;}
        let removed=tabs[index].session;
        tabs=tabs.filter((tab,i)=>i!==index);activeTab=Math.min(activeTab,tabs.length-1);
        Bridge.releaseTerminal(removed);followOutput=true;Qt.callLater(focusTerminal);
    }
    function flush() {
        if(closed)return;
        closed=true;
        let sessions=tabs.map(tab=>tab.session);tabs=[];
        for(let owned of sessions)Bridge.releaseTerminal(owned);
    }
    function command(name) {
        if(name==="new" || name==="newWindow")host.desktop.newTerminalWindow();
        else if(name==="newTab")addTab();
        else if(name==="closeTab")closeTab(activeTab);
        else if(name==="nextTab" && tabs.length)activeTab=(activeTab+1)%tabs.length;
        else if(name==="previousTab" && tabs.length)activeTab=(activeTab+tabs.length-1)%tabs.length;
        else if(name==="copy")Bridge.copyText(output.selectedText);
        else if(name==="selectAll")output.selectAll();
        else if(name==="paste" && session){Bridge.pasteToTerminal(session);followOutput=true;}
        else if(name==="clearScrollback" && session)session.clearScrollback();
        else if(name==="clearScreen" && session)session.clearScreen();
        else if(name==="bigger")fontSize=Math.min(28,fontSize+1);
        else if(name==="smaller")fontSize=Math.max(8,fontSize-1);
        else if(name==="defaultFont")fontSize=12;
        else if(name==="showTabs")alwaysShowTabs=!alwaysShowTabs;
        Qt.callLater(focusTerminal);
    }
    onSessionChanged:{followOutput=true;Qt.callLater(resizeTerminal);Qt.callLater(focusTerminal);}
    onCellWidthChanged:resizeDelay.restart()
    onCellHeightChanged:resizeDelay.restart()
    Component.onCompleted:addTab()
    Component.onDestruction:flush()
    Timer {id:resizeDelay;interval:40;onTriggered:terminalApp.resizeTerminal()}
    Connections {
        target:host
        function onActiveChanged(){if(host.active)terminalApp.focusTerminal();}
    }
    Rectangle {
        id:tabBar;visible:terminalApp.tabBarVisible;height:visible?28:0;width:parent.width;color:"#292e35"
        Row {
            width:parent.width-30;height:parent.height
            Repeater {
                model:terminalApp.tabs
                delegate:Rectangle {
                    required property var modelData
                    required property int index
                    width:Math.max(80,(tabBar.width-30)/Math.max(1,terminalApp.tabs.length));height:28
                    color:terminalApp.activeTab===index?"#394049":"#292e35"
                    Text {x:22;anchors.verticalCenter:parent.verticalCenter;width:parent.width-32;text:modelData.session.title;elide:Text.ElideRight;color:terminalApp.activeTab===index?"#e7e9ec":"#a6abb2";font.pixelSize:11}
                    MouseArea {anchors.fill:parent;onClicked:{terminalApp.activeTab=index;terminalApp.focusTerminal();}Accessible.role:Accessible.PageTab;Accessible.name:modelData.session.title;Accessible.onPressAction:{terminalApp.activeTab=index;terminalApp.focusTerminal();}}
                    AbstractButton {objectName:"terminalCloseTab_"+index;x:3;y:5;width:18;height:18;onClicked:terminalApp.closeTab(index);contentItem:Text {text:"×";font.pixelSize:14;color:"#d0d4db";horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter}Accessible.name:"Close tab"}
                }
            }
        }
        AbstractButton {objectName:"terminalNewTab";anchors.right:parent.right;width:28;height:28;onClicked:terminalApp.addTab();contentItem:Text{text:"+";font.pixelSize:18;color:"#d0d4db";horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter}Accessible.name:"New tab"}
    }
    Flickable {
        id:viewport;objectName:"terminalViewport"
        x:0;y:tabBar.height;width:parent.width;height:parent.height-y;clip:true
        contentWidth:Math.max(width,output.contentWidth+20);contentHeight:Math.max(height,output.contentHeight+12)
        boundsBehavior:Flickable.StopAtBounds
        onWidthChanged:resizeDelay.restart()
        onHeightChanged:resizeDelay.restart()
        onMovementEnded:terminalApp.followOutput=contentY>=contentHeight-height-3
        ScrollBar.vertical:ScrollBar {id:scrollbar;policy:ScrollBar.AsNeeded;onPressedChanged:if(!pressed)terminalApp.followOutput=viewport.contentY>=viewport.contentHeight-viewport.height-3}
        WheelHandler {target:null;onWheel:function(event){Qt.callLater(function(){terminalApp.followOutput=viewport.contentY>=viewport.contentHeight-viewport.height-3;});event.accepted=false;}}
        TextArea {
            id:output;objectName:"terminalOutput"
            x:10;y:5;width:Math.max(viewport.width-20,contentWidth);height:Math.max(viewport.height-10,contentHeight)
            text:terminalApp.session?terminalApp.session.richText:""
            textFormat:TextEdit.RichText
            readOnly:true;selectByMouse:true;wrapMode:TextEdit.NoWrap
            color:"#e5e9f0";selectionColor:"#425981";selectedTextColor:"white"
            font.family:Bridge.isMac?"Menlo":"DejaVu Sans Mono";font.pixelSize:terminalApp.fontSize
            leftPadding:0;rightPadding:0;topPadding:0;bottomPadding:0
            background:null;Accessible.name:"Terminal output and input"
            onTextChanged:Qt.callLater(function(){if(terminalApp.followOutput)viewport.contentY=Math.max(0,viewport.contentHeight-viewport.height);})
            onSelectedTextChanged:if(selectedText)cursorBlink.blinkOn=false
            Keys.onPressed:function(event){
                if(!terminalApp.session || !terminalApp.session.running)return;
                let shellControl=Bridge.isMac?Qt.MetaModifier:Qt.ControlModifier;
                let clipboardModifier=Bridge.isMac?Qt.ControlModifier:(Qt.ControlModifier|Qt.ShiftModifier);
                if((event.modifiers & clipboardModifier)===clipboardModifier){
                    if(event.key===Qt.Key_C){terminalApp.command("copy");event.accepted=true;return;}
                    if(event.key===Qt.Key_V){terminalApp.command("paste");event.accepted=true;return;}
                    if(event.key===Qt.Key_A){terminalApp.command("selectAll");event.accepted=true;return;}
                    if(event.key===Qt.Key_K){terminalApp.command("clearScreen");event.accepted=true;return;}
                    if(event.key===Qt.Key_T){terminalApp.command("newTab");event.accepted=true;return;}
                    if(event.key===Qt.Key_N){terminalApp.command("newWindow");event.accepted=true;return;}
                    if(event.key===Qt.Key_W){terminalApp.command("closeTab");event.accepted=true;return;}
                    if(event.key===Qt.Key_Plus || event.key===Qt.Key_Equal){terminalApp.command("bigger");event.accepted=true;return;}
                    if(event.key===Qt.Key_Minus){terminalApp.command("smaller");event.accepted=true;return;}
                    if(event.key===Qt.Key_0){terminalApp.command("defaultFont");event.accepted=true;return;}
                    if(Bridge.isMac)return;
                }
                let value="";
                if((event.modifiers & shellControl) && event.key>=Qt.Key_A && event.key<=Qt.Key_Z){
                    if(event.key===Qt.Key_C){terminalApp.session.interrupt();event.accepted=true;return;}
                    value=String.fromCharCode(event.key-Qt.Key_A+1);
                } else if(event.key===Qt.Key_Return || event.key===Qt.Key_Enter)value="\r";
                else if(event.key===Qt.Key_Backspace)value="\x7f";
                else if(event.key===Qt.Key_Tab)value=(event.modifiers & Qt.ShiftModifier)?"\x1b[Z":"\t";
                else if(event.key===Qt.Key_Up)value="\x1b[A";
                else if(event.key===Qt.Key_Down)value="\x1b[B";
                else if(event.key===Qt.Key_Right)value="\x1b[C";
                else if(event.key===Qt.Key_Left)value="\x1b[D";
                else if(event.key===Qt.Key_Home)value="\x1b[H";
                else if(event.key===Qt.Key_End)value="\x1b[F";
                else if(event.key===Qt.Key_Delete)value="\x1b[3~";
                else if(event.key===Qt.Key_PageUp)value="\x1b[5~";
                else if(event.key===Qt.Key_PageDown)value="\x1b[6~";
                else if(event.key===Qt.Key_Escape)value="\x1b";
                else value=event.text;
                if(value){terminalApp.followOutput=true;terminalApp.session.write(value);event.accepted=true;cursorBlink.blinkOn=true;}
            }
        }
        Rectangle {
            readonly property rect cursor:output.positionToRectangle(Math.min(output.length,terminalApp.session?terminalApp.session.cursorPosition:0))
            x:output.x+cursor.x;y:output.y+cursor.y
            width:terminalApp.cellWidth;height:terminalApp.cellHeight
            color:"#b6b9c0";opacity:0.65
            visible:!!terminalApp.session && !!terminalApp.session.cursorVisible && output.activeFocus && !output.selectedText && cursorBlink.blinkOn
        }
    }
    Timer {id:cursorBlink;property bool blinkOn:true;interval:600;repeat:true;running:output.activeFocus && !!terminalApp.session && terminalApp.session.running;onTriggered:blinkOn=!blinkOn}
    Text {x:10;y:6;width:parent.width-20;visible:!!terminalApp.session && !!terminalApp.session.errorText;text:terminalApp.session?terminalApp.session.errorText:"";color:"#ff8d7b";font.pixelSize:12;wrapMode:Text.Wrap}
}
