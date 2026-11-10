import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtWebEngine

Item {
    id: manager
    objectName: "browserDownloads"
    required property var owner
    readonly property var host: owner.host
    property var profile: null
    property var entries: []
    property var pendingEntry: null
    property alias proposedName: fileName.text
    property bool closing: false
    property bool traceLifecycle: false
    readonly property bool awaitingConfirmation: pendingEntry !== null
    readonly property bool listVisible: downloadList.opened
    readonly property int activeCount: entries.filter(item => item.status === "downloading" || item.status === "awaiting").length

    function trace(label, request) {
        if (traceLifecycle)
            console.info("DOWNLOAD", label, request ? request.id : "-", request ? request.state : "-", request ? request.isFinished : "-", request ? request.interruptReason : "-");
    }

    function byteText(value) {
        if (value < 0)
            return "Unknown size";
        if (value < 1024)
            return Math.round(value) + " bytes";
        if (value < 1024 * 1024)
            return (value / 1024).toFixed(1) + " KB";
        if (value < 1024 * 1024 * 1024)
            return (value / (1024 * 1024)).toFixed(1) + " MB";
        return (value / (1024 * 1024 * 1024)).toFixed(1) + " GB";
    }
    function originName(url) {
        let match = url.match(/^[a-z]+:\/\/([^/?#]+)/i);
        return match ? match[1].split("@").pop() : "Website";
    }
    function showList() {
        downloadList.open();
    }
    function hideList() {
        downloadList.close();
    }
    function toggleList() {
        downloadList.opened ? hideList() : showList();
    }
    function command(name) {
        // The app menu remains in the desktop menubar while this sheet is open.
        // Keep its editing actions on the filename, and prevent navigation
        // commands from acting on the page behind the confirmation.
        if (!pendingEntry)
            return false;
        if (["undo", "redo", "cut", "copy", "paste", "selectAll"].indexOf(name) >= 0 && typeof fileName[name] === "function")
            fileName[name]();
        return true;
    }
    function decide(save) {
        if (!pendingEntry)
            return;
        if (save && (!fileName.text.trim() || /[\\/\x00]/.test(fileName.text) || [".", ".."].indexOf(fileName.text.trim()) >= 0))
            return;
        Bridge.resolveDownloadDecision(manager, save);
    }
    function requested(download) {
        // Qt 6.8.2 can recreate a request with the same ID during an automatic
        // retry of a truncated response. It has replaced its profile lookup,
        // so the first wrapper will no longer receive terminal notifications.
        // Reject that retry once; do not prompt again or reserve another file.
        let existing = entries.find(item => item.uid === download.id);
        if (existing) {
            trace("duplicate-rejected", download);
            download.cancel();
            if (existing.finalized) {
                Bridge.browserProfiles.releaseDownload(download);
                return;
            }
            existing.duplicateRequests = existing.duplicateRequests.concat([download]);
            existing.rejectionMessage = "The transfer could not be continued. Try downloading the file again.";
            if (existing === pendingEntry)
                decide(false);
            else
                existing.settleSoon();
            return;
        }
        // A regular profile is shared between windows. Only the page that
        // originated the download may show its prompt or cancel the request.
        if (!owner.ownsWebView(download.view))
            return;
        trace("requested", download);
        // Qt 6.8 destroys an unaccepted request when this signal returns.
        // The bridge's nested event loop keeps this request alive while the
        // in-desktop confirmation remains interactive, without writing a file.
        if (closing || pendingEntry || download.isSavePageDownload) {
            download.cancel();
            return;
        }
        let entry = entryComponent.createObject(manager, {
            request: download,
            uid: download.id,
            name: download.suggestedFileName || "Download",
            sourceUrl: download.url.toString(),
            total: download.totalBytes
        });
        entries = [entry].concat(entries);
        pendingEntry = entry;
        fileName.text = entry.name;
        downloadList.close();
        savePrompt.open();
        trace("decision-wait", download);
        let accepted = Bridge.waitForDownloadDecision(manager);
        trace(accepted ? "decision-save" : "decision-cancel", download);
        savePrompt.close();
        pendingEntry = null;
        if (!accepted || closing) {
            download.cancel();
            entry.request = null;
            entry.status = entry.rejectionMessage ? "failed" : "cancelled";
            entry.message = entry.rejectionMessage;
            entry.finalized = true;
            releaseRequests(entry, download);
            return;
        }
        let destination = Bridge.suite.downloadDestination(fileName.text.trim());
        if (!destination || !destination.token) {
            download.cancel();
            entry.request = null;
            entry.status = "failed";
            entry.message = destination && destination.error ? destination.error : "The destination could not be prepared.";
            entry.finalized = true;
            Bridge.browserProfiles.releaseDownload(download);
            showList();
            return;
        }
        entry.token = destination.token;
        entry.name = destination.name;
        download.downloadDirectory = destination.directory;
        download.downloadFileName = destination.name;
        entry.status = "downloading";
        trace("accept-before", download);
        download.accept();
        trace("accept-after", download);
        updateEntry(entry);
        showList();
    }
    function updateEntry(entry) {
        let request = entry.request;
        if (!request || entry.finalized)
            return;
        if (entry.lastTraceState !== request.state) {
            entry.lastTraceState = request.state;
            trace("state", request);
        }
        entry.received = request.receivedBytes;
        entry.total = request.totalBytes;
        if (request.state === WebEngineDownloadRequest.DownloadCompleted || request.state === WebEngineDownloadRequest.DownloadCancelled || request.state === WebEngineDownloadRequest.DownloadInterrupted)
            entry.settleSoon();
    }
    function settleEntry(entry) {
        let request = entry.request;
        if (!request || entry.finalized)
            return;
        // Qt publishes stateChanged before receivedBytes/isFinished, while
        // Chromium is still notifying its observers. Finalize on the next turn
        // so we see the complete update and do not cancel inside that frame.
        entry.received = request.receivedBytes;
        entry.total = request.totalBytes;
        if (entry.rejectionMessage) {
            entry.finalized = true;
            if (!request.isFinished)
                request.cancel();
            if (entry.token)
                Bridge.suite.cancelDownload(entry.token);
            entry.token = "";
            entry.request = null;
            entry.status = "failed";
            entry.message = entry.rejectionMessage;
            releaseRequests(entry, request);
            trace("duplicate-finalized", null);
        } else if (request.state === WebEngineDownloadRequest.DownloadCompleted) {
            entry.finalized = true;
            let result = Bridge.suite.finishDownload(entry.token, true);
            if (!result || !result.url)
                Bridge.suite.cancelDownload(entry.token);
            entry.token = "";
            entry.request = null;
            Bridge.browserProfiles.releaseDownload(request);
            if (result && result.url) {
                entry.savedUrl = result.url;
                entry.name = result.name || entry.name;
                entry.status = "complete";
                entry.message = "Saved in Downloads";
            } else {
                entry.status = "failed";
                entry.message = result && result.error ? result.error : "The completed file could not be saved.";
            }
        } else if (request.state === WebEngineDownloadRequest.DownloadCancelled || request.state === WebEngineDownloadRequest.DownloadInterrupted) {
            let interrupted = request.state === WebEngineDownloadRequest.DownloadInterrupted;
            entry.finalized = true;
            entry.status = interrupted ? "failed" : "cancelled";
            entry.message = interrupted ? request.interruptReasonString || "Download interrupted" : "";
            if (interrupted && !request.isFinished) {
                trace("interrupted-cancel-before", request);
                request.cancel();
                trace("interrupted-cancel-after", request);
            }
            if (entry.token)
                Bridge.suite.cancelDownload(entry.token);
            entry.token = "";
            entry.request = null;
            Bridge.browserProfiles.releaseDownload(request);
            trace("failure-finalized", null);
        }
    }
    function releaseRequests(entry, request) {
        if (request)
            Bridge.browserProfiles.releaseDownload(request);
        for (let duplicate of entry.duplicateRequests)
            Bridge.browserProfiles.releaseDownload(duplicate);
        entry.duplicateRequests = [];
    }
    function cancelEntry(entry) {
        if (!entry || entry.finalized)
            return;
        if (entry === pendingEntry) {
            decide(false);
            return;
        }
        let request = entry.request;
        if (request)
            request.cancel();
        // Also clean up synchronously when an entire window is closing and
        // its signal receivers may disappear before Chromium emits finished.
        if (entry.token)
            Bridge.suite.cancelDownload(entry.token);
        entry.token = "";
        entry.request = null;
        releaseRequests(entry, request);
        entry.finalized = true;
        entry.status = "cancelled";
        entry.message = "";
    }
    function clearFinished() {
        let retained = [];
        for (let entry of entries) {
            if (entry.finalized)
                entry.destroy();
            else
                retained.push(entry);
        }
        entries = retained;
    }
    function flush() {
        closing = true;
        if (pendingEntry)
            decide(false);
        for (let entry of entries)
            if (entry !== pendingEntry)
                cancelEntry(entry);
        savePrompt.close();
        downloadList.close();
    }
    function releaseProfile() {
        if (profile) {
            Bridge.browserProfiles.release(profile);
            profile = null;
        }
    }
    Component.onCompleted: profile = Bridge.browserProfiles.acquire(owner.privateBrowsing)
    Component.onDestruction: releaseProfile()
    Connections {
        target: manager.profile
        function onDownloadRequested(download) {
            manager.requested(download);
        }
    }
    Component {
        id: entryComponent
        Item {
            id: entry
            visible: false
            property var request: null
            property int uid: 0
            property string name: "Download"
            property string sourceUrl: ""
            property string savedUrl: ""
            property string token: ""
            property string status: "awaiting"
            property string message: ""
            property real received: 0
            property real total: -1
            property bool finalized: false
            property int lastTraceState: -1
            property string rejectionMessage: ""
            property var duplicateRequests: []
            function settleSoon() { terminalUpdate.start(); }
            Timer {
                id: terminalUpdate
                interval: 0
                onTriggered: manager.settleEntry(entry)
            }
            Connections {
                target: entry.request
                function onStateChanged() {
                    manager.updateEntry(entry);
                }
                function onIsFinishedChanged() {
                    manager.updateEntry(entry);
                }
                function onReceivedBytesChanged() {
                    manager.updateEntry(entry);
                }
                function onTotalBytesChanged() {
                    manager.updateEntry(entry);
                }
            }
        }
    }
    MaterialPopup {
        id: savePrompt
        objectName: "browserSavePrompt"
        x: Math.max(12, (manager.width - width) / 2)
        y: Math.max(12, (manager.height - height) / 2)
        width: Math.min(440, manager.width - 24)
        height: 282
        modal: true
        focus: true
        closePolicy: Popup.NoAutoClose
        reducedMotion: host.desktop.reduceMotion
        padding: 24
        background: Rectangle {
            radius: 20
            color: host.dark ? "#30363c" : "#fbfcfd"
            border.color: host.dark ? "#65717c" : "#c8d0d9"
        }
        contentItem: Column {
            spacing: 13
            Text {
                text: "Save Download"
                color: host.ink
                font.pixelSize: 21
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                text: manager.pendingEntry ? manager.originName(manager.pendingEntry.sourceUrl) + " · " + manager.byteText(manager.pendingEntry.total) : ""
                textFormat: Text.PlainText
                color: host.muted
                font.pixelSize: 12
                elide: Text.ElideMiddle
            }
            RecordsField {
                id: fileName
                objectName: "browserDownloadName"
                width: parent.width
                dark: host.dark
                placeholderText: "File name"
                selectByMouse: true
                Accessible.name: "Download file name"
                Keys.onReturnPressed: manager.decide(true)
                Keys.onEscapePressed: manager.decide(false)
            }
            Text {
                text: "Where: Downloads"
                color: host.ink
                font.pixelSize: 13
            }
            Text {
                width: parent.width
                text: "Existing files are kept. A number is added when a name is already in use."
                wrapMode: Text.Wrap
                color: host.muted
                font.pixelSize: 11
            }
            Row {
                anchors.right: parent.right
                spacing: 10
                DialogButton {
                    text: "Cancel"
                    dark: host.dark
                    onClicked: manager.decide(false)
                }
                DialogButton {
                    text: "Save"
                    dark: host.dark
                    primary: true
                    enabled: fileName.text.trim() !== "" && !/[\\/\x00]/.test(fileName.text) && [".", ".."].indexOf(fileName.text.trim()) < 0
                    onClicked: manager.decide(true)
                }
            }
        }
        onOpened: {
            fileName.forceActiveFocus();
            fileName.selectAll();
        }
    }
    MaterialPopup {
        id: downloadList
        objectName: "browserDownloadList"
        x: Math.max(12, manager.width - width - 16)
        y: 46
        width: Math.min(430, manager.width - 24)
        height: Math.min(440, Math.max(168, manager.height - 70))
        padding: 15
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        reducedMotion: host.desktop.reduceMotion
        background: Rectangle {
            radius: 18
            color: host.dark ? "#30383f" : "#f9fbfd"
            border.color: host.dark ? "#687682" : "#bdc9d5"
        }
        contentItem: Item {
            Text {
                x: 4
                y: 4
                text: "Downloads"
                color: host.ink
                font.pixelSize: 19
                font.weight: Font.DemiBold
            }
            DialogButton {
                anchors.right: parent.right
                y: 0
                text: "Clear"
                dark: host.dark
                implicitWidth: 65
                enabled: manager.entries.some(item => item.finalized)
                onClicked: manager.clearFinished()
            }
            ListView {
                id: list
                x: 0
                y: 44
                width: parent.width
                height: parent.height - y
                model: manager.entries
                spacing: 5
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {
                    width: 5
                }
                delegate: Rectangle {
                    required property var modelData
                    width: list.width
                    height: 94
                    radius: 10
                    color: host.dark ? "#242c32" : "#ffffff"
                    Icon {
                        x: 10
                        y: 17
                        width: 26
                        height: 26
                        name: modelData.status === "complete" ? "document" : "downloads"
                        color: modelData.status === "failed" ? "#e66b60" : host.muted
                    }
                    Text {
                        x: 48
                        y: 11
                        width: parent.width - 90
                        text: modelData.name
                        textFormat: Text.PlainText
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: host.ink
                        elide: Text.ElideMiddle
                    }
                    Text {
                        x: 48
                        y: 34
                        width: parent.width - 75
                        text: modelData.status === "downloading" ? manager.byteText(modelData.received) + (modelData.total > 0 ? " of " + manager.byteText(modelData.total) : "") : modelData.status === "complete" ? modelData.message : modelData.status === "failed" ? modelData.message : modelData.status === "awaiting" ? "Waiting for confirmation" : "Cancelled"
                        textFormat: Text.PlainText
                        color: host.muted
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                    ProgressBar {
                        x: 48
                        y: 57
                        width: parent.width - 65
                        height: 5
                        visible: modelData.status === "downloading"
                        from: 0
                        to: Math.max(1, modelData.total)
                        value: modelData.received
                        indeterminate: modelData.total <= 0
                    }
                    Text {
                        x: 48
                        y: 72
                        width: parent.width - 65
                        text: manager.originName(modelData.sourceUrl)
                        color: host.muted
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                    IconButton {
                        anchors.right: parent.right
                        anchors.rightMargin: 5
                        y: 10
                        width: 28
                        height: 28
                        symbol: modelData.status === "complete" ? "search" : "close"
                        dark: host.dark
                        visible: !modelData.finalized || modelData.status === "complete"
                        tip: modelData.status === "complete" ? "Show in Finder" : "Cancel Download"
                        onClicked: if (modelData.status === "complete") {
                            downloadList.close();
                            host.desktop.openFolder("Downloads");
                        } else
                            manager.cancelEntry(modelData)
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: manager.entries.length === 0
                    text: "No downloads yet"
                    font.pixelSize: 14
                    color: host.muted
                }
            }
        }
    }
}
