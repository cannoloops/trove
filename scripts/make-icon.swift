// Genera Resources/AppIcon.icns: scrigno stilizzato (pila di card) su fondo blu notte con accento oro.
import AppKit
let out = CommandLine.arguments[1]
let set = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: set)
try! FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let inset = s * 0.09
    let bg = NSBezierPath(roundedRect: NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset), xRadius: s * 0.19, yRadius: s * 0.19)
    NSGradient(colors: [NSColor(red: 0.12, green: 0.15, blue: 0.30, alpha: 1), NSColor(red: 0.05, green: 0.06, blue: 0.14, alpha: 1)])!.draw(in: bg, angle: -90)
    let gold = NSColor(red: 0.91, green: 0.71, blue: 0.29, alpha: 1)
    for i in 0..<3 {
        let w = s * (0.42 - CGFloat(i) * 0.04), h = s * 0.30
        let x = s * 0.5 - w / 2 + CGFloat(i - 1) * s * 0.07, y = s * 0.30 + CGFloat(i) * s * 0.075
        let card = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: s * 0.035, yRadius: s * 0.035)
        (i == 2 ? NSColor.white : NSColor.white.withAlphaComponent(0.35 + 0.2 * CGFloat(i))).setFill()
        card.fill()
        if i == 2 {
            gold.setFill()
            NSBezierPath(roundedRect: NSRect(x: x, y: y + h - s * 0.075, width: w, height: s * 0.075), xRadius: s * 0.035, yRadius: s * 0.035).fill()
            NSColor(white: 0.75, alpha: 1).setFill()
            for l in 0..<3 { NSBezierPath(rect: NSRect(x: x + s * 0.03, y: y + s * 0.05 + CGFloat(l) * s * 0.045, width: w * (l == 0 ? 0.5 : 0.8), height: s * 0.018)).fill() }
        }
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}
for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128), ("128x128@2x", 256),
                   ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    try! render(px).write(to: set.appendingPathComponent("icon_\(name).png"))
}
let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil"); p.arguments = ["-c", "icns", set.path, "-o", out]
try! p.run(); p.waitUntilExit()
