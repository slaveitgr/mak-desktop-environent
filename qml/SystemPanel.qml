import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

MaterialPopup {
    id: panel
    required property var desktop
    required property Item backdrop
    property string section: "control"
    property real anchorX: desktop.width - 12
    property bool editing: false
    property string selectedControl: ""
    readonly property var controls: desktop.controls
    readonly property bool dark: desktop.dark
    readonly property color ink: dark ? "#f5f5f7" : "#24252a"
    readonly property color muted: dark ? "#c1c1ca" : "#666670"
    readonly property int revision: controls.revision
    readonly property var definition: controls.info(section) || ({label: section === "control" ? "Control Center" : "Clock", settingsPage: ""})
    property var hardwareVolume: null
    property var hardwareBrightness: null
    readonly property real volume: { let r = revision; return controls.nativeSystem && hardwareVolume ? hardwareVolume.value : Math.max(0, Math.min(1, Number(controls.preference("sound.volume", "0.75")))); }
    readonly property bool soundMuted: { let r = revision; return controls.nativeSystem && hardwareVolume ? hardwareVolume.muted : controls.preference("sound.muted", "false") === "true"; }
    readonly property real brightness: { let r = revision; return controls.nativeSystem ? hardwareBrightness ? hardwareBrightness.value : 0 : Math.max(0.1, Math.min(1, Number(controls.preference("display.brightness", "1")))); }
    readonly property bool brightnessWritable: !controls.nativeSystem
    readonly property alias gridItem: controlGrid
    readonly property bool mainView: section === "control"
    readonly property bool nativeDetail: ["wifi", "bluetooth", "battery", "lowpower"].indexOf(section) >= 0
    readonly property bool unavailable: !nativeDetail && ["wifi", "bluetooth", "airdrop", "mirroring", "battery", "weather", "keyboardbrightness", "lowpower", "musicrecognition", "stagemanager", "timemachine", "hearing", "users", "textinput", "capture"].indexOf(section) >= 0
    width: mainView ? 306 : nativeDetail ? 306 : 320
    height: Math.min(desktop.height - 48, mainView ? controlGrid.implicitHeight + (editing ? 105 : 66) : nativeDetail ? detailColumn.implicitHeight + 62 : detailColumn.implicitHeight + 105)
    x: Math.max(8, Math.min(desktop.width - width - 8, anchorX - width))
    y: 36
    padding: mainView ? 8 : 12
    focus: true
    reducedMotion: desktop.reduceMotion
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    onClosed: { editing = false; tileMenu.close(); }
    onSectionChanged: {
        if (!mainView) editing = false;
        viewport.contentY = 0;
        if (desktop && desktop.statusPanel !== undefined && desktop.statusPanel !== section) desktop.statusPanel = section;
    }

    function settings(page) { close(); desktop.openSettings(page || ""); }
    function showDetail(id) {
        section = id;
    }
    function openMusic() { close(); desktop.openApplication("music"); }
    function timeLabel(seconds) {
        let value = Math.max(0, Math.round(seconds));
        return Math.floor(value / 60) + ":" + (value % 60 < 10 ? "0" : "") + value % 60;
    }
    function captionFor(id) {
        if (controls.nativeSystem) {
            if (id === "wifi") return controls.systemState.network.available ? (controls.systemState.network.wifiEnabled ? "On" : "Off") : "Unavailable";
            if (id === "bluetooth") return controls.systemState.bluetooth.available ? (controls.isActive(id) ? "On" : "Off") : "Unavailable";
            if (id === "battery") return controls.systemState.battery.available ? Math.round(controls.systemState.battery.percent) + "%" : "Unavailable";
        }
        if (id === "focus") return controls.isActive(id) ? "Do Not Disturb" : "Off";
        if (id === "darkmode") return desktop.dark ? "On" : "Off";
        if (id === "timer") return controls.timerRunning ? "Running" : controls.timerRemaining > 0 ? "Paused" : "Start a timer";
        return "";
    }
    function activateControl(id) {
        if (id === "darkmode") desktop.setAppearance(desktop.dark ? "light" : "dark");
        else if (id === "search") { close(); desktop.dispatch("search"); }
        else showDetail(id);
    }
    // Values originate in the compositor's actual hardware services. This
    // signal never changes a setting or guesses an increment from a key press.
    function hardwareLevelChanged(kind, value, muted, label, available) {
        let valid = available && Number.isFinite(value) && value >= 0 && value <= 1;
        if (kind === "volume") hardwareVolume = valid ? {value:value,muted:!!muted,label:label} : null;
        if (kind === "brightness") hardwareBrightness = valid ? {value:value} : null;
        let id = kind === "volume" ? "sound" : kind === "brightness" ? "display" : "";
        return visible && id !== "" && (mainView ? controls.layout.some(item => item.id === id) : section === id);
    }
    Connections {
        target: panel.controls.systemBackend
        function onChanged() { panel.hardwareVolume = null; }
    }
    function canToggle(id) {
        if (id === "focus" || id === "darkmode") return true;
        if (!controls.nativeSystem || !controls.systemBackend.ready || controls.systemBackend.busy) return false;
        if (id === "wifi") return !!controls.systemState.network.wifiWritable;
        if (id === "bluetooth") return !!(controls.systemState.bluetooth.adapters || []).find(adapter => adapter.writable);
        return false;
    }
    function toggleControl(id) {
        if (!canToggle(id)) { showDetail(id); return; }
        if (id === "wifi") controls.systemBackend.apply("wifi.enabled", !controls.systemState.network.wifiEnabled, "");
        else if (id === "bluetooth") {
            let adapter = (controls.systemState.bluetooth.adapters || []).find(item => item.writable);
            if (adapter) controls.systemBackend.apply("bluetooth.powered", !adapter.powered, adapter.id);
        } else if (id === "focus") controls.setPreference("focus.doNotDisturb", !controls.isActive("focus"));
        else if (id === "darkmode") desktop.setAppearance(desktop.dark ? "light" : "dark");
    }
    function changeLevel(id, value) {
        if (id === "sound") {
            controls.requestVolume(value);
        } else if (id === "display" && brightnessWritable) controls.setPreference("display.brightness", String(Math.max(0.1, Math.min(1, value))));
    }
    function cycleSize(id, current) {
        let info = controls.info(id);
        if (info && info.sizes.length > 1) controls.resizeControl(id, info.sizes[(info.sizes.indexOf(current) + 1) % info.sizes.length]);
    }
    function moveSelected(direction) {
        let index = controls.layout.findIndex(item => item.id === selectedControl);
        if (index >= 0) controls.moveControl(selectedControl, index + direction);
    }
    function dropControl(id, point) {
        let nearest = -1, distance = Infinity;
        for (let index = 0; index < tileRepeater.count; index++) {
            let item = tileRepeater.itemAt(index);
            if (!item) continue;
            let dx = point.x - item.x - item.width / 2, dy = point.y - item.y - item.height / 2;
            if (dx * dx + dy * dy < distance) { distance = dx * dx + dy * dy; nearest = index; }
        }
        if (nearest >= 0) controls.moveControl(id, nearest);
    }
    function showTileMenu(id, item) {
        let info = controls.info(id), index = controls.layout.findIndex(entry => entry.id === id);
        if (!info) return;
        selectedControl = id;
        let options = [];
        options.push({label: controls.inMenu(id) ? "Remove from Menu Bar" : "Add to Menu Bar", command: "pin:" + id});
        if (index >= 0) {
            if (options.length) options.push({separator: true});
            options.push({label: "Move Earlier", command: "earlier:" + id, enabled: index > 0});
            options.push({label: "Move Later", command: "later:" + id, enabled: index < controls.layout.length - 1});
            if (info.sizes.length > 1) {
                options.push({separator: true});
                for (let size of info.sizes) options.push({label: size.charAt(0).toUpperCase() + size.slice(1), command: "size:" + id + ":" + size, checked: controls.layout[index].size === size});
            }
            options.push({separator: true}, {label: "Remove Control", command: "remove:" + id});
        }
        tileMenu.rows = options;
        let point = item.mapToItem(panel.parent, Math.min(item.width, 40), 20);
        tileMenu.x = Math.max(8, Math.min(desktop.width - tileMenu.width - 8, point.x));
        tileMenu.y = Math.max(36, Math.min(desktop.height - tileMenu.height - 8, point.y));
        tileMenu.open();
    }
    function detailMessage(id) {
        let messages = {
            wifi: "Wi-Fi is managed by the host system. Network controls are not connected to this desktop.",
            bluetooth: "Bluetooth is managed by the host system. Nearby devices are not available in this desktop.",
            airdrop: "AirDrop sharing is not available in this desktop.",
            mirroring: "No screen mirroring service is connected.",
            battery: "Battery status is not available. No power telemetry is connected.",
            weather: "No weather service is connected.",
            keyboardbrightness: "Keyboard lighting is managed by the host system.",
            lowpower: "Power modes are managed by the host system.",
            musicrecognition: "No music recognition service is connected.",
            stagemanager: "Stage Manager is not available. Use the desktop's window controls to arrange your apps.",
            timemachine: "No backup service is connected to this desktop.",
            hearing: "Hearing device controls are not connected.",
            users: "User switching is managed by the host system.",
            textinput: "Keyboard input sources are managed by the host system.",
            capture: "Screen capture is not connected yet."
        };
        return messages[id] || "";
    }
    background: Glass {
        objectName: "controlCenterMaterial"; visible: !panel.mainView
        backdrop: panel.backdrop; sampleX: panel.x; sampleY: panel.y
        dark: panel.dark; corner: panel.nativeDetail ? 14 : 23; tint: panel.dark ? 0.53 : 0.57; frost: 0.98; refraction: 3
        reveal: panel.materialization; reducedTransparency: desktop.reduceTransparency; shadowOpacity: 0.23
    }
    contentItem: Item {
        Item {
            id: header; width: parent.width; height: panel.mainView || panel.nativeDetail ? 0 : 34; visible: height > 0
            ControlActionButton { objectName: "controlBack"; visible: !panel.mainView; x: -5; text: "Back to Control Center"; symbol: "back"; dark: panel.dark; onClicked: panel.showDetail("control") }
            Text { x: panel.mainView ? 2 : 31; anchors.verticalCenter: parent.verticalCenter; text: panel.definition.label; color: panel.ink; font.pixelSize: 15; font.weight: Font.DemiBold; elide: Text.ElideRight; width: parent.width - x - 66 }
            ControlActionButton { objectName: "legacyControlEdit"; visible: panel.mainView; anchors.right: parent.right; text: panel.editing ? "Done" : "Edit"; filled: panel.editing; dark: panel.dark; onClicked: panel.editing = !panel.editing }
            ControlActionButton { objectName: "controlClose"; visible: !panel.mainView; anchors.right: parent.right; text: "Close"; symbol: "close"; dark: panel.dark; onClicked: panel.close() }
        }
        Flickable {
            id: viewport; objectName: "controlViewport"
            anchors.top: header.bottom; anchors.bottom: footer.top; width: parent.width
            contentWidth: width
            contentHeight: panel.mainView ? controlGrid.implicitHeight + 12 : detailColumn.implicitHeight + 10
            clip: true; boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            GridLayout {
                id: controlGrid
                property var controller: panel
                visible: panel.mainView
                x: 0; y: 0; width: parent.width
                columns: 4; columnSpacing: 14; rowSpacing: 14
                Repeater {
                    id: tileRepeater
                    model: panel.controls.layout
                    delegate: ControlTile {
                        required property var modelData
                        required property int index
                        objectName: "controlTile_" + modelData.id
                        panel: controlGrid.controller; entry: modelData; order: index
                        Layout.columnSpan: modelData.size === "large" ? 4 : modelData.size === "medium" ? 2 : 1
                        Layout.rowSpan: modelData.id === "nowplaying" && modelData.size === "medium" ? 2 : 1
                        Layout.fillWidth: true
                        Layout.preferredWidth: (Layout.columnSpan * 62) + (Layout.columnSpan - 1) * 14
                        Layout.preferredHeight: implicitHeight
                    }
                }
            }
            Column {
                id: detailColumn
                x: panel.nativeDetail ? 0 : 4; y: panel.nativeDetail ? 0 : 6; width: parent.width - 2*x; spacing: 14
                visible: !panel.mainView
                NativeControlDetails { width: parent.width; visible: controlGrid.controller.nativeDetail; panel: controlGrid.controller }
                Rectangle {
                    visible: panel.unavailable
                    width: parent.width; height: unavailableBody.implicitHeight + 40; radius: 19
                    color: panel.dark ? "#3143434d" : "#7affffff"
                    Column { id: unavailableBody; x: 18; y: 18; width: parent.width - 36; spacing: 12
                        Icon { name: panel.definition.icon || "control"; width: 32; height: 32; color: panel.muted }
                        Text { objectName: "controlUnavailableMessage"; width: parent.width; text: panel.detailMessage(panel.section); color: panel.muted; font.pixelSize: 13; wrapMode: Text.Wrap; lineHeight: 1.2 }
                    }
                }
                Column {
                    visible: panel.section === "focus"; width: parent.width; spacing: 7
                    Switch { objectName: "controlFocusSwitch"; text: "Do Not Disturb"; checked: panel.controls.isActive("focus"); onToggled: panel.controls.setPreference("focus.doNotDisturb", checked) }
                    Text { width: parent.width; text: "Silence notifications from this desktop."; color: panel.muted; font.pixelSize: 12; wrapMode: Text.Wrap }
                }
                Column {
                    visible: panel.section === "display"; width: parent.width; spacing: 13
                    ControlSlider { objectName: "controlDetailBrightness"; width: parent.width; symbol: "sun"; dark: panel.dark; from: controls.nativeSystem ? 0 : 0.1; enabled:panel.brightnessWritable;value: panel.brightness; Accessible.name: controls.nativeSystem ? "Display brightness" : "Desktop brightness"; onMoved: panel.changeLevel("display", value) }
                    Text { width: parent.width; text: panel.controls.nativeSystem ? (panel.hardwareBrightness ? "Brightness from the display keys. Slider adjustment is not connected yet." : "Display brightness is unavailable until the display service reports a level.") : "Brightness changes the appearance of this desktop."; color: panel.muted; font.pixelSize: 12; wrapMode: Text.Wrap }
                    Switch { objectName: "controlDisplayDarkMode"; text: "Dark Mode"; checked: desktop.dark; onToggled: desktop.setAppearance(checked ? "dark" : "light") }
                }
                Column {
                    visible: panel.section === "sound"; width: parent.width; spacing: 10
                    ControlSlider { objectName: "controlDetailVolume"; width: parent.width; dark: panel.dark; enabled: panel.controls.soundAvailable; value: panel.soundMuted ? 0 : panel.volume; Accessible.name: panel.controls.nativeSystem || Bridge.ddeAudio.available ? "System volume" : "Music volume"; onMoved: panel.changeLevel("sound", value) }
                    Switch { objectName: "controlMuteSwitch"; text: "Mute"; enabled: panel.controls.soundAvailable && (!panel.controls.nativeSystem || !panel.controls.systemBackend.busy); checked: panel.soundMuted; onToggled: { panel.controls.setPreference("sound.muted", checked); checked = Qt.binding(() => panel.soundMuted); } }
                    Text { width: parent.width; text: panel.controls.nativeSystem ? (panel.controls.systemOutput ? panel.controls.systemOutput.name : "No audio output available") : Bridge.ddeAudio.available ? "System output" : "Music playback volume"; color: panel.muted; font.pixelSize: 12; wrapMode: Text.Wrap }
                    Text { width: parent.width; visible: panel.controls.nativeSystem && text !== ""; text: panel.controls.systemBackend.errorText; color: panel.muted; font.pixelSize: 12; wrapMode: Text.Wrap }
                }
                Column {
                    visible: panel.section === "nowplaying"; width: parent.width; spacing: 15
                    Text { width: parent.width; text: panel.controls.nowPlaying.title || "Not Playing"; color: panel.ink; font.pixelSize: 18; font.weight: Font.DemiBold; wrapMode: Text.Wrap }
                    Row { anchors.horizontalCenter: parent.horizontalCenter; spacing: 22
                        ControlActionButton { text: "Previous Track"; symbol: "previous"; dark: panel.dark; enabled: panel.controls.nowPlaying.available; onClicked: panel.controls.mediaCommand("previous") }
                        ControlActionButton { text: panel.controls.nowPlaying.playing ? "Pause" : "Play"; symbol: panel.controls.nowPlaying.playing ? "pause" : "play"; dark: panel.dark; enabled: panel.controls.nowPlaying.available; onClicked: panel.controls.mediaCommand("playPause") }
                        ControlActionButton { text: "Next Track"; symbol: "next"; dark: panel.dark; enabled: panel.controls.nowPlaying.available; onClicked: panel.controls.mediaCommand("next") }
                    }
                    DialogButton { text: "Open Music"; dark: panel.dark; onClicked: panel.openMusic() }
                }
                Column {
                    visible: panel.section === "timer"; width: parent.width; spacing: 12
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: panel.timeLabel(panel.controls.timerRemaining); font.pixelSize: 46; font.weight: Font.Light; color: panel.ink }
                    Row { anchors.horizontalCenter: parent.horizontalCenter; spacing: 10
                        SpinBox { id: minutes; objectName: "controlTimerMinutes"; from: 1; to: 120; value: 5; editable: true; enabled: !panel.controls.timerRunning; Accessible.name: "Timer duration in minutes" }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "minutes"; color: panel.muted; font.pixelSize: 12 }
                    }
                    Row { anchors.horizontalCenter: parent.horizontalCenter; spacing: 9
                        DialogButton { objectName: "controlTimerStart"; text: panel.controls.timerRunning ? "Pause" : panel.controls.timerRemaining > 0 ? "Resume" : "Start"; primary: !panel.controls.timerRunning; dark: panel.dark; onClicked: panel.controls.timerRunning ? panel.controls.pauseTimer() : panel.controls.startTimer(panel.controls.timerRemaining || minutes.value * 60) }
                        DialogButton { objectName: "controlTimerReset"; text: "Reset"; dark: panel.dark; enabled: panel.controls.timerRemaining > 0; onClicked: panel.controls.resetTimer() }
                    }
                }
                Column {
                    visible: panel.section === "accessibility"; width: parent.width; spacing: 5
                    Switch { text: "Reduce Motion"; checked: desktop.reduceMotion; onToggled: desktop.reduceMotion = checked }
                    Switch { text: "Reduce Transparency"; checked: desktop.reduceTransparency; onToggled: desktop.reduceTransparency = checked }
                }
                Column {
                    visible: panel.section === "darkmode"; width: parent.width; spacing: 8
                    Switch { text: "Dark Mode"; checked: desktop.dark; onToggled: desktop.setAppearance(checked ? "dark" : "light") }
                }
                Column {
                    visible: panel.section === "clock"; width: parent.width; spacing: 13
                    Text { text: Qt.formatDateTime(desktop.now, "dddd, d MMMM"); color: panel.ink; font.pixelSize: 16 }
                    Text { text: Qt.formatDateTime(desktop.now, "HH:mm"); color: panel.ink; font.pixelSize: 48; font.weight: Font.Light }
                    DialogButton { text: "Open Calendar"; dark: panel.dark; onClicked: { panel.close(); desktop.openApplication("calendar"); } }
                }
                Row {
                    visible: !!panel.definition.id && !panel.nativeDetail
                    width: parent.width; spacing: 8
                    Switch { objectName: "controlPinSwitch"; text: "Show in Menu Bar"; checked: panel.controls.inMenu(panel.section); onToggled: panel.controls.setInMenu(panel.section, checked) }
                }
            }
        }
        Item {
            id: footer; anchors.bottom: parent.bottom; width: parent.width
            height: panel.mainView ? (panel.editing ? 88 : 42) : panel.nativeDetail ? 34 : 40
            Row {
                visible: panel.mainView && panel.editing; spacing: 5; height: 34
                ControlActionButton { objectName: "controlMoveEarlier"; text: "Move Earlier"; symbol: "back"; dark: panel.dark; enabled: panel.selectedControl !== "" && panel.controls.layout.findIndex(item => item.id === panel.selectedControl) > 0; onClicked: panel.moveSelected(-1) }
                Text { anchors.verticalCenter: parent.verticalCenter; width: 160; elide: Text.ElideRight; text: (panel.controls.info(panel.selectedControl) || {}).label || "Select a control"; font.pixelSize: 11; color: panel.muted }
                ControlActionButton { objectName: "controlMoveLater"; text: "Move Later"; symbol: "forward"; dark: panel.dark; enabled: panel.selectedControl !== "" && panel.controls.layout.findIndex(item => item.id === panel.selectedControl) < panel.controls.layout.length - 1; onClicked: panel.moveSelected(1) }
                ControlActionButton { objectName: "controlEditOptions"; text: "Control Options"; symbol: "more"; dark: panel.dark; enabled: panel.selectedControl !== ""; onClicked: panel.showTileMenu(panel.selectedControl, this) }
            }
            ControlActionButton { objectName: "controlEdit"; visible: panel.mainView && !panel.editing; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; text: "Edit Controls"; filled: true; dark: panel.dark; onClicked: panel.editing = true }
            ControlActionButton { objectName: "controlAddControls"; visible: panel.mainView && panel.editing; anchors.left: parent.left; anchors.bottom: parent.bottom; text: "Add Controls"; filled: true; dark: panel.dark; onClicked: { panel.close(); desktop.openControlGallery(); } }
            ControlActionButton { visible: panel.mainView && panel.editing; anchors.right: parent.right; anchors.bottom: parent.bottom; text: "Done"; filled: true; dark: panel.dark; onClicked: panel.editing = false }
            Rectangle { visible: panel.nativeDetail; width:parent.width; height:1; color:panel.dark?"#24ffffff":"#22000000" }
            AbstractButton {
                objectName: "controlSettings"; visible: !panel.mainView; width:parent.width; height:32; anchors.bottom:parent.bottom
                onClicked: panel.definition.settingsPage ? panel.settings(panel.definition.settingsPage) : panel.close()
                background:Rectangle { radius:6; color:parent.hovered?(panel.dark?"#20ffffff":"#16000000"):"transparent" }
                contentItem:Text { text:panel.definition.settingsPage?panel.definition.settingsPage+" Settings…":"Done";leftPadding:6;verticalAlignment:Text.AlignVCenter;color:panel.ink;font.pixelSize:13 }
            }
        }
    }
    GlassMenu {
        id: tileMenu; objectName: "controlTileMenu"
        parent: panel.parent; backdrop: panel.backdrop; dark: panel.dark
        reducedMotion: desktop.reduceMotion; reducedTransparency: desktop.reduceTransparency
        onChosen: function(command) {
            let parts = command.split(":"), id = parts[1];
            if (parts[0] === "pin") panel.controls.setInMenu(id, !panel.controls.inMenu(id));
            else if (parts[0] === "remove") panel.controls.removeControl(id);
            else if (parts[0] === "earlier") panel.controls.moveControl(id, panel.controls.layout.findIndex(item => item.id === id) - 1);
            else if (parts[0] === "later") panel.controls.moveControl(id, panel.controls.layout.findIndex(item => item.id === id) + 1);
            else if (parts[0] === "size") panel.controls.resizeControl(id, parts[2]);
        }
    }
}
