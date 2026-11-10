import QtQuick
import QtQuick.Controls
import QtQuick.Window
import MakOS.Cutefish 1.0

Item {
    id:adapter
    property var popup:null
    readonly property var surfaceWindow:popup&&popup.contentItem?popup.contentItem.Window.window:null
    readonly property var parentWindow:popup&&popup.parent?popup.parent.Window.window:null
    readonly property bool ready:glass.active&&glass.glassEnabled
    CutefishWindow {
        id:glass
        window:adapter.surfaceWindow!==adapter.parentWindow?adapter.surfaceWindow:null
        glassEnabled:!!(adapter.popup&&adapter.popup.visible&&adapter.popup.popupType===Popup.Window&&adapter.popup.mode!=="spotlight"&&!adapter.popup.desktop.reduceTransparency&&adapter.surfaceWindow&&Math.abs(adapter.surfaceWindow.width-adapter.popup.width)<2&&Math.abs(adapter.surfaceWindow.height-adapter.popup.height)<2)
        glassRect:adapter.surfaceWindow?Qt.rect(0,0,adapter.surfaceWindow.width,adapter.surfaceWindow.height):Qt.rect(0,0,0,0)
        glassRadius:30
        dark:adapter.popup?adapter.popup.desktop.dark:false
        menus:"[]"
    }
}
