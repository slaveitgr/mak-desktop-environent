import QtQuick

QtObject {
    id: state
    property string kind: ""
    property string label: ""
    property real value: 0
    property bool muted: false
    property bool levelAvailable: false
    property bool active: false
    property int dismissalInterval: 1600
    function present(eventKind, actualValue, actualMuted, actualLabel, available) {
        if (!["volume","brightness","microphone","keyboardBrightness"].includes(eventKind) || !available || !Number.isFinite(actualValue) || actualValue<0 || actualValue>1) {
            levelAvailable=false;dismiss();return false;
        }
        kind=eventKind;value=actualValue;muted=!!actualMuted;
        label=actualLabel || (kind==="brightness"?"Display":kind==="keyboardBrightness"?"Keyboard Brightness":kind==="microphone"?"Input Volume":"Sound");
        levelAvailable=true;active=true;deadline.restart();return true;
    }
    function dismiss() { deadline.stop();active=false; }
    property Timer deadline:Timer { interval:state.dismissalInterval;onTriggered:state.active=false }
}
