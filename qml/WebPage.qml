import QtQuick
import QtQuick.Controls
import QtWebEngine

Item {
    id: page
    required property var owner
    required property int tabUid
    required property string initialUrl
    property alias currentUrl: web.url
    property alias canGoBack: web.canGoBack
    property alias canGoForward: web.canGoForward
    property alias loading: web.loading
    property alias loadProgress: web.loadProgress
    property string loadError: ""
    function load(address) {
        web.url = address;
    }
    function back() {
        web.goBack();
    }
    function forward() {
        web.goForward();
    }
    function reload() {
        web.reload();
    }
    function stop() {
        web.stop();
    }
    function command(name) {
        let actions = {
            undo: WebEngineView.Undo,
            cut: WebEngineView.Cut,
            copy: WebEngineView.Copy,
            paste: WebEngineView.Paste,
            selectAll: WebEngineView.SelectAll
        };
        if (actions[name] !== undefined)
            web.triggerWebAction(actions[name]);
    }
    WebEngineView {
        id: web
        anchors.fill: parent
        profile: page.owner.browsingProfile
        url: page.initialUrl
        backgroundColor: page.owner.host.dark ? "#202326" : "white"
        settings.fullScreenSupportEnabled: false
        settings.localContentCanAccessRemoteUrls: false
        settings.localContentCanAccessFileUrls: false
        onUrlChanged: page.owner.updateTab(page.tabUid, url.toString(), title)
        onTitleChanged: page.owner.updateTab(page.tabUid, url.toString(), title)
        onLoadingChanged: function (request) {
            if (request.status === WebEngineView.LoadStartedStatus)
                page.loadError = "";
            else if (request.status === WebEngineView.LoadFailedStatus && request.errorCode !== -3)
                page.loadError = request.errorString || "The page could not be loaded.";
        }
        onNewWindowRequested: function (request) {
            page.owner.openUrl(request.requestedUrl.toString(), true);
        }
        onFeaturePermissionRequested: function (origin, feature) {
            grantFeaturePermission(origin, feature, false);
            page.owner.host.desktop.showInfo("Website permission", "Camera, microphone and location access from websites are not enabled in this prototype.");
        }
        onRenderProcessTerminated: function (status, code) {
            page.loadError = "The web process stopped. Reload this page to try again.";
        }
    }
    Rectangle {
        anchors.fill: parent
        visible: page.loadError !== ""
        color: page.owner.host.dark ? "#24282b" : "#fafafa"
        Column {
            anchors.centerIn: parent
            width: Math.min(440, parent.width - 50)
            spacing: 18
            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "network"
                width: 56
                height: 56
                color: page.owner.host.muted
            }
            Text {
                width: parent.width
                text: "Unable to Open Page"
                color: page.owner.host.ink
                font.pixelSize: 25
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                width: parent.width
                text: page.loadError
                color: page.owner.host.muted
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 13
            }
            DialogButton {
                text: "Try Again"
                dark: page.owner.host.dark
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: {
                    page.loadError = "";
                    web.reload();
                }
            }
        }
    }
}
