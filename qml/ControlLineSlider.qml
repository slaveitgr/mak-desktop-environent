import QtQuick
import QtQuick.Controls

Slider {
    id: slider
    property string symbol: "speaker"
    property color ink: "white"
    from: 0; to: 1
    implicitHeight: 22
    leftPadding: 27; rightPadding: 27
    opacity: enabled ? 1 : 0.4
    background: Item {
        Icon { x:0;y:3;width:16;height:16;name:slider.symbol==="sun"?"sun":"speaker-low";color:slider.ink;opacity:0.75 }
        Icon { anchors.right:parent.right;y:1;width:20;height:20;name:slider.symbol==="sun"?"sun":"speaker-high";color:slider.ink }
        Rectangle {
            x:slider.leftPadding;y:10;width:slider.availableWidth;height:3;radius:1.5;color:"#50000000"
            Rectangle { width:slider.visualPosition*parent.width;height:parent.height;radius:1.5;color:slider.ink;opacity:0.65 }
        }
    }
    handle: Rectangle {
        x:slider.leftPadding+slider.visualPosition*slider.availableWidth-width/2
        y:(slider.height-height)/2;width:11;height:11;radius:5.5;color:"#f9f9fb"
        border.color:slider.activeFocus?"#1688fa":"#20000000";border.width:slider.activeFocus?2:1
    }
}
