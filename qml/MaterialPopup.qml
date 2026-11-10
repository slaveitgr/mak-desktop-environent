import QtQuick
import QtQuick.Controls

Popup {
    property bool reducedMotion: false
    property real materialization: 1
    enter: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: reducedMotion ? 0 : 130
            }
            NumberAnimation {
                property: "scale"
                from: 0.96
                to: 1
                duration: reducedMotion ? 0 : 200
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "materialization"
                from: 0.2
                to: 1
                duration: reducedMotion ? 0 : 220
                easing.type: Easing.OutCubic
            }
        }
    }
    exit: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: reducedMotion ? 0 : 90
            }
            NumberAnimation {
                property: "scale"
                from: 1
                to: 0.985
                duration: reducedMotion ? 0 : 100
                easing.type: Easing.InCubic
            }
        }
    }
}
