// Read-only extraction of Tahoe Settings resources through public AppKit APIs.
// No app is launched, no window is inspected, and no system preference is changed.
import AppKit
import Foundation
import CryptoKit

let fm = FileManager.default
let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "assets/settings-reference", isDirectory: true)
try fm.createDirectory(at: output, withIntermediateDirectories: true)
let appearancePath = "/System/Library/ExtensionKit/Extensions/Appearance.appex"
let settingsPath = "/System/Applications/System Settings.app"
let appearanceBundle = Bundle(path: appearancePath)!
let contextNames: [(String, NSAppearance.Name)] = [("light", .aqua), ("dark", .darkAqua)]
var records: [[String: Any]] = []
var unknowns: [[String: Any]] = []

func digest(_ path: String) -> String? {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}
func sourceInfo(_ path: String) -> [String: Any] {
    var result: [String: Any] = ["path": path]
    if let value = digest(path) { result["sha256"] = value }
    return result
}
func writeImage(_ image: NSImage, filename: String, logicalSize: NSSize, scale: CGFloat, appearance: NSAppearance) throws -> [String: Any] {
    let width = max(1, Int((logicalSize.width * scale).rounded()))
    let height = max(1, Int((logicalSize.height * scale).rounded()))
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    bitmap.size = logicalSize
    appearance.performAsCurrentDrawingAppearance {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.current?.imageInterpolation = .high
        // bitmap.size supplies the point-to-pixel scale to NSGraphicsContext;
        // applying an additional transform would crop enlarged artwork.
        image.draw(in: NSRect(origin: .zero, size: logicalSize), from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
    }
    let data = bitmap.representation(using: .png, properties: [:])!
    try data.write(to: output.appendingPathComponent(filename), options: .atomic)
    return ["file": filename, "logical_size": [Double(logicalSize.width), Double(logicalSize.height)], "pixel_size": [width, height], "scale": Double(scale), "png_sha256": SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()]
}
let previewNames: [(String,String)] = [
    ("AppearanceLight", "appearance-light"), ("AppearanceDark", "appearance-dark"), ("AppearanceAuto", "appearance-auto"),
    ("AppearanceLightNoColor", "appearance-light-no-color"), ("AppearanceDarkNoColor", "appearance-dark-no-color"), ("AppearanceAutoNoColor", "appearance-auto-no-color"),
    ("GlassClear", "glass-clear"), ("GlassTinted", "glass-tinted")
]
let catalog = sourceInfo(appearancePath + "/Contents/Resources/Assets.car")
for (asset, stem) in previewNames {
    for (theme, name) in contextNames {
        let appearance = NSAppearance(named: name)!
        var image: NSImage?
        appearance.performAsCurrentDrawingAppearance { image = appearanceBundle.image(forResource: NSImage.Name(asset)) }
        guard let original = image else {
            unknowns.append(["asset":asset,"appearance":theme,"reason":"Bundle.image(forResource:) returned nil"])
            continue
        }
        let nativeSize = original.size
        var record = try writeImage(original, filename: stem + "-" + theme + ".png", logicalSize: nativeSize, scale: 2, appearance: appearance)
        record["kind"] = "named-resource"
        record["asset_name"] = asset
        record["bundle_path"] = appearancePath
        record["drawing_appearance"] = name.rawValue
        record["catalog"] = catalog
        record["evidence_id"] = "ev_b8a3a8cdd4c7bc67d9eb135c741e4bd1b9f49ec2f3bbd1041c34cd3873fef483"
        record["evidence_scope"] = "Existing REA catalog identity; names beyond its bounded first 12 records verified by successful public named-image lookup."
        records.append(record)
        print("Preview \(asset) [\(theme)] \(nativeSize.width) × \(nativeSize.height) pt → \(record["file"]!)")
    }
}

// Exact identifiers found in the shipped Settings Sidebar124.plist, mapped only
// to resource labels. Their icon artwork does not establish live-control behavior.
let categories: [String:(String,String)] = [
    "com.apple.systempreferences.AppleIDSettings": ("apple-account", "Apple Account bundle icon; not the user's avatar"),
    "com.apple.Family-Settings.extension": ("family", "Family"),
    "com.apple.wifi-settings-extension": ("wifi", "Wi-Fi"),
    "com.apple.BluetoothSettings": ("bluetooth", "Bluetooth"),
    "com.apple.Network-Settings.extension": ("network", "Network"),
    "com.apple.NetworkExtensionSettingsUI.NESettingsUIExtension": ("vpn", "VPN"),
    "com.apple.Battery-Settings.extension": ("battery", "Battery"),
    "com.apple.systempreferences.GeneralSettings": ("general", "General"),
    "com.apple.Accessibility-Settings.extension": ("accessibility", "Accessibility"),
    "com.apple.Appearance-Settings.extension": ("appearance", "Appearance"),
    "com.apple.Desktop-Settings.extension": ("desktop-dock", "Desktop & Dock"),
    "com.apple.Displays-Settings.extension": ("displays", "Displays"),
    "com.apple.ControlCenter-Settings.extension": ("menu-bar", "Control Center / Menu Bar bundle"),
    "com.apple.Siri-Settings.extension": ("siri", "Siri"),
    "com.apple.Spotlight-Settings.extension": ("spotlight", "Spotlight"),
    "com.apple.Wallpaper-Settings.extension": ("wallpaper", "Wallpaper"),
    "com.apple.Notifications-Settings.extension": ("notifications", "Notifications"),
    "com.apple.Sound-Settings.extension": ("sound", "Sound"),
    "com.apple.Focus-Settings.extension": ("focus", "Focus"),
    "com.apple.Screen-Time-Settings.extension": ("screen-time", "Screen Time"),
    "com.apple.Lock-Screen-Settings.extension": ("lock-screen", "Lock Screen"),
    "com.apple.settings.PrivacySecurity.extension": ("privacy-security", "Privacy & Security"),
    "com.apple.Touch-ID-Settings.extension": ("touch-id", "Touch ID bundle; not proof of the Login Password-only row icon"),
    "com.apple.Users-Groups-Settings.extension": ("users-groups", "Users & Groups"),
    "com.apple.Internet-Accounts-Settings.extension": ("internet-accounts", "Internet Accounts"),
    "com.apple.Game-Center-Settings.extension": ("game-center", "Game Center"),
    "com.apple.WalletSettingsExtension": ("wallet", "Wallet & Apple Pay"),
    "com.apple.Keyboard-Settings.extension": ("keyboard", "Keyboard"),
    "com.apple.Mouse-Settings.extension": ("mouse", "Mouse"),
    "com.apple.Trackpad-Settings.extension": ("trackpad", "Trackpad"),
    "com.apple.Print-Scan-Settings.extension": ("printers", "Printers & Scanners")
]
let roots = ["/System/Library/ExtensionKit/Extensions", settingsPath + "/Contents/PlugIns", "/System/Library/PreferencePanes"]
var found = Set<String>()
for directory in roots {
    let entries = (try? fm.contentsOfDirectory(atPath: directory)) ?? []
    for entry in entries.sorted() {
        let path = directory + "/" + entry
        guard let bundle = Bundle(path: path), let identifier = bundle.bundleIdentifier, let (stem, label) = categories[identifier] else { continue }
        if found.contains(identifier) { continue }
        found.insert(identifier)
        let metadata = bundle.infoDictionary ?? [:]
        let iconDeclaration = metadata["CFBundleIcons"] ?? metadata["CFBundleIconFile"] ?? metadata["CFBundleIconName"] ?? NSNull()
        for (theme, appearanceName) in contextNames {
            let appearance = NSAppearance(named: appearanceName)!
            var icon: NSImage?
            var method = "NSWorkspace.shared.icon(forFile:)"
            appearance.performAsCurrentDrawingAppearance {
                if let resource = (metadata["CFBundleIconFile"] ?? metadata["CFBundleIconName"]) as? String,
                   let declared = bundle.image(forResource: NSImage.Name(resource)) {
                    icon = declared
                    method = "Bundle.image(forResource:) using CFBundleIconFile/CFBundleIconName"
                } else {
                    icon = NSWorkspace.shared.icon(forFile: path)
                }
            }
            guard let original = icon else { continue }
            var record = try writeImage(original, filename: "category-" + stem + "-" + theme + ".png", logicalSize: NSSize(width:20,height:20), scale:3, appearance:appearance)
            record["kind"] = "declared-category-bundle-icon"
            record["category_label"] = label
            record["bundle_identifier"] = identifier
            record["bundle_path"] = path
            record["drawing_appearance"] = appearanceName.rawValue
            record["icon_declaration"] = iconDeclaration
            record["method"] = method
            record["info_plist"] = sourceInfo(path + "/Contents/Info.plist")
            let car = path + "/Contents/Resources/Assets.car"
            if fm.fileExists(atPath:car) { record["catalog"] = sourceInfo(car) }
            record["limitation"] = "Declared bundle icon rendered by public AppKit. Compare with the live sidebar before asserting exact row parity."
            records.append(record)
        }
        print("Category \(label): \(path)")
    }
}
for (identifier,(stem,label)) in categories where !found.contains(identifier) {
    unknowns.append(["category":label,"file_stem":stem,"bundle_identifier":identifier,"reason":"No matching bundle in the three scoped metadata roots"])
}
unknowns.append(["requested":"Icon / Widget style previews", "reason":"No named preview image keys were observed in the scoped Appearance and DesktopSettings asset-catalog string inventories or the existing bounded REA projections. No substitute AppIcon was presented as a live preview control."])
unknowns.append(["requested":"iCloud, Software Update and Login Password-only sidebar icons", "reason":"These dynamic/subpage rows were not resolved to explicit artwork by this scoped extraction. Touch ID artwork must not be substituted for a Password-only row without live evidence."])
let provenance: [String:Any] = [
    "format_version":1,
    "host_os":ProcessInfo.processInfo.operatingSystemVersionString,
    "method":"Public AppKit Bundle.image(forResource:), NSWorkspace.icon(forFile:) and NSAppearance drawing contexts; no UI automation, target execution, or system preference mutation.",
    "sidebar_configuration":sourceInfo(settingsPath + "/Contents/Resources/Sidebar124.plist"),
    "asset_count":records.count,
    "assets":records,
    "unknowns":unknowns
]
try JSONSerialization.data(withJSONObject:provenance, options:[.prettyPrinted,.sortedKeys]).write(to: output.appendingPathComponent("provenance.json"), options:.atomic)
print("Wrote \(records.count) images and provenance to \(output.path)")
