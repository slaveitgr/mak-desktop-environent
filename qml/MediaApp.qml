import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtMultimedia

Item {
    id: root
    required property var host
    readonly property bool music: host.appKind === "music"
    property string section: "Library"
    property string query: ""
    property var selection: null
    property bool enlarged: false
    property var playingTrack: null
    readonly property bool playbackPlaying: player.playbackState === MediaPlayer.PlayingState
    property var files: {
        let revision = Bridge.suite.revision;
        return Bridge.suite.media(music ? "music" : "photos");
    }
    property var favorites: {
        let revision = Bridge.suite.revision;
        try {
            return JSON.parse(Bridge.suite.preference(music ? "music.favorites" : "photos.favorites", "[]"));
        } catch (e) {
            return [];
        }
    }
    readonly property var filtered: files.filter(item => (!query || item.name.toLowerCase().indexOf(query.toLowerCase()) >= 0) && (section !== "Favorites" || favorites.indexOf(item.path) >= 0))
    readonly property real volume: {
        let revision = Bridge.suite.revision;
        return Math.max(0, Math.min(1, Number(Bridge.suite.preference("sound.volume", "0.75"))));
    }
    readonly property bool muted: {
        let revision = Bridge.suite.revision;
        return Bridge.suite.preference("sound.muted", "false") === "true";
    }
    function flush() {
        player.stop();
    }
    function command(name) {
        if (name === "new")
            importDialog.open();
        else if (name === "open" && selection && !music)
            enlarged = true;
        else if (name === "back" && enlarged)
            enlarged = false;
        else if (name === "favorite")
            toggleFavorite(selection);
        else if (name === "previous") {
            if (music)
                nextTrack(-1);
            else
                nextPhoto(-1);
        } else if (name === "next") {
            if (music)
                nextTrack(1);
            else
                nextPhoto(1);
        } else if (name === "library") {
            enlarged = false;
            section = "Library";
        } else if (name === "favorites") {
            enlarged = false;
            section = "Favorites";
        } else if (name === "playPause" && music && filtered.length) {
            if (player.playbackState === MediaPlayer.PlayingState)
                player.pause();
            else if (playingTrack)
                player.play();
            else
                playTrack(filtered[0]);
        }
    }
    function toggleFavorite(item) {
        if (!item)
            return;
        let next = favorites.slice();
        let index = next.indexOf(item.path);
        if (index >= 0)
            next.splice(index, 1);
        else
            next.push(item.path);
        Bridge.suite.setPreference(music ? "music.favorites" : "photos.favorites", JSON.stringify(next));
    }
    function playTrack(item) {
        if (!item)
            return;
        playingTrack = item;
        selection = item;
        player.source = item.url;
        player.play();
    }
    function nextTrack(direction) {
        if (!filtered.length)
            return;
        let index = filtered.findIndex(item => playingTrack && item.path === playingTrack.path);
        playTrack(filtered[(index + direction + filtered.length) % filtered.length]);
    }
    function nextPhoto(direction) {
        if (!filtered.length)
            return;
        let index = filtered.findIndex(item => selection && item.path === selection.path);
        selection = filtered[(index + direction + filtered.length) % filtered.length];
    }
    onFilteredChanged: if (enlarged && selection && !filtered.some(item => item.path === selection.path))
        enlarged = false
    function timeLabel(ms) {
        let seconds = Math.floor(ms / 1000);
        return Math.floor(seconds / 60) + ":" + (seconds % 60 < 10 ? "0" : "") + seconds % 60;
    }
    FileDialog {
        id: importDialog
        title: root.music ? "Add Music" : "Import Photos"
        fileMode: FileDialog.OpenFiles
        nameFilters: root.music ? ["Audio (*.mp3 *.m4a *.aac *.wav *.ogg *.flac *.opus)"] : ["Images (*.png *.jpg *.jpeg *.webp *.gif *.bmp)"]
        onAccepted: {
            let count = Bridge.suite.importMedia(selectedFiles.map(item => item.toString()), root.music ? "music" : "photos");
            if (count)
                root.section = "Library";
        }
    }
    AudioOutput {
        id: audio
        volume: root.volume
        muted: root.muted
    }
    MediaPlayer {
        id: player
        audioOutput: audio
        onMediaStatusChanged: if (mediaStatus === MediaPlayer.EndOfMedia)
            root.nextTrack(1)
        onErrorOccurred: function (error, errorString) {
            host.desktop.showInfo("Unable to Play", errorString);
        }
    }
    Item {
        id: sidebar
        x: 18
        y: 3
        width: 186
        height: parent.height - 18
        TextField {
            id: search
            width: parent.width
            height: 30
            placeholderText: "Search"
            color: host.ink
            placeholderTextColor: host.muted
            font.pixelSize: 12
            leftPadding: 12
            selectByMouse: true
            background: Rectangle {
                radius: 8
                color: host.dark ? "#38535a61" : "#80ffffff"
                border.color: host.dark ? "#1fffffff" : "#18000000"
            }
            onTextChanged: root.query = text
        }
        Column {
            y: 51
            width: parent.width
            spacing: 4
            Text {
                text: "Library"
                color: host.muted
                font.pixelSize: 11
                font.weight: Font.DemiBold
                height: 24
            }
            Repeater {
                model: root.music ? ["Library", "Favorites", "Recently Added"] : ["Library", "Favorites", "Photo Booth"]
                delegate: Rectangle {
                    required property string modelData
                    required property int index
                    width: sidebar.width
                    height: 33
                    radius: 8
                    color: root.section === modelData ? (host.dark ? "#625e6c79" : "#c4ffffff") : "transparent"
                    Row {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 9
                        Icon {
                            name: index === 0 ? (root.music ? "speaker" : "image") : index === 1 ? "tag" : "clock"
                            width: 19
                            height: 19
                            color: root.music ? "#e95669" : "#248be4"
                        }
                        Text {
                            text: modelData
                            color: host.ink
                            font.pixelSize: 13
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.section = modelData;
                            root.enlarged = false;
                            if (modelData === "Photo Booth")
                                host.desktop.openApplication("photobooth");
                        }
                    }
                }
            }
            Text {
                text: root.music ? "On This Desktop" : "Collections"
                color: host.muted
                font.pixelSize: 11
                font.weight: Font.DemiBold
                topPadding: 26
                bottomPadding: 6
            }
            DialogButton {
                text: root.music ? "Add Music…" : "Import…"
                dark: host.dark
                width: parent.width
                onClicked: importDialog.open()
            }
        }
        Text {
            anchors.bottom: parent.bottom
            width: parent.width
            text: root.files.length + (root.music ? " songs" : " photos")
            color: host.muted
            font.pixelSize: 11
        }
    }
    Rectangle {
        id: library
        x: 222
        y: 0
        width: parent.width - x - 8
        height: parent.height - 8
        radius: 17
        color: host.dark ? "#202527" : "#fdfdfd"
        clip: true
        Row {
            x: 24
            y: 18
            spacing: 12
            Text {
                text: root.section === "Recently Added" ? "Recently Added" : root.section === "Favorites" ? "Favorites" : root.music ? "Songs" : "Library"
                color: host.ink
                font.pixelSize: 25
                font.weight: Font.Bold
            }
            Text {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                text: root.filtered.length.toString()
                color: host.muted
                font.pixelSize: 14
            }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 20
            y: 18
            spacing: 6
            IconButton {
                visible: !root.music
                symbol: "image"
                tip: "Open Photo Booth"
                dark: host.dark
                onClicked: host.desktop.openApplication("photobooth")
            }
            IconButton {
                symbol: "downloads"
                tip: root.music ? "Add Music" : "Import Photos"
                dark: host.dark
                onClicked: importDialog.open()
            }
        }
        Text {
            x: 24
            y: 55
            text: root.music ? "Music stored on this desktop" : "All photos, in one place"
            color: host.muted
            font.pixelSize: 12
        }
        Column {
            anchors.centerIn: parent
            width: Math.min(380, parent.width - 64)
            spacing: 18
            visible: root.filtered.length === 0
            Image {
                source: Bridge.assetRoot + (root.music ? "music.png" : "photos.png")
                width: 86
                height: 86
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: root.query ? "No Results" : root.section === "Favorites" ? "No Favorites Yet" : root.music ? "Your Music Library" : "Your Photos"
                color: host.ink
                font.pixelSize: 24
                font.weight: Font.DemiBold
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                text: root.query ? "Try another search." : root.section === "Favorites" ? "Mark items as favorites to find them here." : root.music ? "Add songs from your computer to start listening." : "Import your pictures, or take a new photo in Photo Booth."
                color: host.muted
                font.pixelSize: 13
                wrapMode: Text.Wrap
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }
            DialogButton {
                text: root.music ? "Add Music…" : "Import Photos…"
                primary: true
                dark: host.dark
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: importDialog.open()
            }
        }
        GridView {
            id: photosGrid
            Keys.onReturnPressed: if (root.selection)
                root.enlarged = true
            onCurrentIndexChanged: if (currentIndex >= 0 && currentIndex < root.filtered.length && !root.music)
                root.selection = root.filtered[currentIndex]
            visible: !root.music
            x: 18
            y: 89
            width: parent.width - 36
            height: parent.height - y - 22
            clip: true
            model: root.music ? [] : root.filtered
            cellWidth: Math.max(130, width / Math.max(1, Math.floor(width / 170)))
            cellHeight: cellWidth + 29
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
            delegate: Item {
                id: photo
                required property var modelData
                required property int index
                width: photosGrid.cellWidth
                height: photosGrid.cellHeight
                Rectangle {
                    x: 5
                    y: 5
                    width: parent.width - 10
                    height: width
                    radius: 8
                    clip: true
                    color: host.dark ? "#33393d" : "#eaeef0"
                    Image {
                        anchors.fill: parent
                        anchors.margins: 2
                        source: photo.modelData.url
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 420
                        sourceSize.height: 420
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        radius: 8
                        border.width: root.selection && root.selection.path === photo.modelData.path ? 3 : 0
                        border.color: "#2889ef"
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 9
                        text: "♥"
                        color: "white"
                        font.pixelSize: 22
                        visible: root.favorites.indexOf(photo.modelData.path) >= 0
                        style: Text.Outline
                        styleColor: "#80000000"
                    }
                    MouseArea {
                        anchors.fill: parent
                        Accessible.role: Accessible.Button
                        Accessible.name: photo.modelData.name
                        onClicked: {
                            root.selection = photo.modelData;
                            photosGrid.currentIndex = photo.index;
                            photosGrid.forceActiveFocus();
                        }
                        onDoubleClicked: {
                            root.selection = photo.modelData;
                            root.enlarged = true;
                        }
                        Accessible.onPressAction: {
                            root.selection = photo.modelData;
                            root.enlarged = true;
                        }
                    }
                }
                Text {
                    x: 8
                    y: parent.width + 1
                    width: parent.width - 16
                    text: modelData.name
                    color: host.ink
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
            }
        }
        ListView {
            id: songs
            visible: root.music
            x: 18
            y: 89
            width: parent.width - 36
            height: parent.height - y - 107
            clip: true
            model: root.music ? root.filtered : []
            spacing: 1
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
            delegate: Rectangle {
                id: song
                required property var modelData
                required property int index
                width: songs.width
                height: 56
                radius: 8
                color: root.selection && root.selection.path === modelData.path ? (host.dark ? "#4b3948" : "#ffedef") : index % 2 ? (host.dark ? "#262c2f" : "#f6f7f8") : "transparent"
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.selection = song.modelData
                    onDoubleClicked: root.playTrack(song.modelData)
                }
                Rectangle {
                    x: 10
                    y: 8
                    width: 40
                    height: 40
                    radius: 7
                    color: host.dark ? "#51414d" : "#f3dbe0"
                    Text {
                        anchors.centerIn: parent
                        text: root.playingTrack && root.playingTrack.path === song.modelData.path && player.playbackState === MediaPlayer.PlayingState ? "♫" : "♪"
                        color: "#d6516a"
                        font.pixelSize: 26
                    }
                }
                Text {
                    x: 64
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 152
                    text: modelData.name
                    color: host.ink
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
                Button {
                    anchors.right: parent.right
                    anchors.rightMargin: 40
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    flat: true
                    text: root.favorites.indexOf(song.modelData.path) >= 0 ? "♥" : "♡"
                    Accessible.name: "Favorite " + song.modelData.name
                    onClicked: root.toggleFavorite(song.modelData)
                    contentItem: Text {
                        text: parent.text
                        color: "#dc5b75"
                        font.pixelSize: 21
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                Button {
                    anchors.right: parent.right
                    anchors.rightMargin: 5
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    flat: true
                    text: "▶"
                    Accessible.name: "Play " + song.modelData.name
                    onClicked: root.playTrack(song.modelData)
                    contentItem: Text {
                        text: parent.text
                        color: "#dd556c"
                        font.pixelSize: 17
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
        Rectangle {
            visible: root.music
            x: 16
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 13
            width: parent.width - 32
            height: 82
            radius: 14
            color: host.dark ? "#353c41" : "#f1f2f5"
            border.color: host.dark ? "#22ffffff" : "#12000000"
            Row {
                x: 14
                y: 16
                spacing: 8
                Repeater {
                    model: ["◀", player.playbackState === MediaPlayer.PlayingState ? "Ⅱ" : "▶", "▶"]
                    delegate: Button {
                        required property string modelData
                        required property int index
                        width: index === 1 ? 36 : 27
                        height: 34
                        flat: true
                        Accessible.name: index === 0 ? "Previous Song" : index === 1 ? (player.playbackState === MediaPlayer.PlayingState ? "Pause" : "Play") : "Next Song"
                        enabled: root.files.length > 0
                        onClicked: {
                            if (index === 0)
                                root.nextTrack(-1);
                            else if (index === 2)
                                root.nextTrack(1);
                            else if (player.playbackState === MediaPlayer.PlayingState)
                                player.pause();
                            else if (root.playingTrack)
                                player.play();
                            else
                                root.playTrack(root.filtered[0]);
                        }
                        contentItem: Icon {name:index===0?"previous":index===2?"next":player.playbackState===MediaPlayer.PlayingState?"pause":"play";color:host.ink}
                    }
                }
            }
            Text {
                x: 139
                y: 14
                width: parent.width - 156
                text: root.playingTrack ? root.playingTrack.name : "Not Playing"
                color: host.ink
                font.pixelSize: 12
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Slider {
                id: progress
                x: 133
                y: 33
                width: parent.width - 151
                height: 24
                from: 0
                to: Math.max(1, player.duration)
                value: player.position
                enabled: player.seekable
                onMoved: player.position = value
            }
            Text {
                x: 139
                y: 61
                text: root.timeLabel(player.position)
                color: host.muted
                font.pixelSize: 10
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 20
                y: 61
                text: root.timeLabel(player.duration)
                color: host.muted
                font.pixelSize: 10
            }
        }
        Rectangle {
            id: photoViewer
            anchors.fill: parent
            color: host.dark ? "#171b1e" : "#f5f5f6"
            radius: 17
            visible: root.enlarged && root.selection && !root.music
            Image {
                x: 14
                y: 55
                width: parent.width - 28
                height: parent.height - 111
                source: !root.music && root.selection ? root.selection.url : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }
            Row {
                x: 12
                y: 9
                spacing: 4
                IconButton {
                    symbol: "back"
                    tip: "Back to Library"
                    dark: host.dark
                    onClicked: root.enlarged = false
                }
                Text {
                    height: 32
                    verticalAlignment: Text.AlignVCenter
                    text: root.selection ? root.selection.name : ""
                    color: host.ink
                    font.pixelSize: 13
                    width: Math.max(80, library.width - 180)
                    elide: Text.ElideRight
                }
            }
            Button {
                anchors.right: parent.right
                anchors.rightMargin: 17
                y: 8
                width: 34
                height: 34
                flat: true
                text: root.selection && root.favorites.indexOf(root.selection.path) >= 0 ? "♥" : "♡"
                Accessible.name: "Favorite Photo"
                onClicked: root.toggleFavorite(root.selection)
                contentItem: Text {
                    text: parent.text
                    color: "#ef5670"
                    font.pixelSize: 27
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                spacing: 18
                IconButton {
                    symbol: "back"
                    tip: "Previous Photo"
                    dark: host.dark
                    onClicked: root.nextPhoto(-1)
                }
                Text {
                    height: 32
                    verticalAlignment: Text.AlignVCenter
                    text: (root.filtered.findIndex(item => root.selection && item.path === root.selection.path) + 1) + " of " + root.filtered.length
                    color: host.muted
                    font.pixelSize: 12
                }
                IconButton {
                    symbol: "forward"
                    tip: "Next Photo"
                    dark: host.dark
                    onClicked: root.nextPhoto(1)
                }
            }
        }
    }
}
