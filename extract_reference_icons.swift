// Local Tahoe reference capture. AppKit reads image resources; no UI automation.
import AppKit
import Foundation
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let baseSymbols: [String:String] = ["calendar":"calendar", "pin":"pin.fill", "star":"star", "starfill":"star.fill", "plus":"plus", "compose":"square.and.pencil", "play":"play.fill", "pause":"pause.fill", "previous":"backward.end.fill", "next":"forward.end.fill", "camera":"camera.fill", "video":"video.fill", "phone":"phone.fill", "reload":"arrow.clockwise", "bookmark":"bookmark", "bookmarkfill":"bookmark.fill", "keypad":"circle.grid.3x3.fill", "bluetooth":"NSBluetoothTemplate", "network":"globe", "account":"person.crop.circle", "bell":"bell.badge.fill", "speaker":"speaker.wave.2.fill", "lock":"lock.fill", "shield":"hand.raised.fill", "key":"key.fill", "games":"gamecontroller.fill", "wallet":"wallet.bifold.fill", "keyboard":"keyboard", "mouse":"computermouse", "trackpad":"rectangle", "printer":"printer.fill",

    "back":"chevron.left", "forward":"chevron.right", "chevron":"chevron.right",
    "down":"chevron.down", "up":"chevron.up", "search":"magnifyingglass",
    "grid":"square.grid.2x2", "list":"list.bullet", "columns":"rectangle.split.3x1",
    "gallery":"rectangle.bottomthird.inset.filled", "more":"ellipsis",
    "group":"square.grid.3x1.below.line.grid.1x2", "folder":"folder",
    "newfolder":"folder.badge.plus", "home":"house", "clock":"clock",
    "desktop":"menubar.dock.rectangle", "document":"doc", "downloads":"arrow.down.circle",
    "image":"photo", "trash":"trash", "tag":"tag", "share":"square.and.arrow.up",
    "wifi":"wifi", "battery":"battery.100percent", "control":"switch.2",
    "sun":"sun.max", "moon":"moon", "close":"xmark", "check":"checkmark",
    "sidebar":"sidebar.left", "apple":"apple.logo", "applications":"square.stack.3d.up",
    "shared":"folder.badge.person.crop", "drive":"externaldrive", "cloud":"icloud", "airdrop":"airplayaudio", "settings":"gearshape", "accessibility":"accessibility", "appearance":"circle.lefthalf.filled", "display":"display", "menubar":"menubar.rectangle",
    // Public SF artwork for status states; the application-to-symbol mapping is
    // semantic reconstruction, not a claim about a captured live native glyph.
    "speaker-muted":"speaker.slash.fill", "speaker-low":"speaker.wave.1.fill",
    "speaker-high":"speaker.wave.3.fill", "timer":"timer", "mirroring":"display.2",
    "weather":"cloud.sun", "timemachine":"arrow.counterclockwise.clock"
]
// Finder NSActionImage resources plus explicitly inferred common menu actions.
// Assignments and evidence scope: assets/symbols/menu.provenance.json.
let menuSymbols: [String:String] = [
    "menu-arrow.clockwise": "arrow.clockwise",
    "menu-arrow.down.circle": "arrow.down.circle",
    "menu-arrow.down.right.and.arrow.up.left": "arrow.down.right.and.arrow.up.left",
    "menu-arrow.forward.folder": "arrow.forward.folder",
    "menu-arrow.up.arrow.down": "arrow.up.arrow.down",
    "menu-arrow.up.folder": "arrow.up.folder",
    "menu-arrow.up.forward.app": "arrow.up.forward.app",
    "menu-arrow.up.left.and.arrow.down.right": "arrow.up.left.and.arrow.down.right",
    "menu-arrow.uturn.backward": "arrow.uturn.backward",
    "menu-arrow.uturn.forward": "arrow.uturn.forward",
    "menu-arrowshape.turn.up.left": "arrowshape.turn.up.left",
    "menu-bag": "bag",
    "menu-book.pages": "book.pages",
    "menu-character.textbox": "character.textbox",
    "menu-chevron.backward": "chevron.backward",
    "menu-chevron.forward": "chevron.forward",
    "menu-clipboard": "clipboard",
    "menu-clock": "clock",
    "menu-desktopcomputer": "desktopcomputer",
    "menu-display": "display",
    "menu-document": "document",
    "menu-document.on.clipboard": "document.on.clipboard",
    "menu-document.on.document": "document.on.document",
    "menu-eject": "eject",
    "menu-eye": "eye",
    "menu-eye.slash": "eye.slash",
    "menu-folder": "folder",
    "menu-folder.badge.person.crop": "folder.badge.person.crop",
    "menu-folder.badge.plus": "folder.badge.plus",
    "menu-gear": "gear",
    "menu-gearshape": "gearshape",
    "menu-house": "house",
    "menu-icloud": "icloud",
    "menu-info.circle": "info.circle",
    "menu-keyboard": "keyboard",
    "menu-lightbulb": "lightbulb",
    "menu-link": "link",
    "menu-list.bullet": "list.bullet",
    "menu-lock": "lock",
    "menu-magnifyingglass": "magnifyingglass",
    "menu-menubar.dock.rectangle": "menubar.dock.rectangle",
    "menu-minus": "minus",
    "menu-moon.zzz": "moon.zzz",
    "menu-network": "network",
    "menu-pencil": "pencil",
    "menu-photo": "photo",
    "menu-plus.rectangle": "plus.rectangle",
    "menu-plus.square.on.square": "plus.square.on.square",
    "menu-power": "power",
    "menu-printer": "printer",
    "menu-rectangle.connected.to.line.below": "rectangle.connected.to.line.below",
    "menu-rectangle.on.rectangle": "rectangle.on.rectangle",
    "menu-rectangle.portrait.and.arrow.right": "rectangle.portrait.and.arrow.right",
    "menu-rectangle.split.3x1": "rectangle.split.3x1",
    "menu-scissors": "scissors",
    "menu-sidebar.leading": "sidebar.leading",
    "menu-sidebar.trailing": "sidebar.trailing",
    "menu-square.and.arrow.up": "square.and.arrow.up",
    "menu-square.grid.2x2": "square.grid.2x2",
    "menu-square.grid.3x1.below.line.grid.1x2": "square.grid.3x1.below.line.grid.1x2",
    "menu-square.grid.3x3": "square.grid.3x3",
    "menu-squares.below.rectangle": "squares.below.rectangle",
    "menu-star": "star",
    "menu-tag": "tag",
    "menu-trash": "trash",
    "menu-wrench.adjustable": "wrench.adjustable",
    "menu-wrench.and.screwdriver": "wrench.and.screwdriver",
    "menu-xmark": "xmark",
    "menu-xmark.octagon": "xmark.octagon",
    "menu-zipper.page": "zipper.page"
]
let symbols = baseSymbols.merging(menuSymbols) { _, menu in menu }

func writePNG(_ image: NSImage, _ target: URL, size: Int) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size), from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: target)
}
var saved: [String:String] = [:]
for (key, name) in symbols {
    // Bluetooth is an AppKit template resource, not an unrelated radio SF symbol.
    if let original = name == "NSBluetoothTemplate"
        ? NSImage(named: NSImage.Name(name))
        : NSImage(systemSymbolName: name, accessibilityDescription: nil),
       let image = name == "NSBluetoothTemplate"
        ? original
        : original.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)) {
        // Preserve each symbol's aspect ratio inside the shared 24 pt coordinate space.
        let canvas = NSImage(size: NSSize(width: 24, height: 24))
        canvas.lockFocus()
        let scale = min(20 / image.size.width, 20 / image.size.height)
        let w = image.size.width * scale, h = image.size.height * scale
        image.draw(in: NSRect(x: (24-w)/2, y: (24-h)/2, width: w, height: h))
        canvas.unlockFocus()
        try writePNG(canvas, output.appendingPathComponent(key + ".png"), size: 72)
        saved[key] = name
    } else { print("Unavailable: \(key): \(name)") }
}
try JSONSerialization.data(withJSONObject: saved, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("sources.json"))
print("Exported \(saved.count) native reference symbols")
if CommandLine.arguments.count > 2 {
    let folderPath = URL(fileURLWithPath: CommandLine.arguments[2]).standardized.path
    let folder = NSWorkspace.shared.icon(forFile: folderPath)
    try writePNG(folder, output.deletingLastPathComponent().appendingPathComponent("folder.png"), size: 128)
    print("Exported NSWorkspace folder icon")
}

for (key, resource) in ["airdrop": "SidebarAirDrop", "applications": "SidebarApplicationsFolder"] {
    let path = "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/" + resource + ".icns"
    if let image = NSImage(contentsOfFile: path) {
        try writePNG(image, output.appendingPathComponent(key + ".png"), size: 72)
        saved[key] = path
    }
}
try JSONSerialization.data(withJSONObject: saved, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("sources.json"))

if let settings = NSImage(contentsOfFile: "/System/Applications/System Settings.app/Contents/Resources/SystemSettings.icns") {
    try writePNG(settings, output.deletingLastPathComponent().appendingPathComponent("settings.png"), size: 128)
}

let applicationIcons: [String:String] = ["apps": "/System/Applications/Apps.app", "calculator": "/System/Applications/Calculator.app", "chess": "/System/Applications/Chess.app", "photobooth": "/System/Applications/Photo Booth.app", "safari": "/Applications/Safari.app", "messages": "/System/Applications/Messages.app", "mail": "/System/Applications/Mail.app", "maps": "/System/Applications/Maps.app", "photos": "/System/Applications/Photos.app", "facetime": "/System/Applications/FaceTime.app", "phone": "/System/Applications/Phone.app", "calendar": "/System/Applications/Calendar.app", "reminders": "/System/Applications/Reminders.app", "notes": "/System/Applications/Notes.app", "contacts": "/System/Applications/Contacts.app", "music": "/System/Applications/Music.app", "games": "/System/Applications/Games.app", "appstore": "/System/Applications/App Store.app", "terminal": "/System/Applications/Utilities/Terminal.app"]
for (key, appPath) in applicationIcons {
    if FileManager.default.fileExists(atPath: appPath) {
        let icon = NSWorkspace.shared.icon(forFile: appPath)
        try writePNG(icon, output.deletingLastPathComponent().appendingPathComponent(key + ".png"), size: 128)
    }
}
