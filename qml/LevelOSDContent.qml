import QtQuick

Item {
    id: content
    required property var level
    required property var desktop
    property Item backdrop: null
    property real sampleX: 0
    property real sampleY: 0
    Glass {
        anchors.fill:parent
        backdrop:content.backdrop;sampleX:content.sampleX;sampleY:content.sampleY;corner:31
        dark:content.desktop.dark;tint:dark?0.53:0.57;frost:0.98;refraction:3;shadowOpacity:0.14
        reducedTransparency:content.desktop.reduceTransparency
    }
    Text { objectName:"hardwareLevelTitle";x:15;y:10;width:parent.width-30;text:content.level.label;elide:Text.ElideRight;font.pixelSize:12;font.weight:Font.DemiBold;color:content.desktop.dark?"#f5f5f7":"#24252a" }
    ControlLineSlider {
        objectName:"hardwareLevelIndicator";x:15;y:30;width:parent.width-30;height:22
        symbol:content.level.kind==="brightness"?"sun":content.level.kind==="keyboardBrightness"?"keyboard":"speaker"
        value:content.level.muted?0:content.level.value;ink:content.desktop.dark?"#f5f5f7":"#24252a"
        // Reporting an observed value must not introduce an independent setter.
        enabled:false;opacity:1
        Accessible.name:content.level.label;Accessible.description:content.level.muted?"Muted":Math.round(content.level.value*100)+" percent"
    }
}
