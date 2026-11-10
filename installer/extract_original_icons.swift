// Reproduce selected original image resources on macOS. Does not load target
// executables, launch Disk Utility, inspect disks or change system files.
import AppKit
import CryptoKit
import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "installer/assets/original", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let diskBundlePath = "/System/Applications/Utilities/Disk Utility.app"
let diskBundle = Bundle(path: diskBundlePath)!
let coreResources = "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/"
var records: [[String: Any]] = []
var missing: [[String: String]] = []
func sha256(_ path: String) throws -> String {
    SHA256.hash(data: try Data(contentsOf: URL(fileURLWithPath: path))).map { String(format: "%02x", $0) }.joined()
}
func writePNG(_ image: NSImage, name: String, pixels: Int, source: String, resource: String? = nil, appearance: String? = nil, template: Bool = false) throws {
    let originalSize = image.size
    guard originalSize.width > 0 && originalSize.height > 0 else { throw NSError(domain: "InvalidImage", code: 1) }
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let draw = {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let scale = min(CGFloat(pixels) / originalSize.width, CGFloat(pixels) / originalSize.height)
        let width = originalSize.width * scale, height = originalSize.height * scale
        let bounds = NSRect(x: (CGFloat(pixels)-width)/2, y: (CGFloat(pixels)-height)/2, width: width, height: height)
        image.draw(in: bounds, from: .zero, operation: .copy, fraction: 1)
        if template {
            // AppKit templates encode coverage; this is native control-text tint,
            // not replacement artwork. The unmodified source remains identified.
            NSColor.controlTextColor.setFill()
            bounds.fill(using: .sourceAtop)
        }
        NSGraphicsContext.restoreGraphicsState()
    }
    if let appearance = appearance, let native = NSAppearance(named: NSAppearance.Name(appearance)) { native.performAsCurrentDrawingAppearance(draw) } else { draw() }
    let target = output.appendingPathComponent(name + ".png")
    try bitmap.representation(using: .png, properties: [:])!.write(to: target)
    var entry: [String: Any] = ["output": target.lastPathComponent, "source":source, "output_sha256":try sha256(target.path), "pixels":[pixels,pixels], "source_logical_size":[originalSize.width,originalSize.height], "method":"AppKit NSImage resource rendering; aspect ratio preserved", "template_tint":template ? "NSColor.controlTextColor in selected appearance" : "none"]
    if FileManager.default.fileExists(atPath:source) {
        entry["source_sha256"] = try sha256(source)
        entry["source_kind"] = "file"
    } else {
        entry["source_kind"] = "AppKit system symbol"
        entry["source_identity_limit"] = "Resolved by NSImage(systemSymbolName:) on the recorded host OS; no standalone source file or source-byte digest is asserted."
    }
    if let resource = resource {entry["resource_name"] = resource}
    if let appearance = appearance {entry["appearance"] = appearance}
    records.append(entry)
}
let iconSources: [(String,String)] = [
    ("disk-utility",diskBundlePath + "/Contents/Resources/AppIcon.icns"),
    ("time-machine","/System/Applications/Time Machine.app/Contents/Resources/AppIcon.icns"),
    ("safari","/Applications/Safari.app/Contents/Resources/AppIcon.icns"),
    ("drive-internal","/System/Library/Extensions/IOStorageFamily.kext/Contents/Resources/Internal.icns"),
    ("drive-external","/System/Library/Extensions/IOStorageFamily.kext/Contents/Resources/External.icns"),
    ("drive-removable","/System/Library/Extensions/IOStorageFamily.kext/Contents/Resources/Removable.icns"),
    ("sidebar-internal",coreResources + "SidebarInternalDisk.icns"),
    ("sidebar-external",coreResources + "SidebarExternalDisk.icns"),
    ("sidebar-removable",coreResources + "SidebarRemovableDisk.icns")
]
for (name,path) in iconSources {
    if let image = NSImage(contentsOfFile:path) {
        try writePNG(image,name:name,pixels:name.hasPrefix("sidebar-") ? 72 : 256,source:path)
        if name.hasPrefix("sidebar-") {
            try writePNG(image,name:name+"-dark",pixels:72,source:path,appearance:NSAppearance.Name.darkAqua.rawValue,template:true)
        }
    }
    else {missing.append(["name":name,"reason":"Resource unavailable at " + path])}
}
let toolbarSources: [(String,String)] = [("erase","erase_enabled"),("first-aid","firstaid_enabled"),("partition","partition_enabled"),("restore","restore_enabled"),("mount","mountUnmount_enabled"),("info","info_enabled"),("view","sidebar_enabled")]
let catalog = diskBundlePath + "/Contents/Resources/Assets.car"
for (name,key) in toolbarSources {
    if let image = diskBundle.image(forResource:NSImage.Name(key)) {
        try writePNG(image,name:name+"-source",pixels:72,source:catalog,resource:key)
        for (variant,appearance) in [("light",NSAppearance.Name.aqua.rawValue),("dark",NSAppearance.Name.darkAqua.rawValue)] {
            try writePNG(image,name:name+"-"+variant,pixels:72,source:catalog,resource:key,appearance:appearance,template:true)
        }
    } else {missing.append(["name":name,"reason":"AppKit could not resolve catalog resource " + key])}
}
if let original = NSImage(systemSymbolName:"apple.logo",accessibilityDescription:nil),
   let symbol = original.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize:18,weight:.regular)) {
    try writePNG(symbol,name:"apple-logo-dark",pixels:72,source:"system-symbol:apple.logo",resource:"apple.logo",appearance:NSAppearance.Name.darkAqua.rawValue,template:true)
} else {missing.append(["name":"apple-logo-dark","reason":"AppKit system symbol apple.logo unavailable"])}
let os = ProcessInfo.processInfo.operatingSystemVersionString
let provenance: [String:Any] = ["host_os":os,"disk_utility_bundle_id":diskBundle.bundleIdentifier ?? "unknown","disk_utility_version":diskBundle.infoDictionary?["CFBundleShortVersionString"] ?? "unknown","disk_utility_build":diskBundle.infoDictionary?["CFBundleVersion"] ?? "unknown","assets":records,"missing":missing + [["name":"macos-installation","reason":"No Install macOS application or OS-specific recovery installer icon was found in the inspected installed locations; package installer artwork is not substituted."]],"limitations":["Rendered PNGs preserve original artwork but are rasterizations, not byte-identical copies of the source resources.","Toolbar source PNGs preserve catalog colors. Light/dark variants explicitly tint the original monochrome coverage with AppKit controlTextColor; catalog NSImage.isTemplate was false. Runtime per-state visibility and toolbar sizing must be measured separately.","The Time Machine icon is visual reference artwork, not a claim of Time Machine backup support.","Only explicitly listed files and catalog resources are read; target application code is not executed."]]
try JSONSerialization.data(withJSONObject:provenance,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("provenance.json"))
print("Rendered \(records.count) original resources; missing \(missing.count) requested installed resources.")
