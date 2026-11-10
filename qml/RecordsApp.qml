import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    objectName: "recordsApp"
    required property var host
    readonly property string kind: host.appKind
    readonly property var service: Bridge.suite
    readonly property bool dark: host.dark
    readonly property color ink: host.ink
    readonly property color muted: host.muted
    readonly property color accent: kind === "notes" ? "#dba824" : kind === "reminders" ? "#2084ef" : kind === "calendar" ? "#ed5349" : "#2787ed"
    property var rows: []
    property string query: ""
    property string category: "all"
    property string selectedId: ""
    property var draft: ({})
    property bool dirty: false
    property bool saving: false
    property bool loading: false
    property var editTarget: null
    property string undoDeletedId: ""
    property bool undoWasDeleted: false
    readonly property bool trash: category === "deleted"
    readonly property bool isCorrespondence: kind === "mail" || kind === "messages"
    readonly property var categories: kind === "notes" ? [
        {
            id: "all",
            name: "Notes",
            icon: "document"
        },
        {
            id: "pinned",
            name: "Pinned",
            icon: "tag"
        },
        {
            id: "deleted",
            name: "Recently Deleted",
            icon: "trash"
        }
    ] : kind === "reminders" ? [
        {
            id: "all",
            name: "All",
            icon: "list"
        },
        {
            id: "today",
            name: "Today",
            icon: "clock"
        },
        {
            id: "scheduled",
            name: "Scheduled",
            icon: "calendar"
        },
        {
            id: "completed",
            name: "Completed",
            icon: "check"
        },
        {
            id: "deleted",
            name: "Recently Deleted",
            icon: "trash"
        }
    ] : kind === "calendar" ? [
        {
            id: "all",
            name: "All Calendars",
            icon: "calendar"
        },
        {
            id: "Personal",
            name: "Personal",
            icon: "clock"
        },
        {
            id: "Work",
            name: "Work",
            icon: "document"
        },
        {
            id: "deleted",
            name: "Recently Deleted",
            icon: "trash"
        }
    ] : kind === "contacts" ? [
        {
            id: "all",
            name: "All Contacts",
            icon: "account"
        },
        {
            id: "favorites",
            name: "Favorites",
            icon: "tag"
        },
        {
            id: "deleted",
            name: "Recently Deleted",
            icon: "trash"
        }
    ] : [
        {
            id: "all",
            name: kind === "mail" ? "Drafts" : "Draft Conversations",
            icon: kind === "mail" ? "document" : "shared"
        },
        {
            id: "deleted",
            name: "Recently Deleted",
            icon: "trash"
        }
    ]
    readonly property var filtered: {
        let term = query.trim().toLowerCase();
        return rows.filter(function (r) {
            if (category === "pinned" && !r.pinned)
                return false;
            if (category === "favorites" && !r.favorite)
                return false;
            if (kind === "reminders") {
                if (category === "completed" && !r.done)
                    return false;
                if (category !== "completed" && category !== "deleted" && r.done)
                    return false;
                if (category === "today" && r.date !== dateKey(new Date()))
                    return false;
                if (category === "scheduled" && !r.date)
                    return false;
            }
            if (kind === "calendar" && ["Personal", "Work"].indexOf(category) >= 0 && (r.list || "Personal") !== category)
                return false;
            return !term || [r.title, r.body, r.recipient, r.email, r.phone, r.company, r.date].join(" ").toLowerCase().indexOf(term) >= 0;
        }).sort(function (a, b) {
            if (kind === "contacts")
                return (a.title || "").localeCompare(b.title || "");
            if (kind === "calendar")
                return ((a.date || "") + (a.time || "")).localeCompare((b.date || "") + (b.time || ""));
            return (b.pinned ? 1 : 0) - (a.pinned ? 1 : 0);
        });
    }
    function dateKey(date) {
        return Qt.formatDate(date, "yyyy-MM-dd");
    }
    function validDate(value) {
        if (!/^\d{4}-\d{2}-\d{2}$/.test(value))
            return false;
        let date = new Date(value + "T12:00:00");
        return !isNaN(date.getTime()) && dateKey(date) === value;
    }
    function refresh() {
        rows = service.records(kind, trash);
    }
    function setField(field, value) {
        if (loading || !selectedId || trash || draft[field] === value)
            return;
        let copy = Object.assign({}, draft);
        copy[field] = value;
        draft = copy;
        dirty = true;
        saveTimer.restart();
    }
    function flush() {
        saveTimer.stop();
        if (!dirty || !selectedId || saving)
            return;
        // Invalid event edits stay in the editor instead of replacing valid stored data.
        if (kind === "calendar" && (!/^\d{4}-\d{2}-\d{2}$/.test(draft.date || "") || !/^([01]\d|2[0-3]):[0-5]\d$/.test(draft.time || "")))
            return;
        saving = true;
        let saved = service.save(kind, selectedId, draft);
        if (saved)
            dirty = false;
        saving = false;
    }
    function select(record) {
        if (record && selectedId === record.id)
            return;
        flush();
        loading = true;
        selectedId = record ? record.id : "";
        draft = record ? Object.assign({}, record) : {};
        dirty = false;
        loading = false;
        if (kind === "calendar" && record && calendar.item)
            calendar.item.selectDate(record.date);
    }
    function chooseCategory(id) {
        flush();
        category = id;
        refresh();
        select(filtered.length ? filtered[0] : null);
    }
    function newRecord(date) {
        flush();
        query = "";
        search.text = "";
        if (trash || category === "completed" || category === "favorites" || category === "pinned")
            category = "all";
        let fields = {
            title: kind === "notes" ? "New Note" : kind === "contacts" ? "New Contact" : kind === "calendar" ? "New Event" : kind === "reminders" ? "New Reminder" : "",
            body: "",
            done: false,
            pinned: false,
            favorite: false,
            recipient: "",
            email: "",
            phone: "",
            company: "",
            address: "",
            date: kind === "calendar" ? (date || dateKey(new Date())) : kind === "reminders" && (category === "today" || category === "scheduled") ? dateKey(new Date()) : "",
            time: "09:00",
            list: category === "Work" ? "Work" : "Personal",
            priority: "None"
        };
        let id = service.save(kind, "", fields);
        if (!id)
            return;
        fields.id = id;
        select(fields);
        refresh();
        if (calendar.item)
            calendar.item.selectDate(fields.date);
        Qt.callLater(function () {
            if (kind === "calendar" && calendar.item)
                calendar.item.focusTitle();
            else if (editor.item && editor.item.focusTitle)
                editor.item.focusTitle();
        });
    }
    function removeSelected() {
        if (!selectedId)
            return;
        flush();
        let id = selectedId;
        undoDeletedId = id;
        undoWasDeleted = trash;
        service.setDeleted(id, !trash);
        selectedId = "";
        refresh();
        select(filtered.length ? filtered[0] : null);
    }
    function toggleComplete(record) {
        if (record.id === selectedId) {
            setField("done", !draft.done);
            flush();
        } else {
            let changed = Object.assign({}, record);
            changed.done = !record.done;
            service.save(kind, record.id, changed);
        }
    }
    function command(name) {
        if (name.indexOf("category:") === 0) {
            let id = name.slice(9);
            if (categories.some(item => item.id === id))
                chooseCategory(id);
            return;
        }
        if (name === "find") {
            search.forceActiveFocus();
            search.selectAll();
            return;
        }
        if (kind === "calendar" && calendar.item && ["today", "previous", "next"].indexOf(name) >= 0) {
            if (name === "today") {
                let today = dateKey(new Date());
                calendar.item.selectDate(today);
                calendar.item.selectDay(today);
            } else
                calendar.item.changeMonth(name === "previous" ? -1 : 1);
            return;
        }
        if (name === "toggleCompleted" && kind === "reminders") {
            chooseCategory(category === "completed" ? "all" : "completed");
            return;
        }
        if (name === "edit" && editor.item) {
            editor.item.focusTitle();
            return;
        }
        if (selectedId && !trash) {
            if (name === "pin" && kind === "notes") {
                setField("pinned", !draft.pinned);
                flush();
                return;
            }
            if (name === "favorite" && kind === "contacts") {
                setField("favorite", !draft.favorite);
                flush();
                return;
            }
            if (name === "complete" && kind === "reminders") {
                setField("done", !draft.done);
                flush();
                return;
            }
            if (name === "export" && kind === "mail") {
                flush();
                let path = service.exportMail(selectedId);
                if (path)
                    host.desktop.showInfo("Draft exported", "Saved to:\n" + path);
                return;
            }
        }
        if (name === "new") {
            newRecord(kind === "calendar" && calendar.item ? calendar.item.day : undefined);
            return;
        }
        if (name === "undo" && undoDeletedId) {
            service.setDeleted(undoDeletedId, undoWasDeleted);
            undoDeletedId = "";
            refresh();
            return;
        }
        if (name === "delete") {
            removeSelected();
            return;
        }
        if (editTarget && typeof editTarget[name] === "function")
            editTarget[name]();
    }
    Component.onCompleted: {
        refresh();
        if (filtered.length)
            select(filtered[0]);
    }
    Shortcut {
        sequence: "Ctrl+F"
        enabled: host.active
        onActivated: {
            search.forceActiveFocus();
            search.selectAll();
        }
    }
    Timer {
        id: saveTimer
        interval: 450
        onTriggered: root.flush()
    }
    Connections {
        target: root.service
        function onChanged() {
            root.refresh();
        }
    }

    Item {
        id: sidebar
        width: 222
        height: parent.height
        RecordsField {
            id: search
            objectName: "recordSearch"
            x: 17
            y: 8
            width: 188
            height: 30
            dark: root.dark
            placeholderText: "Search"
            leftPadding: 29
            Accessible.name: "Search " + host.windowTitle
            onTextEdited: root.query = text
            onActiveFocusChanged: if (activeFocus)
                root.editTarget = search
            Icon {
                x: 9
                y: 8
                width: 14
                height: 14
                name: "search"
                color: root.muted
            }
        }
        Text {
            x: 24
            y: 55
            text: root.isCorrespondence ? "On My Desktop" : root.kind === "calendar" ? "Calendars" : "On My Desktop"
            color: root.muted
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }
        Column {
            x: 10
            y: 79
            width: 202
            spacing: 4
            Repeater {
                model: root.categories
                delegate: Rectangle {
                    required property var modelData
                    width: parent.width
                    height: 35
                    radius: 9
                    color: root.category === modelData.id ? (root.dark ? "#495158" : "#dce2e8") : navHover.hovered ? (root.dark ? "#22ffffff" : "#0c000000") : "transparent"
                    Icon {
                        x: 10
                        y: 9
                        width: 18
                        height: 18
                        name: modelData.icon
                        color: root.accent
                    }
                    Text {
                        x: 37
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name
                        font.pixelSize: 13
                        color: root.ink
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 11
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.category === modelData.id
                        text: root.filtered.length
                        color: root.muted
                        font.pixelSize: 12
                    }
                    HoverHandler {
                        id: navHover
                    }
                    TapHandler {
                        onTapped: root.chooseCategory(modelData.id)
                    }
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.name
                    Accessible.onPressAction: root.chooseCategory(modelData.id)
                }
            }
        }
        Column {
            x: 24
            width: 174
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 24
            spacing: 8
            Text {
                width: parent.width
                text: root.isCorrespondence ? "Local drafts" : "Saved on this desktop"
                color: root.muted
                font.pixelSize: 12
                font.weight: Font.Medium
            }
            Text {
                width: parent.width
                text: root.kind === "mail" ? "Add an account connection to receive or send mail." : root.kind === "messages" ? "No messaging account is connected. Drafts stay on this desktop." : root.kind === "calendar" ? "Events are stored locally. Cloud calendars are not connected." : "Your changes are saved automatically."
                color: root.muted
                font.pixelSize: 11
                wrapMode: Text.Wrap
                lineHeight: 1.2
            }
        }
    }

    Rectangle {
        x: 222
        y: 0
        width: parent.width - x
        height: parent.height - 8
        radius: 14
        color: root.dark ? "#1e2225" : "#ffffff"
        border.color: root.dark ? "#343a3f" : "#e3e5e8"
        clip: true
        Loader {
            id: calendar
            active: root.kind === "calendar"
            anchors.fill: parent
            sourceComponent: Component {
                RecordsCalendar {
                    owner: root
                    host: root.host
                }
            }
        }
        Item {
            id: regular
            visible: root.kind !== "calendar"
            anchors.fill: parent
            readonly property real listWidth: Math.max(188, Math.min(root.kind === "mail" ? 285 : 245, width * 0.36))
            Rectangle {
                x: regular.listWidth
                width: 1
                height: parent.height
                color: root.dark ? "#353b40" : "#e6e7e9"
            }
            Text {
                x: 18
                y: 16
                width: regular.listWidth - 68
                text: root.categories.find(r => r.id === root.category).name
                color: root.ink
                font.pixelSize: 18
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            ToolButton {
                x: regular.listWidth - 44
                y: 8
                width: 36
                height: 36
                contentItem: Icon {
                    name: root.kind === "notes" || root.isCorrespondence ? "compose" : "plus"
                    color: root.accent
                }
                font.pixelSize: 24
                palette.buttonText: root.accent
                enabled: !root.trash
                Accessible.name: "New " + (root.kind === "contacts" ? "contact" : root.kind === "notes" ? "note" : root.kind === "reminders" ? "reminder" : "draft")
                onClicked: root.newRecord()
                ToolTip.visible: hovered
                ToolTip.text: Accessible.name
            }
            ListView {
                id: recordList
                x: 8
                y: 52
                width: regular.listWidth - 16
                height: parent.height - y - 10
                clip: true
                spacing: 3
                model: root.filtered
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {
                    width: 5
                    policy: host.desktop.alwaysShowScrollbars ? ScrollBar.AlwaysOn : ScrollBar.AsNeeded
                }
                delegate: Rectangle {
                    id: record
                    required property var modelData
                    width: recordList.width
                    height: root.kind === "contacts" ? 62 : root.kind === "reminders" ? 78 : 82
                    radius: 10
                    readonly property bool chosen: root.selectedId === modelData.id
                    color: chosen ? (root.kind === "notes" ? (root.dark ? "#6f5b23" : "#f9e8ad") : root.dark ? "#244867" : "#e0edfc") : rowHover.hovered ? (root.dark ? "#2b3035" : "#f5f6f8") : "transparent"
                    CheckBox {
                        id: completion
                        visible: root.kind === "reminders"
                        x: 5
                        y: 18
                        width: 30
                        height: 30
                        checked: !!record.modelData.done
                        enabled: !root.trash
                        Accessible.name: "Complete " + (record.modelData.title || "reminder")
                        onClicked: root.toggleComplete(record.modelData)
                        indicator: Rectangle {
                            x: 7
                            y: 7
                            width: 18
                            height: 18
                            radius: 9
                            color: completion.checked ? root.accent : "transparent"
                            border.width: 1.5
                            border.color: completion.checked ? root.accent : root.muted
                            Text {
                                anchors.centerIn: parent
                                text: completion.checked ? "✓" : ""
                                color: "white"
                                font.pixelSize: 13
                            }
                        }
                    }
                    Rectangle {
                        visible: root.kind === "contacts" || root.kind === "messages"
                        x: 10
                        y: 15
                        width: 32
                        height: 32
                        radius: 16
                        color: root.dark ? "#56606a" : "#bec5cd"
                        Text {
                            anchors.centerIn: parent
                            text: (record.modelData.title || record.modelData.recipient || "?").slice(0, 2).toUpperCase()
                            color: "white"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }
                    Column {
                        x: root.kind === "reminders" ? 38 : root.kind === "contacts" || root.kind === "messages" ? 52 : 13
                        y: 13
                        width: parent.width - x - 13
                        spacing: 5
                        Text {
                            width: parent.width
                            text: record.modelData.title || record.modelData.recipient || "Untitled Draft"
                            color: root.ink
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            font.strikeout: root.kind === "reminders" && !!record.modelData.done
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: root.kind === "contacts" ? record.modelData.company || record.modelData.email || record.modelData.phone || "No contact details" : root.kind === "reminders" ? record.modelData.date ? "Due " + record.modelData.date : record.modelData.body || "No date" : root.kind === "mail" ? record.modelData.recipient || "No recipient" : record.modelData.body || "No additional text"
                            color: root.muted
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                        Text {
                            visible: root.kind !== "contacts" && root.kind !== "reminders"
                            width: parent.width
                            text: root.isCorrespondence ? "Draft · Not sent" : record.modelData.pinned ? "Pinned" : record.modelData.modified ? Qt.formatDateTime(new Date(record.modelData.modified), "d MMM, HH:mm") : "Just now"
                            color: root.muted
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }
                    HoverHandler {
                        id: rowHover
                    }
                    TapHandler {
                        onTapped: root.select(record.modelData)
                    }
                    Accessible.role: Accessible.ListItem
                    Accessible.name: (modelData.title || modelData.recipient || "Untitled Draft") + (root.isCorrespondence ? ", unsent draft" : "")
                    Accessible.onPressAction: root.select(modelData)
                }
                Text {
                    anchors.centerIn: parent
                    width: parent.width - 20
                    visible: recordList.count === 0
                    text: root.query ? "No results" : root.trash ? "No recently deleted items" : root.kind === "reminders" && root.category === "completed" ? "No completed reminders" : "No items yet"
                    horizontalAlignment: Text.AlignHCenter
                    color: root.muted
                    font.pixelSize: 13
                    wrapMode: Text.Wrap
                }
            }
            Loader {
                id: editor
                active: root.kind !== "calendar"
                x: regular.listWidth + 1
                width: parent.width - x
                height: parent.height
                sourceComponent: Component {
                    RecordsEditor {
                        owner: root
                        host: root.host
                    }
                }
            }
        }
    }
}
