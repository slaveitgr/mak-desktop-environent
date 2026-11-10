import QtQuick
import QtQuick.Controls

// Preview-only in-scene feedback. The real session injects an Osd-role native
// window; it must not use Popup.Window, which can request an xdg_popup grab.
MaterialPopup {
    id: osd
    required property var desktop
    required property Item backdrop
    property alias kind:levelState.kind
    property alias label:levelState.label
    property alias value:levelState.value
    property alias muted:levelState.muted
    property alias levelAvailable:levelState.levelAvailable
    property alias dismissalInterval:levelState.dismissalInterval
    popupType:Popup.Item
    width:290;height:62;padding:0
    x:Math.max(8,desktop.width-width-28);y:41
    focus:false
    reducedMotion:desktop.reduceMotion
    closePolicy:Popup.NoAutoClose
    function present(kind,value,muted,label,available) { return levelState.present(kind,value,muted,label,available); }
    function dismiss() { levelState.dismiss(); }
    onClosed:levelState.dismiss()
    HardwareLevelState {
        id:levelState
        onActiveChanged:if(active)osd.open();else osd.close()
    }
    background:Item { }
    contentItem:LevelOSDContent { level:levelState;desktop:osd.desktop;backdrop:osd.backdrop;sampleX:osd.x;sampleY:osd.y }
}
