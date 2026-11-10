import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    required property var host
    readonly property bool video: host.appKind === "facetime"
    property string page: video ? "Contacts" : "Keypad"
    property string query: ""
    property string number: ""
    property var selectedContact: null
    readonly property var contacts: {
        let revision = Bridge.suite.revision;
        return Bridge.suite.records("contacts", false).filter(item => !query || ((item.name || item.title || "") + " " + (item.phone || "") + " " + (item.email || "")).toLowerCase().indexOf(query.toLowerCase()) >= 0);
    }
    function flush() {
    }
    function command(name) {
        if (name === "new")
            host.desktop.openApplication("contacts");
        else if (name === "copy")
            copyNumber();
        else if (name === "keypad" && !video)
            page = "Keypad";
        else if (name === "contacts")
            page = "Contacts";
        else if (name === "recents")
            page = "Recents";
    }
    function copyNumber() {
        if (!number)
            return;
        copyText.text = number;
        copyText.selectAll();
        copyText.copy();
        feedback.text = "Number copied";
        feedbackTimer.restart();
    }
    TextEdit {
        id: copyText
        visible: false
    }
    Timer {
        id: feedbackTimer
        interval: 2500
        onTriggered: feedback.text = ""
    }
    Item {
        id: sidebar
        x: 18
        y: 3
        width: 186
        height: parent.height - 18
        TextField {
            width: parent.width
            height: 30
            placeholderText: "Search contacts"
            color: host.ink
            placeholderTextColor: host.muted
            font.pixelSize: 12
            leftPadding: 11
            selectByMouse: true
            background: Rectangle {
                radius: 8
                color: host.dark ? "#38535a61" : "#80ffffff"
                border.color: host.dark ? "#1fffffff" : "#18000000"
            }
            onTextChanged: {
                root.query = text;
                if (text)
                    root.page = "Contacts";
            }
        }
        Column {
            y: 51
            width: parent.width
            spacing: 4
            Repeater {
                model: root.video ? ["Contacts", "Recents"] : ["Keypad", "Contacts", "Recents"]
                delegate: Rectangle {
                    required property string modelData
                    width: sidebar.width
                    height: 34
                    radius: 8
                    color: root.page === modelData ? (host.dark ? "#625e6c79" : "#c4ffffff") : "transparent"
                    Row {
                        x: 11
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        Icon {
                            name: modelData === "Keypad" ? "grid" : modelData === "Contacts" ? "account" : "clock"
                            width: 19
                            height: 19
                            color: "#3da66b"
                        }
                        Text {
                            text: modelData
                            color: host.ink
                            font.pixelSize: 13
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.page = modelData
                    }
                }
            }
        }
        DialogButton {
            anchors.bottom: parent.bottom
            text: "Open Contacts"
            width: parent.width
            dark: host.dark
            onClicked: host.desktop.openApplication("contacts")
        }
    }
    Rectangle {
        id: content
        x: 222
        y: 0
        width: parent.width - x - 8
        height: parent.height - 8
        radius: 18
        color: host.dark ? "#20272a" : "#fdfdfd"
        clip: true
        Text {
            x: 26
            y: 20
            text: root.page
            color: host.ink
            font.pixelSize: 25
            font.weight: Font.Bold
        }
        Text {
            x: 26
            y: 55
            text: root.video ? "Video calls" : "Calls from your desktop"
            color: host.muted
            font.pixelSize: 12
        }
        Flickable {
            clip: true
            contentWidth: width
            contentHeight: keypadColumn.height + 12
            visible: root.page === "Keypad"
            x: 24
            y: 86
            width: parent.width - 48
            height: parent.height - y - 92
            Column {
                id: keypadColumn
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(300, parent.width)
                spacing: 12
                TextField {
                    id: dialNumber
                    width: parent.width
                    height: 48
                    text: root.number
                    color: host.ink
                    font.pixelSize: 27
                    placeholderText: "Enter number"
                    placeholderTextColor: host.muted
                    horizontalAlignment: TextInput.AlignHCenter
                    selectByMouse: true
                    inputMethodHints: Qt.ImhDialableCharactersOnly
                    background: Rectangle {
                        color: "transparent"
                    }
                    onTextEdited: root.number = text
                }
                Grid {
                    width: parent.width
                    columns: 3
                    columnSpacing: 14
                    rowSpacing: 9
                    Repeater {
                        model: [
                            {
                                n: "1",
                                l: ""
                            },
                            {
                                n: "2",
                                l: "ABC"
                            },
                            {
                                n: "3",
                                l: "DEF"
                            },
                            {
                                n: "4",
                                l: "GHI"
                            },
                            {
                                n: "5",
                                l: "JKL"
                            },
                            {
                                n: "6",
                                l: "MNO"
                            },
                            {
                                n: "7",
                                l: "PQRS"
                            },
                            {
                                n: "8",
                                l: "TUV"
                            },
                            {
                                n: "9",
                                l: "WXYZ"
                            },
                            {
                                n: "*",
                                l: ""
                            },
                            {
                                n: "0",
                                l: "+"
                            },
                            {
                                n: "#",
                                l: ""
                            }
                        ]
                        delegate: AbstractButton {
                            required property var modelData
                            property bool held: false
                            width: (parent.width - 28) / 3
                            height: Math.min(62, Math.max(42, (content.height - 250) / 4))
                            Accessible.name: modelData.n
                            background: Rectangle {
                                radius: 29
                                color: parent.down ? (host.dark ? "#647078" : "#dce3e7") : (host.dark ? "#39444b" : "#f0f3f5")
                            }
                            contentItem: Column {
                                anchors.centerIn: parent
                                spacing: 0
                                Text {
                                    width: parent.width
                                    text: modelData.n
                                    color: host.ink
                                    font.pixelSize: 25
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                Text {
                                    width: parent.width
                                    text: modelData.l
                                    color: host.muted
                                    font.pixelSize: 8
                                    font.letterSpacing: 1
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                            onPressed: held = false
                            onClicked: if (!held)
                                root.number += modelData.n
                            onPressAndHold: if (modelData.n === "0") {
                                held = true;
                                root.number += "+";
                            }
                        }
                    }
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12
                    DialogButton {
                        text: "Copy Number"
                        dark: host.dark
                        enabled: root.number !== ""
                        onClicked: root.copyNumber()
                    }
                    DialogButton {
                        text: "⌫"
                        implicitWidth: 50
                        dark: host.dark
                        enabled: root.number !== ""
                        Accessible.name: "Delete last digit"
                        onClicked: root.number = root.number.slice(0, -1)
                    }
                }
            }
        }
        Item {
            visible: root.page === "Contacts"
            x: 20
            y: 86
            width: parent.width - 40
            height: parent.height - y - 94
            ListView {
                id: contactList
                width: parent.width
                height: parent.height
                model: root.contacts
                spacing: 5
                clip: true
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    width: contactList.width
                    height: 69
                    radius: 11
                    color: root.selectedContact && root.selectedContact.id === modelData.id ? (host.dark ? "#384b45" : "#e6f6ec") : (host.dark ? "#293136" : "#f5f6f7")
                    Rectangle {
                        x: 12
                        y: 11
                        width: 46
                        height: 46
                        radius: 23
                        color: "#7e9aa6"
                        Text {
                            anchors.centerIn: parent
                            text: (row.modelData.name || row.modelData.title || "?").slice(0, 2).toUpperCase()
                            color: "white"
                            font.pixelSize: 19
                            font.weight: Font.DemiBold
                        }
                    }
                    Text {
                        x: 72
                        y: 14
                        width: parent.width - 90
                        text: modelData.name || modelData.title || "No Name"
                        color: host.ink
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        x: 72
                        y: 39
                        width: parent.width - 90
                        text: modelData.phone || modelData.email || "No contact details"
                        color: host.muted
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root.selectedContact = row.modelData;
                            root.number = row.modelData.phone || "";
                            if (!root.video && root.number)
                                root.page = "Keypad";
                        }
                    }
                }
            }
            Column {
                anchors.centerIn: parent
                width: parent.width - 30
                spacing: 16
                visible: !root.contacts.length
                Icon {
                    name: "account"
                    width: 54
                    height: 54
                    color: host.muted
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    width: parent.width
                    text: root.query ? "No Contacts Found" : "Your Contacts"
                    color: host.ink
                    font.pixelSize: 23
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    width: parent.width
                    text: root.query ? "Try another name or number." : "Create a contact in Contacts to find it here."
                    color: host.muted
                    font.pixelSize: 13
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }
                DialogButton {
                    text: "Open Contacts"
                    dark: host.dark
                    anchors.horizontalCenter: parent.horizontalCenter
                    onClicked: host.desktop.openApplication("contacts")
                }
            }
        }
        Column {
            visible: root.page === "Recents"
            anchors.centerIn: parent
            width: parent.width - 70
            spacing: 18
            Image {
                source: Bridge.assetRoot + (root.video ? "facetime.png" : "phone.png")
                width: 76
                height: 76
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: "No Recent Calls"
                color: host.ink
                font.pixelSize: 25
                font.weight: Font.DemiBold
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                text: "Calls will appear here when a calling provider is connected."
                color: host.muted
                font.pixelSize: 13
                width: parent.width
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
        Rectangle {
            x: 20
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 15
            width: parent.width - 40
            height: 67
            radius: 11
            color: host.dark ? "#303a3e" : "#eff4f2"
            Row {
                x: 14
                y: 12
                spacing: 10
                Icon {
                    name: "network"
                    width: 20
                    height: 20
                    color: "#72887e"
                }
                Column {
                    spacing: 5
                    width: content.width - 116
                    Text {
                        text: "No calling provider connected"
                        color: host.ink
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                    Text {
                        width: parent.width
                        text: root.video ? "FaceTime service is not available in this desktop." : "Dialing and calls require a phone service connection."
                        color: host.muted
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
        Text {
            id: feedback
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 87
            color: "#3b9b6a"
            font.pixelSize: 12
        }
    }
}
