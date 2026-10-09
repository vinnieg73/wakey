// Renders AppIcon.icns from the menu bar "awake" face. Run: bash make-icon.sh
import AppKit

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: 1024, height: 1024)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    // "Night glow": dark tile, warm glow behind the awake face, subtle top shine.
    // macOS icon grid: 820pt rounded square centered in 1024.
    let tile = NSBezierPath(roundedRect: NSRect(x: 102, y: 102, width: 820, height: 820), xRadius: 184, yRadius: 184)
    NSGradient(starting: NSColor(srgbRed: 0x26 / 255.0, green: 0x30 / 255.0, blue: 0x4f / 255.0, alpha: 1),
               ending: NSColor(srgbRed: 0x12 / 255.0, green: 0x18 / 255.0, blue: 0x29 / 255.0, alpha: 1))?.draw(in: tile, angle: -90)
    NSGraphicsContext.saveGraphicsState()
    tile.addClip()
    let face = NSRect(x: 180, y: 200, width: 664, height: 664)
    let screenCenter = NSPoint(x: 512, y: face.maxY - face.height * 6.75 / 18)
    // Radial glow squashed into a 666x512 ellipse; fades fully to clear at its edge.
    let warm = NSColor(srgbRed: 1, green: 0xb3 / 255.0, blue: 0x47 / 255.0, alpha: 0.7)
    NSGraphicsContext.saveGraphicsState()
    let squash = NSAffineTransform()
    squash.translateX(by: screenCenter.x, yBy: screenCenter.y)
    squash.scaleX(by: 1, yBy: 512.0 / 666)
    squash.concat()
    NSGradient(starting: warm, ending: warm.withAlphaComponent(0))?
        .draw(fromCenter: .zero, radius: 0, toCenter: .zero, radius: 333, options: [])
    NSGraphicsContext.restoreGraphicsState()
    awakeIcon.draw(in: face)
    NSGradient(starting: NSColor(white: 1, alpha: 0.22), ending: NSColor(white: 1, alpha: 0))?
        .draw(in: NSRect(x: 102, y: 512, width: 820, height: 410), angle: -90)  // top → middle
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let dir = "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
for s in [16, 32, 128, 256, 512] {
    try! render(s).write(to: URL(fileURLWithPath: "\(dir)/icon_\(s)x\(s).png"))
    try! render(s * 2).write(to: URL(fileURLWithPath: "\(dir)/icon_\(s)x\(s)@2x.png"))
}
try! render(1024).write(to: URL(fileURLWithPath: "icon-preview-app.png"))
