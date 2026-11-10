import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

Item {
    id: root
    required property var host
    property bool awaitingPermission: false
    property bool cameraStarted: false
    property string status: "Camera is off"
    property int countdown: 0
    property bool mirror: true
    property string effect: "normal"
    property string captureMode: "single"
    property bool effectsVisible: false
    property bool capturePending: false
    property int framesRemaining: 0
    property int totalFrames: 1
    property int readinessRetries: 0
    property var framePaths: []
    property string shotEffect: "normal"
    property bool shotMirror: true
    property var selectedPhoto: null
    readonly property bool busy: countdown > 0 || capturePending || framesRemaining > 0
    readonly property var effects: [
        {
            id: "normal",
            name: "Normal",
            code: 0
        },
        {
            id: "mono",
            name: "Black & White",
            code: 1
        },
        {
            id: "sepia",
            name: "Sepia",
            code: 2
        },
        {
            id: "mirror",
            name: "Mirror",
            code: 3
        }
    ]
    readonly property int effectCode: Math.max(0, effects.findIndex(item => item.id === effect))
    readonly property var liveSource: captureLoader.item ? captureLoader.item.previewSource : null
    readonly property bool allowed: {
        let revision = Bridge.suite.revision;
        return Bridge.suite.preference("camera.allowed", "true") !== "false";
    }
    readonly property var pictures: {
        let revision = Bridge.suite.revision;
        return Bridge.suite.media("photos").filter(item => item.path.indexOf("Pictures/Photo Booth/") === 0);
    }
    Component.onCompleted: {
        let saved = Bridge.suite.preference("photobooth.effect", "normal");
        effect = effects.some(item => item.id === saved) ? saved : "normal";
        mirror = Bridge.suite.preference("photobooth.flip", "true") === "true";
        captureMode = Bridge.suite.preference("photobooth.mode", "single") === "four" ? "four" : "single";
    }
    function stopSequence() {
        countdownTimer.stop();
        nextShotTimer.stop();
        countdown = 0;
        capturePending = false;
        framesRemaining = 0;
        readinessRetries = 0;
        framePaths = [];
    }
    function flush() {
        stopSequence();
        awaitingPermission = false;
        if (captureLoader.item)
            captureLoader.item.stop();
        captureLoader.active = false;
        cameraStarted = false;
        status = "Camera is off";
    }
    function setEffect(value) {
        if (busy || !effects.some(item => item.id === value))
            return;
        effect = value;
        effectsVisible = false;
        if (cameraStarted)
            status = "Ready · " + effects.find(item => item.id === value).name;
        Bridge.suite.setPreference("photobooth.effect", value);
    }
    function setCaptureMode(value) {
        if (busy || (value !== "single" && value !== "four"))
            return;
        captureMode = value;
        Bridge.suite.setPreference("photobooth.mode", value);
    }
    function setMirror(value) {
        if (busy)
            return;
        mirror = value;
        Bridge.suite.setPreference("photobooth.flip", String(value));
    }
    function command(name) {
        if (name === "new" && cameraStarted)
            takePhoto();
        else if (name === "startCamera" && allowed && !cameraStarted && !awaitingPermission)
            startCamera();
        else if (name === "stopCamera")
            flush();
        else if (name === "mirror")
            setMirror(!mirror);
        else if (name === "effects" && !busy) {
            selectedPhoto = null;
            effectsVisible = !effectsVisible;
        } else if (name.indexOf("effect:") === 0)
            setEffect(name.slice(7));
        else if (name.indexOf("mode:") === 0)
            setCaptureMode(name.slice(5));
        else if (name === "library")
            host.desktop.openApplication("photos");
    }
    function startCamera() {
        if (!allowed) {
            status = "Camera access is disabled in this desktop’s Privacy & Security settings.";
            return;
        }
        selectedPhoto = null;
        effectsVisible = false;
        awaitingPermission = true;
        status = "Waiting for camera permission…";
        Bridge.requestCameraPermission();
    }
    function takePhoto() {
        if (!captureLoader.item || !captureLoader.item.ready || busy)
            return;
        effectsVisible = false;
        selectedPhoto = null;
        framePaths = [];
        totalFrames = captureMode === "four" ? 4 : 1;
        framesRemaining = totalFrames;
        shotEffect = effect;
        shotMirror = mirror;
        readinessRetries = 0;
        countdown = 3;
        status = totalFrames === 4 ? "Four photos · Get ready" : "Get ready";
        countdownTimer.start();
    }
    function captureFrame() {
        if (!cameraStarted || !captureLoader.item || framesRemaining < 1) {
            stopSequence();
            return;
        }
        if (!captureLoader.item.ready) {
            if (++readinessRetries > 20) {
                stopSequence();
                status = "The camera is not ready. Try again.";
            } else {
                nextShotTimer.interval = 100;
                nextShotTimer.restart();
            }
            return;
        }
        let path = Bridge.suite.photoPath();
        if (!path) {
            stopSequence();
            status = "A capture file could not be created.";
            return;
        }
        readinessRetries = 0;
        capturePending = true;
        status = totalFrames === 4 ? "Photo " + (totalFrames - framesRemaining + 1) + " of 4" : "Taking photo…";
        captureLoader.item.capture(path);
    }
    function savedCapture(fileName) {
        if (!capturePending)
            return;
        capturePending = false;
        let result = Bridge.suite.finishPhoto(fileName, shotEffect, shotMirror);
        if (!result.path) {
            stopSequence();
            status = "The photo could not be processed. Its original has been kept.";
            return;
        }
        framePaths = framePaths.concat([fileName]);
        framesRemaining--;
        if (framesRemaining > 0) {
            nextShotTimer.interval = 850;
            nextShotTimer.restart();
        } else if (totalFrames === 4) {
            nextShotTimer.stop();
            let sheet = Bridge.suite.photoStrip(framePaths, shotEffect, shotMirror);
            status = sheet.path ? "Four photos and a contact sheet saved to Photos" : "Four photos saved. The contact sheet could not be created.";
        } else
            status = "Photo saved to Photos";
    }
    function inspectPhoto(photo) {
        flush();
        effectsVisible = false;
        selectedPhoto = photo;
        status = photo.name;
    }
    onAllowedChanged: if (!allowed)
        flush()
    Connections {
        target: Bridge
        function onCameraPermissionResult(granted, message) {
            if (!root.awaitingPermission || host.closing)
                return;
            root.awaitingPermission = false;
            if (granted) {
                root.status = "Starting camera…";
                if (captureLoader.item)
                    captureLoader.item.start();
                else
                    captureLoader.active = true;
            } else
                root.status = message || "Camera access was not granted.";
        }
    }
    Connections {
        target: host
        ignoreUnknownSignals: true
        function onAppHiddenChanged() { if (root.host.appHidden) root.stopCamera(); }
        function onMinimizedChanged() {
            if (host.minimized)
                root.flush();
        }
    }
    Timer {
        id: countdownTimer
        objectName: "photoCountdownTimer"
        interval: 1000
        repeat: true
        onTriggered: {
            root.countdown--;
            if (root.countdown === 0) {
                stop();
                root.captureFrame();
            }
        }
    }
    Timer {
        id: nextShotTimer
        objectName: "photoSequenceTimer"
        interval: 850
        onTriggered: root.captureFrame()
    }
    Rectangle {
        anchors.fill: parent
        radius: 19
        color: "#272329"
    }
    Item {
        id: sampleVisual
        width: 400
        height: 300
        Rectangle {
            anchors.fill: parent
            color: "#77b9d1"
        }
        Rectangle {
            y: 200
            width: parent.width
            height: 100
            color: "#dce3b4"
        }
        Rectangle {
            x: 270
            y: 30
            width: 52
            height: 52
            radius: 26
            color: "#ffe6a1"
        }
        Rectangle {
            x: 125
            y: 85
            width: 150
            height: 170
            radius: 70
            color: "#e6a583"
        }
        Rectangle {
            x: 155
            y: 145
            width: 14
            height: 14
            radius: 7
            color: "#514b51"
        }
        Rectangle {
            x: 231
            y: 145
            width: 14
            height: 14
            radius: 7
            color: "#514b51"
        }
        Rectangle {
            x: 178
            y: 195
            width: 45
            height: 9
            radius: 4
            color: "#b75562"
        }
        Rectangle {
            x: 104
            y: 248
            width: 192
            height: 90
            radius: 45
            color: "#4777b5"
        }
    }
    ShaderEffectSource {
        id: sampleTexture
        sourceItem: sampleVisual
        hideSource: true
        live: false
        visible: false
        textureSize: Qt.size(400, 300)
    }
    Rectangle {
        id: stage
        x: 12
        y: 4
        width: parent.width - 24
        height: Math.max(160, parent.height - 182)
        radius: 12
        color: "#111216"
        clip: true
        Rectangle {
            x: 0
            width: 28
            height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: "#35141f"
                }
                GradientStop {
                    position: 0.5
                    color: "#8b3044"
                }
                GradientStop {
                    position: 1
                    color: "#431923"
                }
            }
        }
        Rectangle {
            anchors.right: parent.right
            width: 28
            height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: "#431923"
                }
                GradientStop {
                    position: 0.5
                    color: "#8b3044"
                }
                GradientStop {
                    position: 1
                    color: "#35141f"
                }
            }
        }
        Loader {
            id: captureLoader
            x: 28
            y: 0
            width: parent.width - 56
            height: parent.height
            active: false
            sourceComponent: captureComponent
        }
        Image {
            anchors.fill: parent
            anchors.margins: 12
            visible: !!root.selectedPhoto
            source: root.selectedPhoto ? root.selectedPhoto.url : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }
        Column {
            anchors.centerIn: parent
            width: Math.min(430, parent.width - 100)
            spacing: 15
            visible: !root.cameraStarted && !root.selectedPhoto && !root.effectsVisible
            Image {
                source: Bridge.assetRoot + "photobooth.png"
                width: 66
                height: 66
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: "Photo Booth"
                color: "#f6f3f4"
                font.pixelSize: 27
                font.weight: Font.DemiBold
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: root.status
                color: "#b8b5be"
                font.pixelSize: 13
                width: parent.width
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
            }
            DialogButton {
                text: root.awaitingPermission ? "Waiting…" : "Start Camera"
                primary: true
                dark: true
                enabled: !root.awaitingPermission && root.allowed
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: root.startCamera()
            }
        }
        Rectangle {
            anchors.fill: parent
            color: "#e61d1b22"
            visible: root.effectsVisible
            Text {
                x: 22
                y: 16
                text: "Effects"
                color: "#f6f3f4"
                font.pixelSize: 21
                font.weight: Font.DemiBold
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 22
                y: 22
                text: root.cameraStarted ? "Live preview" : "Sample preview · Camera is off"
                color: "#bfb8c4"
                font.pixelSize: 11
            }
            Grid {
                x: 22
                y: 54
                width: parent.width - 44
                height: parent.height - 72
                columns: 2
                columnSpacing: 12
                rowSpacing: 12
                Repeater {
                    model: root.effects
                    delegate: AbstractButton {
                        id: effectChoice
                        required property var modelData
                        width: (parent.width - 12) / 2
                        height: (parent.height - 12) / 2
                        Accessible.name: modelData.name + " effect"
                        onClicked: root.setEffect(modelData.id)
                        background: Rectangle {
                            radius: 10
                            color: "#39323e"
                            border.width: root.effect === effectChoice.modelData.id ? 3 : 1
                            border.color: root.effect === effectChoice.modelData.id ? "#f4e7f4" : "#5a5261"
                        }
                        contentItem: Item {
                            ShaderEffect {
                                x: 5
                                y: 5
                                width: parent.width - 10
                                height: parent.height - 31
                                property var source: root.liveSource || sampleTexture
                                property real effectCode: effectChoice.modelData.code
                                property real flipHorizontal: root.mirror ? 1 : 0
                                fragmentShader: "../shaders/photo_effect.frag.qsb"
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 6
                                text: effectChoice.modelData.name
                                color: "#f1edf4"
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }
                        }
                    }
                }
            }
        }
        Text {
            anchors.centerIn: parent
            text: root.countdown
            visible: root.countdown > 0
            font.pixelSize: 100
            font.weight: Font.Bold
            color: "white"
            style: Text.Outline
            styleColor: "#59000000"
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 44
            y: 16
            visible: root.busy && root.totalFrames === 4
            text: (root.totalFrames - root.framesRemaining + 1) + " / 4"
            font.pixelSize: 17
            font.weight: Font.DemiBold
            color: "white"
            style: Text.Outline
            styleColor: "#80000000"
        }
        Rectangle {
            id: flash
            anchors.fill: parent
            color: "white"
            opacity: 0
            visible: opacity > 0
            SequentialAnimation {
                id: flashAnimation
                NumberAnimation {
                    target: flash
                    property: "opacity"
                    to: 0.85
                    duration: host.desktop.reduceMotion ? 0 : 60
                }
                NumberAnimation {
                    target: flash
                    property: "opacity"
                    to: 0
                    duration: host.desktop.reduceMotion ? 0 : 240
                }
            }
        }
    }
    Row {
        x: 23
        y: stage.y + stage.height + 10
        spacing: 4
        Repeater {
            model: [
                {
                    id: "four",
                    label: "Four Photos",
                    symbol: "grid"
                },
                {
                    id: "single",
                    label: "Single Photo",
                    symbol: "image"
                }
            ]
            delegate: AbstractButton {
                id: modeButton
                required property var modelData
                width: 38
                height: 33
                enabled: !root.busy
                Accessible.name: modelData.label
                onClicked: root.setCaptureMode(modelData.id)
                background: Rectangle {
                    radius: 7
                    color: root.captureMode === modeButton.modelData.id ? "#6c5d70" : "#39323d"
                    border.color: "#786a7d"
                    border.width: root.captureMode === modeButton.modelData.id ? 1 : 0
                }
                contentItem: Icon {
                    name: modeButton.modelData.symbol
                    color: "#e7dee8"
                    width: 19
                    height: 19
                }
                ToolTip.visible: hovered
                ToolTip.text: modelData.label
                ToolTip.delay: 500
            }
        }
        CheckBox {
            text: "Flip Photos"
            checked: root.mirror
            enabled: !root.busy
            onToggled: root.setMirror(checked)
            contentItem: Text {
                text: parent.text
                color: "#ddd8df"
                leftPadding: parent.indicator.width + 8
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 11
            }
        }
    }
    Button {
        anchors.horizontalCenter: parent.horizontalCenter
        y: stage.y + stage.height + 6
        width: 56
        height: 44
        enabled: captureLoader.item && captureLoader.item.ready && !root.busy && !root.effectsVisible
        Accessible.name: root.captureMode === "four" ? "Take Four Photos" : "Take Photo"
        onClicked: root.takePhoto()
        background: Rectangle {
            radius: 22
            color: parent.enabled ? (parent.down ? "#d13c4f" : "#e94f61") : "#6e3e49"
            border.width: 2
            border.color: "#d999a1"
        }
        contentItem: Icon {
            name: root.captureMode === "four" ? "grid" : "image"
            color: "white"
            width: 24
            height: 24
        }
    }
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 23
        y: stage.y + stage.height + 12
        spacing: 7
        DialogButton {
            text: root.effectsVisible ? "Done" : "Effects"
            dark: true
            implicitWidth: 70
            enabled: !root.busy
            onClicked: {
                root.selectedPhoto = null;
                root.effectsVisible = !root.effectsVisible;
            }
        }
        DialogButton {
            visible: root.cameraStarted || !!root.selectedPhoto
            text: root.cameraStarted ? "Stop" : "Camera"
            dark: true
            implicitWidth: 70
            onClicked: root.cameraStarted ? root.flush() : root.startCamera()
        }
    }
    Text {
        x: 24
        y: stage.y + stage.height + 55
        width: parent.width - 48
        text: root.cameraStarted || root.selectedPhoto || root.busy ? root.status : "Effects are saved with your photo. Originals are kept."
        color: "#bcb1c0"
        font.pixelSize: 11
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
    }
    ListView {
        id: filmstrip
        x: 21
        y: parent.height - 84
        width: parent.width - 42
        height: 71
        spacing: 9
        orientation: ListView.Horizontal
        clip: true
        model: root.pictures
        delegate: Rectangle {
            id: thumbnail
            required property var modelData
            width: 88
            height: 66
            radius: 5
            color: "#18151c"
            border.color: root.selectedPhoto && root.selectedPhoto.path === modelData.path ? "#f8d2f0" : "#64606b"
            border.width: 1
            Image {
                anchors.fill: parent
                anchors.margins: 3
                source: modelData.url
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 180
                sourceSize.height: 140
            }
            MouseArea {
                anchors.fill: parent
                Accessible.role: Accessible.Button
                Accessible.name: thumbnail.modelData.name
                onClicked: root.inspectPhoto(thumbnail.modelData)
                onDoubleClicked: host.desktop.openApplication("photos")
                Accessible.onPressAction: root.inspectPhoto(thumbnail.modelData)
            }
        }
        Text {
            visible: !root.pictures.length
            anchors.centerIn: parent
            text: "Your photos will appear here and in Photos."
            color: "#a59daa"
            font.pixelSize: 12
        }
    }
    Component {
        id: captureComponent
        Item {
            id: captureItem
            property bool ready: imageCapture.readyForCapture && camera.active
            property alias previewSource: cameraTexture
            function capture(path) {
                imageCapture.captureToFile(path);
            }
            function stop() {
                camera.stop();
            }
            function start() {
                if (!devices.videoInputs.length) {
                    root.status = "No camera is available. Connect a camera and try again.";
                    return;
                }
                if (!Bridge.configurePhotoCapture(imageCapture)) {
                    root.status = "The camera capture format could not be configured.";
                    return;
                }
                camera.start();
            }
            MediaDevices {
                id: devices
            }
            Camera {
                id: camera
                cameraDevice: devices.defaultVideoInput
                active: false
                onActiveChanged: {
                    root.cameraStarted = active;
                    if (active)
                        root.status = "Ready · " + root.effects[root.effectCode].name;
                }
                onErrorOccurred: function (error, errorString) {
                    root.stopSequence();
                    root.status = errorString || "The camera is unavailable.";
                    root.cameraStarted = false;
                }
            }
            CaptureSession {
                camera: camera
                imageCapture: ImageCapture {
                    id: imageCapture
                    onImageCaptured: flashAnimation.restart()
                    onImageSaved: function (id, fileName) {
                        root.savedCapture(fileName);
                    }
                    onErrorOccurred: function (id, error, errorString) {
                        root.stopSequence();
                        root.status = errorString || "The photo could not be saved.";
                    }
                }
                videoOutput: video
            }
            VideoOutput {
                id: video
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectFit
            }
            ShaderEffectSource {
                id: cameraTexture
                anchors.fill: parent
                sourceItem: video
                hideSource: true
                live: root.cameraStarted
                visible: false
            }
            ShaderEffect {
                anchors.fill: parent
                property var source: cameraTexture
                property real effectCode: root.effectCode
                property real flipHorizontal: root.mirror ? 1 : 0
                fragmentShader: "../shaders/photo_effect.frag.qsb"
            }
            Component.onCompleted: start()
            Component.onDestruction: camera.stop()
        }
    }
}
