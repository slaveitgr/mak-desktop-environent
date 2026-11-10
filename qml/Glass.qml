import QtQuick
import QtQuick.Effects

Item {
    id: glass
    property Item backdrop
    property real sampleX: 0
    property real sampleY: 0
    property real corner: 22
    property bool dark: false
    property real tint: dark ? 0.64 : 0.68
    property real refraction: 5.5
    property real frost: 0.75
    property real reveal: 1
    property real shadowOpacity: 0
    property bool reducedTransparency: false
    readonly property int capturePadding: 40
    readonly property real captureLeft: Math.max(0, sampleX - capturePadding)
    readonly property real captureTop: Math.max(0, sampleY - capturePadding)
    Rectangle {
        id: shape
        anchors.fill: parent
        radius: glass.corner
        color: "black"
        visible: false
        layer.enabled: true
    }
    MultiEffect {
        anchors.fill: shape
        source: shape
        visible: glass.shadowOpacity > 0
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, glass.shadowOpacity)
        shadowBlur: 0.7
        shadowVerticalOffset: 7
        blurMax: 32
    }
    ShaderEffectSource {
        id: capture
        width: Math.max(1, Math.min(glass.backdrop ? glass.backdrop.width : glass.width, glass.sampleX + glass.width + glass.capturePadding) - glass.captureLeft)
        height: Math.max(1, Math.min(glass.backdrop ? glass.backdrop.height : glass.height, glass.sampleY + glass.height + glass.capturePadding) - glass.captureTop)
        sourceItem: glass.backdrop
        sourceRect: Qt.rect(glass.captureLeft, glass.captureTop, width, height)
        textureSize: Qt.size(Math.max(1, width), Math.max(1, height))
        live: glass.visible && !glass.reducedTransparency
        hideSource: false
        visible: false
        smooth: true
    }
    MultiEffect {
        id: soft
        width: capture.width
        height: capture.height
        source: capture
        blurEnabled: true
        blur: 0.8
        blurMax: 32
        autoPaddingEnabled: false
        visible: false
        layer.enabled: true
        layer.smooth: true
    }
    ShaderEffect {
        anchors.fill: parent
        visible: !glass.reducedTransparency
        property var sharpSource: capture
        property var softSource: soft
        property real radius: glass.corner
        property size panelSize: Qt.size(width, height)
        property size captureSize: Qt.size(capture.width, capture.height)
        property point captureOffset: Qt.point(glass.sampleX - glass.captureLeft, glass.sampleY - glass.captureTop)
        property real tintAmount: glass.tint
        property real darkAmount: glass.dark ? 1 : 0
        property real refraction: glass.refraction
        property real materialization: glass.reveal
        property real frost: glass.frost
        fragmentShader: "../shaders/liquidglass.frag.qsb"
    }
    Rectangle {
        anchors.fill: parent
        visible: glass.reducedTransparency
        radius: glass.corner
        color: glass.dark ? "#292b30" : "#eff0f2"
        border.color: glass.dark ? "#586069" : "#c6cbd1"
    }
}
