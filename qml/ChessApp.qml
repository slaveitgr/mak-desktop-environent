import QtQuick
import QtQuick.Controls

Item {
    id: chessApp
    required property var host
    property var game: Bridge.chess
    property bool flipped: false
    function command(name) { if(name==="undo")game.undo(); else if(name==="new") confirmNew.open(); }
    Rectangle { anchors.fill: parent; anchors.margins: 8; radius: 18; color: host.dark ? "#302d29" : "#e8dfd3" }
    Item {
        id: boardFrame
        x: 24; y: 45
        width: Math.min(chessApp.width-240,chessApp.height-95)
        height: width
        Rectangle { anchors.fill:parent; anchors.margins:-8; radius:8; color:"#594332"; border.color:"#b99a74"; border.width:2 }
        Grid {
            id: boardGrid; anchors.fill:parent; columns:8
            Repeater {
                model: chessApp.flipped ? game.squares.slice().reverse() : game.squares
                delegate: Rectangle {
                    id: square
                    required property var modelData
                    required property int index
                    width: boardFrame.width/8; height:width
                    color:modelData.selected ? "#e1b952" : modelData.light ? "#ecd9b3" : "#96734f"
                    border.width:modelData.selected ? 3 : 0; border.color:"#ffdf75"
                    Behavior on color { ColorAnimation { duration:host.desktop.reduceMotion ? 0 : 100 } }
                    Text { anchors.centerIn:parent; anchors.verticalCenterOffset:1; text:square.modelData.piece; font.family:"Arial Unicode MS"; font.pixelSize:parent.height*0.76; color:square.modelData.white ? "#fff9eb" : "#302318"; style:Text.Outline; styleColor:square.modelData.white ? "#6c5135" : "#bc9a6b" }
                    Rectangle { visible:square.modelData.legal; width:parent.width*0.23;height:width;radius:width/2;anchors.centerIn:parent;color:"#704d8236" }
                    Text { x:3;y:2;visible:square.index%8===0;text:square.modelData.name.slice(1);color:square.modelData.light?"#806548":"#e5d2ab";font.pixelSize:10 }
                    Text { anchors.right:parent.right;anchors.bottom:parent.bottom;anchors.margins:3;visible:square.index>=56;text:square.modelData.name[0];color:square.modelData.light?"#806548":"#e5d2ab";font.pixelSize:10 }
                    MouseArea { anchors.fill:parent;Accessible.role:Accessible.Button;Accessible.name:square.modelData.name+" "+square.modelData.piece;onClicked:game.select(square.modelData.square);Accessible.onPressAction:clicked(null) }
                }
            }
        }
    }
    Text { x:24; y:8; text:game.status; color:host.ink; font.pixelSize:17; font.weight:Font.DemiBold }
    Column {
        x:boardFrame.x+boardFrame.width+28; y:20; width:parent.width-x-20; spacing:14
        Text { text:"Chess";color:host.ink;font.pixelSize:26;font.weight:Font.Bold }
        Text { text:game.versusComputer ? "You play White" : "Local game";color:host.muted;font.pixelSize:12;wrapMode:Text.Wrap;width:parent.width }
        ComboBox {width:parent.width;model:["Two Players","Computer"];currentIndex:game.versusComputer?1:0;onActivated:game.setComputer(currentIndex===1);Accessible.name:"Chess opponent"}
        DialogButton { text:"New Game";width:parent.width;dark:host.dark;onClicked:confirmNew.open() }
        DialogButton { text:"Take Back Move";width:parent.width;dark:host.dark;enabled:game.canUndo;onClicked:game.undo() }
        DialogButton { visible:game.canClaimDraw; text:"Claim Draw"; width:parent.width; dark:host.dark; onClicked:game.claimDraw() }
        DialogButton { text:"Rotate Board";width:parent.width;dark:host.dark;onClicked:flipped=!flipped }
        Text { text:"Moves";color:host.ink;font.pixelSize:14;font.weight:Font.DemiBold }
        ScrollView { width:parent.width;height:Math.max(80,chessApp.height-335);clip:true
            TextArea { text:game.moves || "Select a piece to see its legal moves.";readOnly:true;wrapMode:Text.Wrap;color:host.ink;font.pixelSize:14;selectByMouse:true;background:null }
        }
    }
    Popup {
        id: promotion
        parent:chessApp;anchors.centerIn:parent;width:300;height:126;modal:true;closePolicy:Popup.NoAutoClose
        visible:game.promotionPending
        background:Rectangle {radius:16;color:host.dark?"#31383f":"#f7f7f7";border.color:host.muted}
        Column {anchors.fill:parent;spacing:12;Text{text:"Promote pawn to";color:host.ink;font.pixelSize:17}Row{spacing:8;Repeater{model:[{key:"q",label:"♛"},{key:"r",label:"♜"},{key:"b",label:"♝"},{key:"n",label:"♞"}];delegate:Button{required property var modelData;text:modelData.label;font.pixelSize:32;width:60;height:55;onClicked:game.promote(modelData.key)}}}}
    }
    Popup {
        id:confirmNew;parent:chessApp;anchors.centerIn:parent;width:300;height:170;modal:true
        background:Rectangle{radius:18;color:host.dark?"#333b44":"#f7f7f8";border.color:host.muted}
        Column {anchors.fill:parent;spacing:16;Text{text:"Start a new game?";color:host.ink;font.pixelSize:19;font.weight:Font.DemiBold}Text{width:parent.width;text:"The current game is saved in the game archive.";wrapMode:Text.Wrap;color:host.muted}Row{spacing:10;DialogButton{text:"Cancel";dark:host.dark;onClicked:confirmNew.close()}DialogButton{text:"New Game";primary:true;onClicked:{game.newGame();confirmNew.close();}}}}
    }
}
