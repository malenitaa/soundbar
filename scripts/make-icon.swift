// Generates the app icon: the extension's slider motif, redrawn at macOS
// icon geometry. Run with `swift scripts/make-icon.swift`; writes
// scripts/AppIcon.icns (bundled by build-app.sh) and docs/icon.png.
import AppKit

// NSBitmapImageRep with size pinned to pixel dimensions: lockFocus on a
// Retina display renders at 2x and doubles every size, this path doesn't.
func render(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let S = CGFloat(pixels)
    // macOS icon grid: the rounded square sits inside ~10% transparent margin.
    let margin = 0.098 * S
    let shape = S - 2 * margin
    let square = NSRect(x: margin, y: margin, width: shape, height: shape)
    let path = NSBezierPath(roundedRect: square, xRadius: 0.225 * shape, yRadius: 0.225 * shape)

    NSGradient(
        starting: NSColor(calibratedRed: 0.486, green: 0.525, blue: 0.925, alpha: 1),
        ending: NSColor(calibratedRed: 0.675, green: 0.486, blue: 0.910, alpha: 1)
    )!.draw(in: path, angle: -45)

    // Three sliders, knobs echoing the extension icon: right, left, middle.
    NSColor.white.setFill()
    let cx = S / 2, cy = S / 2
    let barLength = 0.60 * shape
    let barThickness = 0.055 * shape
    let knobRadius = 0.075 * shape
    let rows: [(y: CGFloat, knobX: CGFloat)] = [
        (cy + 0.22 * shape, cx + 0.18 * shape),
        (cy, cx - 0.15 * shape),
        (cy - 0.22 * shape, cx + 0.05 * shape),
    ]
    for row in rows {
        let bar = NSRect(
            x: cx - barLength / 2, y: row.y - barThickness / 2,
            width: barLength, height: barThickness
        )
        NSBezierPath(roundedRect: bar, xRadius: barThickness / 2, yRadius: barThickness / 2).fill()
        NSBezierPath(ovalIn: NSRect(
            x: row.knobX - knobRadius, y: row.y - knobRadius,
            width: knobRadius * 2, height: knobRadius * 2
        )).fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func writePNG(_ rep: NSBitmapImageRep, to path: String) {
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let scriptsDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().path
let root = URL(fileURLWithPath: scriptsDir).deletingLastPathComponent().path
let iconset = "\(scriptsDir)/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconset)
try! FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

for (name, pixels) in [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
] {
    writePNG(render(pixels: pixels), to: "\(iconset)/\(name).png")
}
writePNG(render(pixels: 512), to: "\(root)/docs/icon.png")

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset, "-o", "\(scriptsDir)/AppIcon.icns"]
try! iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
try? FileManager.default.removeItem(atPath: iconset)
print("Wrote \(scriptsDir)/AppIcon.icns and docs/icon.png")
