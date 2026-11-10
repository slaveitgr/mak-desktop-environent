import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: calendar
    objectName: "recordsCalendar"
    required property var owner
    required property var host
    property date month: new Date(new Date().getFullYear(), new Date().getMonth(), 1)
    property string day: Qt.formatDate(new Date(), "yyyy-MM-dd")
    readonly property int offset: (new Date(month.getFullYear(), month.getMonth(), 1).getDay() + 6) % 7
    readonly property real panelWidth: Math.max(230, Math.min(280, width * 0.36))
    readonly property var dayEvents: owner.filtered.filter(r => r.date === day)
    function focusTitle() {
        eventTitle.forceActiveFocus();
        eventTitle.selectAll();
    }
    function dateForCell(index) {
        return new Date(month.getFullYear(), month.getMonth(), index - offset + 1);
    }
    function selectDate(value) {
        if (!value)
            return;
        day = value;
        let d = new Date(value + "T12:00:00");
        if (!isNaN(d.getTime()))
            month = new Date(d.getFullYear(), d.getMonth(), 1);
    }
    function changeMonth(delta) {
        month = new Date(month.getFullYear(), month.getMonth() + delta, 1);
    }
    function selectDay(value) {
        owner.flush();
        day = value;
        let events = owner.filtered.filter(r => r.date === day);
        owner.select(events.length ? events[0] : null);
    }
    Item {
        id: monthView
        width: parent.width - calendar.panelWidth - 1
        height: parent.height
        Text {
            x: 19
            y: 17
            width: parent.width - 140
            text: Qt.formatDate(calendar.month, "MMMM yyyy")
            font.pixelSize: 24
            font.weight: Font.DemiBold
            color: host.ink
            elide: Text.ElideRight
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 12
            y: 12
            spacing: 2
            ToolButton {
                text: "‹"
                font.pixelSize: 23
                width: 28
                height: 32
                palette.buttonText: host.ink
                Accessible.name: "Previous month"
                onClicked: calendar.changeMonth(-1)
            }
            ToolButton {
                text: "Today"
                font.pixelSize: 12
                width: 48
                height: 32
                palette.buttonText: host.ink
                onClicked: {
                    calendar.selectDate(Qt.formatDate(new Date(), "yyyy-MM-dd"));
                    calendar.selectDay(calendar.day);
                }
            }
            ToolButton {
                text: "›"
                font.pixelSize: 23
                width: 28
                height: 32
                palette.buttonText: host.ink
                Accessible.name: "Next month"
                onClicked: calendar.changeMonth(1)
            }
        }
        Row {
            x: 12
            y: 62
            width: parent.width - 24
            height: 28
            Repeater {
                model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                delegate: Text {
                    required property string modelData
                    width: (monthView.width - 24) / 7
                    height: 28
                    text: modelData
                    color: host.muted
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
        Grid {
            id: monthGrid
            x: 12
            y: 90
            width: parent.width - 24
            height: parent.height - y - 16
            columns: 7
            spacing: 0
            Repeater {
                model: 42
                delegate: Rectangle {
                    id: cell
                    required property int index
                    readonly property date date: calendar.dateForCell(index)
                    readonly property string key: Qt.formatDate(date, "yyyy-MM-dd")
                    readonly property var events: owner.filtered.filter(r => r.date === key)
                    width: monthGrid.width / 7
                    height: monthGrid.height / 6
                    color: calendar.day === key ? (host.dark ? "#343c46" : "#f0f5fc") : "transparent"
                    border.width: 0.5
                    border.color: host.dark ? "#383d43" : "#e8e9ec"
                    Rectangle {
                        width: 25
                        height: 25
                        radius: 13
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 7
                        color: cell.key === Qt.formatDate(new Date(), "yyyy-MM-dd") ? "#ec5147" : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: cell.date.getDate()
                            color: cell.key === Qt.formatDate(new Date(), "yyyy-MM-dd") ? "white" : cell.date.getMonth() === calendar.month.getMonth() ? host.ink : host.muted
                            font.pixelSize: 12
                            opacity: cell.date.getMonth() === calendar.month.getMonth() ? 1 : 0.4
                        }
                    }
                    Column {
                        x: 3
                        y: 36
                        width: parent.width - 6
                        spacing: 3
                        Repeater {
                            model: cell.events.slice(0, Math.max(0, Math.floor((cell.height - 42) / 18)))
                            delegate: Rectangle {
                                required property var modelData
                                width: parent.width
                                height: 16
                                radius: 3
                                color: (modelData.list || "Personal") === "Work" ? (host.dark ? "#344f74" : "#e1ecfc") : (host.dark ? "#604536" : "#fae6d8")
                                Text {
                                    anchors.fill: parent
                                    anchors.leftMargin: 3
                                    text: modelData.title || "New Event"
                                    font.pixelSize: 9
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                    color: host.ink
                                }
                            }
                        }
                    }
                    TapHandler {
                        onTapped: calendar.selectDay(cell.key)
                        onDoubleTapped: {
                            calendar.selectDay(cell.key);
                            owner.newRecord(cell.key);
                        }
                    }
                    Accessible.role: Accessible.Button
                    Accessible.name: Qt.formatDate(date, "dddd, d MMMM yyyy") + ", " + events.length + " events"
                    Accessible.onPressAction: calendar.selectDay(key)
                }
            }
        }
    }
    Rectangle {
        x: monthView.width
        width: 1
        height: parent.height
        color: host.dark ? "#353b40" : "#e6e7e9"
    }
    Item {
        x: monthView.width + 1
        width: calendar.panelWidth
        height: parent.height
        Text {
            x: 16
            y: 17
            width: parent.width - 58
            text: Qt.formatDate(new Date(calendar.day + "T12:00:00"), "ddd, d MMM")
            color: host.ink
            font.pixelSize: 17
            font.weight: Font.DemiBold
        }
        ToolButton {
            anchors.right: parent.right
            anchors.rightMargin: 9
            y: 9
            width: 34
            height: 34
            text: "＋"
            font.pixelSize: 23
            palette.buttonText: owner.accent
            enabled: !owner.trash
            Accessible.name: "New event"
            onClicked: owner.newRecord(calendar.day)
        }
        ListView {
            id: events
            x: 12
            y: 54
            width: parent.width - 24
            height: Math.min(122, Math.max(36, contentHeight))
            clip: true
            spacing: 3
            model: calendar.dayEvents
            delegate: Rectangle {
                required property var modelData
                width: events.width
                height: 47
                radius: 7
                color: owner.selectedId === modelData.id ? host.dark ? "#3a424d" : "#e5edf8" : "transparent"
                Rectangle {
                    x: 5
                    y: 9
                    width: 3
                    height: 29
                    radius: 2
                    color: (modelData.list || "Personal") === "Work" ? "#3f8aee" : "#e88746"
                }
                Text {
                    x: 15
                    y: 6
                    width: parent.width - 20
                    text: modelData.title || "New Event"
                    color: host.ink
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    x: 15
                    y: 25
                    text: modelData.time || "09:00"
                    color: host.muted
                    font.pixelSize: 11
                }
                TapHandler {
                    onTapped: owner.select(modelData)
                }
                Accessible.role: Accessible.ListItem
                Accessible.name: (modelData.title || "New Event") + ", " + modelData.time
                Accessible.onPressAction: owner.select(modelData)
            }
            Text {
                visible: events.count === 0
                anchors.centerIn: parent
                text: "No events"
                color: host.muted
                font.pixelSize: 12
            }
        }
        Flickable {
            id: eventForm
            x: 16
            y: events.y + events.height + 16
            width: parent.width - 32
            height: parent.height - y - 14
            contentHeight: fields.implicitHeight
            clip: true
            visible: owner.selectedId !== ""
            ScrollBar.vertical: ScrollBar {
                width: 5
            }
            Column {
                id: fields
                width: parent.width
                spacing: 10
                RecordsField {
                    id: eventTitle
                    objectName: "eventTitle"
                    width: parent.width
                    dark: host.dark
                    text: owner.draft.title || ""
                    placeholderText: "Event title"
                    readOnly: owner.trash
                    Accessible.name: "Event title"
                    onTextEdited: owner.setField("title", text)
                    onActiveFocusChanged: if (activeFocus)
                        owner.editTarget = eventTitle
                }
                Text {
                    text: "Date"
                    color: host.muted
                    font.pixelSize: 11
                }
                RecordsField {
                    id: eventDate
                    width: parent.width
                    dark: host.dark
                    text: owner.draft.date || ""
                    placeholderText: "YYYY-MM-DD"
                    readOnly: owner.trash
                    Accessible.name: "Event date"
                    validator: RegularExpressionValidator {
                        regularExpression: /\d{4}-\d{2}-\d{2}/
                    }
                    onTextEdited: if (owner.validDate(text)) {
                        owner.setField("date", text);
                        calendar.selectDate(text);
                    }
                    onEditingFinished: if (!owner.validDate(text))
                        text = owner.draft.date || ""
                    onActiveFocusChanged: if (activeFocus)
                        owner.editTarget = eventDate
                }
                Text {
                    text: "Time"
                    color: host.muted
                    font.pixelSize: 11
                }
                RecordsField {
                    id: eventTime
                    width: parent.width
                    dark: host.dark
                    text: owner.draft.time || "09:00"
                    placeholderText: "HH:mm"
                    readOnly: owner.trash
                    Accessible.name: "Event time"
                    validator: RegularExpressionValidator {
                        regularExpression: /([01]\d|2[0-3]):[0-5]\d/
                    }
                    onTextEdited: if (acceptableInput)
                        owner.setField("time", text)
                    onEditingFinished: if (!acceptableInput)
                        text = owner.draft.time || "09:00"
                    onActiveFocusChanged: if (activeFocus)
                        owner.editTarget = eventTime
                }
                Text {
                    text: "Calendar"
                    color: host.muted
                    font.pixelSize: 11
                }
                ComboBox {
                    width: parent.width
                    height: 32
                    model: ["Personal", "Work"]
                    currentIndex: owner.draft.list === "Work" ? 1 : 0
                    enabled: !owner.trash
                    palette.button: host.dark ? "#32383d" : "#f1f2f4"
                    palette.buttonText: host.ink
                    onActivated: owner.setField("list", currentText)
                    Accessible.name: "Calendar"
                }
                TextArea {
                    id: eventNotes
                    width: parent.width
                    height: 110
                    text: owner.draft.body || ""
                    placeholderText: "Add notes or location…"
                    font.pixelSize: 13
                    color: host.ink
                    placeholderTextColor: host.muted
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    readOnly: owner.trash
                    background: Rectangle {
                        radius: 8
                        color: host.dark ? "#272c31" : "#f4f5f6"
                    }
                    onTextChanged: if (text !== (owner.draft.body || ""))
                        owner.setField("body", text)
                    onActiveFocusChanged: if (activeFocus)
                        owner.editTarget = eventNotes
                    Accessible.name: "Event notes"
                }
                DialogButton {
                    text: owner.trash ? "Restore Event" : "Delete Event"
                    dark: host.dark
                    onClicked: owner.removeSelected()
                }
                Text {
                    text: owner.dirty ? "Saving…" : "Saved locally"
                    color: host.muted
                    font.pixelSize: 10
                }
            }
        }
    }
}
