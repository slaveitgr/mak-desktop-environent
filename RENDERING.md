# Rendering and motion · 0.6

The renderer is an independent Qt Quick implementation, tuned against the local macOS Tahoe Finder and Apple's published design explanation. It does not use Apple's Liquid Glass renderer or private APIs, and exact visual or temporal equivalence has not been established.

## Backdrop composition

The desktop scene contains wallpaper, desktop items and internal application windows. Dock, menus and popups live outside that scene, so they can sample it without capturing themselves.

Each Finder has a separate backdrop made from the desktop base and the internal application windows below it in stacking order. A window never samples itself or a higher window. This directed composition avoids texture feedback when windows overlap or change focus. The sidebar consequently responds to lower windows as well as the wallpaper.

A glass surface captures a padded local region, clamps that region to scene boundaries and creates a blurred texture. The fragment shader combines the blurred region with limited sharp transmission around the edge. A rounded-rectangle distance field supplies the boundary normal for refraction and directional highlights. Tint depends on appearance and sampled luminance. The rim and an inner falloff replace a uniform white outline.

## Material presets

| Surface | Light tint | Dark tint | Refraction strength | Character |
| --- | ---: | ---: | ---: | --- |
| Dock | 0.14 | 0.18 | 9 | Clear lens, colored background |
| Finder sidebar | 0.76 | 0.86 | 4 | Regular material, readable navigation |
| Menus | 0.78 | 0.76 | 6 | Regular material, stronger separation |

These are implementation parameters, not measured Apple material constants. The normal menu bar defaults to a fully transparent background. The optional Show menu bar background preference adds an independent translucent dark treatment; its opacity has not been measured against Tahoe. Full-screen reveal uses an opaque black background. Reduce Transparency replaces glass with opaque surfaces; the choice is saved between runs.

## Motion

| Interaction | Implemented transition |
| --- | --- |
| Dock hover | Continuous distance-based enlargement with 110 ms interpolation |
| Dock labels | 300 ms delay, 110 ms fade |
| Finder reopening | Two diminishing Dock hops and a 220 ms window reveal |
| Minimize / restore | 32 × 40 vertex mesh, curved funnel and travel to the window's Dock slot, 560 ms |
| Zoom | 280 ms geometry interpolation |
| Window full screen | 420 ms geometry interpolation; prior geometry restored on exit |
| Full-screen menu reveal | 3 px top edge; 180 ms slide; 350 ms hide grace |
| Dock reveal | 3 px bottom edge; 180 ms dwell; 220 ms slide; 350 ms hide grace |
| Close | 140 ms fade, followed by actual window/browser destruction |
| Popups | Anchored scale, fade and optical materialization |
| Appearance | Preloaded wallpapers with a 220 ms crossfade |

The minimize texture is rounded before deformation to prevent rectangular shadow fragments at the corners. Minimized Dock items show the actual Finder surface. Restore reverses the same deformation. Reduce Motion removes the main transitions and magnification; it does not change file operations.

## Shader build

The release includes compiled `.qsb` packages; users do not need a shader compiler to launch it. To rebuild after editing GLSL, run `build_shaders.py` with the same PySide6 environment as the application. It uses the bundled Qt 6.8.3 `qsb --qt6` compiler and includes SPIR-V, GLSL, Metal and HLSL representations. Compilation for a backend is not evidence of a hardware test on that backend.

## Verification and remaining gaps

The earlier 0.3 milestone passed 27 filesystem/browser/full-screen/application-adapter tests, compiled-shader checks and a QML launch smoke check. The 0.4 milestone passes 96 unit/integration tests and the focused QML/application checks listed in README.md. Live macOS UI checks covered overlapping-window glass, Dock material over a moved window, magnification, minimize/restore, zoom, dragging, close/reopen, menu keyboard traversal, saved dark appearance and opaque fallbacks. A dragging regression introduced while reorganizing the render layers was fixed and rechecked. Accessibility-driven appearance changes were also corrected and verified.

No pixel-difference benchmark, synchronized native animation capture, GPU frame-time benchmark or Linux graphics-driver test has been completed. The optical profile, blur response, shadow distribution and easing remain approximations. Full-screen presentation is implemented inside the Qt workspace; actual compositor Spaces transitions, the exact native Dock geometry and the complete Finder control set are not replicated. The shell still runs in one application window and does not manage external Linux windows.

## References

Apple describes lensing, refraction, adaptive materials and their relationship to motion in [Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/). The GPU implementation follows Qt's [ShaderEffect pipeline and uniform conventions](https://doc.qt.io/qt-6/qml-qtquick-shadereffect.html). Native Finder geometry was inspected on the local Tahoe installation; Apple's shaders and animation constants were not extracted.

## Native reference pass in 0.3

The local reference was Tahoe 26.7.2. The Finder showed a 231 px sidebar split, approximately 112 px icon-grid spacing, a compact view picker at normal widths and a wider view selector at full-screen widths. Its inactive state removes the sidebar material and toolbar capsule outlines and dims the folder title. The prototype now distinguishes these states explicitly, including when the host app loses focus.

The folder artwork is obtained through public `NSWorkspace.icon(forFile:)`; this differs from the older `GenericFolderIcon.icns` bitmap. Symbol artwork is exported through public `NSImage(systemSymbolName:)`, with specific CoreTypes sidebar assets where appropriate. The source manifest lives in `assets/symbols/sources.json`; tinting uses a separate premultiplied-alpha shader. No private renderer or original application source has been extracted.

System Settings was inspected locally for sidebar width, toolbar arrangement, rounded setting groups and the Appearance/Clear/Tinted controls. Its prototype counterpart implements a selected set of real preferences. The thumbnail illustrations, materials, settings coverage and transitions remain independent approximations. The Clear/Tinted choice alters material opacity; it does not invoke Apple's renderer.

Apple explicitly describes the [transparent Tahoe menu bar](https://www.apple.com/newsroom/2025/06/macos-tahoe-26-makes-the-mac-more-capable-productive-and-intelligent-than-ever/) and [top-edge menu-bar reveal in full screen](https://support.apple.com/en-ie/guide/mac-help/mchl9c21d2be/mac). The public AppKit [visual-effect state API](https://developer.apple.com/documentation/appkit/nsvisualeffectview/state-swift.property) provides additional reference for following window activation. These document behavior; they do not supply Apple's exact shaders or timing constants.

The expanded Dock contains 21 built-in application entries (Finder, Apps, 18 additional applications and System Settings), followed by Downloads, minimized windows and Trash. Resting icon size adapts to the viewport width and the size preference. Removing a pin does not remove a running application. Application hiding is separate from minimization and does not generate a thumbnail. All built-in windows participate in the internal QML scene; external host windows do not.


## Resource-driven pass in 0.4

REA decoded 25 installed app/shell targets and four modern Settings extensions. The source-bound audit is `reference/coverage.json`; it separates observed labels, assets and connections from inferred grouping and unverified runtime geometry. In particular, AppIcon layers in the Apps bundle do not establish the live launcher layout. Legacy/debug menus and shared picker nibs do not establish an application's current main window.

The corresponding implementation adds contextual app menus, Finder Sort By/Tags submenus, scrollable bounded menus, per-application Hide/Hide Others, Control Center panels, real application windows and configurable clock/menu-bar modes. Menu glass samples its actual parent-relative scene position, including submenus. Clock options and Show menu bar background use labels observed in the ControlCenterSettings extension. Initial values, grouping, opacity and timings remain independent choices pending runtime comparison.

Photo Booth's live effect shader and saved-image pipeline share luminance/transfer-function math for Normal, B&W, Sepia, Mirror and horizontal flip. Synthetic color checks allow one code value of rounding difference. Four-photo capture generates independent PNGs and a 2×2 contact sheet. Hardware camera color spaces, orientation and live preview synchronization remain unverified.

Final 0.4 checks run in isolated offscreen instances. They exercise shell/menu state, all application pages, SQLite data, a local browser server, calculator input, asynchronous chess, synthetic captures and silent media playback. The Mac locked during development, so there is no final 0.4 live visual sign-off. Earlier native comparisons remain useful references but do not validate the new UI or prove 1:1 fidelity.


## Live refinement pass in 0.5

The unlocked native Finder window was observed at 960×481 pt, with a floating 222 pt sidebar, 32 pt rows, 112 pt icon pitch and a compact 35 pt toolbar capsule. The prototype's sidebar alignment, icon-selection plate and label spacing were corrected from those measurements. Native Appearance Settings was observed at 723×861 pt with a 223 pt sidebar and content beginning at x=243/y=52. The reconstructed Appearance page now uses its native 67×44 pt appearance/glass previews and extracted category icons. Values are recorded in `reference/visual-comparison-0.5.json`; these observations are not an exhaustive pixel diff.

The Dock regression was a layout-order bug: the new thumbnail existed before its Row assigned its horizontal position. Synchronously resolving that layout before mapping the thumbnail fixes the leftward minimize target. Mapping its entire rectangle includes magnification and pressed scaling. Full-screen interruption tests also preserve logical restore bounds when entering again during an exit animation. Native motion curves have not been recovered or measured frame by frame.

The desktop file surface shares the reversible workspace backend with Finder. Drag previews render in a common overlay and file mutations are deferred until drop delivery finishes, avoiding destruction of the source delegate during its mouse-release event. Popup rollover is tracked in the popup overlay, where Qt delivers pointer events while menus are open.


## Control Center pass in 0.6

Status-panel anchors are derived from the clicked icon's right edge and clamped to the viewport. A pointer tracker in the popup overlay enables adjacent-icon switching while a popup owns the pointer. Its coordinates map to the desktop item, not a transient/null overlay parent, avoiding host-window coordinate offsets. Shared preference values drive both Settings and panel controls. Persisted layout JSON and visible-ID strings gate model updates, preserving live slider delegates and pointer grabs when unrelated preferences change.

Menu Bar settings follows the native 45 pt rows, left checkbox/category-icon columns and trailing options buttons. Clock and Battery sheets follow their observed field groups. Settings windows reserve space above the Dock so Reset and other bottom actions remain clickable on shorter hosts. Control Center/gallery use the existing scene-sampling Glass material and reduced-motion/transparency settings. Exact native gallery geometry and motion curves remain unverified.
