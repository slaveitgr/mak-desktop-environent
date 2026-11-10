import QtQuick
import QtQuick.Controls

Item {
    id: terminalApp
    required property var host
    property var session: Bridge.createTerminal()
    property bool closed: false
    function flush() { if(!closed){closed=true;Bridge.releaseTerminal(session);session=null;} }
    function command(name) { if(name==="new" && session)session.start();else if(name==="copy")Bridge.copyText(output.selectedText);else if(name==="selectAll")output.selectAll();else if(name==="paste" && session)Bridge.pasteToTerminal(session); }
    Rectangle {anchors.fill:parent;anchors.margins:8;radius:16;color:"#171b20"}
    Row {
        x:20;y:10;spacing:12
        DialogButton{text:session && session.running ? "Shell Running" : "Start Shell";enabled:session && !session.running;dark:true;onClicked:{session.start();output.forceActiveFocus();}}
        DialogButton{text:"Interrupt";enabled:session && session.running;dark:true;onClicked:{session.interrupt();output.forceActiveFocus();}}
        DialogButton{text:"End Session";enabled:session && session.running;dark:true;onClicked:session.stop()}
    }
    ScrollView {
        x:20;y:53;width:parent.width-40;height:parent.height-70;clip:true
        TextArea {
            id:output
            text:session ? session.text : "Session closed."
            readOnly:true;selectByMouse:true;wrapMode:Text.NoWrap
            color:"#e5ebed";selectionColor:"#425981";selectedTextColor:"white";font.family:"Menlo";font.pixelSize:13
            background:null;Accessible.name:"Terminal output and input"
            Keys.onPressed:function(event){
                if(!session || !session.running)return;
                let shellControl = Bridge.isMac ? Qt.MetaModifier : Qt.ControlModifier;
                let clipboardModifier = Bridge.isMac ? Qt.ControlModifier : (Qt.ControlModifier | Qt.ShiftModifier);
                if ((event.modifiers & clipboardModifier) === clipboardModifier) {
                    if(event.key === Qt.Key_C) {output.copy(); event.accepted=true;return;}
                    if(event.key === Qt.Key_V) {Bridge.pasteToTerminal(session);event.accepted=true;return;}
                    if(Bridge.isMac) return;
                }
                let value="";
                if(event.modifiers & shellControl && event.key>=Qt.Key_A && event.key<=Qt.Key_Z){if(event.key===Qt.Key_C){session.interrupt();event.accepted=true;return;}value=String.fromCharCode(event.key-Qt.Key_A+1);}
                else if(event.key===Qt.Key_Return || event.key===Qt.Key_Enter)value="\r";
                else if(event.key===Qt.Key_Backspace)value="\x7f";
                else if(event.key===Qt.Key_Tab)value="\t";
                else if(event.key===Qt.Key_Up)value="\x1b[A";
                else if(event.key===Qt.Key_Down)value="\x1b[B";
                else if(event.key===Qt.Key_Right)value="\x1b[C";
                else if(event.key===Qt.Key_Left)value="\x1b[D";
                else if(event.key===Qt.Key_Escape)value="\x1b";
                else value=event.text;
                if(value){session.write(value);event.accepted=true;}
            }
        }
    }
}
