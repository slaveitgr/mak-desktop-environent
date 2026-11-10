// Read-only local macOS icon reference extraction. No app is launched or loaded.
// Render candidates separately: a legacy ICNS may differ from IconServices.
import AppKit
import CryptoKit
import Foundation

guard CommandLine.arguments.count == 2 || CommandLine.arguments.count == 3 else {
    fatalError("Usage: swift extract_primary_icons.swift NEW_OUTPUT_DIRECTORY [PIXELS]")
}
let pixels = CommandLine.arguments.count == 3 ? Int(CommandLine.arguments[2])! : 256
guard (64...1024).contains(pixels) else { fatalError("Pixel size must be between 64 and 1024") }
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let fm = FileManager.default
guard !fm.fileExists(atPath: output.path) else { fatalError("Output directory must be new") }
try fm.createDirectory(at: output, withIntermediateDirectories: true)
let targets = [
    ("settings", "/System/Applications/System Settings.app"),
    ("safari", "/Applications/Safari.app"),
    ("calendar", "/System/Applications/Calendar.app"),
    ("apps", "/System/Applications/Apps.app")
]
func sha(_ path: String) -> String? {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}
var records: [[String: Any]] = []
var missing: [[String: String]] = []
for (name, suppliedPath) in targets {
    let canonical = URL(fileURLWithPath: suppliedPath).resolvingSymlinksInPath().path
    guard let bundle = Bundle(path: canonical), let info = bundle.infoDictionary else { continue }
    let iconName = (info["CFBundleIconName"] ?? info["CFBundleIconFile"]) as? String ?? "AppIcon"
    let icns = canonical + "/Contents/Resources/" + iconName + ".icns"
    let sources = ["Info.plist": canonical + "/Contents/Info.plist", "Assets.car": canonical + "/Contents/Resources/Assets.car", "ICNS": icns]
    for (theme, appearanceName) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
        let appearance = NSAppearance(named: appearanceName)!
        for method in ["workspace-canonical", "bundle-declared", "icns"] {
            var rendered: Data?
            var logicalSize = NSSize.zero
            appearance.performAsCurrentDrawingAppearance {
                let image: NSImage?
                if method == "workspace-canonical" { image = NSWorkspace.shared.icon(forFile: canonical) }
                else if method == "bundle-declared" { image = bundle.image(forResource: NSImage.Name(iconName)) }
                else { image = NSImage(contentsOfFile: icns) }
                guard let image = image else { return }
                logicalSize = image.size
                let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
                image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels), from: .zero, operation: .copy, fraction: 1)
                NSGraphicsContext.restoreGraphicsState()
                rendered = bitmap.representation(using: .png, properties: [:])
            }
            let filename = name + "-" + method + "-" + theme + ".png"
            guard let data = rendered else { missing.append(["output": filename, "reason": "Public image lookup returned nil"]); continue }
            try data.write(to: output.appendingPathComponent(filename))
            records.append(["file": filename, "method": method, "appearance": appearanceName.rawValue,
                "caller_bundle": suppliedPath, "canonical_bundle": canonical, "bundle_id": bundle.bundleIdentifier ?? "unknown",
                "version": info["CFBundleShortVersionString"] ?? "unknown", "build": info["CFBundleVersion"] ?? "unknown",
                "declared_icon": iconName, "logical_size": [logicalSize.width, logicalSize.height],
                "pixels": [pixels,pixels], "source_sha256": sources.mapValues { sha($0) ?? "unavailable" },
                "png_sha256": sha(output.appendingPathComponent(filename).path)!])
        }
    }
}
let report: [String:Any] = ["host_os": ProcessInfo.processInfo.operatingSystemVersionString,
    "captured_at": ISO8601DateFormatter().string(from: Date()), "records": records, "missing": missing,
    "limits": ["These are public AppKit rasterizations, not raw extracted catalog renditions or screenshots.",
               "No target executable or dock tile plugin is loaded. Dynamic calendar composition may require a separate implementation.",
               "Native artwork provenance does not itself grant redistribution rights."]]
try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted,.sortedKeys]).write(to: output.appendingPathComponent("provenance.json"))
print("Rendered \(records.count) icon candidates; \(missing.count) unavailable")
