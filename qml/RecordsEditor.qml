import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: editor
    objectName: "recordsEditor"
    required property var owner
    required property var host
    readonly property string kind: owner.kind
    readonly property bool selected: owner.selectedId.length > 0
    readonly property bool dark: host.dark
    readonly property color ink: host.ink
    readonly property color muted: host.muted
    function focusTitle() {
        titleField.forceActiveFocus();
        titleField.selectAll();
    }
    function today() {
        return Qt.formatDate(new Date(), "yyyy-MM-dd");
    }
    Item {
        anchors.fill: parent
        visible: editor.selected
        Row {
            x: 14
            y: 8
            spacing: 3
            ToolButton {
                width: 32
                height: 32
                contentItem: Icon {
                    name: "trash"
                    color: editor.muted
                }
                visible: !owner.trash
                Accessible.name: "Move to Recently Deleted"
                onClicked: owner.removeSelected()
                ToolTip.visible: hovered
                ToolTip.text: Accessible.name
            }
            ToolButton {
                visible: editor.kind === "notes" || editor.kind === "contacts"
                width: 32
                height: 32
                contentItem: Icon {name: editor.kind === "notes" ? "pin" : owner.draft.favorite ? "starfill" : "star";color:(editor.kind === "notes" ? owner.draft.pinned : owner.draft.favorite) ? owner.accent : editor.muted}
                font.pixelSize: 21
                palette.buttonText: (editor.kind === "notes" ? owner.draft.pinned : owner.draft.favorite) ? owner.accent : editor.muted
                enabled: !owner.trash
                Accessible.name: editor.kind === "notes" ? (owner.draft.pinned ? "Unpin note" : "Pin note") : (owner.draft.favorite ? "Remove from favorites" : "Add to favorites")
                onClicked: {
                    owner.setField(editor.kind === "notes" ? "pinned" : "favorite", !(editor.kind === "notes" ? owner.draft.pinned : owner.draft.favorite));
                    owner.flush();
                }
                ToolTip.visible: hovered
                ToolTip.text: Accessible.name
            }
        }
        DialogButton {
            visible: owner.trash
            x: 16
            y: 10
            text: "Restore"
            dark: editor.dark
            onClicked: owner.removeSelected()
        }
        ToolButton {
            visible: editor.kind === "mail" && !owner.trash
            anchors.right: parent.right
            anchors.rightMargin: 12
            y: 8
            width: 34
            height: 32
            contentItem: Icon {
                name: "share"
                color: editor.muted
            }
            Accessible.name: "Export draft as EML"
            ToolTip.visible: hovered
            ToolTip.text: Accessible.name
            onClicked: {
                owner.flush();
                let path = owner.service.exportMail(owner.selectedId);
                if (path)
                    host.desktop.showInfo("Draft exported", "Saved to:\n" + path);
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 17
            width: Math.max(10, parent.width - 150)
            text: owner.trash ? "Recently Deleted" : owner.isCorrespondence ? "Draft · Not sent" : owner.draft.modified ? Qt.formatDateTime(new Date(owner.draft.modified), "d MMMM yyyy, HH:mm") : "Just now"
            color: editor.muted
            font.pixelSize: 10
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }
        Flickable {
            id: form
            x: 24
            y: 52
            width: parent.width - 48
            height: parent.height - y - 32
            contentWidth: width
            contentHeight: Math.max(height, formColumn.implicitHeight + 16)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                width: 5
                policy: host.desktop.alwaysShowScrollbars ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
            }
            Column {
                id: formColumn
                width: form.width
                spacing: 12
                Rectangle {
                    visible: editor.kind === "contacts"
                    height: visible ? 72 : 0
                    width: 72
                    radius: 36
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: editor.dark ? "#596470" : "#a4afba"
                    Text {
                        anchors.centerIn: parent
                        text: (owner.draft.title || "?").split(" ").filter(s => s.length).map(s => s.charAt(0)).slice(0, 2).join("").toUpperCase()
                        color: "white"
                        font.pixelSize: 28
                        font.weight: Font.Medium
                    }
                }
                RecordsField {
                    id: recipient
                    visible: editor.kind === "mail" || editor.kind === "messages"
                    width: parent.width
                    height: visible ? 34 : 0
                    dark: editor.dark
                    placeholderText: editor.kind === "mail" ? "To: email address" : "To: name, phone or email"
                    text: owner.draft.recipient || ""
                    readOnly: owner.trash
                    Accessible.name: editor.kind === "mail" ? "Mail recipient" : "Message recipient"
                    onTextEdited: owner.setField("recipient", text)
                    onActiveFocusChanged: if (activeFocus)
                        owner.editTarget = recipient
                }
                TextField {
                    id: titleField
                    objectName: "recordTitle"
                    width: parent.width
                    height: editor.kind === "contacts" ? 42 : 38
                    text: owner.draft.title || ""
                    placeholderText: editor.kind === "contacts" ? "Name" : editor.kind === "mail" ? "Subject" : editor.kind === "messages" ? "Conversation name" : "Title"
                    color: editor.ink
                    placeholderTextColor: editor.muted
                    selectionColor: "#438dd7"
                    selectedTextColor: "white"
                    font.pixelSize: editor.kind === "notes" || editor.kind === "contacts" ? 23 : 20
                    font.weight: Font.DemiBold
                    horizontalAlignment: editor.kind === "contacts" ? Text.AlignHCenter : Text.AlignLeft
                    leftPadding: 0
                    rightPadding: 0
                    selectByMouse: true
                    readOnly: owner.trash
                    background: Rectangle {
                        color: "transparent"
                    }
                    Accessible.name: editor.kind === "contacts" ? "Contact name" : editor.kind === "mail" ? "Subject" : "Title"
                    onTextEdited: owner.setField("title", text)
                    onActiveFocusChanged: if (activeFocus)
                        owner.editTarget = titleField
                }
                Column {
                    visible: editor.kind === "contacts"
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: [
                            {
                                key: "email",
                                title: "Email"
                            },
                            {
                                key: "phone",
                                title: "Phone"
                            },
                            {
                                key: "company",
                                title: "Company"
                            },
                            {
                                key: "address",
                                title: "Address"
                            }
                        ]
                        delegate: Column {
                            required property var modelData
                            width: parent.width
                            spacing: 5
                            Text {
                                text: modelData.title
                                color: editor.muted
                                font.pixelSize: 11
                            }
                            RecordsField {
                                id: contactField
                                width: parent.width
                                dark: editor.dark
                                text: owner.draft[modelData.key] || ""
                                placeholderText: modelData.title
                                readOnly: owner.trash
                                Accessible.name: modelData.title
                                onTextEdited: owner.setField(modelData.key, text)
                                onActiveFocusChanged: if (activeFocus)
                                    owner.editTarget = contactField
                            }
                        }
                    }
                }
                Column {
                    visible: editor.kind === "reminders"
                    width: parent.width
                    spacing: 8
                    CheckBox {
                        text: "Completed"
                        checked: !!owner.draft.done
                        enabled: !owner.trash
                        palette.windowText: editor.ink
                        onClicked: {
                            owner.setField("done", checked);
                            owner.flush();
                        }
                    }
                    Text {
                        text: "Due date"
                        color: editor.muted
                        font.pixelSize: 11
                    }
                    Row {
                        width: parent.width
                        spacing: 8
                        RecordsField {
                            id: dueField
                            width: Math.max(90, parent.width - 86)
                            dark: editor.dark
                            placeholderText: "YYYY-MM-DD"
                            text: owner.draft.date || ""
                            readOnly: owner.trash
                            Accessible.name: "Reminder due date"
                            validator: RegularExpressionValidator {
                                regularExpression: /\d{4}-\d{2}-\d{2}/
                            }
                            onTextEdited: if (text === "" || owner.validDate(text))
                                owner.setField("date", text)
                            onEditingFinished: if (text !== "" && !owner.validDate(text))
                                text = owner.draft.date || ""
                            onActiveFocusChanged: if (activeFocus)
                                owner.editTarget = dueField
                        }
                        DialogButton {
                            text: "Today"
                            implicitWidth: 78
                            dark: editor.dark
                            enabled: !owner.trash
                            onClicked: owner.setField("date", editor.today())
                        }
                    }
                    Text {
                        text: "Priority"
                        color: editor.muted
                        font.pixelSize: 11
                    }
                    ComboBox {
                        width: parent.width
                        height: 32
                        model: ["None", "Low", "Medium", "High"]
                        currentIndex: Math.max(0, model.indexOf(owner.draft.priority || "None"))
                        enabled: !owner.trash
                        palette.button: editor.dark ? "#32383d" : "#f1f2f4"
                        palette.buttonText: editor.ink
                        onActivated: owner.setField("priority", currentText)
                        Accessible.name: "Reminder priority"
                    }
                }
                Text {
                    visible: owner.isCorrespondence
                    width: parent.width
                    text: editor.kind === "mail" ? "This draft is stored locally. Sending and receiving need a mail account connection." : "This is an unsent message draft. No iMessage or other messaging service is connected."
                    color: editor.muted
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                    lineHeight: 1.15
                }
                Text {
                    visible: editor.kind === "contacts" || editor.kind === "reminders"
                    text: "Notes"
                    color: editor.muted
                    font.pixelSize: 11
                }
                TextArea {
                    id: bodyField
                    objectName: "recordBody"
                    width: parent.width
                    height: Math.max(editor.kind === "notes" ? form.height - 90 : editor.kind === "contacts" ? 100 : 180, contentHeight + 12)
                    text: owner.draft.body || ""
                    placeholderText: editor.kind === "notes" ? "Start writing…" : editor.kind === "mail" ? "Write your message…" : editor.kind === "messages" ? "Write a message draft…" : "Add notes…"
                    color: editor.ink
                    placeholderTextColor: editor.muted
                    selectionColor: "#438dd7"
                    selectedTextColor: "white"
                    font.pixelSize: 14
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    readOnly: owner.trash
                    leftPadding: editor.kind === "messages" ? 14 : 0
                    rightPadding: editor.kind === "messages" ? 14 : 0
                    topPadding: editor.kind === "messages" ? 12 : 4
                    background: Rectangle {
                        color: editor.kind === "messages" ? editor.dark ? "#293d53" : "#e9f2ff" : "transparent"
                        radius: 16
                    }
                    Accessible.name: editor.kind === "notes" ? "Note body" : owner.isCorrespondence ? "Message draft" : "Notes"
                    onTextChanged: if (text !== (owner.draft.body || ""))
                        owner.setField("body", text)
                    onActiveFocusChanged: if (activeFocus)
                        owner.editTarget = bodyField
                    onCursorRectangleChanged: {
                        if (!activeFocus)
                            return;
                        let cursorY = y + cursorRectangle.y;
                        if (cursorY - form.contentY > form.height - 32)
                            form.contentY = Math.min(form.contentHeight - form.height, cursorY - form.height + 40);
                        else if (cursorY < form.contentY)
                            form.contentY = cursorY;
                    }
                }
            }
        }
        Text {
            x: 24
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            text: owner.trash ? "Restore this item to edit it." : owner.dirty ? "Saving…" : "Saved locally"
            color: editor.muted
            font.pixelSize: 10
        }
    }
    Column {
        visible: !editor.selected
        anchors.centerIn: parent
        width: Math.max(100, parent.width - 60)
        spacing: 14
        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 48
            height: 48
            name: editor.kind === "contacts" ? "account" : editor.kind === "reminders" ? "check" : "document"
            color: editor.muted
        }
        Text {
            width: parent.width
            text: owner.trash ? "Recently Deleted" : editor.kind === "notes" ? "Your ideas, all together" : editor.kind === "contacts" ? "Your contacts" : editor.kind === "reminders" ? "A little more organized" : "Your drafts"
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 20
            font.weight: Font.DemiBold
            color: editor.ink
            wrapMode: Text.Wrap
        }
        Text {
            width: parent.width
            text: owner.trash ? "Deleted items can be restored here." : "Choose an item or create a new one."
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 13
            color: editor.muted
            wrapMode: Text.Wrap
        }
        DialogButton {
            visible: !owner.trash
            anchors.horizontalCenter: parent.horizontalCenter
            text: editor.kind === "contacts" ? "New Contact" : editor.kind === "notes" ? "New Note" : editor.kind === "reminders" ? "New Reminder" : "New Draft"
            dark: editor.dark
            onClicked: owner.newRecord()
        }
    }
}
