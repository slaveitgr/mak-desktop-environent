import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Column {
    id: details
    required property var host
    readonly property string page: host.page
    readonly property bool dark: host.dark
    readonly property color ink: host.ink
    readonly property color muted: host.muted
    readonly property var suite: Bridge.suite
    property int revision: suite.revision
    property var disk: suite.storage()
    spacing: 14
    function pref(key, fallback) {
        let current = revision;
        if (Bridge.ddeAudio.available) {
            if (key === "sound.volume") return String(Bridge.ddeAudio.volume);
            if (key === "sound.muted") return String(Bridge.ddeAudio.muted);
        }
        return suite.preference(key, fallback);
    }
    function save(key, value) {
        if (Bridge.ddeAudio.available) {
            if (key === "sound.volume") { Bridge.ddeAudio.setVolume(Number(value)); return; }
            if (key === "sound.muted") { Bridge.ddeAudio.setMuted(String(value) === "true"); return; }
        }
        let defaults = {
            "sound.volume": "0.75",
            "sound.muted": "false",
            "camera.allowed": "true",
            "clock.24hour": "true"
        };
        let text = String(value);
        if (suite.preference(key, defaults[key] || "") !== text)
            suite.setPreference(key, text);
    }
    function size(bytes) {
        return (bytes / 1000000000).toFixed(1) + " GB";
    }
    function row(name, value, detail) {
        return {
            name: name,
            value: value || "",
            detail: detail || ""
        };
    }
    function group(title, rows) {
        return {
            title: title,
            rows: rows
        };
    }
    function specification() {
        switch (page) {
        case "Apple Account":
            return {
                icon: "account",
                color: "#1689ec",
                subtitle: "Sign in to use iCloud and Apple services.",
                notice: "Apple Account sign-in is not connected to this desktop.",
                groups: [group("Apple Account", [row("Sign In", "Not connected"), row("Personal Information", "Requires an account"), row("Sign-In & Security", "Requires an account"), row("Payment & Shipping", "Requires an account")]), group("Services", [row("iCloud", "Not connected"), row("Media & Purchases", "Not connected"), row("Family", "Not connected")])]
            };
        case "Family":
            return {
                icon: "shared",
                color: "#1689ec",
                subtitle: "Manage family members and shared subscriptions.",
                notice: "Family Sharing requires a connected Apple Account.",
                groups: [group("Family Sharing", [row("Family Members", "No connected account"), row("Purchase Sharing", "Unavailable"), row("Subscriptions", "Unavailable"), row("Location Sharing", "Unavailable"), row("Screen Time", "Unavailable")])]
            };
        case "Software Update":
            return {
                icon: "settings",
                color: "#82878c",
                subtitle: "Keep your desktop up to date.",
                groups: [group("Installed Version", [row("Tahoe Desktop", "Prototype 0.4"), row("Update Channel", "Local development"), row("Automatic Updates", "Not connected", "Updates are applied when a new prototype build is installed.")]), group("System Software", [row("Operating System Updates", "Managed by your system", "Open system settings to check for updates to the operating system.")])]
            };
        case "Wi-Fi":
            return {
                icon: "wifi",
                color: "#1689ec",
                subtitle: "Connect to the internet and nearby wireless networks.",
                notice: "Wireless status and network changes need the operating system’s network service.",
                groups: [group("Wi-Fi", [row("Wi-Fi", "System managed"), row("Current Network", "Not available to this desktop"), row("Other Networks", "Not scanned")]), group("Options", [row("Known Networks", "System managed"), row("Ask to Join Networks", "System managed"), row("Ask to Join Hotspots", "System managed")])]
            };
        case "Bluetooth":
            return {
                icon: "bluetooth",
                color: "#1689ec",
                subtitle: "Connect wireless accessories to your computer.",
                notice: "Pairing and Bluetooth status are not connected to the operating system yet.",
                groups: [group("Bluetooth", [row("Bluetooth", "System managed"), row("My Devices", "Not available"), row("Nearby Devices", "Not scanned")])]
            };
        case "Network":
            return {
                icon: "network",
                color: "#1689ec",
                subtitle: "Manage your network connections and services.",
                notice: "This desktop uses the computer’s existing network connection.",
                groups: [group("Network Services", [row("Wi-Fi", "System managed"), row("Ethernet", "System managed"), row("VPN & Filters", "System managed")]), group("Advanced", [row("DNS", "System managed"), row("Proxies", "System managed"), row("Firewall", "System managed")])]
            };
        case "Battery":
            return {
                icon: "battery",
                color: "#35b657",
                subtitle: "See power usage and choose when to save energy.",
                notice: "Battery charge and power profiles are not connected to a system power service.",
                groups: [group("Battery", [row("Battery Level", "Not available"), row("Battery Health", "Not available"), row("Low Power Mode", "System managed")]), group("Power", [row("Turn Display Off", "System managed"), row("Sleep", "System managed"), row("Optimized Battery Charging", "System managed")])]
            };
        case "Siri":
            return {
                icon: "sun",
                color: "#aa63da",
                subtitle: "Get help with everyday tasks using your voice.",
                notice: "A voice assistant is not connected. The desktop does not listen to the microphone.",
                groups: [group("Siri", [row("Talk to Siri", "Not available"), row("Keyboard Shortcut", "Not assigned"), row("Language", "Not configured"), row("Siri Voice", "Not available")])]
            };
        case "Spotlight":
            return {
                icon: "search",
                color: "#7d8186",
                subtitle: "Find files and open applications.",
                groups: [group("Search", [row("Files", "Available", "Use the search icon in the menu bar to find workspace files."), row("Applications", "Available in Apps", "Open Apps from the Dock to browse or search the application library."), row("Search Scope", "Desktop workspace", Bridge.rootPath)]), group("Sources", [row("Web Suggestions", "Not connected"), row("Siri Suggestions", "Not connected"), row("System Index", "Not connected")])]
            };
        case "Notifications":
            return {
                icon: "bell",
                color: "#ed4d64",
                subtitle: "Choose how applications get your attention.",
                notice: "A notification delivery service is not connected yet.",
                groups: [group("Notifications", [row("Notification Center", "Not connected"), row("Show Previews", "Not available"), row("Allow Notifications When Locked", "Not available")]), group("Application Notifications", [row("Calendar", "Events are stored locally", "Timed event alerts are not scheduled yet."), row("Reminders", "Lists are stored locally", "Timed reminder alerts are not scheduled yet."), row("Mail", "Local drafts only"), row("Messages", "Local drafts only")])]
            };
        case "Sound":
            return {
                icon: "speaker",
                color: "#ed4d64",
                subtitle: Bridge.ddeAudio.available ? "Adjust the default system output through DDE." : "Adjust the volume of this desktop’s applications.",
                groups: [group("Output", [row("Output Device", "System default", "Device selection is managed by the operating system.")]), group("Input", [row("Microphone", "Not in use"), row("Input Device", "System managed")])]
            };
        case "Focus":
            return {
                icon: "moon",
                color: "#7761cc",
                subtitle: "Stay focused by controlling interruptions.",
                notice: "Focus schedules need a connected notification service.",
                groups: [group("Focus Modes", [row("Do Not Disturb", "Not connected"), row("Personal", "Not configured"), row("Work", "Not configured"), row("Sleep", "Not configured")]), group("Options", [row("Share Across Devices", "Requires an account"), row("Focus Status", "Not shared")])]
            };
        case "Screen Time":
            return {
                icon: "clock",
                color: "#7761cc",
                subtitle: "Understand how you spend time on your computer.",
                notice: "Usage reporting and application limits are not connected.",
                groups: [group("Activity", [row("App & Website Activity", "Not collected"), row("Notifications", "Not collected"), row("Pickups", "Not collected")]), group("Limits", [row("Downtime", "Not configured"), row("App Limits", "Not configured"), row("Content & Privacy", "Not configured")])]
            };
        case "Lock Screen":
            return {
                icon: "lock",
                color: "#1689ec",
                subtitle: "Choose what happens when you leave your computer.",
                notice: "Screen locking and authentication are managed by the operating system.",
                groups: [group("Lock Screen", [row("Start Screen Saver", "System managed"), row("Turn Display Off", "System managed"), row("Require Password", "System managed")]), group("Login Window", [row("Show User List", "System managed"), row("Show Password Hints", "System managed")])]
            };
        case "Privacy & Security":
            return {
                icon: "shield",
                color: "#408cde",
                subtitle: "Control access to devices and your information.",
                groups: [group("Privacy", [row("Microphone", "Not in use"), row("Location Services", "Not requested"), row("Contacts", "Local workspace records", "Applications use contacts you create in this desktop, not the host address book."), row("Photos", "Local Pictures folder", "Importing an image copies the selected file into the workspace."), row("Files and Folders", "Workspace", Bridge.rootPath)]), group("Security", [row("Login Password", "System managed"), row("Disk Encryption", "System managed"), row("Firewall", "System managed")])]
            };
        case "Login Password":
            return {
                icon: "key",
                color: "#1689ec",
                subtitle: "Change the password used to log in to your computer.",
                notice: "This desktop does not manage operating-system credentials.",
                groups: [group("Password", [row("Login Password", "System managed"), row("Password Hint", "System managed"), row("Automatic Login", "System managed")])]
            };
        case "Users & Groups":
            return {
                icon: "shared",
                color: "#1689ec",
                subtitle: "Manage who can use this computer.",
                notice: "User creation and permissions require an operating-system account service.",
                groups: [group("Users", [row("Current Workspace", "Local", Bridge.rootPath), row("System Accounts", "Not available to this desktop"), row("Guest User", "System managed")]), group("Groups", [row("System Groups", "System managed")])]
            };
        case "Internet Accounts":
            return {
                icon: "network",
                color: "#1689ec",
                subtitle: "Connect accounts for mail, contacts and calendars.",
                notice: "Account providers are not connected. Your local records remain available without an account.",
                groups: [group("Accounts", [row("iCloud", "Not connected"), row("Google", "Not connected"), row("Microsoft Exchange", "Not connected"), row("Other Account", "Not connected")]), group("On This Desktop", [row("Contacts", "Local storage"), row("Calendars", "Local storage"), row("Notes", "Local storage"), row("Mail", "Local drafts")])]
            };
        case "Game Center":
            return {
                icon: "games",
                color: "#e25f9d",
                subtitle: "Play with friends and track achievements.",
                notice: "Game Center requires Apple services. Local Chess is available without an account.",
                groups: [group("Game Center", [row("Player Profile", "Not connected"), row("Friends", "Not connected"), row("Achievements", "Not connected")]), group("Local Games", [row("Chess", "Available", "Play a two-player game on this computer.")])]
            };
        case "iCloud":
            return {
                icon: "cloud",
                color: "#1689ec",
                subtitle: "Keep your files and information available across devices.",
                notice: "iCloud is not connected. Documents are saved to the local workspace.",
                groups: [group("Saved to iCloud", [row("iCloud Drive", "Not connected"), row("Photos", "Not connected"), row("Passwords", "Not connected"), row("Notes", "Not connected"), row("Contacts & Calendars", "Not connected")]), group("Storage", [row("iCloud Storage", "Requires an account"), row("Local Workspace", "Available", Bridge.rootPath)])]
            };
        case "Wallet & Apple Pay":
            return {
                icon: "wallet",
                color: "#383a3f",
                subtitle: "Manage payment cards and Apple Pay.",
                notice: "Wallet and Apple Pay are not supported by this desktop.",
                groups: [group("Wallet", [row("Payment Cards", "Not connected"), row("Apple Pay", "Unavailable"), row("Shipping & Billing", "Not collected")])]
            };
        case "Keyboard":
            return {
                icon: "keyboard",
                color: "#81858a",
                subtitle: "Type, navigate and control the desktop with shortcuts.",
                groups: [group("Desktop Shortcuts", [row("New Window or Item", "⌘N / Ctrl+N"), row("Close Window", "⌘W / Ctrl+W"), row("Minimize Window", "⌘M / Ctrl+M"), row("Find", "⌘F / Ctrl+F")]), group("Input", [row("Input Sources", "System managed"), row("Key Repeat Rate", "System managed"), row("Delay Until Repeat", "System managed"), row("Dictation", "Not connected")])]
            };
        case "Mouse":
            return {
                icon: "mouse",
                color: "#81858a",
                subtitle: "Point, click and move around your desktop.",
                groups: [group("Point & Click", [row("Primary Click", "Select"), row("Secondary Click", "Context menu"), row("Double Click", "Open items"), row("Tracking Speed", "System managed")]), group("Windows", [row("Move", "Drag the title bar"), row("Resize", "Drag the lower-right corner"), row("Scroll Direction", "System managed")])]
            };
        case "Trackpad":
            return {
                icon: "trackpad",
                color: "#81858a",
                subtitle: "Use gestures to move through your desktop.",
                groups: [group("Point & Click", [row("Tap to Click", "System managed"), row("Secondary Click", "Context menu"), row("Tracking Speed", "System managed")]), group("Scroll & Zoom", [row("Scrolling", "Available"), row("Pinch to Zoom", "Application dependent"), row("Full-Screen Spaces", "Not connected"), row("Mission Control", "Not connected")])]
            };
        case "Printers & Scanners":
            return {
                icon: "printer",
                color: "#81858a",
                subtitle: "Add printers and scanners to your computer.",
                notice: "Printing and scanning are not connected to a system print service.",
                groups: [group("Printers", [row("Configured Printers", "Not available"), row("Default Printer", "System managed"), row("Default Paper Size", "System managed")]), group("Scanners", [row("Configured Scanners", "Not available")])]
            };
        case "Storage":
            return {
                icon: "drive",
                color: "#81858a",
                subtitle: "See available disk space and the content in your workspace.",
                groups: [group("Workspace Content", [row("Photos", String(disk.photos)), row("Music", String(disk.songs)), row("Application Records", String(disk.documents))]), group("Location", [row("Workspace", "Local", disk.path)])]
            };
        case "AppleCare & Warranty":
            return {
                icon: "shield",
                color: "#1689ec",
                subtitle: "See support and service information for your devices.",
                notice: "Hardware warranty information requires Apple’s device and account services.",
                groups: [group("Coverage", [row("This Computer", "Not available"), row("Other Devices", "Requires an account"), row("Support", "Managed by your device provider")])]
            };
        case "AirDrop & Continuity":
            return {
                icon: "airdrop",
                color: "#1689ec",
                subtitle: "Share files and work across nearby devices.",
                notice: "AirDrop and Continuity services are not connected.",
                groups: [group("Sharing", [row("AirDrop", "Unavailable"), row("Handoff", "Unavailable"), row("Universal Clipboard", "Unavailable")]), group("Nearby Devices", [row("Continuity Camera", "Unavailable"), row("iPhone Mirroring", "Unavailable"), row("AirPlay Receiver", "Unavailable")])]
            };
        case "AutoFill & Passwords":
            return {
                icon: "key",
                color: "#81858a",
                subtitle: "Choose how passwords and personal information are filled in.",
                notice: "A password manager is not connected. This desktop does not import saved credentials.",
                groups: [group("AutoFill", [row("Passwords and Passkeys", "Not connected"), row("Contact Information", "Not connected"), row("Payment Cards", "Not connected"), row("Verification Codes", "Not connected")])]
            };
        case "Date & Time":
            return {
                icon: "clock",
                color: "#1689ec",
                subtitle: "Choose how the date and time appear in the menu bar.",
                groups: [group("System Clock", [row("Current Date", Qt.formatDateTime(host.desktop.now, "dddd, d MMMM yyyy")), row("Current Time", Qt.formatDateTime(host.desktop.now, "HH:mm:ss")), row("Time Zone", "System time zone"), row("Set Time Automatically", "System managed")])]
            };
        case "Language & Region":
            return {
                icon: "network",
                color: "#1689ec",
                subtitle: "Choose the language and formats used by your computer.",
                notice: "The prototype interface is currently in English. Input languages come from the operating system.",
                groups: [group("Language", [row("Interface Language", "English"), row("Preferred Input Languages", "System managed")]), group("Region", [row("System Locale", Qt.locale().name), row("Calendar", "Gregorian"), row("Date Format", Qt.formatDate(new Date(), Qt.DefaultLocaleShortDate))])]
            };
        case "Login Items & Extensions":
            return {
                icon: "settings",
                color: "#81858a",
                subtitle: "Manage applications and extensions that start with your session.",
                notice: "The desktop does not install background login items or system extensions.",
                groups: [group("Open at Login", [row("Tahoe Desktop", "Manual launch"), row("Other Applications", "System managed")]), group("Extensions", [row("System Extensions", "System managed"), row("Finder Extensions", "Not connected"), row("Background Activities", "Not registered")])]
            };
        case "Sharing":
            return {
                icon: "shared",
                color: "#1689ec",
                subtitle: "Share resources with other computers on your network.",
                notice: "Remote services are managed by the operating system.",
                groups: [group("Sharing Services", [row("File Sharing", "System managed"), row("Screen Sharing", "System managed"), row("Remote Login", "System managed"), row("Printer Sharing", "System managed"), row("Internet Sharing", "System managed")])]
            };
        case "Startup Disk":
            return {
                icon: "drive",
                color: "#81858a",
                subtitle: "Choose the operating system used when the computer starts.",
                notice: "Boot disks are outside this desktop’s application workspace.",
                groups: [group("Startup", [row("Startup Disk", "System managed"), row("Boot Options", "System managed"), row("Restart", "Use the operating system’s controls")])]
            };
        case "Time Machine":
            return {
                icon: "clock",
                color: "#37aa73",
                subtitle: "Keep a backup of your files.",
                notice: "Scheduled backup storage is not connected. Local application data is stored with the workspace.",
                groups: [group("Backups", [row("Backup Disk", "Not configured"), row("Last Backup", "Not available"), row("Backup Frequency", "Not configured")]), group("Data Location", [row("Workspace", "Local", Bridge.rootPath)])]
            };
        case "Device Management":
            return {
                icon: "settings",
                color: "#81858a",
                subtitle: "Review profiles that manage this computer.",
                notice: "This desktop does not read or modify operating-system management profiles.",
                groups: [group("Profiles", [row("Configuration Profiles", "System managed"), row("Enrollment", "System managed")])]
            };
        case "Transfer or Reset":
            return {
                icon: "settings",
                color: "#81858a",
                subtitle: "Move your information to another computer.",
                notice: "Workspace data can be copied with Finder. Erasing or resetting the operating system is not available here.",
                groups: [group("Migration", [row("Local Workspace", "Available", Bridge.rootPath), row("Migration Assistant", "Not connected")]), group("Reset", [row("Erase All Content and Settings", "System managed")])]
            };
        default:
            return {
                icon: "settings",
                color: "#81858a",
                subtitle: "Manage your desktop preferences.",
                groups: [group("Status", [row(page, "System managed")])]
            };
        }
    }
    readonly property var specificationData: specification()
    SettingsCard {
        dark: details.dark
        Column {
            width: parent.width
            topPadding: 20
            bottomPadding: 18
            spacing: 9
            Rectangle {
                width: 55
                height: 55
                radius: 13
                anchors.horizontalCenter: parent.horizontalCenter
                color: details.specificationData.color
                Icon {
                    anchors.fill: parent
                    anchors.margins: 10
                    name: details.specificationData.icon
                    color: "white"
                }
            }
            Text {
                width: parent.width
                text: details.page
                font.pixelSize: 22
                font.weight: Font.DemiBold
                color: details.ink
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
            Text {
                width: parent.width
                text: details.specificationData.subtitle
                font.pixelSize: 12
                color: details.muted
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
        }
    }
    SettingsCard {
        visible: details.page === "Sound"
        dark: details.dark
        SettingsToggle {
            dark: details.dark
            reducedMotion: host.desktop.reduceMotion
            label: Bridge.ddeAudio.available ? "Mute system audio" : "Mute application audio"
            description: Bridge.ddeAudio.available ? "Controls the default DDE output device." : "Applies to the Music player in this desktop."
            checked: details.pref("sound.muted", "false") === "true"
            onToggled: function (value) {
                details.save("sound.muted", value);
            }
        }
        Item {
            width: parent.width
            height: 64
            Text {
                y: 9
                text: "Output volume"
                color: details.ink
                font.pixelSize: 13
            }
            Text {
                y: 9
                anchors.right: parent.right
                text: Math.round(volume.value * 100) + "%"
                color: details.muted
                font.pixelSize: 12
            }
            Slider {
                id: volume
                x: 0
                y: 29
                width: parent.width
                height: 26
                from: 0
                to: 1
                stepSize: 0.01
                value: Number(details.pref("sound.volume", "0.75"))
                onMoved: details.save("sound.volume", value)
                Accessible.name: "Application output volume"
            }
        }
    }
    SettingsCard {
        visible: details.page === "Privacy & Security"
        dark: details.dark
        SettingsToggle {
            dark: details.dark
            reducedMotion: host.desktop.reduceMotion
            label: "Allow Photo Booth to use the camera"
            description: "Camera starts only when you choose Start Camera."
            checked: details.pref("camera.allowed", "true") === "true"
            onToggled: function (value) {
                details.save("camera.allowed", value);
            }
        }
        Text {
            width: parent.width
            bottomPadding: 12
            text: "This preference applies to this desktop. The operating system may also ask for camera permission."
            font.pixelSize: 11
            color: details.muted
            wrapMode: Text.Wrap
        }
    }
    SettingsCard {
        visible: details.page === "Date & Time"
        dark: details.dark
        SettingsToggle {
            dark: details.dark
            reducedMotion: host.desktop.reduceMotion
            label: "Use a 24-hour clock"
            checked: details.pref("clock.24hour", "true") === "true"
            onToggled: function (value) {
                details.save("clock.24hour", value);
            }
        }
        SettingsToggle {
            dark: details.dark
            reducedMotion: host.desktop.reduceMotion
            label: "Show date and time in the menu bar"
            checked: host.desktop.showClock
            onToggled: function (value) {
                host.desktop.showClock = value;
            }
        }
    }
    SettingsCard {
        visible: details.page === "Storage"
        dark: details.dark
        Column {
            width: parent.width
            spacing: 12
            topPadding: 14
            bottomPadding: 12
            Row {
                width: parent.width
                Text {
                    width: parent.width * 0.7
                    text: details.size(details.disk.free) + " available"
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    color: details.ink
                }
                Text {
                    width: parent.width * 0.3
                    text: details.size(details.disk.total)
                    horizontalAlignment: Text.AlignRight
                    font.pixelSize: 12
                    color: details.muted
                }
            }
            Rectangle {
                width: parent.width
                height: 18
                radius: 5
                color: details.dark ? "#484c50" : "#e8e9eb"
                clip: true
                Rectangle {
                    height: parent.height
                    radius: 5
                    width: parent.width * Math.max(0, Math.min(1, 1 - details.disk.free / Math.max(1, details.disk.total)))
                    color: "#1689ed"
                }
            }
            Text {
                width: parent.width
                text: "Disk usage includes the operating system and files outside this workspace."
                color: details.muted
                font.pixelSize: 11
                wrapMode: Text.Wrap
            }
            DialogButton {
                text: "Refresh"
                dark: details.dark
                onClicked: details.disk = details.suite.storage()
            }
        }
    }
    Repeater {
        model: details.specificationData.groups
        delegate: Column {
            required property var modelData
            width: details.width
            spacing: 7
            Text {
                visible: text !== ""
                leftPadding: 10
                text: modelData.title
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: details.muted
            }
            SettingsCard {
                dark: details.dark
                Repeater {
                    model: modelData.rows
                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: parent.width
                        height: Math.max(47, Math.max(label.implicitHeight, valueLabel.implicitHeight) + (description.text ? description.implicitHeight + 4 : 0) + 24)
                        Text {
                            id: label
                            y: 13
                            width: parent.width * 0.48
                            text: modelData.name
                            color: details.ink
                            font.pixelSize: 13
                            wrapMode: Text.Wrap
                        }
                        Text {
                            id: valueLabel
                            y: 13
                            anchors.right: parent.right
                            width: parent.width * 0.48
                            text: modelData.value
                            color: details.muted
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                            horizontalAlignment: Text.AlignRight
                        }
                        Text {
                            id: description
                            y: label.y + Math.max(label.implicitHeight, valueLabel.implicitHeight) + 4
                            width: parent.width
                            text: modelData.detail
                            color: details.muted
                            font.pixelSize: 11
                            wrapMode: Text.WrapAnywhere
                        }
                        Rectangle {
                            visible: index > 0
                            width: parent.width
                            height: 1
                            color: details.dark ? "#12ffffff" : "#0c000000"
                        }
                    }
                }
            }
        }
    }
    Text {
        visible: !!details.specificationData.notice
        width: parent.width
        leftPadding: 10
        rightPadding: 10
        text: details.specificationData.notice || ""
        color: details.muted
        font.pixelSize: 12
        wrapMode: Text.Wrap
    }
    Row {
        spacing: 8
        visible: ["Spotlight", "Game Center", "Storage", "Transfer or Reset", "Internet Accounts"].indexOf(details.page) >= 0
        DialogButton {
            dark: details.dark
            text: details.page === "Game Center" ? "Open Chess" : details.page === "Spotlight" ? "Open Apps" : details.page === "Internet Accounts" ? "Open Contacts" : "Open Workspace"
            onClicked: {
                if (details.page === "Game Center")
                    host.desktop.openApplication("chess");
                else if (details.page === "Spotlight")
                    host.desktop.openApplication("apps");
                else if (details.page === "Internet Accounts")
                    host.desktop.openApplication("contacts");
                else
                    host.desktop.openFolder("");
            }
        }
    }
    DialogButton {
        visible: ["Apple Account", "Family", "Wi-Fi", "Bluetooth", "Network", "Battery", "Sound", "Lock Screen", "Privacy & Security", "Login Password", "Users & Groups", "Keyboard", "Mouse", "Trackpad", "Printers & Scanners", "Software Update", "Date & Time", "Language & Region", "Login Items & Extensions", "Sharing", "Startup Disk", "Time Machine", "Device Management"].indexOf(details.page) >= 0
        dark: details.dark
        text: Bridge.isMac ? "Open macOS System Settings…" : "Open System Settings…"
        enabled: Bridge.hostSettingsAvailable
        onClicked: Bridge.launchApplication("host-settings")
    }
}
